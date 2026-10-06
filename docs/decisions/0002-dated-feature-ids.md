# 0002. Dated feature IDs derived from the name

Status: active
Date: 2026-10-06

## Intent

People or agents starting specs on separate branches never collide because of allocation order; they
collide only when they start the same feature, and then they find out at merge.

## Decision

Feature directories are named `<yyyyMMdd>-<hash>-<slug>`. The hash is SHA-1 of the slug, truncated to
7 hex characters (never fewer, so Spec Kit's six-digit timestamp time cannot read as a hash), computed
by the script only. It adds no uniqueness over the slug; it is a short handle and lets the audit catch
hand-edited slugs. The audit (`new-feature-id.ps1 -Verify`) fails a hash that does not match its slug
and a slug held by more than one directory, legacy names included, so a dated ID beside `007-auth` for
the same name fails. Legacy `NNN-` and Spec Kit `yyyyMMdd-HHmmss-` directories coexist and can be
migrated with a committed mapping file so every branch derives the same names.

## Rejected

- Sequential `NNN-` numbering: the next number depends on what one branch can see, so two branches take
  the same number and neither is wrong.
- Spec Kit's `timestamp` numbering: unique, but two branches starting the same feature get two
  directories and nothing reports it.
- `<date>-<slug>` without a hash: equally unique. Kept the hash for the short handle and the
  hand-edit check; dropping it now would rename every existing ID.

## Evidence

- **measured**: `tests/feature-id.Tests.ps1` pins slug folding, the README's example hash, the
  duplicate-slug audit across dated and legacy names, timestamp IDs read as legacy, and migration of
  prefix-sharing, same-slug and timestamp legacy names (2026-10-06).
- **documented**: a 7-hex prefix gives 2^28 values; a clash between two different slugs is about one in
  268 million per pair.

## Revisit when

A repository using it hits a hash-prefix clash in practice, or Spec Kit adopts a collision-safe ID scheme
of its own.
