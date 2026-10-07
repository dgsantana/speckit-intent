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
| `preset/` (`intent`) | Preset | Replaces `spec-template`, `plan-template`, `tasks-template` and the `specify`, `clarify`, `plan`, `tasks`, `analyze`, `converge`, `checklist` commands with outcome-first versions |
| `extensions/intent` | Extension | Adds `speckit.intent.verify` and runs it after `implement` |
| `extensions/companion` | Extension | Adds `speckit.companion.show`: visual questions in a local browser tab, each settled choice recorded in the spec or plan |
| `extensions/feature-id` | Extension | Names feature directories `<yyyyMMdd>-<hash>-<slug>` instead of `NNN-slug`; allocator, audit and migration scripts |

Core `implement`, `constitution` and `taskstoissues` are untouched. `clarify`, `analyze` and `converge`
are replaced because the core versions inventory `FR-###`, `SC-###` and user stories and write answers
into those sections, which an intent spec does not have. `checklist` is replaced because the core version
asks its questions as a table of lettered options to type back.

Every command that asks the user something carries the same "Asking the user" rule: use the agent's
structured question tool when it has one (`AskUserQuestion` in Claude Code), one decision per question
with the recommendation first, and propose an order rather than asking the user to rank a list. Spec Kit
1.1.1 has no notion of such tools, so without this the agent prints tables and waits for a typed letter. `taskstoissues` keeps working; the
`[O#]` labels stay in issue titles.

## Why replace instead of compose

Spec Kit presets can prepend, append or wrap core commands. A short preamble on top of a 345-line core
command leaves the agent two sets of instructions to reconcile, and in practice it drifts back to the
heavier one. The replaced commands are deliberately small and keep what other tools rely on: the
setup scripts, hook dispatch, `.specify/feature.json`, and the `- [ ] T### ...` task format. The cost is
that upstream changes to the replaced commands do not flow in; review the Spec Kit changelog on upgrade.

## The artifacts

**spec.md**: frontmatter `id` and `status` (`draft`, `planned`, `verified`, `partial`, `failed`, and
`dropped` set by hand);
Goal; an Outcomes table where every outcome carries its check, with behaviour that must not change
written as `Unchanged:` outcomes and ways the intent could still be missed as `Never:` outcomes;
Constraints; Out of scope;
Edge cases; Evidence tagged `measured`, `documented` or `assumption`; at most three Open questions;
Target changes, logged when Outcomes or Constraints change after planning; Results, filled only by
verification.

**plan.md**: Approach (interfaces and pseudo-code, no implementations); Changes mapped to the outcomes
they serve; Choices that are hard to reverse, with the rejected alternative; Risks; links to any
supporting document and why it exists.

**tasks.md**: `- [ ] T### [P?] [O#,...] Description with file path`, grouped so each group reaches an
outcome end to end, tests before the change they hold. Verification is not a task: the intent
extension runs it after `implement`.

**Results** (written by `speckit.intent.verify`): per outcome Pass, Fail, Partial or Not run, with the
command, numbers and commit checked.

An outcome or its check can change after the spec is written, when planning, tasking or verification
shows it was wrong. Tightening it, or correcting a check that tested the wrong thing, is recorded in the
spec and needs no approval. Loosening it (dropping it, lowering a threshold, narrowing what the check
covers) needs the user's confirmation first: otherwise the agent can make the work pass by moving the
target.

`plan` records a hash of the spec's Outcomes and Constraints (`target_hash`, computed by
`target-hash.ps1`). Any later edit to them adds a line to the spec's Target changes section and
re-records the hash; `analyze` and `intent.verify` report a change that no line explains. This detects a
moved target; it does not prevent one.

Every plan carries a fixed "When to stop and ask" section, which `implement` reads with the plan: the
spec outranks decision records, which outrank the plan, which outranks the tasks, and the build stops for
the user only for ambiguity, a conflict between things the user owns, a loosened target, an irreversible
action, or being stuck. Each answer is written into the files and not asked again.

