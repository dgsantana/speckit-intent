---
description: Check each outcome of the current spec and record what happened, with evidence.
---

## User Input

```text
$ARGUMENTS
```

The input may name a feature directory or particular outcomes; otherwise verify every outcome of the
feature in `.specify/feature.json`. The word `independent` in the input asks for the independent check
in step 4; without it, that step is skipped.

## Principle

A result is what was observed, not what was intended. Report a failure as plainly as a pass; a partial
result is partial, not "mostly done". Reading the code is not a check. Verify changes checks, never the
code under test or tasks.md: anything that fails is a Fail row, and the report sends it on (see Report).

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

1. Read `.specify/feature.json` for the feature directory, then its `spec.md` and `tasks.md`. For a
   `normal` spec, run
   `pwsh -NoProfile -File .specify/extensions/intent/scripts/powershell/target-hash.ps1 -Check`.
   `changed` with no Target changes line for an edit: note it at the top of Results ("target changed
   after planning without a Target changes line", with what `git log -p -- <spec>` or `git diff -- <spec>`
   shows) and go on. `unrecorded`: note it for the report and go on.

2. For each outcome, run its check exactly as written. A check that is a person's observation is run by
   asking the user to do it or confirm what they saw, recorded with who, when and the artifact (a
   screenshot, a log), checked by `user`. A check too long to repeat here may use this build's own run of
   it, named with where, when and on which code it ran. A check that cannot run at all is Not run, with
   what is needed.

   Then read the changes under test (`git diff $(git merge-base HEAD <default branch>)`, uncommitted work
   included) and check the Constraints and existing behaviour they touch, including edits that reach
   beyond what the tasks name. A regression the work caused is a Fail even when no outcome names it: add
   an `Unchanged:` outcome holding the behaviour (a tightening, see Changing the target) and record it as
   failing. A gap the work did not cause goes under "found, not fixed".

3. Judge each:
   - **Pass**: the check ran and met its threshold.
   - **Fail**: it ran and did not; quote the shortest decisive output.
   - **Partial**: met in part, or proven in a different form than the outcome claims; say which part.
   - **Not run**: and why.

   If the check itself proved wrong (it tests something other than the outcome, or breaks the red-first
   rule), say so. Red-first: an outcome's check is written before the change and fails without it. An
   `Unchanged:` check passes before and after the change. A `Never:` check fails before the change when
   the failure happens today (a bug); when it cannot happen yet, it comes with the change and must
   exercise the path where the failure would occur. A fix that tightens the check or makes it test the
   outcome may be made here and run again (see Changing the target). A fix that loosens it (lowers a
   threshold or drops the outcome) is not made here: judge against the check as written and ask the user.

4. **Independent check**, only when the input asks for it, since a second agent costs the user tokens;
   never by default or from the `after_implement` hook. If this agent can start a sub-agent with a fresh
   context and read-only tools, give it the spec's Outcomes, Constraints and Edge cases, the results from
   step 3 and the changes under test from step 2, and ask it to show the work does not meet them. A
   failure it finds makes the outcome Fail, or Partial where it holds in part, with its finding as
   evidence. If no such sub-agent is available, say so and go on.

5. Before replacing rows, note each outcome whose current row is Fail and that a task in a Convergence
   group of tasks.md serves: it has already had a fix. Then update the spec's Results: one row per
   outcome, with the result, the evidence (test or command, numbers, where it ran and what that cannot
   prove), the code checked (a commit hash, or `uncommitted on <short HEAD>`), the date and checked by
   (`builder`, `user`, or `builder + independent`). Replace the rows of outcomes checked in this run; keep
   the others. A row without a checked-by value was not written by this command: replace it if its outcome
   was checked now, otherwise mark it `not verified`. A re-run after an invalid attempt keeps the valid
   run and says why the earlier one does not count. Below the table, one line per noteworthy finding,
   including "found, not fixed" gaps and where they belong.

6. Set the spec's `status` from the whole table: `verified` when every outcome's row is Pass, `failed`
   when none is, `partial` otherwise.

7. Correct the spec's Evidence where a claim's tier changed (an assumption now measured, or one found
   wrong). Measurements taken before the change, which motivated it, stay in Evidence; an outcome's
   measured result lives in Results, and the same number repeated in a task note or decision record is
   noted for the report. If a result contradicts a decision record the plan links, or meets its "Revisit
   when" trigger, note it for the report.

## Report

- The results table and the status.
- Anything noted on the way: an unexplained or unrecorded target, checks found wrong and any tightening
  made, `not verified` rows, regressions, "found, not fixed" gaps, Evidence corrections, results repeated
  outside Results, decision records to revisit.
- Whether the results were checked by the builder alone; if so, that
  `__SPECKIT_COMMAND_INTENT_VERIFY__ independent` adds a second agent's check at extra token cost.
- The next step. For a Fail, Partial or regression, and for new behaviour the user names while reviewing:
  change the target if needed (a new or changed outcome), then `__SPECKIT_COMMAND_CONVERGE__` appends the
  fix tasks, then `__SPECKIT_COMMAND_IMPLEMENT__`, which verifies again. For a Not run: what is needed, for
  the user. For an outcome noted in step 5 as already fixed once and still failing: say so and ask the
  user how to proceed instead.
