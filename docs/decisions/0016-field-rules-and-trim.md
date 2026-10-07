# 0016. Field-report rules after 0015, and a trim

Status: active
Date: 2026-10-07

## Intent

The rules taken from live use stay as general rules that pay for their reading cost. Rules that only
patched one incident go, and verify reads as one procedure with one route for anything that fails.

## Decision

Amends 0013 and 0015. These came from field reports in widget-server and gadget-ue5 and are kept:

- `specify`: a check runs on what the outcome names; an observation check gives exact steps; a check
  says what its data is and leaves its evidence intact (it works on a copy of anything it writes).
- `plan`: BRANCH is a suggested name; test infrastructure a check needs belongs in Changes.
- tasks: corrections go on an indented line under the task.
- `verify` changes checks, never the code under test or tasks.md. Anything that fails is a Fail row. The
  report sends it to `converge` for a fix task, then `implement`, which verifies again; a second failure
  of the same outcome is asked about instead. Verify reads the diff together with its regression check,
  records `user` as checked-by for an observation, and keeps the valid run when an attempt was invalid.

A review on 2026-10-07 found weight creeping back (verify at 1,514 words, 60% more than at c656a8d), so
these were trimmed:

- The flaky-check rule is cut. It added a third kind of loosening that 0012 had removed; correcting a
  check that tests the wrong thing already covers that case.
- The three failure routes in verify become one.
- "An outcome added after verification drops the status" is cut: the status rule already implies it.
- The measured-number rule is stated once, in verify, narrowed to outcomes' results (amends 0013).
- `analyze` loses its copy of the asking rule: it asks one yes/no question.
- The `feature.json` note moves to the README install steps.
- A small spec has no Target changes section; the shared rule now says it is edited directly.
- `clarify` may write a Decided line and restore a section removed as empty.
- Each Report now includes what its steps say to report.

A second review of the trim found it had cut too far in places, so: a regression always becomes an
`Unchanged:` outcome (a constraint row had no route to a fix, since converge walks outcomes); "measurements
taken before the change stay in Evidence" is back in verify; the tasks template again says a task note
links to a Results row; verify notes repeated results instead of editing other files; an independent
failure is Fail or Partial; a Not run goes to the user, not to converge; "already fixed once" is detected
from the old Fail row and a Convergence task before rows are replaced; and the shared rule says a small
spec's loosening still needs the user's confirmation.

## Rejected

- Keep every field-report rule: each was small, but together they made verify the longest command and
  gave it three failure procedures.
- Move the repeated blocks (asking, changing the target, hooks, red-first) into one shared file: it cuts
  about a fifth of the reading, but each command would stop standing alone (0001), and an agent can skip
  a pointer to a file. Kept, with the test that holds copies identical; copies are dropped only from
  commands that do not need them.

## Evidence

- **measured**: review of 0c52239 plus working tree (2026-10-07): command and template text grew from 947
  to 1035 lines since c656a8d; a small bug fix reads 6,886 words (5,864 before); about 22% of command
  words are repeated blocks; verify gave three routes for a failure, and one of them edited tasks.md
  against converge's append-only rule.

## Revisit when

A field report asks for a rule that one of the cut rules would have covered, or verify grows past its
c656a8d size again.
