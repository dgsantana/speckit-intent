# 0008. Failure conditions as Never: outcomes

Status: active
Date: 2026-10-07

## Intent

The ways a feature can look done and still miss its intent (a session that survives logout, the
reported bug still occurring) are checked, not left as notes.

## Decision

An outcome starting with `Never:` names an observable failure; its check tries to cause it and passes
when it cannot. It sits in the Outcomes table with the others, so it has a check, counts for coverage and
is part of the target hash. Its check follows red-first when the failure happens today (a bug); when the
failure cannot happen yet, the check is written with the change and must exercise the path where it
would occur. Edge cases stay as notes unless their wrong handling would miss the intent, in which case
they become outcomes.

## Rejected

- A separate Failure conditions section, as ICED has: one more section, and items that only negate an
  outcome ("signed out while active" against "stays signed in") duplicate it, adding places for the spec
  to contradict itself.
- No change: edge cases carry negative properties today but need no check, so they can go untested.

## Evidence

- **documented**: ICED `spec/SPEC.md` section 4.2, Failure conditions `[F<n>]` that "become negative
  tests".
- **assumption**: a positive outcome's check is usually a happy-path test and does not try the failure.

## Revisit when

Specs routinely list `Never:` outcomes that negate another outcome, or verification finds misses that
were written as edge cases instead.
