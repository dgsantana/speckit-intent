---
description: Check spec, plan and tasks against each other, read-only, and report where they disagree.
scripts:
  sh: scripts/bash/check-prerequisites.sh --json --require-spec --require-tasks --include-tasks
  ps: scripts/powershell/check-prerequisites.ps1 -Json -RequireSpec -RequireTasks -IncludeTasks
  py: scripts/python/check_prerequisites.py --json --require-spec --require-tasks --include-tasks
---

## User Input

```text
$ARGUMENTS
```

## Hooks

Before starting, read `.specify/extensions.yml` if it exists and run each enabled hook under
`hooks.before_analyze`: a hook with `optional: false` is executed now and waited for (command id dots
become hyphens); an optional one is offered to the user as a question.
Skip a hook with a non-empty `condition`; the hook runner evaluates those. If the file cannot be
parsed, say so, including that mandatory hooks were
not run. After reporting, do the same for `hooks.after_analyze`.

## Principle

Read-only. Report disagreements between the artifacts, and between them and the code they name; change
nothing. A finding is concrete: the line, what it says, what contradicts it.

## Steps

1. Run `{SCRIPT}` from the repository root and parse FEATURE_DIR and AVAILABLE_DOCS. Read spec.md,
   plan.md, tasks.md, `.specify/memory/constitution.md` if present, and any document the plan links.

2. Check, and record each failure with its location:
   - **Target** (`normal` specs only): run
     `pwsh -NoProfile -File .specify/extensions/intent/scripts/powershell/target-hash.ps1 -Check`.
     `changed` with a difference that no line in the spec's Target changes section explains is a high
     finding (find the edits with `git log -p -- <spec>` and
     `git diff -- <spec>`); `unrecorded` after planning is a medium one.
   - **Coverage**: every outcome is served by a plan Change and by at least one task; every Change and task
     names an outcome that exists.
   - **Checks**: every outcome has a check with a pass threshold, and tasks order automated checks by
     this rule.
     Red-first: an outcome's check is written before the change and fails without it. An `Unchanged:`
     check passes before and after the change. A `Never:` check fails before the change when the failure
     happens today (a bug); when it cannot happen yet, it comes with the change and must exercise the path
     where the failure would occur.
   - **Format**: every task line is `- [ ] T### [P?] [O#,...] Description with file path`, numbered in
     order.
   - **Consistency**: no constraint is broken by a plan Change; no plan Choice contradicts the spec or a
     decision record it names; terms mean the same thing across the three files.
   - **Evidence**: no outcome or task rests on an `assumption` without a task or check that measures it
     first.
   - **Verification**: when every task is ticked, each Results row was written by intent.verify (it
     carries a "checked by" value). Missing Results, or rows without one, are a medium finding: run
     verify.
   - **Code**: files and interfaces the plan names exist where it says, or the plan says it creates them.
   - **Constitution**: any rule the artifacts break, quoted.

3. Grade each finding: **high** (an outcome cannot be reached or verified as written), **medium** (work
   or a check is missing), **low** (wording or format).

## Report

A table: id, severity, location, finding, suggested fix. Then the counts per severity and the coverage
line `outcomes served: N/M`. Offer to apply the fixes; apply none without the user's go-ahead.
