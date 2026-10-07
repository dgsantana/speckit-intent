---
id: [###-feature-slug]
size: normal             # small | normal
status: draft            # draft | verified | partial | failed; dropped is set by hand
created: [DATE]
---

# [FEATURE NAME]

<!-- Goal, Outcomes and Results are always kept. Every other section is removed when it would be empty. -->

## Goal

[One or two sentences: who needs what, and why now. Name the trigger: a failing file, a request, a measurement.]

## Outcomes

What must be true when this is done. Each outcome is observable from outside the code and carries the
check that proves it. If an outcome has no check, it is a wish; rewrite it or drop it. An outcome may
start with `Unchanged:` (existing behaviour that must hold; its check passes before and after the
change) or `Never:` (a failure the work rules out; its check tries to cause it and passes when it
cannot). For a bug, the outcome is a single `Never:` one: the reported behaviour does not occur.

| ID | Outcome | Check |
|----|---------|-------|
| O1 | [Observable behaviour, with numbers where they matter] | [Test name, command, or measurement and its pass threshold] |

## Decided

Choices the user made, before or during the work, that the work follows (a tier, a publish location, a
layout picked in the companion). One line each, with the options not taken. Not outcomes and not
constraints: the user's decisions, which the builder does not revisit.

- [...]

## Constraints

What must not change or break. Compatibility promises, budgets, rules from the project's constitution or
decision records that bind this work. One line each, with the reason when it is not obvious.

- [...]

## Out of scope

- [Things a reader might expect here and will not find, with where they go instead if anywhere]

## Edge cases

Notes for the builder. An edge case whose wrong handling would miss the intent is an outcome instead,
usually a `Never:` one, so that it gets a check.

- [Situation] -> [expected behaviour]

## Evidence

What this rests on, each tagged by tier. A claim moves up a tier only by measurement.

- **measured**: [observation, number, date, how]
- **documented**: [source that states it, not yet observed here]
- **assumption**: [believed, unverified; a candidate for the first check]

## Open questions

[At most three, only where the answer changes an outcome.]

## Target changes

[Normal size only, after planning: changes to Outcomes or Constraints, one line each: date, item, what
changed, tightened or loosened, who confirmed a loosening.]

## Results

[Written only by the intent extension's verify command: per outcome, Pass / Fail / Partial / Not run,
with the command run, numbers, the code checked and who checked it. Until then, leave this line.]