`intent.verify` is run by the agent that built the work. Adding `independent` to its input
(`/speckit-intent-verify independent` in Claude Code) also has a fresh, read-only sub-agent try to show
the work fails. It never runs by default: a second agent costs tokens.

## Install in a project

To have an agent do it, open the agent in the project's root and paste:

```text
Install speckit-intent in this project. Clone it with
  git clone https://github.com/dgsantana/speckit-intent.git "$HOME/.speckit-intent"
(or update an existing clone with git -C "$HOME/.speckit-intent" pull --ff-only), then follow the
"Install in a project" section of "$HOME/.speckit-intent/README.md" step by step.
```

The steps below are written to be followed as they stand, by a person or an agent:

- Run every command from the project root. Step 1 works in any shell; from step 2 on, run commands in
  PowerShell 7 (`pwsh`), whose syntax they use.
- Where a step says to ask the user, ask with the agent's question tool if it has one, recommendation
  first. If the user cannot be asked, take the default the step names and say so in the report.
- Commit nothing; the user decides that after step 9.

1. **Check the tools.** Run each command; the version must be at least the one shown.

   | Command | Needs | If missing or older |
   |---|---|---|
   | `git --version` | any | install Git |
   | `pwsh --version` | 7.2 | install PowerShell 7: <https://learn.microsoft.com/powershell/scripting/install/installing-powershell> |
   | `specify --version` | 1.1.1 | `uv tool install specify-cli`, or `uv tool upgrade specify-cli`; without `uv`, install it first: <https://docs.astral.sh/uv/getting-started/installation/> |
   | `node --version` | 18 | needed only for the visual companion; see step 4 |

   If Git, PowerShell or Spec Kit is missing or too old, stop and tell the user what to install. Do not
   install system software without asking.

2. **Set up Spec Kit, if it is not set up.** If `.specify/integration.json` exists, go to step 3.
   Otherwise ask the user which agent integrations the project uses, by Spec Kit's names
   (`specify integration list` shows them all; Claude Code is `claude`, Codex CLI is `codex`, GitHub
   Copilot is `copilot`). Order does not matter for speckit-intent; the first becomes Spec Kit's
   default. Default if the user cannot be asked: the integration of the agent running these steps; if
   none in the list matches it, stop and report that.

   ```powershell
   specify init --here --force --non-interactive --integration <first> --script ps
   specify integration install <each further one>
   ```

   `--here` in a folder that has files needs `--force`, and without `--non-interactive` the command
   cancels itself when no one answers its prompt and still exits 0. `--force` writes Spec Kit's files
   into the folder: `.specify/` and each integration's command folder (for example `.claude/skills/`,
   `.agents/skills/`, `.github/skills/`). If `.specify/` or one of those command folders already exists,
   ask the user before running the commands, and stop if the user says no. Other content of `.claude/` or
   `.github/` (settings, workflows) does not count.

   Check that `.specify/integration.json` now exists and lists every integration under
   `installed_integrations`; do not rely on exit codes here. `specify integration install` uses the
   project's script type; it needs no `--script`. It may refuse with "Installing multiple integrations
   is only automatic when all involved integrations are declared multi-install safe" (Copilot does):
   run the same command again with `--force`. That message also suggests `specify integration switch`;
   never run it, because it replaces the default integration. After `--force` it may warn that shared
   infrastructure paths already exist and suggest `specify init --here --force` or
   `specify integration upgrade --force`: that warning is expected; do not run either.

3. **Get the clone.** If `$HOME/.speckit-intent` does not exist, clone it; if it does, update it:

   ```powershell
   git clone https://github.com/dgsantana/speckit-intent.git "$HOME/.speckit-intent"
   git -C "$HOME/.speckit-intent" pull --ff-only
   ```

   The install copies what it needs into the project; the clone is used only to install and update.

