#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Installs (or reinstalls) the intent preset and extensions into the Spec Kit project in
    the current directory, for every agent integration the project has installed.

.DESCRIPTION
    Spec Kit registers preset and extension commands for the active integration only. The
    default integration is installed in place, through Spec Kit, so its registry records the
    preset and extensions. Each other installed integration is rendered by the same commands
    in a temporary copy of the project with that integration active, and only the intent
    command files are brought back.

    Rerun after editing this repository, after `specify integration upgrade`, or after adding
    an integration. An extension left out with -NoFeatureId or -NoCompanion is removed if an
    earlier run installed it.

    Prints one `installed for <integration>` or `skipped <integration>: <reason>` line per
    integration, then a `RESULT:` line. Exits 0 when every integration has the intent commands,
    2 when any was skipped.

.PARAMETER NoFeatureId
    Leave out the feature-id extension (dated <yyyyMMdd>-<hash>-<slug> feature IDs).

.PARAMETER NoCompanion
    Leave out the visual companion extension (needs Node.js 18 or later at run time).

.EXAMPLE
    pwsh -NoProfile -File "$HOME/.speckit-intent/install.ps1"
#>
[CmdletBinding()]
param([switch]$NoFeatureId, [switch]$NoCompanion)

$ErrorActionPreference = 'Stop'

$source = $PSScriptRoot
$project = (Get-Location).Path
$integrationFile = Join-Path $project '.specify/integration.json'
if (-not (Test-Path -LiteralPath $integrationFile)) {
    [Console]::Error.WriteLine("ERROR: .specify/integration.json not found; run this from a Spec Kit project root.")
    exit 1
}

$state = Get-Content -LiteralPath $integrationFile -Raw | ConvertFrom-Json
$default = if ($state.default_integration) { $state.default_integration } else { $state.integration }
$others = @($state.installed_integrations | Where-Object { $_ -and $_ -ne $default })

# Each extension and the commands it provides, as command files are named after them.
$provided = [ordered]@{
    'intent'     = @('intent[.-]verify')
    'feature-id' = @('feature-id[.-]allocate')
    'companion'  = @('companion[.-]show')
}
$extensions = @('intent')
if (-not $NoFeatureId) { $extensions += 'feature-id' }
if (-not $NoCompanion) { $extensions += 'companion' }
$excluded = @($provided.Keys | Where-Object { $_ -notin $extensions })

# Command files and skill directories, in whatever naming style and file extension an integration
# uses: `speckit.plan.md`, `speckit-plan/`, `speckit.plan.agent.md`, `speckit.plan.yaml`.
function Get-NamePattern([string[]]$Names) { '^speckit[.-](' + ($Names -join '|') + ')(\..+)?$' }
$preset = @('specify', 'clarify', 'plan', 'tasks', 'analyze', 'converge', 'checklist')
$ownedPattern = Get-NamePattern ($preset + @($extensions | ForEach-Object { $provided[$_] }))
$removedPattern = if ($excluded) { Get-NamePattern @($excluded | ForEach-Object { $provided[$_] }) } else { $null }

function Invoke-Specify {
    param([string[]]$Arguments, [switch]$AllowFailure)
    $output = & specify @Arguments 2>&1
    if ($LASTEXITCODE -ne 0 -and -not $AllowFailure) {
        $output | ForEach-Object { [Console]::Error.WriteLine("  $_") }
        throw "specify $($Arguments -join ' ') failed with exit code $LASTEXITCODE"
    }
}

function Install-Here {
    Invoke-Specify @('preset', 'remove', 'intent') -AllowFailure
    Invoke-Specify @('preset', 'add', '--dev', (Join-Path $source 'preset'))
    foreach ($extension in $extensions) {
        Invoke-Specify @('extension', 'add', '--dev', (Join-Path $source "extensions/$extension"), '--force')
    }
    # Leaving an extension out of a rerun removes it, hooks included.
    foreach ($extension in $excluded) {
        Invoke-Specify @('extension', 'remove', $extension, '--force') -AllowFailure
    }
}

# The directories an integration writes commands into, from the files its manifest lists:
# `.omp/commands/speckit.plan.md` gives `.omp/commands`, `.claude/skills/speckit-plan/SKILL.md`
# gives `.claude/skills`. Some write more than one (Copilot: `.github/agents` and `.github/prompts`).
function Get-CommandDirectories {
    param([string]$Root, [string]$Integration)
    $manifest = Join-Path $Root ".specify/integrations/$Integration.manifest.json"
    if (-not (Test-Path -LiteralPath $manifest)) { return @() }
    $files = (Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json).files.PSObject.Properties.Name
    $directories = foreach ($file in $files) {
        $parts = $file -split '/'
        $index = [array]::FindIndex($parts, [Predicate[string]] { param($p) $p -match '^speckit[.-]plan(\.|$)' })
        if ($index -gt 0) { $parts[0..($index - 1)] -join '/' }
    }
    return @($directories | Sort-Object -Unique)
}

