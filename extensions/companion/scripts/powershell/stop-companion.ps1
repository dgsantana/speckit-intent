#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Stops a visual companion session started by start-companion.ps1.

.DESCRIPTION
    Signals the server only when its command line carries the session's instance id, so a stale PID
    file never stops an unrelated process. Screens stay in the session directory for later reference.

.PARAMETER SessionDir
    The session directory: the parent of the screen_dir and state_dir the start script reported.
#>
[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$SessionDir)

$ErrorActionPreference = 'Stop'

$stateDir = Join-Path $SessionDir 'state'
$pidFile = Join-Path $stateDir 'server.pid'
$idFile = Join-Path $stateDir 'server-instance-id'

function Set-Stopped([string]$Reason) {
    Remove-Item -LiteralPath (Join-Path $stateDir 'server-info'), $pidFile, $idFile -Force -ErrorAction SilentlyContinue
    @{ reason = $Reason; timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() } | ConvertTo-Json -Compress |
        Set-Content -LiteralPath (Join-Path $stateDir 'server-stopped')
}

if (-not (Test-Path -LiteralPath $pidFile)) {
    @{ status = 'not_running' } | ConvertTo-Json -Compress
    exit 0
}

$serverPid = [int](Get-Content -LiteralPath $pidFile -Raw)
$expected = if (Test-Path -LiteralPath $idFile) { (Get-Content -LiteralPath $idFile -Raw).Trim() } else { $null }

$commandLine = if ($IsWindows) {
    (Get-CimInstance Win32_Process -Filter "ProcessId = $serverPid" -ErrorAction SilentlyContinue).CommandLine
} elseif (Test-Path -LiteralPath "/proc/$serverPid/cmdline") {
    (Get-Content -LiteralPath "/proc/$serverPid/cmdline" -Raw) -replace "`0", ' '
} else {
    & ps -ww -p $serverPid -o command= 2>$null
}

if (-not $expected -or -not $commandLine -or -not $commandLine.Contains("--brainstorm-server-id=$expected")) {
    Set-Stopped 'stale_pid'
    @{ status = 'stale_pid' } | ConvertTo-Json -Compress
    exit 0
}

Stop-Process -Id $serverPid -Force
Wait-Process -Id $serverPid -Timeout 5 -ErrorAction SilentlyContinue
if (Get-Process -Id $serverPid -ErrorAction SilentlyContinue) {
    @{ status = 'failed'; error = 'process still running' } | ConvertTo-Json -Compress
    exit 1
}

Set-Stopped 'stop-companion.ps1'
@{ status = 'stopped' } | ConvertTo-Json -Compress
