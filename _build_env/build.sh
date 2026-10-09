#!/usr/bin/env bash
# ST313 site: render, check, publish. Lives at _build_env/build.sh in the ethics4ds repository.
# _build_env/README.md has the whole process; this is the list of commands.
#
# The usual flow (from 8 October 2026, the same as ST310's): work on a branch of the fork, then
#   WEEK=03 _build_env/build.sh build
# and commit everything it changed, docs/ and _freeze/ included. Merging the pull request publishes.
#
#   _build_env/build.sh build                 student, registry, instructor, solutions, site, check (WEEK=NN limits the instructor and solutions renders)
#   _build_env/build.sh student               regenerate every weeks/wk*/class.qmd from weeks/wk*/instructor/class_complete.qmd
#   _build_env/build.sh registry              build _registry/results_all.md and items_all.yaml from the spine and every week; check R-numbers and item ids
#   _build_env/build.sh instructor            render the teacher pages -> _instructor_rendered/wkNN/ (deck with notes, teacher's class sheet, teacher note)
#   _build_env/build.sh solutions             render each week's class sheet with solutions -> _solutions/wkNN/ (tracked, not published);
#                                             a week whose source has not changed is skipped (FORCE=1 renders it again)
#   _build_env/build.sh site                  public render -> docs/ (unchanged pages come from _freeze/), teacher pages kept
#                                             (everything for teachers -> docs/teachers/wkNN/; for a released week, its stored class sheet
#                                             with solutions -> docs/solutions/wkNN/)
#   _build_env/build.sh check                 gates; non-zero exit on any FAIL
#   _build_env/build.sh push "<commit message>"    stage, check, commit, push the current branch (refuses on main)
#   _build_env/build.sh import <packet-folder> <NN>                       Dropbox fallback: copy a packet to weeks/wkNN/ (needs rsync)
#   _build_env/build.sh deploy <packet-folder> <NN> "<commit message>"    Dropbox fallback: import, build, push
#
# WEEK=02 restricts the instructor and solutions renders to weeks/wk02/. The instructor renders always
# execute their code, so rendering a week you did not change rewrites its teacher pages for nothing.
# SPINE=<folder> is where results.md and readings.csv are read from. The default is the convenor's
# Dropbox path; an agent fetches the two files to a folder outside the repository (README, "The spine files").
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=$(pwd)
SPINE="${SPINE:-$HOME/Dropbox/elthre3/teaching/ST313/proposals/spine}"
SITE="ethics4ds.com"
SPINE_WARNED=""

spine_warn() {   # one line per run, however many steps read the spine
  [ -z "$SPINE_WARNED" ] || return 0
  SPINE_WARNED=1
  echo "WARN: no spine files at $SPINE (results.md, readings.csv): R-numbers and reading ids are not checked. See _build_env/README.md, \"The spine files\"."
}

import() {
  local src="${1:?packet folder required}" nn="${2:?week number required, e.g. 02}"
  [ -d "$src" ] || { echo "no such folder: $src"; exit 1; }
  mkdir -p "weeks/wk$nn"
  # class.qmd is generated; a packet's CHANGELOG.md stays in Dropbox.
  rsync -av --exclude='/CHANGELOG.md' --exclude='class_incomplete.qmd' --exclude='/class.qmd' --exclude='.DS_Store' "$src/" "weeks/wk$nn/"
}

student() {
  local c s
  for c in weeks/wk*/instructor/class_complete.qmd; do
    [ -e "$c" ] || continue
    s="$(dirname "$(dirname "$c")")/class.qmd"
    python3 _build_env/make_incomplete.py "$c" "$s"
  done
}

registry() {
  local r y
  rm -rf _registry
  mkdir -p _registry
  [ -e "$SPINE/results.md" ] || spine_warn
  {
    echo "# ST313 results, all weeks (built by build.sh registry; do not edit)"
    echo
    if [ -e "$SPINE/results.md" ]; then cat "$SPINE/results.md"; fi
    for r in weeks/wk*/instructor/results.md; do
      [ -e "$r" ] || continue
      echo; echo "<!-- $r -->"; echo; cat "$r"
    done
  } > _registry/results_all.md
  {
    for y in weeks/wk*/instructor/items.yaml; do
      [ -e "$y" ] || continue
      echo "# --- $y"; cat "$y"; echo
    done
  } > _registry/items_all.yaml
  python3 - <<'EOF'
import re, sys
txt = open("_registry/results_all.md").read()
nums = [int(n) for n in re.findall(r"^#+\s*R(\d+)\b", txt, flags=re.M)]   # entry headings only, not prose lines such as "R1."
seen, gaps, dups = set(), [], []
for n in nums:
    if n in seen: dups.append(n)
    seen.add(n)
expected = list(range(1, max(seen) + 1)) if seen else []
gaps = [n for n in expected if n not in seen]
print(f"results registry: R1..R{max(seen) if seen else 0}; duplicates {dups or 'none'}; gaps {gaps or 'none'}")
ids = re.findall(r"^\s*-?\s*id:\s*(W\d\d-I\d+)\s*$", open("_registry/items_all.yaml").read(), flags=re.M)   # id: fields only, not comments
d = sorted({i for i in ids if ids.count(i) > 1})
print(f"item bank: {len(ids)} items; duplicate ids {d or 'none'}")
sys.exit(1 if dups or d else 0)
EOF
}

