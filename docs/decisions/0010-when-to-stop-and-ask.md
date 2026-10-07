# 0010. An order of authority and five reasons to stop

Status: active
Date: 2026-10-07

## Intent

While building, the agent stops for the user only when it must, asks each question once, and never
settles a disagreement between artifacts by re-arguing it: the loop that makes vanilla Spec Kit fight
its own outcomes.

## Decision

The plan template carries a fixed "When to stop and ask" section, so core `implement`, which reads
`plan.md`, gets it without being replaced. It sets an order of authority: the spec's Outcomes and
Constraints, then decision records, then the plan, then tasks; a lower one never overrides a higher
one. It names the only reasons to stop: ambiguity, conflict (between things the user owns, or replacing
an active decision record), target (fixing an outcome would loosen it), irreversible, stuck. Each answer
is written where it belongs (outcome with a Target changes line, a superseding decision record, or a
Choice) and is not asked again.

## Rejected

- Escalation kinds alone, as ICED lists them: without an order of authority and a rule against
  re-asking, a disagreement between, say, a decision record and the plan is still open to re-litigation
  on every run.
- Replace core `implement` to carry the rules: one more replaced command to keep in step with Spec Kit
  (0001), when the plan it already reads can carry them.

## Evidence

- **documented**: ICED `spec/SPEC.md` section 8.5 lists the escalation kinds this follows.
- **documented**: core `implement.md:92` (Spec Kit 1.1.1): "**REQUIRED**: Read plan.md for tech stack,
  architecture, and file structure".
- **assumption**: an agent that reads the plan for that purpose also follows a section of rules in it.
  Not yet observed in a build.
- **assumption**: vanilla loops come from several sources of truth (constitution, spec, plan,
  checklists) without precedence; stated from use, not measured.

## Revisit when

A build asks the same question twice across runs, or stops for something outside the five reasons.
