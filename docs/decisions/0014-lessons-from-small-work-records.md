# 0014. What a hand-written small-work record taught the preset

Status: active
Date: 2026-10-07

## Intent

The spec and its Results can hold what real small changes needed in practice, so a team that kept its
own lighter format has no reason to keep it beside the preset.

## Decision

From WIDGET decision 0035, a hand-written `intent.md` format used for specs 024 and 025:

- The spec gains a **Decided** section: choices the user made before or during the work, with the
  options not taken. They are the user's, alongside Outcomes and Constraints; the builder follows them.
  The visual companion writes its settled choices there.
- `verify` accepts a **person's observation** as a check: the user does or confirms it, recorded with
  who, when and an artifact, checked by `user`. Reading the code is not a check.
- Each Results row says **where the check ran and what that cannot prove**; a Pass with a stated limit
  stays a Pass. Partial also covers an outcome proven in a different form than claimed.
- Below Results, **found, not fixed** lines record gaps outside the work and where they belong.
- An outcome **added after verification** is a tightening; the status drops until it is verified.
- A small change that turns out to need a design agreed first, ordered steps or a decision others build
  on is **relabelled normal** during planning.

Not taken: an append-only log replacing research and amended tasks. Target changes, Results notes and
tasks corrected in place with a reason cover it.

## Rejected

- Keep 0035's `intent.md` beside the preset: two formats and two queues, the conflict 0001 avoids.
- Add a log section to every spec: it would repeat Results, Evidence and Target changes.

## Evidence

- **documented**: WIDGET `docs/decisions/0035` and specs 024 and 025, as summarised by the session working
  in that repository (2026-10-07): user choices made mid-work, half-verified outcomes, weak evidence
  stated as weak, a closed record reopened after an install test, gaps found but left for their own
  record, and ticks resting on the product owner's observation with a screenshot.

## Revisit when

A small spec again needs something its own format had and this one lacks.