released() {   # a week's class sheet with solutions is released when its block on the course page links to it
  grep -q "solutions/$1/class_solutions.html" "weeks/$1/_index.qmd" 2>/dev/null
}

# The class sheet with solutions is rendered when its week is built and stored, tracked, in
# _solutions/wkNN/ (convenor, 9 October 2026). Nothing there is published: site copies a week's
# stored page to docs/solutions/wkNN/ only once the week's block links to it. So a release adds
# a link and copies a file; it renders nothing and needs no R.
SOL=_solutions

sol_state() {   # current | stale | missing | none, for week $1 (wkNN)
  local c="weeks/$1/instructor/class_complete.qmd"
  [ -e "$c" ] || { echo none; return 0; }
  [ -e "$SOL/$1/class_solutions.html" ] || { echo missing; return 0; }
  if [ "$(cat "$SOL/$1/class_solutions.sha256" 2>/dev/null)" = "$(python3 _build_env/make_incomplete.py --solutions-hash "$c")" ]; then
    echo current
  else
    echo stale
  fi
}

render_out() {   # render one file under instructor/, self-contained, and move the page to its place in _instructor_rendered/
  local src="$1" dest="$2" out="${1%.qmd}.html"
  if ! quarto render "$src" -M embed-resources:true; then echo "RENDER FAILED: $src"; return 1; fi
  # The output is under docs/ (project output-dir) or, if Quarto treats the file as
  # outside the project, beside the source. Move either out.
  if [ -e "docs/$out" ]; then
    mv "docs/$out" "$dest"
  elif [ -e "$out" ]; then
    mv "$out" "$dest"
  else
    echo "RENDER FAILED: no output found for $src"; return 1
  fi
}

instructor() {
  local d nn f failed=0
  # Start empty: site copies every teacher page it finds here, and a render left over from
  # another branch or an earlier source would be published as if it were current.
  rm -rf _instructor_rendered
  mkdir -p _instructor_rendered
  for d in weeks/wk${WEEK:-*}; do
    [ -d "$d" ] || continue
    nn=$(basename "$d")
    mkdir -p "_instructor_rendered/$nn"
    # The deck with speaker notes kept, self-contained. A single-file render inside a
    # Quarto project lands under docs/, so it is moved out at once.
    if [ -e "$d/slides.qmd" ]; then
      ST313_KEEP_NOTES=1 quarto render "$d/slides.qmd" -M embed-resources:true
      mv "docs/$d/slides.html" "_instructor_rendered/$nn/slides-instructor.html"
    fi
    # The teacher's class sheet and the teacher note, self-contained. Nothing else in instructor/ is rendered.
    for f in class_complete teacher_note; do
      [ -e "$d/instructor/$f.qmd" ] || continue
      render_out "$d/instructor/$f.qmd" "_instructor_rendered/$nn/$f.html" || failed=1
    done
    rm -rf "docs/$d/instructor"
  done
  echo "teacher renders in _instructor_rendered/"
  return "$failed"
}

solutions() {
  # The class sheet with solutions is a separate document, for students, generated from the teacher's
  # sheet. It is rendered here, when the week is built, and kept in _solutions/wkNN/ with the hash of
  # its generated source. A week whose source has not changed since its stored page was rendered is
  # skipped, so a released page does not change under the students when another week is built.
  # The hash covers the source only: after a change to data, packages or the theme, use FORCE=1.
  local d nn c failed=0
  for d in weeks/wk${WEEK:-*}; do
    c="$d/instructor/class_complete.qmd"
    [ -e "$c" ] || continue
    nn=$(basename "$d")
    if [ -z "${FORCE:-}" ] && [ "$(sol_state "$nn")" = current ]; then
      echo "class sheet with solutions for $nn: stored page is current, not rendered again (FORCE=1 to render)"
      continue
    fi
    python3 _build_env/make_incomplete.py --solutions "$c" "$d/instructor/class_solutions.qmd"
    mkdir -p "$SOL/$nn"
    if render_out "$d/instructor/class_solutions.qmd" "$SOL/$nn/class_solutions.html"; then
      python3 _build_env/make_incomplete.py --solutions-hash "$c" > "$SOL/$nn/class_solutions.sha256"
    else
      failed=1
    fi
    rm -f "$d/instructor/class_solutions.qmd"
    rm -rf "docs/$d/instructor"
  done
  echo "class sheets with solutions in $SOL/"
  return "$failed"
}

