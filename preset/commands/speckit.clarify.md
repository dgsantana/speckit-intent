---
description: Resolve what the spec leaves ambiguous, asking only where the answer changes an outcome or its check.
handoffs:
  - label: Plan It
    agent: speckit.plan
    prompt: Plan the change that reaches the spec's outcomes
scripts:
  sh: scripts/bash/check-prerequisites.sh --json --paths-only
  ps: scripts/powershell/check-prerequisites.ps1 -Json -PathsOnly
  py: scripts/python/check_prerequisites.py --json --paths-only
---

## User Input

```text
$ARGUMENTS
```

## Hooks

Before starting, read `.specify/extensions.yml` if it exists and run each enabled hook under
`hooks.before_clarify`: a hook with `optional: false` is executed now and waited for (command id dots
become hyphens); an optional one is offered to the user as a question. Skip a hook with a non-empty `condition`; the hook runner evaluates those. If the file cannot be parsed, say so, including that mandatory hooks were
not run. After updating the spec, do the same for `hooks.after_clarify`.

## Principle

A question earns its place only if a different answer would change an outcome, its check, a constraint or
an edge case. Anything else gets a sensible default, stated in one line, and no question.

## Asking the user

Ask through the agent's structured question tool when it has one (`AskUserQuestion` in Claude Code, the
equivalent tool in other agents): one decision per question, two to four options, your recommendation
first and marked as such, one line on each option's consequence. Questions whose answers do not depend on
each other may share one call. Without such a tool, ask in plain text: the question, then a short
numbered list with the recommendation first. Never print a table of lettered options for the user to
type a letter back. To settle an order (which tasks or items first), propose one and ask whether to keep
it or change it; do not ask the user to rank a list.

## Changing the target

Once the spec has a `target_hash` (`plan` records it), its Outcomes and Constraints are the agreed target.
Any edit to them, tightening or loosening, adds one line to the spec's Target changes section (date, item, what
changed, tightened or loosened, who confirmed a loosening) and then re-records the hash:

```text
pwsh -NoProfile -File .specify/extensions/intent/scripts/powershell/target-hash.ps1 -Record
```

Never re-record without the Target changes line. A recorded hash that no longer matches, with no line explaining
the difference, is how a silent change to the target is found.

## Steps

1. Run `{SCRIPT}` from the repository root and parse FEATURE_SPEC and FEATURE_DIR.

2. Read the spec, and the code and decision records it touches. Look for:
   - an outcome a reader could not observe, or whose check has no pass threshold;
   - two outcomes, or an outcome and a constraint, that cannot both hold;
   - an edge case with no expected behaviour;
   - a claim tagged `documented` or `assumption` that an outcome depends on;
   - the spec's own Open questions.

3. Ask at most five questions, as Asking the user describes. Ask a question whose options depend on an
   earlier answer only after that answer. Stop early when the rest would not change an
   outcome. If a question would be clearer shown than described (a layout, a diagram, visual options side by
   side) and the companion extension is installed, use `__SPECKIT_COMMAND_COMPANION_SHOW__` for it.

4. Write each answer where it belongs: in the outcome, check, constraint, edge case or Evidence entry it
   settles, not in a separate clarifications section. Remove the Open question it answers. An answer
   that loosens an outcome or its check is the user's decision by construction, so it may be applied.
   After planning, record the edit as Changing the target describes.

5. Keep the spec's sections as the template has them; add none.

## Report

Each question with the answer and where it was written, any remaining Open questions, and the next step:
`__SPECKIT_COMMAND_PLAN__`.
