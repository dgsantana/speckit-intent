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
written: reading the code is not a check.

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

1. Read `.specify/feature.json` for the feature directory, then its `spec.md` and `tasks.md`. For a
   `normal` spec, check the target:
   `pwsh -NoProfile -File .specify/extensions/intent/scripts/powershell/target-hash.ps1 -Check`.
   - `match`, or `changed` with a Target changes line for each edit: go on.
   - `changed` otherwise: note it at the top of the Results section ("target changed after planning
     without a Target changes line", with what changed if `git log -p -- <spec>` or `git diff -- <spec>`
     shows it) and go on. Do not stop for it.
   - `unrecorded`: say so in the report and go on.

   A `small` spec has no target hash; skip this check.

2. For each outcome in the spec's Outcomes table, run its check exactly as written: the named test, the
   command, the measurement. A check that is a person's observation (a visual result, a manual flow, a
   packaged build) is run by asking the user to do it or to confirm what they saw, and recorded with who,
   when and the artifact (a screenshot, a log), checked by `user`. A check too long to repeat here (a long
   measurement run) may use this build's own run of it, named with where and when it ran and the code it
   ran on. If a check cannot run at all (missing data, hardware, nobody to observe it), say so and record
   it as not run, with what is needed.

   Then check the spec's Constraints that this work could have broken, and existing behaviour near the
   change. A regression is a failure of the work even when no outcome names it: record it as a Fail row
   for the constraint, or add an `Unchanged:` outcome that holds the behaviour (a tightening, recorded as
   Changing the target describes) and record it as failing. Only a gap the work did not cause goes under
   "found, not fixed".

3. Judge each against its threshold:
   - **Pass**: the check ran and met it.
   - **Fail**: the check ran and did not; quote the shortest decisive output.
   - **Partial**: met in part, or proven in a different form than the outcome claims; say which part.
   - **Not run**: and why.

4. If the check itself proved wrong, say so: it tests something other than what the outcome states, or
   it breaks this rule.
   Red-first: an outcome's check is written before the change and fails without it. An `Unchanged:`
   check passes before and after the change. A `Never:` check fails before the change when the failure
   happens today (a bug); when it cannot happen yet, it comes with the change and must exercise the path
   where the failure would occur.
   A fix that tightens the check or makes it test what the outcome states may be made here; run it
   again and record the change as Changing the target describes. A check that fails only some of the
   time can be joined by a deterministic check of the cause, which can fail first reliably. That is a
   tightening while the behaviour check still runs; dropping the behaviour check for the cause check
   narrows what is proven, and is a loosening. A fix that loosens it (lowers a
   threshold or drops the outcome) is not made here: record the outcome against the check as written and
   ask the user.

5. **Independent check**, only when the input asks for it. It starts a second agent, which costs the user
   tokens, so it never runs by default or from the `after_implement` hook. If this agent can start a
   sub-agent with a fresh context and read-only tools, give it the spec's Outcomes, Constraints and Edge
   cases, the results from step 3, and the changes under test (`git diff $(git merge-base HEAD <default
   branch>)`, which includes uncommitted work), and ask it to show that the work does not meet them; it
   changes nothing. An outcome stays Pass only if the sub-agent found no failure in it; record each
   failure it found as evidence.
   If no such sub-agent is available, say so and go on without it.

6. Update the spec's Results section: a table with one row per outcome (outcome, result, evidence:
   command or test name, numbers, the code checked as a commit hash or `uncommitted on <short HEAD>`,
   date, checked by: `builder`, or `builder + independent` after step 5). Replace the rows of the
   outcomes checked in this run and keep the others as they were. A row without a "checked by" value was
   not written by this command: replace it if its outcome was checked in this run, otherwise mark it
   `not verified` and say so in the report. Each row's evidence says where the check ran and what that
   cannot prove (for example "local build, not a clean machine"); a Pass with a stated limit stays a Pass.
   Below the table, one line per noteworthy finding: a surprise, a correction to the Evidence section, a
   follow-up, or a gap found outside this work and left unfixed ("found, not fixed"), with where it
   belongs.

7. Set the spec's `status` from the whole table: `verified` when every outcome's row is Pass, `failed`
   when none is, `partial` otherwise. An outcome added after an earlier verification (a behaviour that
   was missed) has no row yet, so the status drops until it is verified; adding it is a tightening.
   Verification is not a task in tasks.md; tick nothing there.

8. Move any claim in the spec's Evidence section whose tier changed (an assumption now measured, or one
   found wrong) and correct it where it is written. Results is where the measured result of checking an
   outcome lives: a task note, a decision record or an Evidence line about the same measurement points to
   the Results row instead of repeating it. Measurements taken before the change, the facts that
   motivated the work, stay in Evidence. If a result
   contradicts the Evidence of a decision record the plan links, or meets that record's "Revisit when"
   trigger, say so in the report.

## Report

The results table, the status, for each outcome that did not pass what would make it pass, and any
decision record to revisit. When the results were checked by the builder alone, say so in one line, and
that `__SPECKIT_COMMAND_INTENT_VERIFY__ independent` adds a second agent's check at extra token cost.