site() {
  local keep d w nn f
  # The teacher pages of weeks not re-rendered this time exist only in docs/: keep them across the
  # clean render. docs/solutions/ is not kept: it is filled again below from _solutions/.
  keep=$(mktemp -d)
  for d in teachers; do
    [ -d "docs/$d" ] && mv "docs/$d" "$keep/$d"
  done
  rm -rf docs .quarto
  quarto render
  echo "$SITE" > docs/CNAME
  touch docs/.nojekyll
  # Quarto stamps each sitemap entry with its source file's modification time, which in a fresh
  # clone is the clone time: every branch would rewrite every line and no two would merge.
  if [ -f docs/sitemap.xml ]; then
    grep -v '<lastmod>' docs/sitemap.xml > docs/sitemap.xml.tmp && mv docs/sitemap.xml.tmp docs/sitemap.xml
  fi
  for d in teachers; do
    [ -d "$keep/$d" ] || continue
    mkdir -p "docs/$d"
    cp -R "$keep/$d/." "docs/$d/"
  done
  rm -rf "$keep"
  # Every week has the same file names, so the published path keeps the week.
  for w in _instructor_rendered/wk*; do
    [ -d "$w" ] || continue
    nn=$(basename "$w")
    # Everything students do not need: the deck with speaker notes, the teacher's class sheet, the teacher note.
    for f in slides-instructor class_complete teacher_note; do
      [ -e "$w/$f.html" ] || continue
      mkdir -p "docs/teachers/$nn"
      cp "$w/$f.html" "docs/teachers/$nn/"
    done
  done
  # A class sheet with solutions is published exactly while its week's block links to it: the stored
  # page is copied, nothing is rendered.
  for w in weeks/wk*; do
    [ -d "$w" ] || continue
    nn=$(basename "$w")
    if released "$nn" && [ -e "$SOL/$nn/class_solutions.html" ]; then
      mkdir -p "docs/solutions/$nn"
      cp "$SOL/$nn/class_solutions.html" "docs/solutions/$nn/"
    fi
  done
}

build() {
  student
  registry
  instructor
  solutions
  site
  check
}

