#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Starts the visual companion server for the current Spec Kit project and prints its connection JSON.

.DESCRIPTION
    Port of Superpowers' start-server.sh for PowerShell 7. The server (../companion/server.cjs) serves
    the newest HTML file in the session's content directory and records browser clicks to
    state/events. Sessions live under .specify/companion/<session id>/, which this script keeps out of
    git; the port and access key are reused per project so an open browser tab reconnects after a
    restart.

    By default the server runs as a detached process and this script returns once it has started.
    Use -Foreground under a harness that reaps detached processes, launched with that harness's own
    background mechanism.

    The server stops after -IdleTimeoutMinutes without activity, or when -OwnerPid exits.

.PARAMETER Open
    Open the browser on the first screen. Pass only after the user has accepted the companion.

.PARAMETER OwnerPid
    Stop the server when this process exits. Omit when the calling shell is short-lived.

.EXAMPLE
    pwsh -NoProfile -File .specify/extensions/companion/scripts/powershell/start-companion.ps1 -Open
#>
[CmdletBinding()]
param(
    [string]$BindHost = '127.0.0.1',
    [string]$UrlHost,
    [ValidateRange(1, 1440)]
    [int]$IdleTimeoutMinutes = 240,
    [int]$OwnerPid,
    [switch]$Open,
    [switch]$Foreground
)

$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
    @{ error = $Message } | ConvertTo-Json -Compress
    exit 1
}

if (-not (Get-Command node -ErrorAction SilentlyContinue)) { Fail 'node is not on PATH; the companion server needs Node.js 18 or later.' }

$root = (Get-Location).Path
while ($root -and -not (Test-Path -LiteralPath (Join-Path $root '.specify') -PathType Container)) {
    $parent = Split-Path -Parent $root
    $root = if ($parent -ne $root) { $parent } else { $null }
}
if (-not $root) { Fail 'not inside a Spec Kit project (no .specify directory found).' }

$server = Join-Path $PSScriptRoot '../companion/server.cjs' | Resolve-Path | Select-Object -ExpandProperty Path
$base = Join-Path $root '.specify/companion'
New-Item -ItemType Directory -Force -Path $base | Out-Null
# Session files hold the access key and screens in progress; none of it belongs in the repository.
$ignore = Join-Path $base '.gitignore'
if (-not (Test-Path -LiteralPath $ignore)) { Set-Content -LiteralPath $ignore -Value '*' -NoNewline }

$sessionId = "$PID-$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())"
$sessionDir = Join-Path $base $sessionId
$stateDir = Join-Path $sessionDir 'state'
New-Item -ItemType Directory -Force -Path (Join-Path $sessionDir 'content'), $stateDir | Out-Null

# The stop script signals a PID only if its command line carries this id, so a stale PID file
# cannot make it kill an unrelated process.
$serverId = [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(24)).ToLowerInvariant()
Set-Content -LiteralPath (Join-Path $stateDir 'server-instance-id') -Value $serverId

if (-not $UrlHost) { $UrlHost = if ($BindHost -in @('127.0.0.1', 'localhost')) { 'localhost' } else { $BindHost } }

$env:BRAINSTORM_DIR = $sessionDir
$env:BRAINSTORM_HOST = $BindHost
$env:BRAINSTORM_URL_HOST = $UrlHost
$env:BRAINSTORM_PORT_FILE = Join-Path $base '.last-port'
$env:BRAINSTORM_TOKEN_FILE = Join-Path $base '.last-token'
$env:BRAINSTORM_IDLE_TIMEOUT_MS = [string]($IdleTimeoutMinutes * 60 * 1000)
$env:BRAINSTORM_OWNER_PID = if ($OwnerPid) { [string]$OwnerPid } else { '' }
if ($Open) { $env:BRAINSTORM_OPEN = '1' } else { Remove-Item Env:BRAINSTORM_OPEN -ErrorAction SilentlyContinue }

$arguments = @($server, "--brainstorm-server-id=$serverId")
$pidFile = Join-Path $stateDir 'server.pid'

if ($Foreground) {
    $process = Start-Process -FilePath node -ArgumentList $arguments -NoNewWindow -PassThru
    Set-Content -LiteralPath $pidFile -Value $process.Id
    $process.WaitForExit()
    exit $process.ExitCode
}

# The server must not hold the caller's output handles, or a caller capturing this script's output
# waits for the server to exit. On Windows any redirection turns on handle inheritance, so the server
# gets none and reports through state/server-info; elsewhere all three streams are redirected.
$startArgs = @{ FilePath = 'node'; ArgumentList = $arguments; PassThru = $true }
if ($IsWindows) {
    $startArgs.WindowStyle = 'Hidden'
} else {
    $startArgs.RedirectStandardInput = '/dev/null'
    $startArgs.RedirectStandardOutput = Join-Path $stateDir 'server.log'
    $startArgs.RedirectStandardError = Join-Path $stateDir 'server.err'
}
$process = Start-Process @startArgs
Set-Content -LiteralPath $pidFile -Value $process.Id

$info = Join-Path $stateDir 'server-info'
$deadline = [DateTime]::UtcNow.AddSeconds(10)
while ([DateTime]::UtcNow -lt $deadline) {
    if ($process.HasExited) { Fail "server exited during startup (code $($process.ExitCode)); rerun with -Foreground to see why." }
    if (Test-Path -LiteralPath $info) {
        Get-Content -LiteralPath $info -Raw | ForEach-Object Trim
        exit 0
    }
    Start-Sleep -Milliseconds 100
}
Fail 'server did not start within 10 seconds; rerun with -Foreground to see why.'
