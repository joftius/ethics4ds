#!/usr/bin/env python3
"""Derive the ST313 student class sheet from the instructor's complete one.

Usage:  make_incomplete.py <class_complete.qmd> <class.qmd>
        make_incomplete.py --solutions <class_complete.qmd> <class_solutions.qmd>
        make_incomplete.py --solutions-hash <class_complete.qmd>   (prints the sha256 of what --solutions would write)
        make_incomplete.py --check <class_complete.qmd>      (marker balance only)

Three documents come from the one source (convenor, 8 October 2026). The
teacher's class sheet is class_complete.qmd itself, published for class
teachers only. The student sheet (class.qmd) is that file without its answers.
The class sheet with solutions is what students are given the week after the
class: a separate document, so that the two can differ. For now it is the
teacher's sheet without the instructor-side front matter; what else differs is
to be decided, and derive_solutions() below is the place for it.

ST313 variant of ST310's generator (28 September 2026). The teacher file
carries every answer in a collapsible callout that the class teacher opens on
screen; the student file is the teacher file with those callouts removed, the
instructor-side `st313:` front-matter block removed. The notice at the top
says that answers are revealed in class and nothing about release: the
complete sheet is released the week after its class by a link on the course
page (convenor, 8 October 2026), and the sheet must read true before and after.

Markers in the complete file:
  ::: {.callout-note .answer title="Solution" collapse="true"}
  ...
  :::
      Any fenced div whose opening line carries the class `.answer` is removed
      entirely, up to the next line consisting of `:::` alone. Answer divs must
      not nest other fenced divs. The title may be anything; the class is what
      the generator reads.
  <!-- SOLUTION START --> / <!-- SOLUTION END -->
      Legacy wk01 markers: dropped if present (the div inside them is what is
      removed). The script exits non-zero if an answer div is opened and never
      closed, or if a SOLUTION comment survives without a `.answer` div.
  <details><summary>Hint ...</summary> ... </details>
      Kept (collapsed in both renders).

Front matter: the whole `st313:` mapping is deleted from the student file; the
rest of the YAML is copied. The YAML title loses any " (complete)" suffix. A
teacher-only HTML comment immediately after the YAML is dropped.

Prose: the sentence "Answers are in the collapsed boxes. Attempt each part
first." (and the older "Answers will be released after the class.") becomes
"Answers are revealed in class. Attempt each part first."
"""
import sys, re

RELEASE = "Answers are revealed in class. Attempt each part first."
NOTICE = (
    "::: {.callout-note}\n"
    "This is the student version of the class sheet. Parts marked **(class)** "
    "are for the class; the rest are practice. Answers are revealed in class.\n"
    ":::\n"
)

OPEN = re.compile(r"^:::+\s*\{[^}]*\.answer[^}]*\}\s*$")
CLOSE = re.compile(r"^:::+\s*$")
SOL = re.compile(r"^\s*<!--\s*SOLUTION (START|END)\s*-->\s*$")

def check_markers(txt, name):
    problems = []
    lines = txt.split("\n")
    open_at = None
    for i, line in enumerate(lines, 1):
        if OPEN.match(line):
            if open_at is not None:
                problems.append(f"{name}: answer div opened at line {open_at} not closed before line {i}")
            open_at = i
        elif CLOSE.match(line) and open_at is not None:
            open_at = None
    if open_at is not None:
        problems.append(f"{name}: answer div opened at line {open_at} never closed")
    # a Solution callout without the .answer class would survive into the student file
    for i, line in enumerate(lines, 1):
        if re.match(r"^:::+\s*\{[^}]*callout[^}]*title=\"Solution\"", line) and ".answer" not in line:
            problems.append(f"{name}: line {i} is a Solution callout without the .answer class")
    if "<!-- ANSWER" in txt or "# ANSWER-START" in txt:
        problems.append(f"{name}: cc-style ANSWER markers found; this generator uses .answer divs")
    return problems

