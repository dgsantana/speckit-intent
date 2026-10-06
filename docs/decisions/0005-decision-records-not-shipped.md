# 0005. Decision records stay in this repository

Status: superseded by [0006](0006-ship-decision-records.md)
Date: 2026-10-06

## Intent

This repository's own choices are recorded with their intent and rejected alternatives, without
imposing a decision-record format on projects that install the preset.

## Decision

Records live in `docs/decisions/` here, in the format its README describes. The preset does not ship a
decisions extension: `plan` writes hard-to-reverse choices into the plan's Choices and links to the
project's own decisions folder when it keeps one.

## Rejected

- Ship a decisions extension with a template and command: projects that already keep ADRs would get a
  second format, which is the conflicting-instructions problem 0001 exists to avoid.

## Evidence

- **assumption**: projects adopting the preset either keep decision records already or are served by the
  plan's Choices section.

## Revisit when

Projects using the preset ask for a decision-record format, or plans' Choices sections show the same
decision recorded inconsistently across features.
