# 0012. Friction fixes from the 2026-10-07 review

Status: active
Date: 2026-10-07

## Intent

The rules added for protection stop and ask only where a decision is really the user's, never
contradict each other, and never stall the work on something the agent cannot resolve.

## Decision

Amends 0003, 0006, 0007 and 0010:

- **0003**: loosening means dropping an outcome or lowering a threshold. "Narrowing what the check
  covers" is no longer listed, because it overlapped with correcting a check that tests the wrong thing.
- **0006**: when a project keeps no decisions folder, `plan` asks once whether to keep records in
  `docs/decisions/`, and stores the answer in `.specify/intent.json` (`decision_records`: a path or
  `false`). It no longer creates the folder silently.
- **0007**: an unexplained change to the target is reported and the work carries on. `plan` adds a
  Target changes line for it ("found at planning"); `verify` notes it at the top of Results. Neither stops.
  The hash script treats a removed Constraints section as empty.
- **0010**: the stop section is one paragraph. The constitution, the spec and decision records belong to
  the user; the plan and tasks give way to them. A conflict between two of the user's, including
  replacing a decision record, is asked; `plan` no longer supersedes records on its own.

Also: the red-first rule has one wording, repeated word for word wherever tasks are ordered or checks
judged; the `planned` status is gone (nothing read it); `converge`, which asks nothing, lost its copy of
the asking rule; `verify` records uncommitted work as `uncommitted on <short HEAD>`; and the install
steps recommend feature-id only when `git shortlog` shows more than one author.

## Rejected

- Keep asking on an unexplained target change: a spec never committed gives git nothing to show, so the
  agent cannot answer its own question, and the spec owner is questioned for editing their own spec.
- Drop the target hash: loses detection of a silent edit; reporting keeps it at no cost to the work.

## Evidence

- **documented**: review of c656a8d (2026-10-07): `plan.md:76-77` superseded records without asking
  while `plan-template.md:40-41` said to ask; the constitution was missing from the order of authority;
  red-first was worded four ways; `status: planned` had no reader; `git diff` cannot show an untracked
  spec.

## Revisit when

A build is seen asking for something outside the five reasons, or a silent target change reaches review
unreported.
