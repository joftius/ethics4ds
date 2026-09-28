#!/usr/bin/env python3
"""ST313 style and contract checks, for agents before each round and for build.sh check.

Usage:  check_st313.py <week folder> [--readings path/to/readings.csv] [--results path/to/results_all.md]

Runs two kinds of check and prints them apart.

FAIL (exit 1): mechanically decidable parts of spine/CONTRACT.md and of the
student/instructor split.
  - a student-facing file (notes.qmd, slides.qmd, class.qmd) contains
    backstage tokens: item ids W\\d\\d-I\\d+, competence ids CC-\\d\\d, result
    numbers as bare R\\d+ in prose, "[board]", or encounter codes S\\d;
  - class.qmd contains .answer, a Solution callout, SOLUTION markers, or an
    st313: block;
  - in every file carrying an st313: block: segment minutes do not sum to 80;
    production share below 25% (lecture) or 50% (class);
  - results: ids not present in the results registry (when --results given);
  - readings: ids not present in readings.csv (when --readings given).

WARN (exit 0): spine/STYLE.md §1 and the convenor's 28 Sept decisions.
  - em dashes;
  - British spellings (-ise/-isation/-ised/-ising, -our where US drops it,
    -yse, -re endings such as centre, programme, licence as a noun is flagged
    for a human);
  - STYLE.md's assistant idiom: "license"/"licenses" as a verb, "name the",
    "load-bearing", "doing work", "keeps it honest", "worth remembering",
    "here is the thing", "the point is", "the whole problem in one picture",
    praise words "exactly", "precisely", "sharp", "clean" next to a noun,
    "carries", "sits", "lands", "deforms", "bite";
  - headings of the form "X, and what Y"; headings that summarise ("in two
    numbers", "in one picture");
  - "gets full marks";
  - overclaim words in bold or blockquote text: always, never, every, all,
    guarantees, cannot, must (CONTRACT: flag for a human, never auto-pass).

Notes and slides carry their st313: block in the source; they are not copied
into docs/ (only class.qmd is a resource), so the block check applies to
class.qmd only. build.sh check greps docs/ for `st313:` as the last line of
defence.
"""
import sys, re, os, glob, csv

STUDENT = ["notes.qmd", "slides.qmd", "class.qmd"]

BACKSTAGE = [
    (r"\bW\d\d-I\d+\b", "item id"),
    (r"\bCC-\d\d\b", "competence-core id"),
    (r"(?<![\w$\\])R\d{1,2}\b(?![\w$])", "bare result number"),
    (r"\[board\]", "[board] marker"),
    (r"\bS[1-6]\b(?![\w$])", "spine encounter code"),
]

BRITISH = [
    (r"\b\w+is(e|ed|es|ing|ation|ations)\b", "-ise spelling (check: surprise, advise, exercise, precise, raise, promise, revise, wise, advertise, compromise, otherwise, likewise are fine)"),
    (r"\b(colour|behaviour|labour|favour|honour|flavour|neighbour|rumour|humour|vigour|rigour)\w*\b", "-our spelling"),
    (r"\b\w+(yse|ysed|ysing|yses)\b", "-yse spelling"),
    (r"\b(centre|centres|centred|metre|metres|litre|theatre|fibre|calibre)\b", "-re spelling"),
    (r"\b(programme|programmes|catalogue|catalogues|dialogue|grey|licence|defence|offence|practise|practised|practising|judgement|enrol|enrolment|fulfil|travelling|modelling|modelled|labelled|labelling|cancelled|signalling|totalling)\b", "British form"),
]
BRITISH_OK = {"surprise", "advise", "exercise", "precise", "raise", "promise", "revise", "wise", "advertise",
              "compromise", "otherwise", "likewise", "comprise", "despise", "devise", "disguise", "franchise",
              "supervise", "televise", "arise", "rise", "noise", "concise", "expertise", "enterprise", "merchandise",
              "premise", "premises", "paradise", "exercises", "exercised", "raised", "raises", "raising", "promised",
              "promises", "surprised", "surprises", "surprising", "advised", "advises", "advising", "revised", "revises",
              "revising", "devised", "devises", "arises", "arising", "rises", "rising", "comprises", "comprised",
              "supervised", "supervises", "supervising", "otherwise", "likewise", "compromised", "compromises"}

IDIOM = [
    (r"\b(licenses|licensed|licensing|license)\b(?=\s+(the|a|an|this|that|what|an?\b))", "\"license\" as a verb"),
    (r"\bname (the|a|an) (mechanism|value|judgement|judgment|choice)\b", "\"name\" as a verb"),
    (r"\bload-bearing\b", "load-bearing"),
    (r"\bdoing (the |real )?work\b", "doing work"),
    (r"\bkeeps? (it|the question|them) honest\b", "keeps it honest"),
    (r"\bworth remembering\b", "worth remembering"),
    (r"\bhere is the thing\b", "here is the thing"),
    (r"\bthe point is\b", "the point is"),
    (r"\bthe whole problem in one picture\b", "the whole problem in one picture"),
    (r"\b(exactly|precisely) (the|what|where|how)\b", "praise/intensifier"),
    (r"\b(sharp|clean) (answer|result|number|version|form|statement|example)\b", "praise word"),
    (r"\b(carries|sits|lands|deforms|bites?)\b", "assistant verb (check context)"),
    (r"\bgets full marks\b", "gets full marks"),
    (r"\breal\b (?=(effect|difference|number|question|choice)\b)", "\"real\" as intensifier"),
    (r"\bboth answers are live\b", "\"live\""),
]

