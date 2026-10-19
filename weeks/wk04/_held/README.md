# Utility and order, cut from week 4 on 17 October 2026

The week 4 lecture as drafted on 14 and 15 October had five parts. The
convenor cut part 4, "Utility and order", on 17 October: too many topics
in one lecture. This folder keeps it as a skeleton for a later week.
Nothing here is rendered or published: Quarto skips folders whose names
start with `_`.

## Files

- `slides_part4_utility_order.qmd`: the six slides as drafted, with their
  speaker notes: "A score is a total order", "When a number exists",
  "Under risk", "Four patients, two measures", "Every partial order can
  be completed", "The ordinal society". Two R figures (`lexico`,
  `hasse`); both need only `draw_dag` and the colors from the deck's
  setup chunk.
- `notes_utility_order.qmd`: the notes' section, with the proofs in
  full (the countable representation theorem; the lexicographic
  counterexample; the four patients), and in a comment at the end the
  class-sheet ideas that went with it.

## What it argues, in one paragraph

A score puts people in a total preorder. A preference relation has a
utility representation only if it is complete and transitive, and on a
countable set that is also enough; the lexicographic order on the
plane shows that uncountable sets need more (Debreu 1954: continuity on
a connected, separable set suffices). Under risk, von
Neumann--Morgenstern's independence axiom gives expected utility,
unique up to a positive affine transformation, so adding utility across
people needs a scale per person that no axiom supplies (week 3's
"trading off between people"). "Better for this person" and Pareto are
partial orders; Szpilrajn (1930) says every partial order extends to a
total order, usually in many ways, and a score chooses one. Fourcade
and Healy's ordinal society (2024; "classification situations", 2013)
is the sociology of that choice made everywhere.

## Where it could go

- Week 7 (fairness, statistical): the normative return explains why
  people want different fairness criteria; the partial-order point
  (which comparisons the criteria leave open) fits beside it.
- Week 9 (decisions, interventions, distribution): expected loss at a
  threshold is a von Neumann--Morgenstern computation; luck
  egalitarianism and distributive justice are where "everyone compared
  with everyone" is the live question. The Ordinal Society fits the
  Robodebt and Fragile Families material.
- Week 11 (retrieval week): as a transfer item on benchmarks as
  rankings.

## Sources, and what was checked (14 and 15 October)

- Debreu's theorems and the lexicographic example: the Wikipedia
  article "Debreu's representation theorems", opened 14 October;
  Debreu (1954) itself not opened. The slides stated the conditions as
  sufficient after the external review of 15 October.
- Von Neumann--Morgenstern: the Wikipedia article, opened 14 October;
  the book not opened. The mixing probability is written $q$ ($p$ is
  prevalence in this course).
- Szpilrajn (1930), *Fundamenta Mathematicae* 16, 386--389: the
  Wikipedia article, opened 14 October; the paper not opened.
- The four-patient example: course form; three linear extensions
  (3 first, second or third); costs (7000, 6000, 6500, 2500) and
  (10000, 9000, 11000, 4000); recomputed by the external reviewer.
- Fourcade and Healy: the 2013 article's abstract on the author's page
  and a Berkeley News piece on the 2024 book, opened 14 October;
  neither text was read. The *ordinateur* etymology was removed as
  unverified.