check() {
  local fail=0 n w missing st
  local args=()
  [ -d docs ] || { echo "FAIL: no docs/ (run site first)"; return 1; }
  # ---- what is published where
  n=$(find docs -path 'docs/weeks/*/instructor*' | wc -l | tr -d ' ')
  [ "$n" -eq 0 ] || { echo "FAIL: instructor material under docs/weeks/"; fail=1; }
  n=$(find docs \( -name '*_complete*' -o -name 'teacher_note*' -o -name '*-instructor*' \) -not -path 'docs/teachers/*' | wc -l | tr -d ' ')
  [ "$n" -eq 0 ] || { echo "FAIL: a teacher's class sheet, teacher note or deck with notes under docs/ outside teachers/"; fail=1; }
  n=$(find docs \( -name 'items*.yaml' -o -name 'items*.yml' -o -name 'results*.md' \) | wc -l | tr -d ' ')
  [ "$n" -eq 0 ] || { echo "FAIL: item bank or results file under docs/"; fail=1; }
  # Answers: only under teachers/ and solutions/. In a source they are .answer divs or Solution callouts; in a page, a callout with class "answer".
  if grep -rlq --exclude-dir=teachers --exclude-dir=solutions -e 'title="Solution"' -e '\.answer' -e 'SOLUTION START' docs --include='*.qmd'; then echo "FAIL: answers in a .qmd under docs/"; fail=1; fi
  if grep -rlqE --exclude-dir=teachers --exclude-dir=solutions -e '<div class="(answer|[^"]* answer)[ "]' -e 'title="Solution"' docs --include='*.html'; then echo "FAIL: answer boxes in a page under docs/ outside teachers/ and solutions/"; fail=1; fi
  # Speaker notes: only under teachers/.
  if grep -rlq --exclude-dir=teachers 'class="notes"' docs --include='*.html'; then echo "FAIL: speaker notes under docs/ outside teachers/"; fail=1; fi
  # A class sheet with solutions is published exactly when its week's block on the course page links to it,
  # and what is published is the stored page, made from the teacher's sheet as it is now. For a week not
  # yet released a missing or old stored page is a WARN, for the week's own agent: it must not stop
  # another week's push. For a released week it is a FAIL: students would get no page or an old one.
  for w in weeks/wk*; do
    [ -d "$w" ] || continue
    n=$(basename "$w")
    st=$(sol_state "$n")
    if released "$n"; then
      case "$st" in
        missing|none) echo "FAIL: $w/_index.qmd links to a class sheet with solutions, and there is no stored page $SOL/$n/class_solutions.html (run WEEK=${n#wk} _build_env/build.sh solutions, then site; needs R)"; fail=1 ;;
        stale) echo "FAIL: the class sheet with solutions for $n is older than $w/instructor/class_complete.qmd (run WEEK=${n#wk} _build_env/build.sh solutions, then site; needs R)"; fail=1 ;;
      esac
      if [ -e "$SOL/$n/class_solutions.html" ] && ! cmp -s "$SOL/$n/class_solutions.html" "docs/solutions/$n/class_solutions.html"; then
        echo "FAIL: docs/solutions/$n/class_solutions.html is missing or is not the stored page in $SOL/$n/ (run _build_env/build.sh site)"; fail=1
      fi
    else
      if [ -e "docs/solutions/$n" ]; then echo "FAIL: docs/solutions/$n is published but $w/_index.qmd does not link to it (not released)"; fail=1; fi
      case "$st" in
        missing) echo "WARN: no stored class sheet with solutions for $n (run WEEK=${n#wk} _build_env/build.sh build); without it the week's release has to render it" ;;
        stale) echo "WARN: the stored class sheet with solutions for $n is older than $w/instructor/class_complete.qmd (run WEEK=${n#wk} _build_env/build.sh build)" ;;
      esac
    fi
  done
  # _solutions/ holds one page and its source hash per week, and none of it is under docs/ before release.
  if [ -d "$SOL" ]; then
    n=$(find "$SOL" -type f -not -path "$SOL/wk*/class_solutions.html" -not -path "$SOL/wk*/class_solutions.sha256" | tr '\n' ' ')
    [ -z "$n" ] || { echo "FAIL: something other than wkNN/class_solutions.html and its .sha256 under $SOL/: $n"; fail=1; }
  fi
  [ ! -e "docs/$SOL" ] || { echo "FAIL: docs/$SOL exists: the stored class sheets with solutions were published"; fail=1; }
  if [ -d docs/solutions ]; then
    n=$(find docs/solutions -type f -not -path 'docs/solutions/wk*/class_solutions.html' | wc -l | tr -d ' ')
    [ "$n" -eq 0 ] || { echo "FAIL: something other than wkNN/class_solutions.html under docs/solutions/"; fail=1; }
  fi
  if grep -rlq '^st313:' docs --include='*.qmd'; then echo "FAIL: st313: block in a downloadable .qmd under docs/"; fail=1; fi
  [ "$(cat docs/CNAME 2>/dev/null)" = "$SITE" ] || { echo "FAIL: docs/CNAME"; fail=1; }
  [ -e docs/.nojekyll ] || { echo "FAIL: docs/.nojekyll missing"; fail=1; }
  # ---- what git would commit: tracked files and untracked files that are not ignored
  # Under instructor/ only the complete class sheet and the teacher note.
  n=$(git ls-files --cached --others --exclude-standard | grep '/instructor/' | grep -vEc '^weeks/wk[0-9]+/instructor/(class_complete|teacher_note)\.qmd$' || true)
  [ "$n" -eq 0 ] || { echo "FAIL: files other than class_complete.qmd and teacher_note.qmd under an instructor/ folder would be committed"; fail=1; }
  # Assessments never go in the repository, under any name: exams, problem sets, the item bank, private folders.
  n=$(git ls-files --cached --others --exclude-standard | grep -iE '(^|/)private/|(^|[/_-])exams?[0-9]*([._/-]|$)|problem[_-]?sets?[0-9]*([._/-]|$)|(^|[/_-])psets?[0-9]*([._/-]|$)|held_problems|(^|[/_-])items?[^/]*\.ya?ml$|item[_-]?bank' | tr '\n' ' ' || true)
  [ -z "$n" ] || { echo "FAIL: looks like an exam, a problem set, the item bank or a private folder: $n"; fail=1; }
  # ---- student sheets
  for w in weeks/wk*; do
    [ -d "$w" ] || continue
    if [ -e "$w/class.qmd" ] && [ ! -e "docs/$w/class.qmd" ]; then echo "FAIL: $w/class.qmd not copied to docs/ (check the resources: pattern in _quarto.yml)"; fail=1; fi
  done
  # ---- every week in the tree is on the course page: index.qmd includes one block per week, by name
  for w in weeks/wk*; do
    [ -e "$w/_index.qmd" ] || { [ -d "$w" ] && { echo "FAIL: $w has no _index.qmd (the week's block on the course page)"; fail=1; }; continue; }
    grep -qE "^\{\{< include $w/_index\.qmd >\}\}[[:space:]]*$" index.qmd || { echo "FAIL: index.qmd does not include $w/_index.qmd, so the week is not on the course page (add the line {{< include $w/_index.qmd >}})"; fail=1; }
  done
  # ---- teacher pages are self-contained (no _files or site_libs folder is published beside them)
  if grep -lqE '(src|href)="[^":]*(_files|site_libs)/' docs/teachers/*/*.html docs/solutions/*/*.html "$SOL"/*/*.html 2>/dev/null; then echo "FAIL: a page under docs/teachers/, docs/solutions/ or $SOL/ is not self-contained"; fail=1; fi
  # ---- every deck uses MathJax 4 (html-math-method in _quarto.yml). A deck that ends up without a math
  # method gets MathJax 2.7.9 from reveal's plugin; one that names another URL gets that.
  if grep -rlq --include='*.html' -e "mathjax: 'https://cdn.jsdelivr.net/npm/mathjax@[0-3]" docs; then echo "FAIL: a deck loads a MathJax older than 4 (check html-math-method in its YAML and in _quarto.yml)"; fail=1; fi
  # ---- warnings
  # Nothing under teachers/ is linked from a public page. What students get, the week after the class,
  # is the class sheet with solutions under solutions/.
  n=$(grep -rlE --include='*.html' --exclude-dir=teachers -e 'href="[^"]*teachers/' docs | tr '\n' ' ' || true)
  [ -z "$n" ] || echo "WARN: a page outside teachers/ links to a teacher page: $n"
  # The site is built with one Quarto version; another one rewrites every page.
  if [ -f _build_env/QUARTO_VERSION ] && [ "$(quarto --version 2>/dev/null)" != "$(cat _build_env/QUARTO_VERSION)" ]; then
    echo "WARN: quarto $(quarto --version 2>/dev/null) here, site built with $(cat _build_env/QUARTO_VERSION): every page will change"
  fi
  # ---- contract and style (check_st313.py). Reading ids need the spine; R-numbers need the spine
  # and every week's results.md, which are not in the repository.
  if [ -e "$SPINE/readings.csv" ]; then args=(--readings "$SPINE/readings.csv"); else spine_warn; fi
  missing=""
  for w in weeks/wk*; do
    [ -d "$w" ] || continue
    [ -e "$w/instructor/results.md" ] || missing="$missing $(basename "$w")"
  done
  if [ ! -e "$SPINE/results.md" ]; then
    spine_warn
  elif [ -n "$missing" ]; then
    echo "WARN: no instructor/results.md for$missing: R-numbers are not checked"
  elif [ -e _registry/results_all.md ]; then
    args+=(--results _registry/results_all.md)
  fi
  for w in weeks/wk*; do
    [ -d "$w" ] || continue
    python3 _build_env/check_st313.py "$w" ${args[@]+"${args[@]}"} ||
      echo "WARN: contract checks failed for $w (the FAIL lines above, from check_st313.py); fix them, they do not stop the push"
  done
  if [ "$fail" -eq 0 ]; then echo "checks passed"; fi
  return "$fail"
}

push() {
  local msg="${1:?commit message required}" b
  b=$(git rev-parse --abbrev-ref HEAD)
  [ "$b" != "main" ] || { echo "on main: agents push a branch claude/<week>-<topic> to the fork and the convenor merges"; exit 1; }
  # Stage first, so that check sees exactly what the commit would contain.
  git add -A
  check
  git commit -m "$msg"
  git push -u origin HEAD
}

deploy() {
  import "${1:?packet folder required}" "${2:?week number required}"
  student
  registry
  instructor
  solutions
  site
  push "${3:?commit message required}"
}

cmd="${1:-}"; shift || true
case "$cmd" in
  import|student|registry|instructor|solutions|site|build|check|push|deploy) "$cmd" "$@" ;;
  *) sed -n '2,26p' "$0"; exit 1 ;;
esac
