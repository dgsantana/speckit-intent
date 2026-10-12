#!/usr/bin/env bash
# Stops a visual companion session started by start-companion.sh or start-companion.ps1.
# Bash port of ../powershell/stop-companion.ps1: signals the server only when its command line carries the
# session's instance id, so a stale PID file never stops an unrelated process. Screens stay in the session
# directory for later reference.
#
#   stop-companion.sh SESSION_DIR      the parent of the screen_dir and state_dir the start script reported
set -euo pipefail

session_dir=${1:-}
[[ $session_dir == -SessionDir || $session_dir == --session-dir ]] && session_dir=${2:-}
[[ -n $session_dir ]] || { printf '{"error":"usage: stop-companion.sh SESSION_DIR"}\n'; exit 1; }

state_dir=$session_dir/state
pid_file=$state_dir/server.pid
id_file=$state_dir/server-instance-id

stopped() {
    rm -f "$state_dir/server-info" "$pid_file" "$id_file"
    printf '{"reason":"%s","timestamp":%s}\n' "$1" "$(date +%s)" >"$state_dir/server-stopped"
}

if [[ ! -e $pid_file ]]; then
    printf '{"status":"not_running"}\n'
    exit 0
fi

pid=$(tr -dc '0-9' <"$pid_file")
expected=$( [[ -e $id_file ]] && tr -d '[:space:]' <"$id_file" || true)
if [[ -r /proc/$pid/cmdline ]]; then
    command_line=$(tr '\0' ' ' <"/proc/$pid/cmdline")
else
    command_line=$(ps -ww -p "$pid" -o command= 2>/dev/null || true)
fi

if [[ -z $expected || -z $command_line || $command_line != *"--brainstorm-server-id=$expected"* ]]; then
    stopped stale_pid
    printf '{"status":"stale_pid"}\n'
    exit 0
fi

kill -KILL "$pid" 2>/dev/null || true
for _ in $(seq 50); do
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.1
done
if kill -0 "$pid" 2>/dev/null; then
    printf '{"status":"failed","error":"process still running"}\n'
    exit 1
fi

stopped stop-companion.sh
printf '{"status":"stopped"}\n'
