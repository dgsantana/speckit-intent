# Tasks: [FEATURE NAME]

**Spec**: [link to spec.md] | **Plan**: [link to plan.md]

Format: `- [ ] T### [P?] [O#,...] Description with file path`. `[P]` marks a task that can run in
parallel with its neighbours; `[O#]` names the outcomes it serves. A task that proves an outcome names
the check it adds or runs.

## When to stop and ask

<!-- Normal size only; a small change removes this section. Building reads it here. -->

The constitution, the spec's Outcomes, Decided and Constraints, and decision records belong to the user;
the plan and these tasks belong to the builder, and are the ones fixed when they disagree with the
user's. A task
found wrong while building is corrected here, in place, with an indented line under it saying why: the
outcome decides. Stop
and ask the user once, only for: **ambiguity** (an outcome reads two ways that lead to different work),
**conflict** (two things the user owns disagree, or a decision record would have to be replaced),
**target** (an outcome must be loosened), an **irreversible** action, or being **stuck** after several
attempts. Decide everything else. Write each answer into the spec, a decision record or the plan; an
answered question is not asked again.

## [Group name, e.g. the first outcome reached end to end]

- [ ] T001 [O1] [Failing test that holds O1, in path/to/test]
- [ ] T002 [O1] [Change that makes it pass, in path/to/file]

## Done

Verification is not a task: the intent extension runs every outcome's check after `implement` and writes
the spec's Results. If these tasks were done outside `implement`, run the intent extension's verify
command before calling the work done. Results are written only by it; a task note links to a Results
row rather than repeating its numbers.