def strip_yaml_key(txt, key="st313"):
    m = re.match(r"---\n(.*?)\n---\n", txt, flags=re.S)
    if not m:
        return txt
    yaml = m.group(1).split("\n")
    out, skipping = [], False
    for line in yaml:
        if re.match(rf"^{key}:\s*(#.*)?$", line):
            skipping = True
            continue
        if skipping:
            if line.startswith((" ", "\t")) or line.strip() == "" or line.startswith("#"):
                continue
            skipping = False
        out.append(line)
    # drop the two banner comment lines that introduced the block, if present
    out = [l for l in out if not re.match(r"^# -{4,}", l)]
    return "---\n" + "\n".join(out) + "\n---\n" + txt[m.end():]

def derive_solutions(txt):
    """The class sheet with solutions, for students. Answers are kept."""
    txt = txt.replace(" (complete)", "", 1).replace("(complete)", "", 1)
    txt = strip_yaml_key(txt, "st313")
    txt = re.sub(r"(---\n.*?\n---\n)\s*<!-- Teacher version\..*?-->\n", r"\1", txt, count=1, flags=re.S)
    return txt

def derive(txt):
    out, skipping = [], False
    for line in txt.split("\n"):
        if SOL.match(line):
            continue
        if not skipping and OPEN.match(line):
            skipping = True
            continue
        if skipping:
            if CLOSE.match(line):
                skipping = False
            continue
        out.append(line)
    txt = "\n".join(out)
    txt = re.sub(r"\n{3,}", "\n\n", txt)
    txt = txt.replace(" (complete)", "", 1).replace("(complete)", "", 1)
    txt = strip_yaml_key(txt, "st313")
    txt = re.sub(r"(---\n.*?\n---\n)\s*<!-- Teacher version\..*?-->\n", r"\1", txt, count=1, flags=re.S)
    txt = txt.replace("Answers are in the collapsed boxes. Attempt each part first.", RELEASE)
    txt = txt.replace("Answers will be released after the class.", RELEASE)
    m = re.match(r"---\n.*?\n---\n", txt, flags=re.S)
    if m:
        txt = txt[:m.end()] + "\n" + NOTICE + txt[m.end():]
    return txt

if __name__ == "__main__":
    args = sys.argv[1:]
    if args and args[0] == "--check":
        src = args[1]
        problems = check_markers(open(src).read(), src)
        for p in problems:
            print(p, file=sys.stderr)
        sys.exit(1 if problems else 0)
    if args and args[0] == "--solutions-hash":
        # The build stores each week's rendered class sheet with solutions next to this hash of its
        # source, and check compares the two: a stored page whose hash differs is older than the
        # teacher's sheet it was made from.
        import hashlib
        print(hashlib.sha256(derive_solutions(open(args[1]).read()).encode("utf-8")).hexdigest())
        sys.exit(0)
    if args and args[0] == "--solutions":
        src, dst = args[1], args[2]
        txt = open(src).read()
        problems = check_markers(txt, src)
        if problems:
            for p in problems:
                print(p, file=sys.stderr)
            sys.exit(1)
        out = derive_solutions(txt)
        open(dst, "w").write(out)
        # nothing backstage goes to students: no st313: block, no item or competence ids
        n_left = len(re.findall(r"st313:|W\d\d-I\d+|CC-\d\d", out))
        print(f"wrote {dst}: {n_left} instructor markers left (must be 0)")
        sys.exit(1 if n_left else 0)
    src, dst = args[0], args[1]
    txt = open(src).read()
    problems = check_markers(txt, src)
    if problems:
        for p in problems:
            print(p, file=sys.stderr)
        sys.exit(1)
    out = derive(txt)
    open(dst, "w").write(out)
    n_left = len(re.findall(r"\.answer|title=\"Solution\"|SOLUTION|st313:|W\d\d-I\d+|CC-\d\d", out))
    print(f"wrote {dst}: {n_left} instructor markers left (must be 0)")
    sys.exit(1 if n_left else 0)
