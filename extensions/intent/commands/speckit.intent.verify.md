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

4. If the check itself proved wrong (testing the wrong thing, or passing without the change), say so,
   fix the check if that is within the work, and run it again. Record that it changed.

5. Replace the spec's Results section with a dated table: outcome, result, evidence (command or test
   name, numbers, commit hash of the code checked). Add one line per noteworthy finding below the table:
   a surprise, a correction to the Evidence section, a follow-up.

6. Update the spec's `status`: `verified` when every outcome passes, `partial` otherwise. Tick the
   verification task in tasks.md only when every outcome was run. Do not tick any other task here.

7. Move any claim in the spec's Evidence section whose tier changed (an assumption now measured, or one
   found wrong) and correct it where it is written.

## Report

The results table, the status, and for each outcome that did not pass, what would make it pass.
