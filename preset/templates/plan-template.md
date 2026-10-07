# Plan: [FEATURE NAME]

**Spec**: [link to spec.md]

## Approach

[How the change reaches the outcomes, in a few paragraphs. Interfaces, signatures and pseudo-code are
fine; full implementations are not.]

## Changes

| Where | What | Serves |
|-------|------|--------|
| [path] | [change] | O1 |

## Choices

Only choices that are hard to reverse or that a later reader would re-litigate. One entry each: the
choice, the alternative rejected, why. A choice that binds beyond this feature also gets a decision record
in the project's own decisions folder; link it here.

- [...]

## Risks

- [What could make an outcome fail, and how the plan finds out early]

## When to stop and ask

Fixed text from the preset; keep it as it is. Building reads it here.

Order of authority: the spec's Outcomes and Constraints, then decision records, then this plan, then the
tasks. A lower one never overrides a higher one: when they disagree, the lower one is wrong and is fixed,
unless the disagreement is one of the cases below.

Stop and ask the user, once, only when:

- **ambiguity**: an outcome has two reasonable readings that lead to different work;
- **conflict**: two things the user owns cannot both hold (two outcomes, an outcome and a constraint, the
  spec and a decision record or the constitution), or this work needs to replace an active decision
  record;
- **target**: an outcome or its check is wrong or unreachable, and fixing it would loosen it;
- **irreversible**: the next action cannot be undone (deleting data, a migration, an external side
  effect);
- **stuck**: the same step has failed repeatedly and there is no new approach to try.

Decide everything else, and add it to Choices when it is hard to reverse. Write each answer where it
belongs: the outcome or constraint (with a line in the spec's Target changes), a new decision record that
supersedes the old one, or a Choice here. A question that has been answered is not asked again; its answer
is in these files.

## Supporting documents

[Only those that earn their place, each linked with one line on why it exists: research.md for
investigations whose findings the tasks depend on, contracts/ for an interface other code or consumers
build against, data-model.md for persistent shapes. Remove the section when there are none.]
