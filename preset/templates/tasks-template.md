# Tasks: [FEATURE NAME]

**Spec**: [link to spec.md] | **Plan**: [link to plan.md]

Format: `- [ ] T### [P?] [O#,...] Description with file path`. `[P]` marks a task that can run in
parallel with its neighbours; `[O#]` names the outcomes it serves. A task that proves an outcome names
the check it adds or runs.

## [Group name, e.g. the first outcome reached end to end]

- [ ] T001 [O1] [Failing test that holds O1, in path/to/test]
- [ ] T002 [O1] [Change that makes it pass, in path/to/file]

## Verification

- [ ] T0## Run every outcome's check and record results in spec.md (the intent extension's verify command)
