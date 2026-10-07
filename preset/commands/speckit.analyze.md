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
become hyphens); an optional one is offered to the user as a question. Skip a hook with a non-empty `condition`; the hook runner evaluates those. If the file cannot be parsed, say so, including that mandatory hooks were
not run. After reporting, do the same for `hooks.after_analyze`.

## Principle

Read-only. Report disagreements between the artifacts, and between them and the code they name; change
nothing. A finding is concrete: the line, what it says, what contradicts it.

## Asking the user

Ask through the agent's structured question tool when it has one (`AskUserQuestion` in Claude Code, the
equivalent tool in other agents): one decision per question, two to four options, your recommendation
first and marked as such, one line on each option's consequence. Questions whose answers do not depend on
each other may share one call. Without such a tool, ask in plain text: the question, then a short
numbered list with the recommendation first. Never print a table of lettered options for the user to
type a letter back. To settle an order (which tasks or items first), propose one and ask whether to keep
it or change it; do not ask the user to rank a list.

## Steps

1. Run `{SCRIPT}` from the repository root and parse FEATURE_DIR and AVAILABLE_DOCS. Read spec.md,
   plan.md, tasks.md, `.specify/memory/constitution.md` if present, and any document the plan links.

2. Check, and record each failure with its location:
   - **Target**: run
     `pwsh -NoProfile -File .specify/extensions/intent/scripts/powershell/target-hash.ps1 -Check`.
     `changed` with a difference that no line in the spec's Target changes section explains is a high
     finding (find the edits with `git log -p -- <spec>` and
     `git diff -- <spec>`); `unrecorded` after planning is a medium one.
   - **Coverage**: every outcome is served by a plan Change and by at least one task; every Change and task
     names an outcome that exists.
   - **Checks**: every outcome has a check with a pass threshold; for each non-`Unchanged:` outcome with an
     automated check, a task adds that check before the task that satisfies it (a `Never:` check may come
     with the change when its failure cannot happen yet). A `Never:` check must try to cause the failure
     it names, not only test the happy path.
   - **Format**: every task line is `- [ ] T### [P?] [O#,...] Description with file path`, numbered in
     order.
   - **Consistency**: no constraint is broken by a plan Change; no plan Choice contradicts the spec or a
     decision record it names; terms mean the same thing across the three files.
   - **Evidence**: no outcome rests only on an `assumption` without a task or check that tests it.
   - **Code**: files and interfaces the plan names exist where it says, or the plan says it creates them.
   - **Constitution**: any rule the artifacts break, quoted.

3. Grade each finding: **high** (an outcome cannot be reached or verified as written), **medium** (work
   or a check is missing), **low** (wording or format).

## Report

A table: id, severity, location, finding, suggested fix. Then the counts per severity and the coverage
line `outcomes served: N/M`. Offer to apply the fixes; apply none without the user's go-ahead.
