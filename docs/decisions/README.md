# Decisions

One file per decision that is hard to reverse or likely to be argued again. A record states the outcome
it protects first, because a decision is only right relative to what it is for; when that intent stops
holding, the decision is open again.

Name files `NNNN-short-slug.md`, numbered in order. This repository has one author; projects using the
preset get dated names instead (see 0006). Never edit a record's Decision after the fact: write a
new record and set the old one's status to `superseded by NNNN`, or `amended by NNNN` when the new
record changes only part of it.

```markdown
# NNNN. Title

Status: active | amended by NNNN | superseded by NNNN
Date: YYYY-MM-DD

## Intent

The outcome this decision protects, observable where possible.

## Decision

What was chosen, in a few sentences.

## Rejected

- Alternative: why it lost.

## Evidence

- **measured** / **documented** / **assumption**: what the decision rests on.

## Revisit when

A concrete trigger, not "if needed".
```

| Record | Status |
|---|---|
| [0001 Replace core commands instead of composing](0001-replace-core-commands.md) | active |
| [0002 Dated feature IDs derived from the name](0002-dated-feature-ids.md) | active |
| [0003 Loosening an outcome needs the user's confirmation](0003-loosening-needs-confirmation.md) | amended by 0012 |
| [0004 Vendor the Superpowers visual companion](0004-vendor-visual-companion.md) | active |
| [0005 Decision records stay in this repository](0005-decision-records-not-shipped.md) | superseded by 0006 |
| [0006 Ship lean decision records in the preset](0006-ship-decision-records.md) | amended by 0012 |
| [0007 Detect changes to the target with a hash](0007-target-hash.md) | amended by 0012, 0015 |
| [0008 Failure conditions as Never: outcomes](0008-never-outcomes.md) | active |
| [0009 Independent verification is opt-in](0009-optional-independent-verify.md) | active |
| [0010 An order of authority and five reasons to stop](0010-when-to-stop-and-ask.md) | amended by 0012, 0013 |
| [0011 Two sizes: small and normal](0011-two-sizes.md) | active |
| [0012 Friction fixes from the 2026-10-07 review](0012-review-friction-fixes.md) | active |
| [0013 Build rules live in tasks.md; Results only from verify](0013-build-rules-in-tasks.md) | amended by 0015, 0016 |
| [0014 What a hand-written small-work record taught the preset](0014-lessons-from-small-work-records.md) | amended by 0016 |
| [0015 Verify catches regressions and keeps the history](0015-verify-regressions-and-history.md) | amended by 0016 |
| [0016 Field-report rules after 0015, and a trim](0016-field-rules-and-trim.md) | active |
