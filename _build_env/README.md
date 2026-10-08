# ST313 build, render and publish

8 October 2026. How a change gets onto ethics4ds.com, what `build.sh` does and what `check` refuses. It is ST310's process (`claude/ST310_build.md` in the Teaching project) with ST313's layout. `AGENTS.md` in Dropbox has the rules.

## Where things are

| Where | What |
|---|---|
| `joftius/ethics4ds` | The site repository. Branch `main`; GitHub Pages serves `docs/` at ethics4ds.com. Agents read it and do not push to it. |
| `elthre3/ethics4ds-work` | Its fork. Agents push branches here, named `claude/<week>-<topic>`. |
| `weeks/wkNN/` | One week: `notes.qmd`, `slides.qmd`, `class.qmd` (generated), `_index.qmd` (the week's block on the course page), and `instructor/`. |
| `weeks/wkNN/instructor/` | Tracked: `class_complete.qmd` and `teacher_note.qmd`. Anything else there is ignored by git and stays in Dropbox: `items.yaml`, `results.md`, board scripts, renders. |
| `_templates/teacher_note.qmd` | The teacher note's format: one page, a keep-or-rush table on top. |

Exams, problem sets and the item bank are never in the repository. `check` fails on a path that looks like one.

## One round

```
git clone https://github.com/elthre3/ethics4ds-work && cd ethics4ds-work
git remote add upstream https://github.com/joftius/ethics4ds
git fetch upstream
git checkout -b claude/wk03-consequences upstream/main      # first round only

git fetch upstream && git merge upstream/main               # every later round, before building
# edit the sources in place; class.qmd is generated, edit instructor/class_complete.qmd
WEEK=03 _build_env/build.sh build
git add -A && git commit && git push -u origin HEAD
```

Then give the convenor the compare link, from which he opens and merges the pull request:
`https://github.com/joftius/ethics4ds/compare/main...elthre3:ethics4ds-work:<branch>?expand=1`

- Commit everything `build` changed: sources, the generated `class.qmd`, `docs/` and `_freeze/`.
- Run `_build_env/build.sh check` again after `git add -A` if you created files by hand: it looks at what the commit would contain. `build.sh push "<message>"` does the staging, the check, the commit and the push in that order, and refuses on `main`.
- Never push with a FAIL line.
- When the merge from `upstream/main` conflicts: resolve the source files, then do not resolve `docs/` or `_freeze/` by hand. Run `git checkout upstream/main -- docs _freeze`, run `build` again and commit.

## The script

| Subcommand | Does |
|---|---|
| `build` | `student`, `registry`, `instructor`, `site`, `check`. `WEEK=NN` limits the instructor step to that week. |
| `student` | Regenerates every `weeks/wk*/class.qmd` from `instructor/class_complete.qmd` with `make_incomplete.py` (drops every `.answer` div and the `st313:` block). |
| `registry` | Writes `_registry/results_all.md` and `_registry/items_all.yaml` (ignored by git) from the spine and each week's `instructor/results.md` and `items.yaml`, where they exist; fails on a repeated R-number or item id. |
| `instructor` | Empties `_instructor_rendered/` (ignored by git), then renders into it, self-contained, each week's deck with speaker notes kept (`ST313_KEEP_NOTES=1`), its complete class sheet and its teacher note. These renders always execute their code. |
| `site` | Clean render of the public site into `docs/`, using `_freeze/`. Writes `docs/CNAME` and `docs/.nojekyll`, drops `<lastmod>` from the sitemap, keeps the teacher pages already in `docs/` and adds the ones just rendered. |
| `check` | The gates below. Non-zero exit on a FAIL. |
| `push "<msg>"` | `git add -A`, `check`, commit, push the current branch. Refuses on `main`. |
| `import`, `deploy` | The Dropbox fallback, on the convenor's machine (needs `rsync`). |

## What is published where

| Path on ethics4ds.com | Content | Linked from the site |
|---|---|---|
| `weeks/wkNN/notes.html`, `slides.html` | Notes; deck with notes stripped | yes |
| `weeks/wkNN/class.html` and `class.qmd` | Student class sheet | yes |
| `decks-notes/wkNN/slides-instructor.html` | Deck with speaker notes | no |
| `teachers/wkNN/class_complete.html` | Complete class sheet | from the week after its class |
| `teachers/wkNN/teacher_note.html` | Teacher note | no |

The teacher pages are not in `search.json` or `sitemap.xml`: they are rendered one file at a time and copied in after the site render.

### Releasing a complete class sheet

A week's complete class sheet is released the week after its class (convenor, 8 October). The release is one line: on the "**Class:**" line of `weeks/wkNN/_index.qmd`, right after the `.qmd` link, add

```
 · [class sheet with solutions](https://ethics4ds.com/teachers/wkNN/class_complete.html)
```

then `_build_env/build.sh site` and `check`, commit, push, compare link. The URL is absolute because the teacher pages are not part of the Quarto project. Nothing else changes: `check` allows a public page to link to a complete class sheet (it warns on a link to a teacher note or to a deck with notes), and the notice at the top of the student sheet says only that answers are revealed in class.

## Gates

FAIL:

- anything from an `instructor/` folder under `docs/weeks/`; a complete class sheet or teacher note under `docs/` outside `teachers/`; an item bank or results file anywhere under `docs/`;
- answer boxes (`.answer`, a Solution callout) under `docs/` outside `teachers/`;
- speaker notes (`class="notes"`) under `docs/` outside `decks-notes/`;
- an `st313:` block in a `.qmd` under `docs/`;
- `docs/CNAME` wrong or `docs/.nojekyll` missing;
- a file under an `instructor/` folder, other than `class_complete.qmd` and `teacher_note.qmd`, that a commit would include;
- a path a commit would include that looks like an exam, a problem set, the item bank or a private folder (`private/`, `exam`, `problem_set`, `pset`, `held_problems`, `items*.yaml`, `item_bank`);
- a week's `class.qmd` missing from `docs/`;
- a teacher page that is not self-contained;
- a deck that loads a MathJax older than 4.

WARN:

- a public page links to a teacher note or to a deck with notes;
- `quarto --version` differs from `_build_env/QUARTO_VERSION`;
- the spine files are missing, or a week has no `instructor/results.md` (below);
- everything `check_st313.py` prints. Its own FAIL lines (contract checks: backstage tokens in student prose, segment minutes, ids) are reported and do not change the exit status.

## The spine files

`registry` and `check` read two files that are not in the repository: `results.md` (the numbered results) and `readings.csv`, both in `ST313/proposals/spine/` in Dropbox. `SPINE` names the folder they are read from; the default is the convenor's Dropbox path. When the folder is missing the build prints one WARN line and goes on without those checks.

An agent fetches the two files with the Dropbox connector, into a folder outside the clone:

1. Ask the connector for download links (`download_link`) for `/elthre3/teaching/ST313/proposals/spine/results.md` and `/elthre3/teaching/ST313/proposals/spine/readings.csv`. Fetch these two and nothing else from that folder.
2. `mkdir -p ~/st313-spine`, then `curl -sS -o ~/st313-spine/results.md "<download_url>"` and the same for `readings.csv`. The links expire after a few minutes.
3. Compare `wc -c` with the `size` the connector reported (Dropbox sync lags).
4. `SPINE=~/st313-spine _build_env/build.sh build`.

If `curl` cannot reach the download host, read each file with the connector's `fetch` and write its text to the same two paths.

R-numbers are spread over the spine (R1 to R3) and each week's `instructor/results.md` (week 1 has R4 to R7, week 2 R8 to R12). Those files are not tracked, so a fresh clone has none of them and `check` says so in one WARN line and skips the R-number check. To run it, fetch each live week's `results.md` the same way into `weeks/wkNN/instructor/`; git ignores it there.

## Freeze, Quarto and MathJax

- `execute: freeze: auto`, and `_freeze/` is committed. A site render re-executes only the pages whose source changed, so `site` in a fresh clone changes no file.
- The instructor step re-executes its week. Run `build` without `WEEK` only when you mean to re-render every week's teacher pages.
- The site is built with the Quarto version in `_build_env/QUARTO_VERSION`. Another version rewrites every page; `check` warns. Not every agent container has Quarto or R installed: the pinned Quarto is a tarball on the quarto-cli GitHub releases page, and R is `apt-get install r-base-core`.
- Math is MathJax 4: `html-math-method: mathjax` at the top level of `_quarto.yml`. A deck does not set its own and must not name another URL. Version 4 breaks inline formulas across lines and makes lines with math taller; two rules at the end of `theme/st313.scss` undo that for decks, and `styles.css` has the same two for pages from 768 px up. A deck gets the rules from its theme: `theme: [default, ../../theme/st313.scss]` has them, and a deck that keeps another theme adds `theme/mathjax4.scss`, which holds the same two (week 1: `theme: [simple, ../../theme/mathjax4.scss]`).
- The self-contained teacher pages (complete class sheets, teacher notes) load MathJax 3, as ST310's do. It does not break inline formulas, so they need no rule.
- After a Quarto upgrade, screenshot every slide before and after and compare, before pushing the build.
