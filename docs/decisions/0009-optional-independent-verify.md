# 0009. Independent verification is opt-in

Status: active
Date: 2026-10-07

## Intent

A result can be checked by an agent that did not build the work, when the user wants that and can pay
for it; nobody is charged for it by default.

## Decision

`intent.verify` runs as before, by the builder, after `implement`. With `independent` in its input it
also hands the target, the results and the diff to a sub-agent with a fresh context and read-only tools,
told to show the work does not meet them; an outcome stays Pass only if that agent found no failure. It
never runs from the hook or by default. Results record who checked each outcome (`builder` or
`builder + independent`), and the report says when the builder checked alone.

## Rejected

- Always run an independent verifier, as ICED does for medium and larger units: a fresh agent's base
  prompt and tooling alone are about 65k tokens, a cost some users of the preset cannot carry.
- No independent option: the builder grading its own work is the weakest part of verification.

## Evidence

- **measured**: a fresh agent's base prompt and tooling are about 65k tokens (reported by the
  maintainer, 2026-10-07).
- **measured**: ICED's own unit 008 passed with "independent verifier: no", the verifier having hit a
  usage limit (`intent/008-gate-freeze-scope-while-the-active-unit/evidence.md` in pi-intent).

## Revisit when

Sub-agent cost drops enough to run it by default, or self-checked results are found wrong in review.
