#!/usr/bin/env bash
# Starts the visual companion server for the current Spec Kit project and prints its connection JSON.
# Bash port of ../powershell/start-companion.ps1: same server (../companion/server.cjs), same session
# layout under .specify/companion/<session id>/, same environment, so either stop script can stop it.
#
#   start-companion.sh [--open] [--owner-pid PID] [--foreground] [--host 127.0.0.1] [--url-host HOST]
#                      [--idle-timeout-minutes 1..1440]
#
# --open only after the user has accepted the companion. --foreground under a harness that reaps detached
# processes, launched with that harness's own background mechanism. The server stops after the idle
# timeout or when --owner-pid exits.
set -euo pipefail

fail() { printf '{"error":"%s"}\n' "$1"; exit 1; }

bind_host=127.0.0.1 url_host= idle=240 owner_pid= open= foreground=
while (($#)); do
    case $1 in
        --host|-BindHost) bind_host=$2; shift ;;
        --url-host|-UrlHost) url_host=$2; shift ;;
        --idle-timeout-minutes|-IdleTimeoutMinutes) idle=$2; shift ;;
        --owner-pid|-OwnerPid) owner_pid=$2; shift ;;
        --open|-Open) open=1 ;;
        --foreground|-Foreground) foreground=1 ;;
        *) fail "unknown argument: $1" ;;
    esac
    shift
done
[[ $idle =~ ^[0-9]+$ ]] && ((idle >= 1 && idle <= 1440)) || fail 'idle timeout must be 1..1440 minutes.'
command -v node >/dev/null || fail 'node is not on PATH; the companion server needs Node.js 18 or later.'

root=$PWD
while [[ ! -d $root/.specify ]]; do
    [[ $root == / ]] && fail 'not inside a Spec Kit project (no .specify directory found).'
    root=$(dirname "$root")
done

server=$(cd "$(dirname "$0")/../companion" && pwd)/server.cjs
base=$root/.specify/companion
mkdir -p "$base"
# Session files hold the access key and screens in progress; none of it belongs in the repository.
[[ -e $base/.gitignore ]] || printf '*' >"$base/.gitignore"

session_dir=$base/$$-$(date +%s)
state_dir=$session_dir/state
mkdir -p "$session_dir/content" "$state_dir"

# The stop script signals a PID only if its command line carries this id, so a stale PID file cannot make
# it kill an unrelated process.
server_id=$(od -An -tx1 -N24 /dev/urandom | tr -d ' \n')
printf '%s\n' "$server_id" >"$state_dir/server-instance-id"

[[ -n $url_host ]] || { [[ $bind_host == 127.0.0.1 || $bind_host == localhost ]] && url_host=localhost || url_host=$bind_host; }

export BRAINSTORM_DIR=$session_dir BRAINSTORM_HOST=$bind_host BRAINSTORM_URL_HOST=$url_host
export BRAINSTORM_PORT_FILE=$base/.last-port BRAINSTORM_TOKEN_FILE=$base/.last-token
export BRAINSTORM_IDLE_TIMEOUT_MS=$((idle * 60 * 1000)) BRAINSTORM_OWNER_PID=$owner_pid
if [[ -n $open ]]; then export BRAINSTORM_OPEN=1; else unset BRAINSTORM_OPEN; fi

pid_file=$state_dir/server.pid
if [[ -n $foreground ]]; then
    node "$server" "--brainstorm-server-id=$server_id" &
    pid=$!
    printf '%s\n' "$pid" >"$pid_file"
    code=0; wait "$pid" || code=$?
    exit "$code"
fi

# The server must not hold the caller's output handles, or a caller capturing this script's output waits
# for the server to exit.
setsid node "$server" "--brainstorm-server-id=$server_id" </dev/null >"$state_dir/server.log" 2>"$state_dir/server.err" &
pid=$!
printf '%s\n' "$pid" >"$pid_file"

info=$state_dir/server-info
for _ in $(seq 100); do
    if ! kill -0 "$pid" 2>/dev/null; then
        code=0; wait "$pid" || code=$?
        fail "server exited during startup (code $code); rerun with --foreground to see why."
    fi
    if [[ -s $info ]]; then
        sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$info" | sed -e '/./,$!d'
        exit 0
    fi
    sleep 0.1
done
fail 'server did not start within 10 seconds; rerun with --foreground to see why.'
