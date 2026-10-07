---
id: [###-feature-slug]
status: draft            # draft | planned | verified | partial | failed; dropped is set by hand
created: [DATE]
---

# [FEATURE NAME]

## Goal

[One or two sentences: who needs what, and why now. Name the trigger: a failing file, a request, a measurement.]

## Outcomes

What must be true when this is done. Each outcome is observable from outside the code and carries the
check that proves it. If an outcome has no check, it is a wish; rewrite it or drop it.

| ID | Outcome | Check |
|----|---------|-------|
| O1 | [Observable behaviour, with numbers where they matter] | [Test name, command, or measurement and its pass threshold] |
| O2 | Unchanged: [existing behaviour that must hold] | [Check that passes before and after the change] |
| O3 | Never: [an observable way the intent is missed even when the other outcomes look met] | [Check that tries to cause it and passes when it cannot] |

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

[At most three, only where the answer changes an outcome. Remove the section when there are none.]

## Target changes

[Changes to Outcomes or Constraints after planning, one line each: date, item, what changed, tightened
or loosened, who confirmed a loosening. Empty until then.]

## Results

[Filled by verification, not by hand-waving: per outcome, Pass / Fail / Partial, with the command run,
numbers and commit. Until then, leave this line.]
