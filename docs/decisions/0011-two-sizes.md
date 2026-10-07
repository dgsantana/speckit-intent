# 0011. Two sizes: small and normal

Status: active
Date: 2026-10-07

## Intent

A one-line bug fix costs about what a one-line bug fix should: a failing check first, the fix, and the
observed result. Protection meant for features that others build on is not paid on every change.

## Decision

`specify` sets `size: small | normal` in the spec, says why, and the user can override it. Small means a
bug fix, or a change confined to a few files that adds no interface, data shape, dependency or decision
others build on. A small spec keeps Goal, Outcomes (for a bug, a single `Never:` outcome) and Results,
plus any section with something to say; its plan is Approach and Changes. It gets no target hash, no
decision records and no stop section. In both sizes, a section that would be empty is removed.

## Rejected

- Skip plan and tasks for small changes: core `implement` requires `tasks.md` and reads `plan.md`, so
  skipping them means replacing `implement` (0001).
- Only remove empty sections, with no notion of size: the hash, the stop section and decision records
  would still run on a one-line fix.
- No change: the same path for every change was the review's main finding.

## Evidence

- **documented**: a review of c656a8d walked a one-line bug through the preset: about 8 scripts, 3
  artifacts, the target hash and a plan whose fixed stop text was longer than its content; a grep for
  any notion of size found none (2026-10-07).

## Revisit when

Changes labelled small turn out to need what the normal path adds, or users override the label often in
one direction.
