# 0001. Replace core commands instead of composing

Status: active
Date: 2026-10-06

## Intent

An agent running a Spec Kit command receives one set of instructions, so it cannot drift back to the
vanilla workflow's artifacts (user stories, `FR-###`, research and data-model files by default) when the
intent workflow says otherwise.

## Decision

The preset replaces `specify`, `clarify`, `plan`, `tasks`, `analyze`, `converge` and `checklist`
outright, each kept
short. They keep what other tooling depends on: the setup scripts, hook dispatch, `.specify/feature.json`
and the `- [ ] T### ...` task format. `implement`, `constitution` and `taskstoissues` stay core because
they work on an intent spec unchanged. `checklist` is replaced for how it asks: core
`checklist.md:110` prescribes a table of lettered options. Minimum Spec Kit is 1.1.1, the version `converge`
was checked against.

## Rejected

- Prepend or wrap the core commands: the agent then holds a short intent preamble and a 200 to 350 line
  core command that disagree, and follows the longer one.
- Replace only `specify`, `plan`, `tasks`: core `clarify`, `analyze` and `converge` inventory `FR-###`,
  `SC-###` and user stories and write into those sections, so they report false gaps on an intent spec
  or add vanilla sections to it.

## Evidence

- **documented**: Spec Kit 1.1.1 `core_pack/commands/analyze.md:82-110`, `clarify.md:185-192` and
  `converge.md:111-137` build their inventories from `FR-###`, `SC-###` and user stories.
- **measured**: on a scratch Spec Kit 1.1.1 project with Claude and Codex integrations, `install.ps1`
  renders all six replacements for both (2026-10-06).
- **assumption**: agents follow the longer of two conflicting instruction sets. Stated in the README from
  experience with the preset's first version; not measured.

## Revisit when

A Spec Kit release changes the contract of a replaced command (scripts, hook names, `feature.json`, task
format), or makes core commands configurable enough to express the intent workflow without replacement.
