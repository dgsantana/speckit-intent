# 0003. Loosening an outcome needs the user's confirmation

Status: active
Date: 2026-10-06

## Intent

The work passes because it reached the outcome the user agreed to, not because the agent moved the
outcome to where the work landed.

## Decision

Any step after the spec (`plan`, `tasks`, `intent.verify`) may
tighten an outcome or correct a check that tests the wrong thing, recording the change in the spec. A
change that loosens one (drops it, lowers a threshold, narrows what the check covers) is asked of the
user, with the evidence, before the spec is edited. `verify` records the result against the check as
written meanwhile. Answers the user gives in `clarify`, and choices the user makes in the visual companion, are the
user's decision and apply directly.

## Rejected

- Let the agent change the spec and report it: fastest, but the agent can make any work pass, and a
  report after the fact is easy to miss.
- Confirm every spec change: safe, but brings back the approval-per-step weight the preset removes,
  including for tightenings that carry no risk.

## Evidence

- **documented**: the earlier wording (`plan` "change the spec and say so", `verify` "fix the check")
  let the agent edit the target it is measured against, with no gate. Found in review, 2026-10-06.
- **assumption**: agents under pressure to finish relax the target rather than report a failure. Not
  measured.

## Revisit when

Verification results show outcomes being loosened through a path this rule does not cover, or users
report the confirmation as friction on changes that were never in doubt.
