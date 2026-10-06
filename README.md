# speckit-intent

A Spec Kit preset and two extensions that keep Spec-Driven Development pointed at outcomes. A spec says
what must be true when the work is done and how each part of that is checked; the plan and tasks stay
short; verification records what was actually observed. Extra documents (research, data model,
contracts, quickstart) are written only when they carry something the work depends on.

It follows the shape of [IntentSpec](https://intentspec.org/) (goal, outcomes, constraints, edge cases,
verification, evidence) inside Spec Kit's own files and commands, so the CLI, agent integrations,
branch hooks and anything that reads `tasks.md` keep working.

| Component | Kind | What it changes |
|---|---|---|
| `preset/` (`intent`) | Preset | Replaces `spec-template`, `plan-template`, `tasks-template` and the `specify`, `plan`, `tasks` commands with outcome-first versions |
| `extensions/intent` | Extension | Adds `speckit.intent.verify` and runs it after `implement` |
| `extensions/feature-id` | Extension | Names feature directories `<yyyyMMdd>-<hash>-<slug>` instead of `NNN-slug`; allocator, audit and migration scripts |

Core `implement`, `clarify`, `analyze`, `checklist` and `constitution` are untouched.

## Why replace instead of compose

Spec Kit presets can prepend, append or wrap core commands. A short preamble on top of a 345-line core
command leaves the agent two sets of instructions to reconcile, and in practice it drifts back to the
heavier one. The three replaced commands are deliberately small and keep what other tools rely on: the
setup scripts, hook dispatch, `.specify/feature.json`, and the `- [ ] T### ...` task format. The cost is
that upstream changes to those three commands do not flow in; review the Spec Kit changelog on upgrade.

## The artifacts

**spec.md**: frontmatter `id` and `status` (`draft`, `planned`, `building`, `verified`, `partial`,
`dropped`); Goal; an Outcomes table where every outcome carries its check; Constraints; Out of scope;
Edge cases; Evidence tagged `measured`, `documented` or `assumption`; at most three Open questions;
Results, filled only by verification.

**plan.md**: Approach (interfaces and pseudo-code, no implementations); Changes mapped to the outcomes
they serve; Choices that are hard to reverse, with the rejected alternative; Risks; links to any
supporting document and why it exists.

**tasks.md**: `- [ ] T### [P?] [O#,...] Description with file path`, grouped so each group reaches an
outcome end to end, tests before the change they hold, ending with verification.

**Results** (written by `speckit.intent.verify`): per outcome Pass, Fail, Partial or Not run, with the
command, numbers and commit checked.

## Install in a project

Requires Spec Kit 1.0.4 or later and PowerShell 7 (`pwsh`) for the feature-id scripts.

From the project root:

```text
pwsh -NoProfile -File D:/dev/tools/speckit-intent/install.ps1               # preset, intent and feature-id
pwsh -NoProfile -File D:/dev/tools/speckit-intent/install.ps1 -NoFeatureId  # keep NNN- numbering
```

Use the script rather than `specify preset add` directly. Spec Kit (checked on 1.0.4 and 1.1.1) registers
preset and extension commands for the active integration only, so a project with omp, Claude Code and
Codex installed would get the intent commands in one of them and keep the core ones in the others. The
script installs through Spec Kit for the default integration, renders each other integration in a
temporary copy of the project, and brings back only this repository's command files. It also turns
development-mode symbolic links into ordinary files, so the result can be committed, and ignores the
`.specify-dev` staging folder.

Commands are materialised at install time: rerun the script after editing this repository, after
`specify integration upgrade`, or after adding an integration. It is safe to run repeatedly.

Projects that set rules in `.specify/memory/constitution.md` keep them; the commands read it. Rules there
that demand artifacts this preset makes optional (a research file for every feature, a decision record
for every choice) should be loosened in the same change, or the agent is again given two conflicting
instructions.

## Feature IDs

Sequential IDs make the next number a function of what one person can see. Two branches that cannot see
each other take the same number, and neither is wrong. A dated ID derives its hash from the feature's
name: two features collide only when they are given the same name, which is worth knowing.

```text
20260918-92526bb-standard-geospatial-formats
```

The hash is SHA-1 over the slug, truncated to 7 hex characters and widened only if a different slug holds
that prefix. It is always produced by the script, never written by hand or by a model, and the audit
fails any directory whose hash does not match its own slug.

Use it on repositories where more than one person or agent opens specs on separate branches. A
single-author repository gains little.

### Allocate and audit

The extension runs the allocator as the mandatory `before_specify` hook, so a normal `specify` run needs
nothing extra. Directly:

```text
pwsh -NoProfile -File .specify/extensions/feature-id/scripts/powershell/new-feature-id.ps1 -Name "<feature name>"
pwsh -NoProfile -File .specify/extensions/feature-id/scripts/powershell/new-feature-id.ps1 -Verify
```

### Moving an ongoing project from NNN- numbering

Existing `NNN-slug` directories keep working without migrating: the audit reports them as legacy, the
allocator only creates dated IDs, and the two coexist. Migrating renames them so the register reads one
way.

1. **Pick the moment.** Run it on the integration branch (`dev`, `develop`), with no uncommitted work.
   Open feature branches are easiest to bring across when they are few.
2. **Dry run**, and read the list of renames and of files whose references will be rewritten:
   ```text
   pwsh -NoProfile -File .specify/extensions/feature-id/scripts/powershell/migrate-feature-ids.ps1
   ```
   Dates come from the oldest commit on any branch that added each `spec.md`, so every branch derives the
   same names. Changelogs and `history/` folders are left alone (`-Keep` changes the patterns), because
   they describe what happened under the old names.
3. **Apply and commit** the renames, the rewritten references and `.specify/feature-id-migration.json`
   together, as one commit that does nothing else:
   ```text
   pwsh -NoProfile -File .specify/extensions/feature-id/scripts/powershell/migrate-feature-ids.ps1 -Apply
   pwsh -NoProfile -File .specify/extensions/feature-id/scripts/powershell/new-feature-id.ps1 -Verify
   ```
4. **Bring open feature branches across.** Either merge or rebase the integration branch into them (git
   follows the renames), or run the same migration on the branch after the mapping file has reached it.
   The mapping is authoritative, so the branch takes identical names and the later merge is a no-op
   rename. A spec created only on that branch is renamed by date from history as usual.
5. **Leave branch names alone.** A branch called `007-streaming-raster-ingest` keeps its name until it
   merges; `.specify/feature.json` is what points tools at its spec, and the migration rewrites it.
   New branches take the dated ID.

Going forward: start every spec through `specify` (the hook allocates the ID), never type an ID, and run
`-Verify` when reviewing a branch that adds or renames a spec.

### Renaming a feature

Rename the slug deliberately, run the allocator for the new name, move the directory to the ID it
returns, update references, and run `-Verify`. Do not change the date: it records allocation, not
status.

## Layout

```text
install.ps1      installs into the current project, for every integration
preset/
  preset.yml
  commands/      speckit.specify.md, speckit.plan.md, speckit.tasks.md
  templates/     spec-template.md, plan-template.md, tasks-template.md
extensions/
  intent/        extension.yml, commands/speckit.intent.verify.md
  feature-id/    extension.yml, commands/speckit.feature-id.allocate.md,
                 scripts/powershell/{feature-id-lib,new-feature-id,migrate-feature-ids}.ps1
```
