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
hyphens); an optional one is offered to the user as a question.
Skip a hook with a non-empty `condition`; the hook runner evaluates those. If the file cannot be
parsed, say so, including that mandatory hooks were not run. After
writing the tasks, do the same for `hooks.after_tasks`.

## Asking the user

Ask through the agent's structured question tool when it has one (`AskUserQuestion` in Claude Code, the
equivalent tool in other agents): one decision per question, two to four options, your recommendation
first and marked as such, one line on each option's consequence. Questions whose answers do not depend on
each other may share one call. Without such a tool, ask in plain text: the question, then a short
numbered list with the recommendation first. Never print a table of lettered options for the user to
type a letter back. To settle an order (which tasks or items first), propose one and ask whether to keep
it or change it; do not ask the user to rank a list.

## Changing the target

Once the spec has a `target_hash` (`plan` records it), its Outcomes and Constraints are the agreed target.
Any edit to them, tightening or loosening, adds one line to the spec's Target changes section (date, item, what
changed, tightened or loosened, who confirmed a loosening) and then re-records the hash:

```text
pwsh -NoProfile -File .specify/extensions/intent/scripts/powershell/target-hash.ps1 -Record
```

Never re-record without the Target changes line. A recorded hash that no longer matches, with no line explaining
the difference, is how a silent change to the target is found. A `small` spec has no hash and no Target
changes section; edit it directly, and a loosening still needs the user's confirmation.

## Steps

1. Run `{SCRIPT}` from the repository root and parse FEATURE_DIR, TASKS_TEMPLATE_CONTENT (or read
   TASKS_TEMPLATE) and AVAILABLE_DOCS.

2. Load spec.md and plan.md, and any supporting document the plan links.

3. Write `<FEATURE_DIR>/tasks.md` from the template:
   - Every task line is `- [ ] T### [P?] [O#,...] Description with file path`, numbered in execution
     order. Other tools parse this format; keep it exact.
   - Group tasks so each group reaches an outcome end to end, the most valuable first. No empty phases.
   - Where an outcome has an automated check, order its task by this rule.
     Red-first: an outcome's check is written before the change and fails without it. An `Unchanged:`
     check passes before and after the change. A `Never:` check fails before the change when the failure
     happens today (a bug); when it cannot happen yet, it comes with the change and must exercise the path
     where the failure would occur.
     A test that only shows something exists (a file written, a value constructed, a call returning
     success) does not count as a check.
   - Each task is small enough to finish and verify on its own.
   - A task that depends on an Evidence claim tagged `assumption` starts by measuring it. If the
     measurement contradicts the claim, the outcome decides: correct the task in place, with an indented
     line under it saying why, and move the claim to `measured` in Evidence.
   - Keep the template's "When to stop and ask" section as it is for a `normal` spec, since building
     reads it from tasks.md; remove it for a `small` one. Keep the Done section, which says to run
     `__SPECKIT_COMMAND_INTENT_VERIFY__` when the tasks were done outside `implement`.
   - No verification task: `__SPECKIT_COMMAND_INTENT_VERIFY__` runs every outcome's check after
     implementation, as the intent extension's `after_implement` hook.

4. Every outcome must be served by at least one task, and every task must name an outcome. Report any gap
   rather than inventing work to fill it.

5. If a task cannot be written without changing an outcome or its check, stop and ask the user when the
   change loosens it (drops the outcome or lowers a threshold). Tightening it or
   correcting a check that tests the wrong thing needs no confirmation; record either as Changing the
   target describes.

## Report

The tasks path, the task count per outcome, any outcome no task serves, and the first task to start with.
