---
description: Check each outcome of the current spec and record what happened, with evidence.
---

## User Input

```text
$ARGUMENTS
```

The input may name a feature directory or particular outcomes; otherwise verify every outcome of the
feature in `.specify/feature.json`. The word `independent` in the input asks for the independent check
in step 5; without it, that step is skipped.

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

1. Read `.specify/feature.json` for the feature directory, then its `spec.md` and `tasks.md`. Check the
   target: `pwsh -NoProfile -File .specify/extensions/intent/scripts/powershell/target-hash.ps1 -Check`.
   - `match`: go on.
   - `changed`: Outcomes or Constraints were edited after planning. Find the edits with
     `git log -p -- <spec>` and `git diff -- <spec>`. If a line in the spec's Target changes section explains
     each one, go on. If not, say so at the top of the report and ask the user whether the spec as it
     stands is the target before recording any result.
   - `unrecorded`: say that the target was never recorded, and go on.

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
   meant to), or, for a `Never:` outcome, it never exercises the path where the failure would occur. A fix that tightens it or makes it test what the outcome states may be made here; run it
   again and record the change as Changing the target describes. A fix that loosens it (lowers a
   threshold, narrows what it covers, drops it) is not made here: record the outcome against the check as
   written and ask the user.

5. **Independent check**, only when the input asks for it. It starts a second agent, which costs the user
   tokens, so it never runs by default or from the `after_implement` hook. If this agent can start a
   sub-agent with a fresh context and read-only tools, give it the spec's Outcomes, Constraints and Edge
   cases, the results from step 3, and the changes under test (`git diff $(git merge-base HEAD <default
   branch>)`, which includes uncommitted work), and ask it to show that the work does not meet them; it changes nothing. An outcome
   stays Pass only if the sub-agent found no failure in it; record each failure it found as evidence.
   If no such sub-agent is available, say so and go on without it.

6. Update the spec's Results section: a table with one row per outcome (outcome, result, evidence:
   command or test name, numbers, commit hash of the code checked, date, checked by: `builder`, or
   `builder + independent` after step 5). Replace the rows of the outcomes checked in this run and keep
   the others as they were. Add one line per noteworthy finding below the table: a surprise, a correction
   to the Evidence section, a follow-up.

7. Set the spec's `status` from the whole table: `verified` when every outcome's row is Pass, `failed`
   when none is, `partial` otherwise. Verification is not a task in tasks.md; tick nothing there.

8. Move any claim in the spec's Evidence section whose tier changed (an assumption now measured, or one
   found wrong) and correct it where it is written. If a result contradicts the Evidence of a decision
   record the plan links, or meets that record's "Revisit when" trigger, say so in the report.

## Report

The results table, the status, for each outcome that did not pass what would make it pass, and any
decision record to revisit. When the results were checked by the builder alone, say so in one line, and
that `__SPECKIT_COMMAND_INTENT_VERIFY__ independent` adds a second agent's check at extra token cost.
