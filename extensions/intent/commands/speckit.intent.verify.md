---
description: Check each outcome of the current spec and record what happened, with evidence.
---

## User Input

```text
$ARGUMENTS
```

The input may name a feature directory or particular outcomes; otherwise verify every outcome of the
feature in `.specify/feature.json`.

## Principle

A result is what was observed, not what was intended. Report a failure as plainly as a pass; a partial
result is partial, not "mostly done". Never mark an outcome as passing on the strength of code having been
written.

## Asking the user

Ask through the agent's structured question tool when it has one (`AskUserQuestion` in Claude Code, the
equivalent tool in other agents): one decision per question, two to four options, your recommendation
first and marked as such, one line on each option's consequence. Questions whose answers do not depend on
each other may share one call. Without such a tool, ask in plain text: the question, then a short
numbered list with the recommendation first. Never print a table of lettered options for the user to
type a letter back. To settle an order (which tasks or items first), propose one and ask whether to keep
it or change it; do not ask the user to rank a list.

## Steps

1. Read `.specify/feature.json` for the feature directory, then its `spec.md` and `tasks.md`.

2. For each outcome in the spec's Outcomes table, run its check exactly as written: the named test, the
   command, the measurement. If a check cannot run here (missing data, hardware, a person's judgement),
   say so and record it as not run, with what is needed.

3. Judge each against its threshold:
   - **Pass**: the check ran and met it.
   - **Fail**: the check ran and did not; quote the shortest decisive output.
   - **Partial**: met in part; say which part.
   - **Not run**: and why.

4. If the check itself proved wrong, say so: it tests something other than what the outcome states, or,
   for an outcome not marked `Unchanged:`, it would pass without the change (an `Unchanged:` check is
   meant to). A fix that tightens it or makes it test what the outcome states may be made here; run it
   again and record that it changed. A fix that loosens it (lowers a threshold, narrows what it covers,
   drops it) is not made here: record the outcome against the check as written and ask the user.

5. Update the spec's Results section: a table with one row per outcome (outcome, result, evidence:
   command or test name, numbers, commit hash of the code checked, date). Replace the rows of the outcomes
   checked in this run and keep the others as they were. Add one line per noteworthy finding below the
   table: a surprise, a correction to the Evidence section, a follow-up.

6. Set the spec's `status` from the whole table: `verified` when every outcome's row is Pass, `failed`
   when none is, `partial` otherwise. Verification is not a task in tasks.md; tick nothing there.

7. Move any claim in the spec's Evidence section whose tier changed (an assumption now measured, or one
   found wrong) and correct it where it is written. If a result contradicts the Evidence of a decision
   record the plan links, or meets that record's "Revisit when" trigger, say so in the report.

## Report

The results table, the status, for each outcome that did not pass what would make it pass, and any
decision record to revisit.
