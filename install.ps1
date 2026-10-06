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
    an integration.

.PARAMETER NoFeatureId
    Skip the feature-id extension (dated <yyyyMMdd>-<hash>-<slug> feature IDs).

.EXAMPLE
    pwsh -NoProfile -File D:/dev/tools/speckit-intent/install.ps1
#>
[CmdletBinding()]
param([switch]$NoFeatureId)

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

$extensions = @('intent')
if (-not $NoFeatureId) { $extensions += 'feature-id' }

# Command files and skill directories this repository provides, in either naming style.
$ownedPattern = '^speckit[.-](specify|plan|tasks|intent[.-]verify|feature-id[.-]allocate)(\.md|\.toml)?$'

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
}

# The directory an integration writes commands into, from the files its manifest lists:
# `.omp/commands/speckit.plan.md` gives `.omp/commands`, `.claude/skills/speckit-plan/SKILL.md`
# gives `.claude/skills`.
function Get-CommandDirectory {
    param([string]$Root, [string]$Integration)
    $manifest = Join-Path $Root ".specify/integrations/$Integration.manifest.json"
    if (-not (Test-Path -LiteralPath $manifest)) { return $null }
    $files = (Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json).files.PSObject.Properties.Name
    $first = $files | Where-Object { $_ -match '(^|/)speckit[.-]plan' } | Select-Object -First 1
    if (-not $first) { return $null }
    $parts = $first -split '/'
    $index = [array]::FindIndex($parts, [Predicate[string]] { param($p) $p -match '^speckit[.-]plan' })
    return ($parts[0..($index - 1)] -join '/')
}

# Copies owned entries from one command directory to another, writing file contents so that
# development-mode symbolic links in the temporary copy become ordinary files here.
function Copy-Owned {
    param([string]$From, [string]$To)
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
    }
}

Install-Here

# Development-mode installs link the default integration's extension commands into a
# `.specify-dev` folder; a committed link does not survive a checkout without symbolic-link
# support, so they become ordinary files and the folder stays out of git.
$defaultDirectory = Get-CommandDirectory -Root $project -Integration $default
if ($defaultDirectory) {
    $full = Join-Path $project $defaultDirectory
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
Write-Output "installed for $default"

foreach ($integration in $others) {
    $directory = Get-CommandDirectory -Root $project -Integration $integration
    if (-not $directory) {
        Write-Warning "skipped ${integration}: its manifest does not show where its commands live"
        continue
    }

    $scratch = Join-Path ([IO.Path]::GetTempPath()) "speckit-intent-$([Guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $scratch | Out-Null
    try {
        Copy-Item -Recurse -Force -LiteralPath (Join-Path $project '.specify') -Destination (Join-Path $scratch '.specify')
        $scratchDirectory = Join-Path $scratch $directory
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $scratchDirectory) | Out-Null
        Copy-Item -Recurse -Force -LiteralPath (Join-Path $project $directory) -Destination $scratchDirectory

        Push-Location $scratch
        try {
            Invoke-Specify @('integration', 'use', $integration)
            Install-Here
        } finally {
            Pop-Location
        }

        Copy-Owned -From $scratchDirectory -To (Join-Path $project $directory)
        Write-Output "installed for $integration ($directory)"
    } finally {
        Remove-Item -Recurse -Force -LiteralPath $scratch -ErrorAction SilentlyContinue
    }
}

& specify preset resolve spec-template
