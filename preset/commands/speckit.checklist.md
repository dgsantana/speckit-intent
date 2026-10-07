---
description: Write a reviewer's checklist for one concern (security, accessibility, operability...) that tests whether the spec and plan say enough about it.
scripts:
  sh: scripts/bash/check-prerequisites.sh --json
  ps: scripts/powershell/check-prerequisites.ps1 -Json
  py: scripts/python/check_prerequisites.py --json
---

## User Input

```text
$ARGUMENTS
```

## Hooks

Before starting, read `.specify/extensions.yml` if it exists and run each enabled hook under
`hooks.before_checklist`: a hook with `optional: false` is executed now and waited for (command id dots
become hyphens); an optional one is offered to the user as a question.
Skip a hook with a non-empty `condition`; the hook runner evaluates those. If the file cannot be
parsed, say so, including that mandatory hooks were
not run. After writing the checklist, do the same for `hooks.after_checklist`.

## Principle

A checklist item tests the writing, not the code: whether the spec and plan state what this concern
needs, precisely enough to check. "Is the lockout threshold after failed logins stated, with its
duration?" is an item; "Does login lock out after five failures?" is a test and belongs in an outcome's
check. The checklist belongs to the reviewer: this command writes it and never ticks an item.

## Asking the user

Ask through the agent's structured question tool when it has one (`AskUserQuestion` in Claude Code, the
equivalent tool in other agents): one decision per question, two to four options, your recommendation
first and marked as such, one line on each option's consequence. Questions whose answers do not depend on
each other may share one call. Without such a tool, ask in plain text: the question, then a short
numbered list with the recommendation first. Never print a table of lettered options for the user to
type a letter back. To settle an order (which tasks or items first), propose one and ask whether to keep
it or change it; do not ask the user to rank a list.

## Steps

1. Run `{SCRIPT}` from the repository root and parse FEATURE_DIR. Read spec.md, and plan.md and tasks.md
   if present.

2. Take the concern from the input. If it is missing, or the depth that matters (a quick pre-merge pass,
   a formal review) is unclear and would change the items, ask; at most two questions.

3. Write `<FEATURE_DIR>/checklists/<concern>.md`: a title, one line on what the checklist is for, then
   items `- [ ] CHK### Question? [Outcome O# | Constraint | Edge case | Gap]`, numbered from CHK001.
   Each item names where in the spec or plan it looks, or `Gap` when the subject is missing. Keep to what
   this feature touches; fifteen sharp items beat forty generic ones. If the file exists, append items
   continuing its numbering and leave existing items and their ticks alone.

## Report

The checklist path, the item count, and the items marked `Gap`. `__SPECKIT_COMMAND_IMPLEMENT__` stops
on unticked items in `checklists/`, so the reviewer ticks or removes them first.
