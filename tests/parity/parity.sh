#!/usr/bin/env bash
# Runs each bash port beside its PowerShell original on identical throwaway projects and compares the
# results: parsed JSON (key order aside), exit codes, and for migrations the rewritten trees.
# PowerShell runs in a container (Containerfile here, built on first use), so the host needs only bash,
# perl, git, jq and podman.
#
#   tests/parity/parity.sh            all cases; exit 1 when any differs
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
image=localhost/speckit-intent-pwsh
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
failures=0

podman image exists "$image" || podman build -q -t "$image" -f "$here/Containerfile" "$here" >/dev/null

# run_bash DIR SCRIPT ARGS... / run_ps DIR SCRIPT ARGS...: stdout to DIR.out, exit code to DIR.code.
run_bash() {
    local dir=$1 script=$2; shift 2
    local code=0
    (cd "$dir" && "$repo/extensions/$script.sh" "$@") >"$dir.out" 2>"$dir.err" || code=$?
    echo "$code" >"$dir.code"
}
run_ps() {
    local dir=$1 script=$2; shift 2
    local code=0
    podman run --rm -v "$repo:/tool:ro,Z" -v "$dir:/w:Z" -w /w -e TZ="${TZ:-UTC}" "$image" \
        pwsh -NoProfile -File "/tool/extensions/$script.ps1" "$@" >"$dir.out" 2>"$dir.err" || code=$?
    echo "$code" >"$dir.code"
}

# compare NAME A B [JQ]: JSON outputs (normalised by JQ, default '.') and exit codes must match.
compare() {
    local name=$1 a=$2 b=$3 filter=${4:-.}
    if [[ $(cat "$a.code") != $(cat "$b.code") ]]; then
        echo "FAIL $name: exit $(cat "$a.code") (bash) vs $(cat "$b.code") (pwsh)"; failures=$((failures + 1)); return
    fi
    if [[ -s $a.out || -s $b.out ]] && ! diff <(jq -S "$filter" "$a.out") <(jq -S "$filter" "$b.out") >"$work/diff"; then
        echo "FAIL $name:"; sed 's/^/    /' "$work/diff"; failures=$((failures + 1)); return
    fi
    echo "ok   $name"
}

compare_trees() {
    local name=$1 a=$2 b=$3
    if diff -r --exclude=.git "$a" "$b" >"$work/diff" && diff <(git -C "$a" status --porcelain 2>/dev/null) <(git -C "$b" status --porcelain 2>/dev/null) >>"$work/diff"; then
        echo "ok   $name"
    else
        echo "FAIL $name:"; sed 's/^/    /' "$work/diff"; failures=$((failures + 1))
    fi
}

# A project with legacy, timestamp and dated spec directories and references of every kind the migration
# handles: whole tokens, short specs/NNN, prose, another repository's, missing specs, kept, BOM, not UTF-8.
fixture() {
    local root=$1
    mkdir -p "$root/.specify" "$root/docs"
    git -C "$root" init -q -b main
    git -C "$root" config user.email test@example.com
    git -C "$root" config user.name test
    git -C "$root" config core.autocrlf false
    local spec
    for spec in 001-auth 002-auth-tokens 003-zone-fédération 20260918-92526bb-standard-geospatial-formats; do
        mkdir -p "$root/specs/$spec" && printf '# %s\n' "$spec" >"$root/specs/$spec/spec.md"
        git -C "$root" add -A
        GIT_AUTHOR_DATE="2026-0${spec:2:1}-15T12:00:00Z" GIT_COMMITTER_DATE="2026-0${spec:2:1}-15T12:00:00Z" \
            git -C "$root" commit -q -m "add $spec"
    done
    mkdir -p "$root/specs/20260101-120000-timestamp-feature"
    printf '# t\n' >"$root/specs/20260101-120000-timestamp-feature/spec.md"
    cat >"$root/docs/notes.md" <<'EOF'
See specs/001-auth/spec.md and [tokens](specs/002-auth-tokens/).
Short: specs/002 and specs\003, not specs/0021 nor ../acme/specs/001.
Prose: spec 001 and Specification 002 stay for a person.
Elsewhere: `AcmeCorp/acme` `specs/001` is theirs; specs/009-never-written was planned.
Timestamp: 20260101-120000-timestamp-feature. Not 001-auth-extra.
EOF
    printf '## 001-auth shipped\n' >"$root/CHANGELOG.md"
    printf '\xEF\xBB\xBFBOM file names 002-auth-tokens.\n' >"$root/docs/bom.md"
    printf 'Latin-1 \xE9 names 001-auth.\n' >"$root/docs/latin1.txt"
    git -C "$root" add -A
    GIT_AUTHOR_DATE="2026-05-01T12:00:00Z" GIT_COMMITTER_DATE="2026-05-01T12:00:00Z" git -C "$root" commit -q -m docs
    printf '{"feature_directory": "specs/001-auth"}\n' >"$root/.specify/feature.json"
}

# Two identical copies of a fixture, one per runtime.
pair() {
    local name=$1 builder=$2
    mkdir -p "$work/$name"
    "$builder" "$work/$name/bash"
    cp -a "$work/$name/bash" "$work/$name/pwsh"
}

empty_project() { mkdir -p "$1/.specify/x" "$1/specs/007-zone-fédération" "$1/specs/20260918-92526bb-standard-geospatial-formats"; }

