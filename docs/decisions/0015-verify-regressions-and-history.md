# 0015. Verify catches regressions and keeps the history

Status: active
Date: 2026-10-07

## Intent

Verification reports a regression the work caused even when no outcome names it, does not erase the
measurements that motivated the work, and does not fail a script run over a spec that simply has no
target hash.

## Decision

Amends 0007 and 0013:

- `intent.verify` also checks the spec's Constraints that the work could have broken, and existing
  behaviour near the change. A regression the work caused is a failure: a Fail row for the constraint,
  or a new `Unchanged:` outcome holding the behaviour (a tightening), recorded as failing. "Found, not
  fixed" is only for gaps the work did not cause.
- A check too long to repeat inside verify may use this build's own run of it, named with where and
  when it ran and the code it ran on.
- The single home for a measured number (0013) covers results of checking outcomes. Measurements taken
  before the change, the facts that motivated the work, stay in Evidence.
- `target-hash.ps1 -Check` exits 0 when no hash is recorded; only `changed` exits non-zero. STATUS in its
  JSON still says which.

## Rejected

- Treat the regression as "found, not fixed": it was caused by the work, so it would ship as a pass.
- Keep exit code 2 for an unrecorded hash: a runner that treats non-zero as failure would stop on a
  small spec, which never records one.

## Evidence

- **measured**: widget-server spec 007 verification (2026-10-07), reported by the session running it:
  verify found a deadlock the feature introduced (parallel decode in a mosaic path) that no outcome or
  constraint named; following the earlier wording, the agent moved pre-change measurements out of
  Evidence; a 15-minute measurement could not be repeated inside verify; `-Check` exited 2 on an
  unrecorded hash.

## Revisit when

Verify starts reporting regressions in behaviour the work did not touch, or Evidence loses history
again.
