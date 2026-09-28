#!/usr/bin/env bash
# ST313 site: import a week packet from Dropbox, generate, render, check, deploy.
# Lives at _build_env/build.sh inside the ethics4ds repo clone, ~/work/teaching/ethics4ds.
#
#   _build_env/build.sh import <packet-folder> <NN>    copy a Dropbox packet (wkNN or wkNN-fix-<date>) to weeks/wkNN/ (rsync; skips CHANGELOG.md)
#   _build_env/build.sh student                        regenerate every weeks/wk*/class.qmd from weeks/wk*/instructor/class_complete.qmd
#   _build_env/build.sh registry                       build _instructor_rendered/results_all.md and items_all.yaml from the spine + every week; check R-number continuity
#   _build_env/build.sh instructor                     render instructor material -> _instructor_rendered/wkNN/ (decks with notes, complete class sheet, teacher note, board scripts html+pdf)
#   _build_env/build.sh site                           clean public render -> docs/, restore CNAME
#   _build_env/build.sh check                          gates (non-zero exit on failure) + style warnings
#   _build_env/build.sh push "<commit message>"        check, then git add/commit/push
#   _build_env/build.sh deploy <packet-folder> <NN> "<commit message>"   import, student, registry, instructor, site, check, push
#
# WEEK=02 _build_env/build.sh instructor    restricts the instructor renders to weeks/wk02/.
# SPINE=~/Dropbox/elthre3/teaching/ST313/proposals/spine   where results.md and readings.csv are read from (default shown).
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=$(pwd)
SPINE="${SPINE:-$HOME/Dropbox/elthre3/teaching/ST313/proposals/spine}"

import() {
  local src="${1:?packet folder required}" nn="${2:?week number required, e.g. 02}"
  [ -d "$src" ] || { echo "no such folder: $src"; exit 1; }
  mkdir -p "weeks/wk$nn"
  rsync -av --exclude='/CHANGELOG.md' --exclude='class_incomplete.qmd' --exclude='class.qmd' --exclude='.DS_Store' "$src/" "weeks/wk$nn/"
  # a packet delivered in the old flat layout is moved into the split layout
  local w="weeks/wk$nn"
  if [ -e "$w/class_complete.qmd" ] || [ -e "$w/teacher_note.md" ] || [ -e "$w/items.yaml" ]; then
    mkdir -p "$w/instructor"
    for f in class_complete.qmd teacher_note.md teacher_note.qmd board.qmd items.yaml results.md; do
      [ -e "$w/$f" ] && mv "$w/$f" "$w/instructor/$f"
    done
    [ -e "$w/instructor/teacher_note.md" ] && mv "$w/instructor/teacher_note.md" "$w/instructor/teacher_note.qmd"
    echo "moved instructor files of wk$nn into $w/instructor/"
  fi
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
  mkdir -p _instructor_rendered
  {
    echo "# ST313 results, all weeks (built by build.sh registry; do not edit)"
    echo
    [ -e "$SPINE/results.md" ] && cat "$SPINE/results.md"
    for r in weeks/wk*/instructor/results.md; do
      [ -e "$r" ] || continue
      echo; echo "<!-- $r -->"; echo; cat "$r"
    done
  } > _instructor_rendered/results_all.md
  {
    for y in weeks/wk*/instructor/items.yaml; do
      [ -e "$y" ] || continue
      echo "# --- $y"; cat "$y"; echo
    done
  } > _instructor_rendered/items_all.yaml
  python3 - <<'EOF'
import re, sys
txt = open("_instructor_rendered/results_all.md").read()
nums = [int(n) for n in re.findall(r"^#+\s*R(\d+)\b", txt, flags=re.M)]   # entry headings only, not prose lines such as "R1."
seen, gaps, dups = set(), [], []
for n in nums:
    if n in seen: dups.append(n)
    seen.add(n)
expected = list(range(1, max(seen) + 1)) if seen else []
gaps = [n for n in expected if n not in seen]
print(f"results registry: R1..R{max(seen) if seen else 0}; duplicates {dups or 'none'}; gaps {gaps or 'none'}")
ids = re.findall(r"^\s*-?\s*id:\s*(W\d\d-I\d+)\s*$", open("_instructor_rendered/items_all.yaml").read(), flags=re.M)   # id: fields only, not comments
d = sorted({i for i in ids if ids.count(i) > 1})
print(f"item bank: {len(ids)} items; duplicate ids {d or 'none'}")
sys.exit(1 if dups or d else 0)
EOF
}