HEADING_BAD = [
    (r"^#+\s+.*,\s+and\s+what\b", "\"X, and what Y\" title"),
    (r"^#+\s+.*\bin (two|three|one) (numbers?|pictures?|sentences?)\b", "summarising title"),
]

OVERCLAIM = re.compile(r"\b(always|never|every|all|guarantees?|cannot|must)\b", re.I)

def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()

def strip_code_and_math(txt):
    txt = re.sub(r"```.*?```", "", txt, flags=re.S)
    txt = re.sub(r"\$\$.*?\$\$", "", txt, flags=re.S)
    txt = re.sub(r"\$[^$\n]*\$", "", txt)
    txt = re.sub(r"`[^`\n]*`", "", txt)
    return txt

def yaml_block(txt):
    m = re.match(r"---\n(.*?)\n---\n", txt, flags=re.S)
    return m.group(1) if m else ""

def parse_st313(yaml):
    """Minimal parse: segments' minutes and modes, session, results, readings."""
    if not re.search(r"^st313:\s*(#.*)?$", yaml, flags=re.M):
        return None
    block = yaml[yaml.index("st313:"):]
    session = re.search(r"^\s+session:\s*(\w+)", block, flags=re.M)
    minutes = [(int(m.group(1)), m.group(2)) for m in re.finditer(r"minutes:\s*(\d+),\s*mode:\s*(\w+)", block)]
    results = re.search(r"^\s+results:\s*\[([^\]]*)\]", block, flags=re.M)
    readings = re.search(r"^\s+readings:\s*\[([^\]]*)\]", block, flags=re.M)
    split = lambda m: [x.strip() for x in m.group(1).split(",") if x.strip()] if m else []
    return {"session": session.group(1) if session else None, "minutes": minutes,
            "results": split(results), "readings": split(readings)}

def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__); sys.exit(2)
    week = args[0]
    readings_csv = results_md = None
    if "--readings" in args: readings_csv = args[args.index("--readings") + 1]
    if "--results" in args: results_md = args[args.index("--results") + 1]
    fails, warns = [], []

    known_results = None
    if results_md and os.path.exists(results_md):
        known_results = set(re.findall(r"\bR\d+\b", read(results_md)))
    known_readings = None
    if readings_csv and os.path.exists(readings_csv):
        with open(readings_csv, newline="", encoding="utf-8") as f:
            rows = list(csv.DictReader(f))
        known_readings = {r.get("id", "").strip() for r in rows if r.get("id")}

    # student-facing files
    for name in STUDENT:
        path = os.path.join(week, name)
        if not os.path.exists(path):
            continue
        txt = read(path)
        body = strip_code_and_math(txt[len("---\n" + yaml_block(txt) + "\n---\n"):]) if txt.startswith("---") else strip_code_and_math(txt)
        for pat, what in BACKSTAGE:
            for m in re.finditer(pat, body):
                line = body[:m.start()].count("\n") + 1
                fails.append(f"{path}: {what} '{m.group(0)}' in student-facing prose (near line {line} of the body)")
        if name == "class.qmd":
            for pat, what in [(r"\.answer", ".answer div"), (r"title=\"Solution\"", "Solution callout"),
                              (r"SOLUTION (START|END)", "SOLUTION marker"), (r"^st313:", "st313: block")]:
                if re.search(pat, txt, flags=re.M):
                    fails.append(f"{path}: {what} present in the student class sheet")
        # style warnings
        for i, line in enumerate(body.split("\n"), 1):
            if "—" in line:
                warns.append(f"{path}:{i}: em dash")
            for pat, what in IDIOM:
                if re.search(pat, line, flags=re.I):
                    warns.append(f"{path}:{i}: {what}: {line.strip()[:90]}")
            for pat, what in BRITISH:
                for m in re.finditer(pat, line, flags=re.I):
                    w = m.group(0).lower()
                    if w in BRITISH_OK or w.rstrip("sd") in BRITISH_OK:
                        continue
                    warns.append(f"{path}:{i}: {what}: '{m.group(0)}'")
            for pat, what in HEADING_BAD:
                if re.match(pat, line):
                    warns.append(f"{path}:{i}: {what}: {line.strip()}")
            if (line.startswith(">") or "**" in line) and OVERCLAIM.search(line):
                warns.append(f"{path}:{i}: overclaim word in emphasised text (human check): {line.strip()[:90]}")

    # contract blocks, wherever they are
    for path in glob.glob(os.path.join(week, "**", "*.qmd"), recursive=True) + glob.glob(os.path.join(week, "**", "*.md"), recursive=True):
        txt = read(path)
        info = parse_st313(yaml_block(txt)) if txt.startswith("---") else None
        if not info:
            continue
        total = sum(m for m, _ in info["minutes"])
        prod = sum(m for m, mode in info["minutes"] if mode == "production")
        if info["minutes"] and total != 80:
            fails.append(f"{path}: segment minutes sum to {total}, not 80")
        if info["minutes"]:
            share = prod / total if total else 0
            floor = 0.5 if info["session"] == "class" else 0.25
            if share < floor:
                fails.append(f"{path}: production share {share:.0%} below {floor:.0%} for a {info['session']}")
        if known_results is not None:
            for r in info["results"]:
                if r not in known_results:
                    fails.append(f"{path}: results id {r} not in {results_md}")
        if known_readings is not None:
            for r in info["readings"]:
                if r not in known_readings:
                    fails.append(f"{path}: readings id {r} not in {readings_csv}")

    for w in warns: print("WARN", w)
    for f in fails: print("FAIL", f)
    print(f"{len(fails)} failures, {len(warns)} warnings")
    sys.exit(1 if fails else 0)

if __name__ == "__main__":
    main()
