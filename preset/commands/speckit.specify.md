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
user with its prompt. Leave hook `condition` expressions to the hook runner. If the file cannot be parsed,
say so, including that mandatory hooks were not run. After writing the spec, do the same for
`hooks.after_specify`.

## Principle

The spec states outcomes, not activity. An outcome is something a person or another program can observe,
and it carries the check that proves it. Everything else in the spec exists to make those outcomes
unambiguous: what must not break, what is out of scope, what happens at the edges, and what the claims
rest on. Short beats complete: a reader should finish it in a few minutes.

## Steps

1. **Feature directory.** Use `SPECIFY_FEATURE_DIRECTORY` if the user gave one. Otherwise derive a 2-4 word
   slug from the description and number it from `.specify/init-options.json` `feature_numbering`
   (`sequential` or absent: next free `NNN` under `specs/`; `timestamp`: `YYYYMMDD-HHMMSS`). Create
   `specs/<prefix>-<slug>/`, copy the resolved `spec-template` (the preset stack's, as
   `specify preset resolve spec-template` reports) to `spec.md`, and write
   `{"feature_directory": "<that path>"}` to `.specify/feature.json`. One feature per invocation.

2. **Read before writing.** Load `.specify/memory/constitution.md` if present, and skim the project's own
   docs index and any decision records the description touches. Look at the code the description names:
   a spec that contradicts the code is wrong before it starts.

3. **Fill the template.**
   - Goal: who needs it and the trigger.
   - Outcomes: each observable, with numbers where they matter, each with a check (test, command or
     measurement and its pass threshold). Prefer few strong outcomes over many weak ones.
     Behaviour that must stay the same for existing inputs is an outcome too, with its own check.
   - Constraints, out of scope, edge cases: one line each.
   - Evidence: tag every claim measured, documented or assumption. Do not promote an assumption to fact
     without a measurement.
   - Open questions: at most three, only where the answer changes an outcome. For anything else, choose a
     sensible default and say so in one line.
   - Leave Results as the template has it.

4. **No implementation in the spec.** Interfaces and short pseudo-code are acceptable when an outcome
   cannot be stated without them; function bodies are not.

5. **Do not generate** a separate quality checklist, a research file or a data model here.

## Report

The feature directory, the outcomes in one line each, any open questions (asked with the platform's
question tool if it has one), and the next step: `__SPECKIT_COMMAND_PLAN__`.
