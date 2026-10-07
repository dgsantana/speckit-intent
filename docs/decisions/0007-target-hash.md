# 0007. Detect changes to the target with a hash

Status: active, amended by [0012](0012-review-friction-fixes.md)
Date: 2026-10-07

## Intent

A change to a spec's Outcomes or Constraints after planning is never silent: either it is logged in the
spec's Target changes section, or `analyze` and `intent.verify` report it.

## Decision

`plan` records `target_hash` in the spec's frontmatter: SHA-256 of the normalised Outcomes and
Constraints sections, computed by `extensions/intent/scripts/powershell/target-hash.ps1`, never by a
model. Every command that may edit the target carries the same "Changing the target" rule: add a line to
Target changes, then re-record the hash. `analyze` and `intent.verify` check it and report a change no
line explains, finding the edits through git history.

This is detection, not enforcement. An agent can still edit the target and re-record without logging;
the hash makes the lazy or accidental case visible, and the diff of the spec shows the rest in review.

## Rejected

- Rule in text only (0003 as it stood): nothing notices when it is broken.
- Enforce with a tool-call gate, as ICED does for pi: Spec Kit cannot intercept an agent's tool calls,
  and ICED's gate needs a growing shell-command parser to tell safe commands from edits.
- Hash the whole spec: Evidence, Results and Edge cases change legitimately during the work.

## Evidence

- **documented**: ICED (github.com/arturleao/pi-intent, `spec/SPEC.md` section 5) freezes Intent and
  Expectations with a contract hash; this follows its normalisation.
- **measured**: `tests/target-hash.Tests.ps1` pins the hash value, insensitivity to whitespace, line
  endings, comments and other sections, and detection of a changed threshold or constraint
  (2026-10-07).

## Revisit when

Specs reach review with `changed` reported and no explanation, which would mean detection is not
enough; or Spec Kit gains a way to gate edits.
