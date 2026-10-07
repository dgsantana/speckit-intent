# Decisions

One file per decision that is hard to reverse or likely to be argued again. A record states the outcome
it protects first, because a decision is only right relative to what it is for; when that intent stops
holding, the decision is open again.

Name files `NNNN-short-slug.md`, numbered in order. This repository has one author; projects using the
preset get dated names instead (see 0006). Never edit a record's Decision after the fact: write a
new record and set the old one's status to `superseded by NNNN`.

```markdown
# NNNN. Title

Status: active | superseded by NNNN
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
| [0003 Loosening an outcome needs the user's confirmation](0003-loosening-needs-confirmation.md) | active |
| [0004 Vendor the Superpowers visual companion](0004-vendor-visual-companion.md) | active |
| [0005 Decision records stay in this repository](0005-decision-records-not-shipped.md) | superseded by 0006 |
| [0006 Ship lean decision records in the preset](0006-ship-decision-records.md) | active |
| [0007 Detect changes to the target with a hash](0007-target-hash.md) | active |
| [0008 Failure conditions as Never: outcomes](0008-never-outcomes.md) | active |
| [0009 Independent verification is opt-in](0009-optional-independent-verify.md) | active |
| [0010 An order of authority and five reasons to stop](0010-when-to-stop-and-ask.md) | active |