# Copies owned entries from one command directory to another, writing file contents so that
# development-mode symbolic links in the temporary copy become ordinary files here. Returns the
# number of entries copied.
function Copy-Owned {
    param([string]$From, [string]$To)
    $count = 0
    if (-not (Test-Path -LiteralPath $From)) { return $count }
    foreach ($entry in Get-ChildItem -LiteralPath $From -Force | Where-Object { $_.Name -match $ownedPattern }) {
        $target = Join-Path $To $entry.Name
        if ($entry.PSIsContainer) {
            New-Item -ItemType Directory -Force -Path $target | Out-Null
            foreach ($file in Get-ChildItem -LiteralPath $entry.FullName -File -Force) {
                $destination = Join-Path $target $file.Name
                Remove-Item -LiteralPath $destination -Force -ErrorAction SilentlyContinue
                [IO.File]::WriteAllText($destination, [IO.File]::ReadAllText($file.FullName))
            }
        } else {
            Remove-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue
            [IO.File]::WriteAllText($target, [IO.File]::ReadAllText($entry.FullName))
        }
        $count++
    }
    return $count
}

# Whether an integration in the project now has the intent version of `plan`, recognised by the section
# every intent command carries. Checked rather than assumed, so a silent rendering failure is reported.
function Test-Installed {
    param([string]$Integration)
    foreach ($directory in Get-CommandDirectories -Root $project -Integration $Integration) {
        $full = Join-Path $project $directory
        if (-not (Test-Path -LiteralPath $full)) { continue }
        foreach ($entry in Get-ChildItem -LiteralPath $full -Force | Where-Object { $_.Name -match '^speckit[.-]plan(\..+)?$' }) {
            $files = if ($entry.PSIsContainer) { Get-ChildItem -LiteralPath $entry.FullName -File -Recurse } else { $entry }
            foreach ($file in $files) {
                if ((Get-Content -LiteralPath $file.FullName -Raw).Contains('## Asking the user')) { return $true }
            }
        }
    }
    return $false
}

# Removes the command files of extensions left out of this run.
function Remove-Excluded {
    param([string]$Directory)
    if (-not $removedPattern -or -not (Test-Path -LiteralPath $Directory)) { return }
    Get-ChildItem -LiteralPath $Directory -Force | Where-Object { $_.Name -match $removedPattern } |
        Remove-Item -Recurse -Force
}

Install-Here

# Development-mode installs link the default integration's extension commands into a
# `.specify-dev` folder; a committed link does not survive a checkout without symbolic-link
# support, so they become ordinary files and the folder stays out of git.
foreach ($directory in Get-CommandDirectories -Root $project -Integration $default) {
    $full = Join-Path $project $directory
    foreach ($link in Get-ChildItem -LiteralPath $full -Recurse -Force | Where-Object { $_.LinkType -and $_.Name -match '^(speckit[.-].*|SKILL\.md)$' }) {
        $content = [IO.File]::ReadAllText($link.FullName)
        Remove-Item -LiteralPath $link.FullName -Force
        [IO.File]::WriteAllText($link.FullName, $content)
    }
}
$ignore = Join-Path $project '.specify/.gitignore'
$ignored = if (Test-Path -LiteralPath $ignore) { Get-Content -LiteralPath $ignore } else { @() }
if ($ignored -notcontains 'extensions/*/.specify-dev/') {
    Add-Content -LiteralPath $ignore -Value "`n# Development-mode install staging (speckit-intent install.ps1).`nextensions/*/.specify-dev/"
}
$installed = @()
$skipped = @()
if (Test-Installed -Integration $default) {
    $installed += $default
    Write-Output "installed for $default"
} else {
    $skipped += $default
    Write-Output "skipped ${default}: its plan command is not the intent version after installing"
}

foreach ($integration in $others) {
    $directories = @(Get-CommandDirectories -Root $project -Integration $integration)
    if ($directories.Count -eq 0) {
        $skipped += $integration
        Write-Output "skipped ${integration}: its manifest does not show where its commands live"
        continue
    }

    $scratch = Join-Path ([IO.Path]::GetTempPath()) "speckit-intent-$([Guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $scratch | Out-Null
    try {
        Copy-Item -Recurse -Force -LiteralPath (Join-Path $project '.specify') -Destination (Join-Path $scratch '.specify')
        foreach ($directory in $directories) {
            $scratchDirectory = Join-Path $scratch $directory
            $projectDirectory = Join-Path $project $directory
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $scratchDirectory) | Out-Null
            if (Test-Path -LiteralPath $projectDirectory) {
                Copy-Item -Recurse -Force -LiteralPath $projectDirectory -Destination $scratchDirectory
            }
        }

        Push-Location $scratch
        try {
            Invoke-Specify @('integration', 'use', $integration)
            Install-Here
        } finally {
            Pop-Location
        }

        foreach ($directory in $directories) {
            $null = Copy-Owned -From (Join-Path $scratch $directory) -To (Join-Path $project $directory)
            Remove-Excluded -Directory (Join-Path $project $directory)
        }
        if (Test-Installed -Integration $integration) {
            $installed += $integration
            Write-Output "installed for $integration ($($directories -join ', '))"
        } else {
            $skipped += $integration
            Write-Output "skipped ${integration}: Spec Kit rendered no intent commands into $($directories -join ', ')"
        }
    } finally {
        Remove-Item -Recurse -Force -LiteralPath $scratch -ErrorAction SilentlyContinue
    }
}

# One line to read the result from, and an exit code that says the same: 0 when every integration has
# the intent commands, 2 when any was skipped.
if ($skipped.Count -gt 0) {
    Write-Output "RESULT: incomplete; installed for: $($installed -join ', '); skipped: $($skipped -join ', ')"
    exit 2
}
Write-Output "RESULT: installed for: $($installed -join ', ')"