instructor() {
  local d f nn failed=0
  for d in weeks/wk${WEEK:-*}; do
    [ -d "$d" ] || continue
    nn=$(basename "$d")
    mkdir -p "_instructor_rendered/$nn"
    if [ -e "$d/slides.qmd" ]; then
      ST313_KEEP_NOTES=1 quarto render "$d/slides.qmd" -M embed-resources:true
      mv "docs/$d/slides.html" "_instructor_rendered/$nn/slides-instructor.html"
    fi
    for f in "$d"/instructor/*.qmd; do
      [ -e "$f" ] || continue
      quarto render "$f" -M embed-resources:true || { echo "RENDER FAILED: $f"; failed=1; }
    done
    # single-file renders inside the project land under docs/; move them out
    if [ -d "docs/$d/instructor" ]; then
      rsync -a "docs/$d/instructor/" "_instructor_rendered/$nn/"
      rm -rf "docs/$d/instructor"
    fi
    find "$d/instructor" \( -name '*.html' -o -name '*.pdf' \) -print0 2>/dev/null |
      while IFS= read -r -d '' f; do mv "$f" "_instructor_rendered/$nn/"; done
  done
  echo "instructor renders in _instructor_rendered/"
  return "$failed"
}

site() {
  rm -rf docs _freeze .quarto
  quarto render
  echo "ethics4ds.com" > docs/CNAME
}

check() {
  local fail=0 n w
  [ ! -e docs/weeks ] || n=$(find docs -path '*instructor*' | wc -l | tr -d ' ')
  [ "${n:-0}" -eq 0 ] || { echo "FAIL: instructor material under docs/"; fail=1; }
  if grep -rlq -e '_complete' -e 'items.yaml' -e 'teacher_note' docs --include='*.html' --include='*.qmd'; then echo "FAIL: instructor file names referenced under docs/"; fail=1; fi
  if grep -rlq 'title="Solution"\|\.answer\|SOLUTION START' docs; then echo "FAIL: answers under docs/"; fail=1; fi
  if grep -rlq 'class="notes"' docs --include='*.html'; then echo "FAIL: speaker notes under docs/"; fail=1; fi
  if grep -rlq '^st313:' docs --include='*.qmd'; then echo "FAIL: st313: block in a downloadable .qmd under docs/"; fail=1; fi
  [ "$(cat docs/CNAME 2>/dev/null)" = "ethics4ds.com" ] || { echo "FAIL: docs/CNAME"; fail=1; }
  grep -q '^\*\*/instructor/$' .gitignore || { echo "FAIL: **/instructor/ not in .gitignore"; fail=1; }
  n=$(git ls-files | grep -c '/instructor/' || true)
  [ "$n" -eq 0 ] || { echo "FAIL: instructor files tracked by git"; fail=1; }
  for w in weeks/wk*; do
    [ -d "$w" ] || continue
    [ -e "$w/class.qmd" ] && { [ -e "docs/$w/class.qmd" ] || { echo "FAIL: $w/class.qmd not copied to docs/"; fail=1; }; }
    python3 _build_env/check_st313.py "$w" --readings "$SPINE/readings.csv" --results _instructor_rendered/results_all.md ||
      echo "WARN: contract/style checks failed for $w (above); fix in the next delivery, not blocking the push"
  done
  if [ "$fail" -eq 0 ]; then echo "checks passed"; fi
  return "$fail"
}

push() {
  local msg="${1:?commit message required}"
  check
  git add -A
  git commit -m "$msg"
  git push origin main
}

deploy() {
  import "${1:?packet folder required}" "${2:?week number required}"
  student
  registry
  instructor
  site
  push "${3:?commit message required}"
}

cmd="${1:-}"; shift || true
case "$cmd" in
  import|student|registry|instructor|site|check|push|deploy) "$cmd" "$@" ;;
  *) sed -n '2,15p' "$0"; exit 1 ;;
esac
