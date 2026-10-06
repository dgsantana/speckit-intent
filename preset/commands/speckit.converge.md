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
become hyphens); an optional one is offered to the user as a question. Skip a hook with a non-empty `condition`; the hook runner evaluates those. If the file cannot be parsed, say so, including that mandatory hooks were
not run. After finishing, do the same for `hooks.after_converge`.

## Principle

Append-only. The one write this command makes is a new group at the end of tasks.md. It changes no
existing task, no spec, no plan and no code.

## Asking the user

Ask through the agent's structured question tool when it has one (`AskUserQuestion` in Claude Code, the
equivalent tool in other agents): one decision per question, two to four options, your recommendation
first and marked as such, one line on each option's consequence. Questions whose answers do not depend on
each other may share one call. Without such a tool, ask in plain text: the question, then a short
numbered list with the recommendation first. Never print a table of lettered options for the user to
type a letter back. To settle an order (which tasks or items first), propose one and ask whether to keep
it or change it; do not ask the user to rank a list.

## Steps

1. Run `{SCRIPT}` from the repository root and parse FEATURE_DIR. Read spec.md, plan.md and tasks.md.

2. For each outcome, read the code the plan and tasks name for it and decide whether it is reached:
   the behaviour exists and its check exists. Where the spec's Results section already records a run,
   use it rather than guessing. Note what is missing, by outcome.

3. Note ticked tasks whose change is not in the code, and code the plan names that serves no outcome.
   Report these; do not untick or remove anything.

4. If nothing is missing, leave tasks.md untouched. Otherwise append a `## Convergence` group (numbered
   `## Convergence 2` and so on if one exists) with one task per gap, continuing the T### sequence, in
   the same format: `- [ ] T### [O#] Description with file path`. A missing check comes before the
   change it holds, except for an `Unchanged:` outcome, whose check holds before and after. Add no
   verification task; verification runs after implementation as a hook.

## Report

Per outcome: reached, or what is missing and the task appended for it. The other findings from step 3.
The next step: `__SPECKIT_COMMAND_IMPLEMENT__`.
