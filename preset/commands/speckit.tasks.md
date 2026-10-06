---
description: Break the plan into tasks, each serving named outcomes.
handoffs:
  - label: Implement
    agent: speckit.implement
    prompt: Start the implementation
    send: true
scripts:
  sh: scripts/bash/setup-tasks.sh --json
  ps: scripts/powershell/setup-tasks.ps1 -Json
  py: scripts/python/setup_tasks.py --json
---

## User Input

```text
$ARGUMENTS
```

## Hooks

Before starting, read `.specify/extensions.yml` if it exists and run each enabled hook under
`hooks.before_tasks`: a hook with `optional: false` is executed now and waited for (command id dots become
hyphens); an optional one is offered to the user with its prompt. Leave hook `condition` expressions to
the hook runner. If the file cannot be parsed, say so, including that mandatory hooks were not run. After
writing the tasks, do the same for `hooks.after_tasks`.

## Steps

1. Run `{SCRIPT}` from the repository root and parse FEATURE_DIR, TASKS_TEMPLATE_CONTENT (or read
   TASKS_TEMPLATE) and AVAILABLE_DOCS.

2. Load spec.md and plan.md, and any supporting document the plan links.

3. Write `<FEATURE_DIR>/tasks.md` from the template:
   - Every task line is `- [ ] T### [P?] [O#,...] Description with file path`, numbered in execution
     order. Other tools parse this format; keep it exact.
   - Group tasks so each group reaches an outcome end to end, the most valuable first. No empty phases.
   - Where an outcome has an automated check, the task adding that check comes before the change that
     satisfies it, and the check must fail without the change. A test that only shows something exists
     (a file written, a value constructed, a call returning success) does not count as a check.
   - Each task is small enough to finish and verify on its own.
   - End with the verification task.

4. Every outcome must be served by at least one task, and every task must name an outcome. Report any gap
   rather than inventing work to fill it.

## Report

The tasks path, the task count per outcome, and the first task to start with.
