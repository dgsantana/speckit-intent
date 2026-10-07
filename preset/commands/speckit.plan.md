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
hyphens); an optional one is offered to the user as a question.
Skip a hook with a non-empty `condition`; the hook runner evaluates those. If the file cannot be
parsed, say so, including that mandatory hooks were not run. After
writing the plan, do the same for `hooks.after_plan`.

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
the difference, is how a silent change to the target is found.

## Steps

1. Run `{SCRIPT}` from the repository root and parse FEATURE_SPEC, IMPL_PLAN, FEATURE_DIR and BRANCH.

2. Load the spec, `.specify/memory/constitution.md` if present, and the code and decision records the
   spec touches. Read the code before planning changes to it.

3. Fill IMPL_PLAN from the plan template, by the spec's `size`. A **small** plan has Approach and Changes
   only; remove the other sections and skip steps 4, 5 and 7. If the small change turns out to need a
   design agreed first, ordered steps beyond a few tasks, or a decision others will build on, set the
   spec's `size` to `normal`, say so, and plan it as normal. A **normal** plan removes any section that
   would be empty.
   - Approach: how the outcomes are reached. Interfaces, signatures and pseudo-code only; no full
     implementations.
   - Changes: every file or module touched, with the outcomes it serves. An outcome nothing serves is a gap;
     a change that serves no outcome is scope creep. Fix either before continuing.
   - Choices: only those hard to reverse or likely to be re-litigated, each with the rejected alternative
     and why. Choices the spec lists under Decided are the user's; follow them, do not repeat them here.
   - Risks: what could make an outcome fail, and how the work finds out early.
   - A conflict between the constitution and the spec, or a Choice that would replace an active decision
     record, is the user's to settle: ask once, then write the answer down.
   - If a question would be clearer shown than described (a layout, a diagram, visual options side by
     side) and the companion extension is installed, use `__SPECKIT_COMMAND_COMPANION_SHOW__` for it.

4. **Decision records.** A Choice that binds beyond this feature (other features will build on it, or
   undoing it later costs more than this feature did) also gets a decision record, linked from the
   Choice. Find where records go, in this order:
   - `.specify/intent.json` has `decision_records`: a folder path, or `false` for none.
   - The project keeps a decisions folder (`docs/decisions`, `docs/adr`, `adr`, `doc/adr`): use it, in its
     existing format and naming, and write its path to `.specify/intent.json`.
   - Neither: ask the user once whether to keep decision records in `docs/decisions/`. Write the answer
     to `.specify/intent.json` (`"decision_records": "docs/decisions"` or `false`) so it is not asked again.

   A new record in `docs/decisions/` is `<yyyyMMdd>-<slug>.md` from the resolved `decision-template`
   (`specify preset resolve decision-template`), with no index file, so two branches never conflict over
   a number. With `false`, the Choice is the record.

5. **Supporting documents only when they earn their place.** Write `research.md` only for an
   investigation whose findings the tasks depend on; `contracts/` only for an interface other code or
   consumers build against; `data-model.md` only for persistent shapes. Do not write them by default, and
   do not write a quickstart unless the spec's checks need a manual procedure.

6. If planning reveals that an outcome or its check is wrong or unreachable, do not let the plan drift away
   from it silently. Loosening it (dropping an outcome or lowering a threshold) needs the user's
   confirmation before the spec is edited: ask, with the evidence. Tightening it or correcting a check
   that tests the wrong thing needs none. Before the target hash is first recorded, edit the spec
   directly; after, follow Changing the target.

7. Settle the target hash with the script in Changing the target. If the spec has no `target_hash`, run
   it with `-Record`. If it has one, run it with `-Check` first. On `changed`, compare with the Target
   changes lines; for any edit they do not explain (`git log -p -- <spec>` and `git diff -- <spec>` show
   committed and uncommitted edits; a spec never committed shows none), add a line "found at planning:
   <what changed, or 'not determinable'>", then record. Report it either way.

## Report

The plan path, the outcomes with the changes serving each, any spec changes, any unexplained target
change found, any decision records written or superseded, and the next step:
`__SPECKIT_COMMAND_TASKS__`.