# --- new-feature-id ---
pair alloc empty_project
for name in "Zone Federation" "Standard geospatial formats" "Café Ünïcode — test!!" \
    "Um nome muito comprido que passa largamente os quarenta e oito caracteres" "Brand new feature"; do
    run_bash "$work/alloc/bash" feature-id/scripts/bash/new-feature-id --name "$name" --date 20261012
    run_ps "$work/alloc/pwsh" feature-id/scripts/powershell/new-feature-id -Name "$name" -Date 20261012
    compare "new-feature-id \"$name\"" "$work/alloc/bash" "$work/alloc/pwsh"
done
run_bash "$work/alloc/bash" feature-id/scripts/bash/new-feature-id --name '!!!'
run_ps "$work/alloc/pwsh" feature-id/scripts/powershell/new-feature-id -Name '!!!'
compare "new-feature-id unusable name (exit code)" "$work/alloc/bash" "$work/alloc/pwsh"

verify_filter='.FEATURES |= sort_by(.FEATURE_DIRECTORY) | .FAILURES |= sort'
run_bash "$work/alloc/bash" feature-id/scripts/bash/new-feature-id --verify
run_ps "$work/alloc/pwsh" feature-id/scripts/powershell/new-feature-id -Verify
compare "new-feature-id --verify (clean)" "$work/alloc/bash" "$work/alloc/pwsh" "$verify_filter"

for side in bash pwsh; do
    mkdir -p "$work/alloc/$side/specs/20261012-0000000-bad-hash" "$work/alloc/$side/specs/008-zone-federation" "$work/alloc/$side/specs/odd"
done
run_bash "$work/alloc/bash" feature-id/scripts/bash/new-feature-id --verify
run_ps "$work/alloc/pwsh" feature-id/scripts/powershell/new-feature-id -Verify
compare "new-feature-id --verify (mismatch, duplicate, unrecognised)" "$work/alloc/bash" "$work/alloc/pwsh" "$verify_filter"

# --- migrate-feature-ids ---
pair migrate fixture
for side in bash pwsh; do git -C "$work/migrate/$side" config --local --add safe.directory '*'; done
run_bash "$work/migrate/bash" feature-id/scripts/bash/migrate-feature-ids --json --foreign Acme
run_ps "$work/migrate/pwsh" feature-id/scripts/powershell/migrate-feature-ids -Json -Foreign Acme
compare "migrate dry run" "$work/migrate/bash" "$work/migrate/pwsh"
run_bash "$work/migrate/bash" feature-id/scripts/bash/migrate-feature-ids --json --foreign Acme --apply
run_ps "$work/migrate/pwsh" feature-id/scripts/powershell/migrate-feature-ids -Json -Foreign Acme -Apply
compare "migrate --apply" "$work/migrate/bash" "$work/migrate/pwsh"
compare_trees "migrate --apply (trees)" "$work/migrate/bash" "$work/migrate/pwsh"
run_bash "$work/migrate/bash" feature-id/scripts/bash/migrate-feature-ids --json
run_ps "$work/migrate/pwsh" feature-id/scripts/powershell/migrate-feature-ids -Json
compare "migrate again (nothing left)" "$work/migrate/bash" "$work/migrate/pwsh"

# A second branch with the mapping reuses it; a dirty tree refuses.
pair mapped fixture
for side in bash pwsh; do
    cp "$work/migrate/bash/.specify/feature-id-migration.json" "$work/mapped/$side/.specify/"
    git -C "$work/mapped/$side" add -A && git -C "$work/mapped/$side" commit -q -m mapping
    printf 'dirty\n' >>"$work/mapped/$side/docs/notes.md"
done
run_bash "$work/mapped/bash" feature-id/scripts/bash/migrate-feature-ids --json --apply
run_ps "$work/mapped/pwsh" feature-id/scripts/powershell/migrate-feature-ids -Json -Apply
compare "migrate refuses a dirty tree (exit code)" "$work/mapped/bash" "$work/mapped/pwsh"
run_bash "$work/mapped/bash" feature-id/scripts/bash/migrate-feature-ids --json --allow-dirty --keep 'docs/bom*'
run_ps "$work/mapped/pwsh" feature-id/scripts/powershell/migrate-feature-ids -Json -AllowDirty -Keep 'docs/bom*'
compare "migrate from the mapping, custom --keep" "$work/mapped/bash" "$work/mapped/pwsh"

# --- target-hash ---
spec_project() {
    mkdir -p "$1/.specify" "$1/specs/x"
    cat >"$1/specs/x/spec.md" <<'EOF'
---
title: x
---
# Spec

## Outcomes
<!-- a comment -->
- Users can sign in.

- Sessions expire.
## Constraints
- No new dependency.
## Notes
ignored
EOF
}
pair hash spec_project
run_bash "$work/hash/bash" intent/scripts/bash/target-hash --spec specs/x/spec.md --record
run_ps "$work/hash/pwsh" intent/scripts/powershell/target-hash -Spec specs/x/spec.md -Record
compare "target-hash --record" "$work/hash/bash" "$work/hash/pwsh"
compare_trees "target-hash --record (trees)" "$work/hash/bash" "$work/hash/pwsh"
for side in bash pwsh; do sed -i 's/Sessions expire/Sessions never expire/' "$work/hash/$side/specs/x/spec.md"; done
run_bash "$work/hash/bash" intent/scripts/bash/target-hash --spec specs/x/spec.md --check
run_ps "$work/hash/pwsh" intent/scripts/powershell/target-hash -Spec specs/x/spec.md -Check
compare "target-hash --check (changed)" "$work/hash/bash" "$work/hash/pwsh"

echo
if ((failures)); then echo "$failures case(s) differ"; exit 1; fi
echo "all cases match"
