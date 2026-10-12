#!/usr/bin/env bash
# Installs (or reinstalls) the intent preset and extensions into the Spec Kit project in the current
# directory, for every agent integration the project has installed. Bash port of install.ps1.
#
#   "$HOME/.speckit-intent/install.sh" [--no-feature-id] [--no-companion]
#
# Spec Kit registers preset and extension commands for the active integration only. The default integration
# is installed in place, through Spec Kit, so its registry records the preset and extensions. Each other
# installed integration is rendered by the same commands in a temporary copy of the project with that
# integration active, and only the intent command files are brought back.
#
# Rerun after editing this repository, after `specify integration upgrade`, or after adding an integration.
# An extension left out with --no-feature-id or --no-companion is removed if an earlier run installed it.
#
# Prints one `installed for <integration>` or `skipped <integration>: <reason>` line per integration, then a
# `RESULT:` line. Exits 0 when every integration has the intent commands, 2 when any was skipped.
# Needs bash, perl (ships with git) and the specify CLI.
set -euo pipefail

source_dir=$(cd "$(dirname "$0")" && pwd)
project=$PWD
no_feature_id= no_companion=
for arg in "$@"; do
    case $arg in
        --no-feature-id|-NoFeatureId) no_feature_id=1 ;;
        --no-companion|-NoCompanion) no_companion=1 ;;
        *) echo "ERROR: unknown argument: $arg" >&2; exit 1 ;;
    esac
done

integration_file=$project/.specify/integration.json
if [[ ! -f $integration_file ]]; then
    echo "ERROR: .specify/integration.json not found; run this from a Spec Kit project root." >&2
    exit 1
fi

# json FILE EXPR: evaluates a perl expression over the decoded file ($j), printing one result per line.
json() {
    perl -MJSON::PP -e 'local $/; open my $f, "<", $ARGV[0] or exit 0; my $j = decode_json(<$f>); print map { "$_\n" } grep { defined && $_ ne "" } eval $ARGV[1]' "$1" "$2"
}

default=$(json "$integration_file" '$j->{default_integration} || $j->{integration}')
mapfile -t others < <(json "$integration_file" '@{ $j->{installed_integrations} || [] }' | grep -vxF -- "$default" || true)

# Each extension and the command it provides, as command files are named after them.
declare -A provided=([intent]='intent[.-]verify' [feature-id]='feature-id[.-]allocate' [companion]='companion[.-]show')
extensions=(intent)
[[ -n $no_feature_id ]] || extensions+=(feature-id)
[[ -n $no_companion ]] || extensions+=(companion)
excluded=()
for extension in intent feature-id companion; do
    [[ " ${extensions[*]} " == *" $extension "* ]] || excluded+=("$extension")
done