4. **Choose the extensions.** Ask the user the questions that apply:
   - Dated feature IDs (`feature-id`)? Recommended when more than one person or agent opens specs on
     separate branches; for a single author, leave it out with `-NoFeatureId`. Default: install it.
   - Visual companion (`companion`)? Shows layouts and diagrams in a browser tab while specifying;
     needs Node.js 18. Leave it out with `-NoCompanion`. Default: install it if step 1 found Node.js 18
     or later. If Node.js is missing or older, do not ask: leave it out and tell the user why.

5. **Run the installer once**, adding each switch chosen in step 4. The two switches are independent;
   with neither, both extensions are installed. Run one command only: a second run with different
   switches removes the extensions the first one installed.

   ```powershell
   pwsh -NoProfile -File "$HOME/.speckit-intent/install.ps1" [-NoFeatureId] [-NoCompanion]
   ```

   Read the result from its last line and its exit code:
   - `RESULT: installed for: <integrations>` and exit code 0: the installer has checked that every
     integration has the intent commands. Check that the list matches `installed_integrations`.
   - `RESULT: incomplete; ...` and exit code 2: the integrations after `skipped:` still have the core
     commands. The lines starting with `skipped <integration>:` say why; report them to the user as
     printed.
   - Any other exit code: the installer failed; report its output.

6. **Check the template.** The output of `specify preset resolve spec-template` contains
   `top layer from: intent`. It wraps long lines at the console width, so join the output into one
   line before searching it.

7. **Check the constitution.** Read `.specify/memory/constitution.md`. If it is still Spec Kit's
   unfilled template (headings like `[PRINCIPLE_1_NAME]`, with example principles in comments), it has
   no rules: say so, and suggest the user fills it in later with the `constitution` command. Otherwise
   list for the user each rule that demands artifacts this preset makes optional or does not use: a
   research file or data model for every feature, `FR-###` requirements, user stories, a decision record
   for every choice. Suggest loosening them in the same change; edit nothing without the user's
   go-ahead.

