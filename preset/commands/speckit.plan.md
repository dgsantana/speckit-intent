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
hyphens); an optional one is offered to the user as a question. Skip a hook with a non-empty `condition`; the hook runner evaluates those. If the file cannot be parsed, say so, including that mandatory hooks were not run. After
writing the plan, do the same for `hooks.after_plan`.

## Asking the user

Ask through the agent's structured question tool when it has one (`AskUserQuestion` in Claude Code, the
equivalent tool in other agents): one decision per question, two to four options, your recommendation
first and marked as such, one line on each option's consequence. Questions whose answers do not depend on
each other may share one call. Without such a tool, ask in plain text: the question, then a short
numbered list with the recommendation first. Never print a table of lettered options for the user to
type a letter back. To settle an order (which tasks or items first), propose one and ask whether to keep
it or change it; do not ask the user to rank a list.

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
     and why. A spec Constraint that records a choice and the options not taken becomes a Choice here.
   - Risks: what could make an outcome fail, and how the work finds out early.
   - If the constitution's rules conflict with the plan, name the conflict; do not paper over it.
   - If a question would be clearer shown than described (a layout, a diagram, visual options side by
     side) and the companion extension is installed, use `__SPECKIT_COMMAND_COMPANION_SHOW__` for it.

4. **Decision records.** A Choice that binds beyond this feature (other features will build on it, or
   undoing it later costs more than this feature did) also gets a decision record, linked from the
   Choice. If the project keeps decision records (a folder such as `docs/decisions`, `docs/adr`, `adr` or
   `doc/adr`), add one in that folder's existing format and naming. Otherwise create
   `docs/decisions/<yyyyMMdd>-<slug>.md` from the resolved `decision-template`
   (`specify preset resolve decision-template`), with no index file: dated names and no shared index
   mean two branches never conflict over the next number. A decision that replaces an earlier one sets
   the earlier record's status to `superseded by <new record>`; the earlier Decision is not edited.

5. **Supporting documents only when they earn their place.** Write `research.md` only for an
   investigation whose findings the tasks depend on; `contracts/` only for an interface other code or
   consumers build against; `data-model.md` only for persistent shapes. Do not write them by default, and
   do not write a quickstart unless the spec's checks need a manual procedure.

6. If planning reveals that an outcome or its check is wrong or unreachable, do not let the plan drift away
   from it silently. A change that loosens it (drops it, lowers a threshold, narrows what the check
   covers) needs the user's confirmation before the spec is edited: ask, with the evidence. Tightening it
   or correcting a check that tests the wrong thing needs none. Either way, record the change in the spec.

7. Set the spec's `status` to `planned`.

## Report

The plan path, the outcomes with the changes serving each, any spec changes, any decision records
written or superseded, and the next step:
`__SPECKIT_COMMAND_TASKS__`.
