# 0006. Ship lean decision records in the preset

Status: active
Date: 2026-10-06

## Intent

In a project using the preset, a choice that binds beyond one feature is found by the next feature that
touches it, with what it protects, what was rejected and when to reconsider it, instead of sitting in
an old plan.

## Decision

Supersedes 0005. The preset ships `decision-template`, and `plan` writes a record for each Choice that
binds beyond the feature. It uses the project's existing decisions folder and format when there is one;
otherwise `docs/decisions/<yyyyMMdd>-<slug>.md`, with no index file. `intent.verify` reports results
that contradict a linked record's evidence or meet its revisit trigger. No new command.

## Rejected

- Keep records in this repository only (0005): leaves cross-feature decisions in per-feature plans, the
  gap that made Superpowers' design flow lose decisions.
- A separate decisions extension with its own command: one more thing to install and keep in sync, for
  behaviour that belongs in `plan`.
- Sequential `NNNN-` names and an index, as this repository uses: two branches take the same number and
  both edit the index, the collision 0002 exists to avoid. This repository has one author, so it keeps
  them.

## Evidence

- **documented**: 0005 rejected shipping records because a second format would clash with projects that
  keep ADRs. Writing into the existing folder in its format removes that clash.
- **measured**: `specify preset resolve decision-template` resolves to the preset's template on a
  scratch Spec Kit 1.1.1 project (2026-10-06).

## Revisit when

Plans in a project using the preset write records for choices that do not bind beyond the feature, or
miss ones that do; or Spec Kit adds decision records of its own.