# Command files and skill directories, in whatever naming style and file extension an integration uses:
# `speckit.plan.md`, `speckit-plan/`, `speckit.plan.agent.md`, `speckit.plan.yaml`.
name_pattern() { local IFS='|'; printf '^speckit[.-](%s)(\..+)?$' "$*"; }
owned=(specify clarify plan tasks analyze converge checklist)
for extension in "${extensions[@]}"; do owned+=("${provided[$extension]}"); done
owned_pattern=$(name_pattern "${owned[@]}")
removed_pattern=
if ((${#excluded[@]})); then
    removed=()
    for extension in "${excluded[@]}"; do removed+=("${provided[$extension]}"); done
    removed_pattern=$(name_pattern "${removed[@]}")
fi

# specify ARGS...; failures print specify's output and stop the install, unless allow_failure is set.
run_specify() {
    local output code=0
    output=$(specify "$@" 2>&1) || code=$?
    if ((code)) && [[ -z ${allow_failure:-} ]]; then
        sed 's/^/  /' <<<"$output" >&2
        echo "ERROR: specify $* failed with exit code $code" >&2
        exit 1
    fi
}

install_here() {
    allow_failure=1 run_specify preset remove intent
    run_specify preset add --dev "$source_dir/preset"
    local extension
    for extension in "${extensions[@]}"; do
        run_specify extension add --dev "$source_dir/extensions/$extension" --force
    done
    # Leaving an extension out of a rerun removes it, hooks included.
    for extension in "${excluded[@]}"; do
        allow_failure=1 run_specify extension remove "$extension" --force
    done
}

# The directories an integration writes commands into, from the files its manifest lists:
# `.omp/commands/speckit.plan.md` gives `.omp/commands`, `.claude/skills/speckit-plan/SKILL.md` gives
# `.claude/skills`. Some write more than one (Copilot: `.github/agents` and `.github/prompts`).
command_directories() {
    local root=$1 integration=$2
    json "$root/.specify/integrations/$integration.manifest.json" '
        my %seen;
        grep { !$seen{$_}++ } sort map {
            my @parts = split m{/};
            my ($index) = grep { $parts[$_] =~ /^speckit[.-]plan(\.|$)/i } 0 .. $#parts;
            defined $index && $index > 0 ? join("/", @parts[0 .. $index - 1]) : ();
        } keys %{ $j->{files} || {} }'
}

# Entries of DIR whose names match PATTERN (case-insensitive, like PowerShell -match).
matching() {
    local dir=$1 pattern=$2 entry
    [[ -d $dir ]] || return 0
    for entry in "$dir"/* "$dir"/.[!.]*; do
        [[ -e $entry || -L $entry ]] || continue
        if grep -qiE -- "$pattern" <<<"${entry##*/}"; then printf '%s\n' "$entry"; fi
    done
    return 0
}

# Writes FROM's contents to TO as an ordinary file, so a development-mode symbolic link becomes a file.
write_file() { local content; content=$(cat "$1"; printf x); rm -f "$2"; printf '%s' "${content%x}" >"$2"; }

# Copies owned entries from one command directory to another, links resolved to files.
copy_owned() {
    local from=$1 to=$2 entry file
    while IFS= read -r entry; do
        local target=$to/${entry##*/}
        if [[ -d $entry ]]; then
            mkdir -p "$target"
            for file in "$entry"/* "$entry"/.[!.]*; do
                if [[ -f $file ]]; then write_file "$file" "$target/${file##*/}"; fi
            done
        else
            mkdir -p "$to"
            write_file "$entry" "$target"
        fi
    done < <(matching "$from" "$owned_pattern")
}

# Whether an integration in the project now has the intent version of `plan`, recognised by the section
# every intent command carries. Checked rather than assumed, so a silent rendering failure is reported.
installed_for() {
    local directory entry
    while IFS= read -r directory; do
        while IFS= read -r entry; do
            grep -rqF -- '## Asking the user' "$entry" && return 0
        done < <(matching "$project/$directory" '^speckit[.-]plan(\..+)?$')
    done < <(command_directories "$project" "$1")
    return 1
}

# Removes the command files of extensions left out of this run.
remove_excluded() {
    [[ -n $removed_pattern ]] || return 0
    local entry
    while IFS= read -r entry; do rm -rf -- "$entry"; done < <(matching "$1" "$removed_pattern")
}

install_here

# Development-mode installs link the default integration's extension commands into a `.specify-dev`
# folder; a committed link does not survive a checkout without symbolic-link support, so they become
# ordinary files and the folder stays out of git.
while IFS= read -r directory; do
    [[ -d $project/$directory ]] || continue
    while IFS= read -r -d '' link; do
        write_file "$link" "$link.speckit-intent.tmp" && mv -f "$link.speckit-intent.tmp" "$link"
    done < <(find "$project/$directory" -type l \( -name 'speckit[.-]*' -o -name SKILL.md \) -print0)
done < <(command_directories "$project" "$default")
ignore=$project/.specify/.gitignore
if ! { [[ -f $ignore ]] && grep -qxF 'extensions/*/.specify-dev/' "$ignore"; }; then
    printf '\n# Development-mode install staging (speckit-intent install.sh).\nextensions/*/.specify-dev/\n' >>"$ignore"
fi

installed=() skipped=()
if installed_for "$default"; then
    installed+=("$default")
    echo "installed for $default"
else
    skipped+=("$default")
    echo "skipped $default: its plan command is not the intent version after installing"
fi

for integration in ${others[@]+"${others[@]}"}; do
    mapfile -t directories < <(command_directories "$project" "$integration")
    if ((${#directories[@]} == 0)); then
        skipped+=("$integration")
        echo "skipped $integration: its manifest does not show where its commands live"
        continue
    fi

    scratch=$(mktemp -d "${TMPDIR:-/tmp}/speckit-intent-XXXXXXXX")
    cp -R "$project/.specify" "$scratch/.specify"
    for directory in "${directories[@]}"; do
        mkdir -p "$(dirname "$scratch/$directory")"
        if [[ -e $project/$directory ]]; then cp -R "$project/$directory" "$scratch/$directory"; fi
    done
    (cd "$scratch" && run_specify integration use "$integration" && install_here)
    for directory in "${directories[@]}"; do
        copy_owned "$scratch/$directory" "$project/$directory"
        remove_excluded "$project/$directory"
    done
    rm -rf "$scratch"
    list=$(IFS=,; echo "${directories[*]}" | sed 's/,/, /g')
    if installed_for "$integration"; then
        installed+=("$integration")
        echo "installed for $integration ($list)"
    else
        skipped+=("$integration")
        echo "skipped $integration: Spec Kit rendered no intent commands into $list"
    fi
done

# One line to read the result from, and an exit code that says the same.
join() { local IFS=,; echo "$*" | sed 's/,/, /g'; }
if ((${#skipped[@]})); then
    echo "RESULT: incomplete; installed for: $(join ${installed[@]+"${installed[@]}"}); skipped: $(join "${skipped[@]}")"
    exit 2
fi
echo "RESULT: installed for: $(join "${installed[@]}")"
