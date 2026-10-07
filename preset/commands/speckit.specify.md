---
description: Write an intent spec - the outcomes this feature must reach and how each is checked.
handoffs:
  - label: Plan It
    agent: speckit.plan
    prompt: Plan the change that reaches the spec's outcomes
---

## User Input

```text
$ARGUMENTS
```

The text after `__SPECKIT_COMMAND_SPECIFY__` is the feature description, even if `{ARGS}` appears
literally here. Ask for it only if it is empty.

## Hooks

Before starting, read `.specify/extensions.yml` if it exists and run each enabled hook under
`hooks.before_specify`: a hook with `optional: false` is executed now and waited for (command id dots
become hyphens, e.g. `speckit.git.feature` -> `/speckit-git-feature`); an optional one is offered to the
user as a question. Skip a hook with a non-empty `condition`; the hook runner evaluates those. If the file cannot be parsed,
say so, including that mandatory hooks were not run. After writing the spec, do the same for
`hooks.after_specify`.

## Principle

The spec states outcomes, not activity. An outcome is something a person or another program can observe,
and it carries the check that proves it. Everything else in the spec exists to make those outcomes
unambiguous: what must not break, what is out of scope, what happens at the edges, and what the claims
rest on. Short beats complete: a reader should finish it in a few minutes.

## Asking the user

Ask through the agent's structured question tool when it has one (`AskUserQuestion` in Claude Code, the
equivalent tool in other agents): one decision per question, two to four options, your recommendation
first and marked as such, one line on each option's consequence. Questions whose answers do not depend on
each other may share one call. Without such a tool, ask in plain text: the question, then a short
numbered list with the recommendation first. Never print a table of lettered options for the user to
type a letter back. To settle an order (which tasks or items first), propose one and ask whether to keep
it or change it; do not ask the user to rank a list.

## Steps

1. **Feature directory.** If `SPECIFY_FEATURE_DIRECTORY` is set, whether the user gave it or a
   `before_specify` hook allocated it, that is the directory; do not derive another name over it.
   Otherwise derive a 2-4 word slug from the description and number it from `.specify/init-options.json`
   `feature_numbering` (`sequential` or absent: next free `NNN` under `specs/`; `timestamp`:
   `YYYYMMDD-HHMMSS`), giving `specs/<prefix>-<slug>/`.

   Then, either way: create the directory, copy the resolved `spec-template` (the preset stack's, as
   `specify preset resolve spec-template` reports) to `spec.md`, and write
   `{"feature_directory": "<that path>"}` to `.specify/feature.json`. A hook only names the directory;
   this command creates it. One feature per invocation. This command creates no git branch; say which
   branch the work is on.

2. **Read before writing.** Load `.specify/memory/constitution.md` if present, and skim the project's own
   docs index and any decision records the description touches. Look at the code the description names:
   a spec that contradicts the code is wrong before it starts.

3. **Size.** Set `size` in the frontmatter and say which in one line, with why; the user may override it.
   `small`: a bug fix, or a change confined to a few files that adds no interface, data shape,
   dependency or decision others will build on. `normal`: anything else. A small spec has Goal, Outcomes
   and Results, plus any other section that has something to say; a small change gets no target hash, no
   decision record and a two-section plan.

4. **Fill the template.** Keep Goal, Outcomes and Results; remove every other section that would be empty.
   - Goal: who needs it and the trigger.
   - Outcomes: each observable, with numbers where they matter, each with a check (test, command or
     measurement and its pass threshold), which must be able to run on what the outcome names (a release
     build writes no debug log). A check that is a person's observation states the exact steps: the mode
     or path, the input, and what to look for, in the same form the outcome names, so the observer gets it
     right the first time. Prefer few strong outcomes over many weak ones. Behaviour that
     must stay the same for existing inputs is an `Unchanged:` outcome. For a bug, the outcome is a
     single `Never:` one: the reported behaviour does not occur. For other work, add a `Never:` outcome
     only for a failure a skeptical reviewer would try that no other outcome already rules out.
   - Decided: choices the user has already made that the work must follow, with the options not taken.
   - Constraints, out of scope, edge cases: one line each. An edge case whose wrong handling would miss
     the intent becomes an outcome, usually `Never:`.
   - Evidence: tag every claim measured, documented or assumption. Do not promote an assumption to fact
     without a measurement.
   - Open questions: at most three, only where the answer changes an outcome. For anything else, choose a
     sensible default and say so in one line.
   - Leave Results as the template has it.

   If a question would be clearer shown than described (a layout, a diagram, visual options side by
   side) and the companion extension is installed, use `__SPECKIT_COMMAND_COMPANION_SHOW__` for it.

5. **No implementation in the spec.** Interfaces and short pseudo-code are acceptable when an outcome
   cannot be stated without them; function bodies are not.

6. **Do not generate** a separate quality checklist, a research file or a data model here.

## Report

The feature directory, the size and why, the outcomes in one line each, any open questions (asked as Asking the user
describes), and the next step: `__SPECKIT_COMMAND_PLAN__`.
