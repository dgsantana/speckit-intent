---
description: Allocate the feature directory ID for a new spec, or audit specs/ for IDs that do not match their names.
---

## User Input

```text
$ARGUMENTS
```

## What this does

Allocates the directory a new specification lives in, and nothing else: no spec content, no branch, no
commit. Feature IDs have the shape `<yyyyMMdd>-<hash>-<slug>`, for example
`20260918-92526bb-standard-geospatial-formats`. The date orders the register; the hash is SHA-1 over the
slug, truncated, so it belongs to the name rather than to allocation order. Two people on branches that
cannot see each other collide only if they choose the same name, and that collision is worth knowing.

**The hash comes from the script, never from you.** A plausible hex string written by a model cannot be
re-derived from its slug, and the audit below will fail it.

## Allocate

When run as the `before_specify` hook, the input is the feature description: derive a short name of two
to four words from it first. Then run from the project root:

```text
pwsh -NoProfile -File .specify/extensions/feature-id/scripts/powershell/new-feature-id.ps1 -Name "<short name>"
```

It prints JSON with `FEATURE_ID`, `SLUG`, `HASH`, `DATE`, `FEATURE_DIRECTORY` and `EXISTING`.

1. If `EXISTING` is true, a spec for this name already exists. Stop and tell the user; do not choose a
   variant name to get a fresh ID.
2. Otherwise set `SPECIFY_FEATURE_DIRECTORY` to `FEATURE_DIRECTORY` for the rest of the run, and write
   `{"feature_directory": "<FEATURE_DIRECTORY>"}` to `.specify/feature.json`.
3. Report `FEATURE_ID`.

## Audit

If the input is `--verify`, run the same script with `-Verify`. It recomputes every dated ID's hash from
its own slug; a non-zero exit lists directories that were hand-edited or renamed without re-deriving
their hash, and directories that share a slug (two branches that started the same feature). Legacy
`NNN-` directories are reported as legacy, not failures.

## Renaming a feature

Change the slug deliberately, run the allocator for the new name, move the directory to the ID it
returns, update references, and run the audit. Do not change an ID's date: it records allocation, not
status.
