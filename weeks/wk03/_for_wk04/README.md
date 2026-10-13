# Reinforcement learning, moved from week 3 to week 4

The week 3 lecture on 13 October 2026 ended before its part 4,
"Reinforcement learning", and the convenor moved the part to week 4.
This folder keeps what week 3 had for it, as written and with its
rendered figures, so that week 4 can use it without writing it again.
Nothing here is rendered or published: Quarto skips folders whose names
start with `_`, and the site renders only `weeks/wk*/*.qmd`.

Week 3's slides and notes no longer contain the part (commit after
`c07e23e` on `claude/wk03-consequences`; the text here is from
`c07e23e`). Week 3's class sheet dropped its one problem on the part
earlier the same day.

## Files

- `slides_part4.qmd`: the part's title slide and its five slides,
  "Reinforcement learning", "A cleaning robot", "A job center as an
  agent", "Cream skimming" and "Utilitarianism with a reward", with
  their speaker notes. A first chunk, `rl-setup`, holds the lines of
  week 3's setup chunk that they use: the cividis colors, `two`, and
  the helper `geom_mathtext`. At the end, in a comment, the line of
  week 3's "Lenses this week" that recalled the part.
- `notes_rl.qmd`: the notes' section "Reinforcement learning", with
  the same setup lines, the three figures and the table of the two
  notations. At the end, in a comment, the notes' other passages that
  referred to it: the last sentence of the summary, the lens A
  paragraph and the three sources.
- `class_problem_two_notations.qmd`: the class sheet's optional
  problem on writing one decision (hormone therapy) in both notations,
  with its hint and its solution in `.answer` divs.
- `figures/slides/` and `figures/notes/`: `rl_loop-1.png`,
  `robot-1.png` and `skim-1.png` as rendered for week 3 (R 4.3.3,
  ggplot2 3.4.4, Quarto 1.10.18). The chunks draw them again when the
  file is rendered; these are for looking at without rendering.

## What the part assumes from week 3, and what to change

- The job center. "A job center as an agent" and "Cream skimming" use a
  variant of week 3's job center (part 3 of its lecture: 1,000 people,
  80% of those who worked last year referred to the course and 20% of
  the others; in work six months later, 70% with the course and 60%
  without it for those who worked last year, 40% and 30% for the
  others). The slides call
  it "a variant of the lecture's job center"; in week 4 that becomes
  week 3's. The variant has 100 places, and in work 70% against 64%
  with and without the course for people who worked last year, 40%
  against 14% for those who did not. Its numbers are invented, which
  the chart says. Its effects, 6 and 26 points, are the within-row
  effects in week 3's notes, "For the class".
- Utilitarianism. "Utilitarianism with a reward" maps ms4ds's four
  difficulties of utilitarianism (section 3.2.2), taught in week 3's
  part 1, to choices made in building an agent. Its speaker note says
  "from part 1"; in week 4 that is week 3.
- Notation. The prediction letters are the course's default. Every slide
  of the part declares the reinforcement-learning letters in its first
  line ("**Notation:** reinforcement learning ($S$, $A$, $R$, $\pi$,
  $U$)"), the table of the two notations is in the notes only, not on a
  slide (convenor, 11 October), and the word "register" is never used
  with students.
- $E_\pi[U]$. The convenor asked (11 October) that it not be called a
  causal quantity outright: "Whether $E_\pi[U]$ is a causal quantity
  depends on further assumptions." The notes give the reasons.
- The closing question of week 3's lecture, "Does consequentialism
  become more or less defensible once you have to write the causal
  model down?", came after part 4 and was not reached either. Week 3's
  class sheet asks it in its discussion 4.
- Timing in week 3's plan: 10 minutes, five slides of 2 minutes, one of
  them pairs work. The plan's entries were:

```yaml
    # part 4, reinforcement learning: 10
    - {label: "reinforcement learning, its letters declared; the agent maximizes E_pi[R], a utilitarian wants E_pi[U]; whether E_pi[U] is causal depends on further assumptions (causal reinforcement learning is a subfield)", minutes: 2, mode: exposition, register: 2}
    - {label: "toy example: a cleaning robot rewarded for not seeing mess (Amodei and colleagues 2016)", minutes: 2, mode: exposition, register: 2}
    - {label: "realistic example, pairs: a job center judged on its placement rate; who does it send, and who would a utilitarian send", minutes: 2, mode: production, register: 2}
    - {label: "what the placement rate rewards: 70% and 6 jobs against 40% and 26; cream skimming in JTPA, where the short-run measures barely tracked long-run impacts (Heckman, Heinrich and Smith 2002)", minutes: 2, mode: exposition, register: 2}
    - {label: "utilitarianism with a reward: ms4ds's four difficulties as choices made in building the agent", minutes: 2, mode: exposition, register: 2}
```

## What the figures need

- The font MathJax_Math, the TeX italic of MathJax 2, for $A$, $S$,
  $R$, $U$ and $\pi$ in the figures, so that they look like the letters
  in the formulas (on Debian or Ubuntu, `apt-get install fonts-mathjax`;
  the agents' container has it). `geom_mathtext` draws the text between
  dollar signs in that font. The setup lines stop the render if the R
  package systemfonts is installed and does not find the font.
- The loop figure's chunk sets `dev.args = list(symbolfamily =
  grDevices::cairoSymbolFont("MathJax_Math", usePUA = FALSE))`, which
  draws plotmath's $\pi$ in the same font. It works with R's cairo
  devices (the default on Linux); R's quartz device on a Mac ignores
  `symbolfamily`.
- ggplot2 and the colors in `rl-setup`; nothing outside the course's
  package list. Week 3's deck set `theme_set(theme_minimal(base_size = 18))`
  and its notes `theme_set(theme_minimal())`; the figures' text sizes
  were chosen for those. Each fragment renders on its own after
  `library(ggplot2)` and `library(dplyr)` (checked on 13 October).

## Sources, and what was checked (week 3, 11 and 12 October)

- Amodei, Olah, Steinhardt, Christiano, Schulman and Mané (2016),
  "Concrete Problems in AI Safety", arXiv 1606.06565: the cleaning
  robot is the paper's running example; rewarded "for not seeing any
  messes", it "might simply close its eyes" (section 4), or "cover over
  messes with materials it can't see through" (section 2). Checked
  against a text extract of the arXiv PDF. The slide and the notes
  paraphrase, with no quotation.
- Heckman, Heinrich and Smith (2002), "The Performance of Performance
  Standards", NBER Working Paper 9002: the short-run measures "weakly,
  and sometimes perversely, related to long run impacts" (abstract);
  "the efficiency gains or losses from cream skimming are small"
  (abstract); "Opposition to cream skimming must come on equity
  grounds" (section VIII, page 35). Checked against a text extract of
  the working paper. A paraphrase must keep the direction: cream
  skimming changed efficiency little either way, which is not "a small
  efficiency cost" (an earlier draft said that, twice). The journal
  version was not opened.
- Deng, Jiang, Long and Zhang (2023), "Causal Reinforcement Learning: A
  Survey", *Transactions on Machine Learning Research*: bibliographic
  record and abstract only. The abstract is about using causal
  knowledge inside reinforcement learning, not about whether $E_\pi$
  is causal, so the text claims only the former.
