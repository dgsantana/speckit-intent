# 0017. Linux and macOS without PowerShell

Status: active
Date: 2026-10-12

## Intent

A project on Linux or macOS installs and uses speckit-intent with the tools already there (bash, perl,
git), and gets the same feature IDs, target hashes, migrations and companion sessions as a PowerShell
user on the same repository, so a mixed team never sees two answers.

## Decision

Every PowerShell script gets a bash port beside it, following Spec Kit's own layout
(`scripts/bash/`, `scripts/powershell/`): `target-hash.sh`, `new-feature-id.sh`,
`migrate-feature-ids.sh`, `start-companion.sh`, `stop-companion.sh` and `install.sh`. Scripts with real
logic are bash launchers over a perl body (`exec perl -x`), using only core modules (Digest::SHA,
Unicode::Normalize, JSON::PP, Encode); the feature-id rules live once, in `FeatureIdLib.pm`. Options are
the PowerShell names in kebab case (`--record`, `--allow-dirty`); the PowerShell spellings are accepted
too. Output is the same JSON and exit codes.

Commands and skills show both invocations as `sh:` and `ps:` lines and say which applies: the project's
`.specify/init-options.json` `script` value, the same switch that picks Spec Kit's own scripts.
`extension.yml` lists the bash scripts as `-sh` entries with `runtimes: [bash]`.

The ports are held to the originals by `tests/parity/parity.sh`, which runs both on identical throwaway
projects, PowerShell in a container, and compares parsed JSON, exit codes and the rewritten trees. The
port surfaced one bug in the original, fixed in both: `git ls-files` quotes non-ASCII paths, so
`migrate-feature-ids.ps1` skipped such files; it now lists them with `core.quotePath` off.

## Rejected

- Require PowerShell 7 on Linux and macOS: one implementation, but an install most users do not have, for
  a tool whose scripts are a few hundred lines.
- Python ports: Spec Kit ships a `py` runtime, but a Python on PATH is not guaranteed (`specify` runs from
  uv's own environment), while perl ships with git.
- Pure bash: Unicode normalisation, SHA-1 over UTF-8 and JSON would need external tools that differ
  between GNU and BSD systems.
- Keep the hash and slug rules only in PowerShell and call it from bash: no second copy to drift, but it
  brings the PowerShell dependency back.

## Evidence

- **measured**: `tests/parity/parity.sh` on 2026-10-12: 17 cases (allocation incl. accents and long
  names, audit with mismatch/duplicate/unrecognised, migration dry run, apply, rerun, mapping reuse,
  dirty refusal, custom keep, BOM and Latin-1 files, foreign and short references; target-hash record and
  check) all identical.
- **measured**: `install.sh` into a throwaway Spec Kit 1.1.3 project with `claude` and `codex`:
  `RESULT: installed for: claude, codex`, exit 0, rerun idempotent; Pester suite 63/63 after the command
  text changes.