8. **Check existing specs**, if `feature-id` was installed and `specs/` exists:

   ```powershell
   pwsh -NoProfile -File .specify/extensions/feature-id/scripts/powershell/new-feature-id.ps1 -Verify
   ```

   It prints JSON. `FAILURES` empty and exit code 0 means every directory is fine; each entry in
   `FEATURES` has a `STATUS` of `ok` or `legacy`. Otherwise report the `FAILURES` entries and their
   `STATUS`. Migrating legacy names is a separate decision for the user
   ([Moving an ongoing project](#moving-an-ongoing-project-from-nnn--numbering)), never part of the
   install.

9. **Report.** Show the user `git status --short`. The install adds or changes `.specify/` and each
   integration's command folder (the folders the installer printed in step 5, plus the default
   integration's, such as `.claude/skills/`); a fresh Spec Kit setup also adds the integration folders
   themselves. These are meant to be committed so the whole team gets the same commands. Spec Kit may
   suggest adding agent folders to `.gitignore` because they can hold personal settings and credentials:
   commit the command folders, and if personal files such as `.claude/settings.local.json` appear in
   `git status`, point them out so the user can ignore them. Committing is the user's call. Start a new
   agent session if the new commands do not appear.

### How the installer works

Use the script rather than `specify preset add` directly. Spec Kit (checked on 1.1.1) registers
preset and extension commands for the active integration only, so a project with omp, Claude Code and
Codex installed would get the intent commands in one of them and keep the core ones in the others. The
script installs through Spec Kit for the default integration, renders each other integration in a
temporary copy of the project, and brings back only this repository's command files. It also turns
development-mode symbolic links into ordinary files, so the result can be committed, and ignores the
`.specify-dev` staging folder.

Commands are materialised at install time: rerun the script after updating the clone, after
`specify integration upgrade`, or after adding an integration. It is safe to run repeatedly; an extension
left out with `-NoFeatureId` or `-NoCompanion` is removed, hooks included, if an earlier run installed
it. An integration for which Spec Kit renders no intent command is reported as skipped, not installed.

Projects that set rules in `.specify/memory/constitution.md` keep them; the commands read it. That is why
step 7 checks it: a rule there that demands artifacts this preset makes optional gives the agent two
conflicting instructions again.

## Feature IDs

Sequential IDs make the next number a function of what one person can see. Two branches that cannot see
each other take the same number, and neither is wrong. A dated ID derives its hash from the feature's
name: two features collide only when they are given the same name, which is worth knowing.

```text
20260918-92526bb-standard-geospatial-formats
```

The hash is SHA-1 over the slug, truncated to 7 hex characters and widened only if a different slug in the
same tree holds that prefix. It is always produced by the script, never written by hand or by a model.
It adds no uniqueness the slug does not already have; it is a short, stable handle for the feature in
commit messages and conversation, the way a short git hash is, and it lets the audit catch a slug edited
by hand. Widening depends on what the allocating branch can see, so in theory two branches could pick
different lengths for the same slug; at 7 hex characters a prefix clash between different slugs is
roughly one in 268 million per pair.

The audit fails any directory whose hash does not match its own slug, and any slug used by more than one
directory. The second is how two branches that started the same feature on different days find out at
merge time.

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

This covers Spec Kit's `timestamp` numbering (`yyyyMMdd-HHmmss-slug`) as well; a timestamp directory
keeps the date in its name.

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

## Decision records

A plan's Choices record what was chosen for that feature and what was rejected. A choice that binds
beyond the feature also gets a decision record, so it is found by the next feature rather than buried in
an old plan. `plan` writes it into the project's existing decisions folder, in its format, when there is
one (`docs/decisions`, `docs/adr`, `adr`, `doc/adr`); otherwise into `docs/decisions/<yyyyMMdd>-<slug>.md`
from the preset's `decision-template`: intent, decision, rejected alternatives, evidence tiers, and a
concrete trigger for revisiting it. `intent.verify` reports a result that contradicts a linked record's
evidence or meets its trigger.

## Visual companion

When a question during `specify`, `clarify` or `plan` is clearer shown than described (a layout, a
diagram, visual options side by side), the agent offers a browser tab once, then writes screens to it and
reads the user's clicks back. The server is Superpowers' visual companion (MIT, see
`extensions/companion/NOTICE`), changed to make no request outside the local server and started by a
PowerShell launcher. What it adds over the original is the trail: a choice the browser settles is written
into the spec or the plan's Choices, with the options not taken as rejected alternatives, and the deciding
screen is copied to `<feature>/design/`. Session files under `.specify/companion/` stay out of git.

## Tests

```text
pwsh -NoProfile -Command "Invoke-Pester -Path tests"
```

Requires Pester 5.5 or later (`Install-Module Pester -Scope CurrentUser`) and Node.js for the companion
tests.

## Decisions

Choices about this repository, with what each protects and the alternatives rejected, are in
[docs/decisions](docs/decisions/README.md).

## Layout

```text
install.ps1      installs into the current project, for every integration
preset/
  preset.yml
  commands/      speckit.{specify,clarify,plan,tasks,analyze,converge,checklist}.md
  templates/     spec-template.md, plan-template.md, tasks-template.md, decision-template.md
extensions/
  intent/        extension.yml, commands/speckit.intent.verify.md,
                 scripts/powershell/target-hash.ps1
  companion/     extension.yml, NOTICE, commands/speckit.companion.show.md,
                 scripts/companion/ (vendored server), scripts/powershell/{start,stop}-companion.ps1
  feature-id/    extension.yml, commands/speckit.feature-id.allocate.md,
                 scripts/powershell/{feature-id-lib,new-feature-id,migrate-feature-ids}.ps1
tests/           Pester tests for the scripts and for consistency across commands
docs/decisions/  decision records for this repository
```
