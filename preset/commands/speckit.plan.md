---
description: Plan the change that reaches the spec's outcomes.
handoffs:
  - label: Create Tasks
    agent: speckit.tasks
    prompt: Break the plan into tasks
    send: true
scripts:
  sh: scripts/bash/setup-plan.sh --json
  ps: scripts/powershell/setup-plan.ps1 -Json
  py: scripts/python/setup_plan.py --json
---

## User Input

```text
$ARGUMENTS
```

## Hooks

Before starting, read `.specify/extensions.yml` if it exists and run each enabled hook under
`hooks.before_plan`: a hook with `optional: false` is executed now and waited for (command id dots become
hyphens); an optional one is offered to the user with its prompt. Leave hook `condition` expressions to
the hook runner. If the file cannot be parsed, say so, including that mandatory hooks were not run. After
writing the plan, do the same for `hooks.after_plan`.

## Steps

1. Run `{SCRIPT}` from the repository root and parse FEATURE_SPEC, IMPL_PLAN, FEATURE_DIR and BRANCH.

2. Load the spec, `.specify/memory/constitution.md` if present, and the code and decision records the
   spec touches. Read the code before planning changes to it.

3. Fill IMPL_PLAN from the plan template:
   - Approach: how the outcomes are reached. Interfaces, signatures and pseudo-code only; no full
     implementations.
   - Changes: every file or module touched, with the outcomes it serves. An outcome nothing serves is a gap;
     a change that serves no outcome is scope creep. Fix either before continuing.
   - Choices: only those hard to reverse or likely to be re-litigated, each with the rejected alternative
     and why. A choice binding beyond this feature also gets a record in the project's decisions folder if
     it keeps one.
   - Risks: what could make an outcome fail, and how the work finds out early.
   - If the constitution's rules conflict with the plan, name the conflict; do not paper over it.

4. **Supporting documents only when they earn their place.** Write `research.md` only for an
   investigation whose findings the tasks depend on; `contracts/` only for an interface other code or
   consumers build against; `data-model.md` only for persistent shapes. Do not write them by default, and
   do not write a quickstart unless the spec's checks need a manual procedure.

5. If planning reveals that an outcome or its check is wrong or unreachable, change the spec and say so;
   do not let the plan drift away from it silently.

## Report

The plan path, the outcomes with the changes serving each, any spec changes, and the next step:
`__SPECKIT_COMMAND_TASKS__`.
