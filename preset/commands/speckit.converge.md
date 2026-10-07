---
description: Compare the code with the spec's outcomes and append tasks for what is still missing.
handoffs:
  - label: Implement
    agent: speckit.implement
    prompt: Complete the convergence tasks
    send: true
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
`hooks.before_converge`: a hook with `optional: false` is executed now and waited for (command id dots
become hyphens); an optional one is offered to the user as a question.
Skip a hook with a non-empty `condition`; the hook runner evaluates those. If the file cannot be
parsed, say so, including that mandatory hooks were
not run. After finishing, do the same for `hooks.after_converge`.

## Principle

Append-only. The one write this command makes is a new group at the end of tasks.md. It changes no
existing task, no spec, no plan and no code.

## Steps

1. Run `{SCRIPT}` from the repository root and parse FEATURE_DIR. Read spec.md, plan.md and tasks.md.

2. For each outcome, read the code the plan and tasks name for it and decide whether it is reached:
   the behaviour exists and its check exists. Where the spec's Results section already records a run,
   use it rather than guessing. Note what is missing, by outcome.

3. Note ticked tasks whose change is not in the code, and code the plan names that serves no outcome.
   Report these; do not untick or remove anything.

4. If nothing is missing, leave tasks.md untouched. Otherwise append a `## Convergence` group (numbered
   `## Convergence 2` and so on if one exists) with one task per gap, continuing the T### sequence, in
   the same format: `- [ ] T### [O#] Description with file path`, ordered by this rule.
   Red-first: an outcome's check is written before the change and fails without it. An `Unchanged:`
   check passes before and after the change. A `Never:` check fails before the change when the failure
   happens today (a bug); when it cannot happen yet, it comes with the change and must exercise the path
   where the failure would occur.
   Add no verification task; verification runs after implementation as a hook.

## Report

Per outcome: reached, or what is missing and the task appended for it. The other findings from step 3.
The next step: `__SPECKIT_COMMAND_IMPLEMENT__`.
