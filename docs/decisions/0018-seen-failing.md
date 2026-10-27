# 0018. A check counts once it has been seen failing

Status: active
Date: 2026-10-27

## Intent

Every outcome's check is one that can fail when the outcome is missed, so a green check means the outcome
holds. A check that passes whether or not the work is there gives a verified status on work that does not
do what the spec says.

## Decision

Amends 0008 and the red-first rule in `tasks`, `analyze`, `converge` and `intent.verify`. The rule is now
named "seen failing": an automated check this work adds counts once it has been seen to fail on its own
assertion, not on a compile error or a failure elsewhere, with the behaviour its outcome names absent or
broken: run before the change, or run with that behaviour reverted or broken. For a `Never:` check, that
behaviour is the code that prevents the failure, so a failure that cannot happen yet is seen by removing
the prevention; this replaces 0008's "exercise the path where it would occur". An `Unchanged:` check also
passes before and after the change. A check that only shows something exists (a file written, a value
constructed, a call returning success) does not count; that sentence moves from `tasks` into the shared
wording, because reverting a whole new feature makes a success-only check fail on its own assertion.

Manual observation and measurement checks are out of scope: for new behaviour there is often nothing
honest to see fail.

The task that completes a check's change records, on an indented line, what was reverted or broken and
the assertion that failed. The tasks template carries the guards, because core `implement` reads only
tasks.md. Results name that task rather than copy its note. A check not seen failing, including one
verify tightened (verify changes no code, so it cannot break any), keeps its result and is reported.

The wording stays identical in the four commands; the existing test now holds the new wording.

## Rejected

- Keep red-first (written before the change): the order is not what makes a check useful. Field reports
  showed it fails in two ways. In Unreal and Rust a test written first often does not compile, which
  proves the API is absent, not that the assertion can fail. And a test of behaviour the code already has
  passes on first run, with no honest place to record it.
- Declare the interface first with an empty body so the test can fail against the stub: it keeps the
  order at the cost of an extra step in every compiled language, and adds nothing the revert-and-run
  does not.
- Drop the rule and trust the builder's judgement: a check written after the code and never run against
  broken code may assert nothing the outcome needs, for example a filter test that only checks for a 200
  response.
- Require small increments as a rule: some outcomes need more code before any result can be observed.
  `tasks` already asks that each task be small enough to finish and verify on its own.

## Evidence

- **measured**: sphinx-ue5 spec 20261027-74125c6 (2026-10-27): tests could not compile before the API
  existed, so they were written with the code and never seen failing; recorded in tasks T005 and Results.
- **measured**: vade-server spec 20261027-fe1d29f-las-laz-point-clouds (2026-10-27): red before the
  change caught three real cases (T008/T009 missing RGB, T022 a pixel check found wrong, O8 an abort).
  Red in Rust often meant only a compile error (T004); T019 and T021 passed on first run because the code
  was already right. The session reasoned about perturbations but did not run them, and proposed both
  guards: the failure must be the check's own assertion, and the break must be one the outcome cares
  about. It noted that a perturbation smaller than a check's tolerance passes silently.
- **documented**: Fucci et al., "A Dissection of the Test-Driven Development Process" (IEEE TSE, 2017):
  the gains attributed to TDD come from small, steady steps, not from writing the test first.

## Revisit when

A field report shows a check that met this rule and still passed while its outcome was missed, or
recording how a check was seen failing costs more than the checks it catches.
