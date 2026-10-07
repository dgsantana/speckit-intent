# 0013. Build rules live in tasks.md; Results only from verify

Status: active, amended by [0015](0015-verify-regressions-and-history.md), [0016](0016-field-rules-and-trim.md)
Date: 2026-10-07

## Intent

Whoever builds the feature, `implement` or an agent picking the work up again, meets the stop rules and
the way to verify, and a feature is not called done on results nobody checked.

## Decision

Amends 0010. "When to stop and ask" moves from the plan template to the tasks template (normal size). It
adds: a task found wrong while building is corrected in place with one line on why; the outcome decides.
`tasks` makes a task that depends on an `assumption` claim measure it first.

The tasks template ends with a Done section: run the intent extension's verify command when the tasks
were done outside `implement`, since its hook then never fires. Results are written only by verify,
whose rows carry a "checked by" value; verify replaces or marks `not verified` rows without one, and
`analyze` flags ticked tasks without verified Results. A measured number lives in Results; Evidence,
task notes and decision records point to it.

## Rejected

- Keep the stop rules in the plan: the first real build resumed from tasks.md and never opened plan.md.
- Put them in both plan and tasks: two copies for the builder to reconcile, the problem 0001 avoids.
- Bring back a verification task in tasks.md: verify then ran twice, once as the task and once as the
  hook (found in the 2026-10-06 review).

## Evidence

- **measured**: widget-server spec 007 (2026-10-07), reported by the session building it: tasks T046-T064
  were done inline from tasks.md, so `after_implement` never fired and Results were written by hand; the
  agent resuming the work read tasks.md, not plan.md; a task built on an `assumption` (pyramid about 15%
  of COG) met a measurement of 540%, and the agent rightly followed the outcome; one result was written
  in four places.

## Revisit when

A build is seen skipping tasks.md as well, or verify's handling of rows it did not write misfires.
