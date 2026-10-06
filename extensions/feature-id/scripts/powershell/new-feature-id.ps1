#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Allocates or audits a Spec Kit feature directory ID.

.DESCRIPTION
    Feature IDs have the shape <yyyyMMdd>-<hash>-<slug>, for example
    20260918-92526bb-standard-geospatial-formats.

    The date orders the register. The hash is derived from the slug, so it is a
    property of the feature name rather than of the order in which people or
    agents happened to start work. Two developers on two branches who never see
    each other's specs cannot take the same ID unless they chose the same name,
    and in that case the collision is real and worth surfacing.

    The hash is computed here (see feature-id-lib.ps1), never written by hand or
    by a language model. Re-running with the same name is idempotent: the same
    ID comes back, and an existing directory is reported rather than duplicated.

.PARAMETER Name
    The feature name or a short description of it. Slugified for the ID.

.PARAMETER Date
    Override the date component, as yyyyMMdd. Defaults to today, local time.

.PARAMETER HashLength
    Starting hash length in hex characters. Defaults to 7, widened in steps of 2
    if a different slug already holds that prefix.

.PARAMETER Verify
    Audit every directory under specs/: recompute each dated ID's hash from its
    own slug and report mismatches. Exits non-zero if any directory fails.
    Legacy NNN- directories are reported as legacy, not as failures.

.PARAMETER Json
    Emit JSON. Default; -Json:$false emits human-readable text.

.EXAMPLE
    pwsh -NoProfile -File .specify/extensions/feature-id/scripts/powershell/new-feature-id.ps1 -Name "Standard geospatial formats"

.EXAMPLE
    pwsh -NoProfile -File .specify/extensions/feature-id/scripts/powershell/new-feature-id.ps1 -Verify
#>
[CmdletBinding(DefaultParameterSetName = 'Allocate')]
param(
    [Parameter(ParameterSetName = 'Allocate', Position = 0, Mandatory = $true)]
    [string]$Name,

    [Parameter(ParameterSetName = 'Allocate')]
    [ValidatePattern('^\d{8}$')]
    [string]$Date,

    [Parameter(ParameterSetName = 'Allocate')]
    [ValidateRange(4, 40)]
    [int]$HashLength = 7,

    [Parameter(ParameterSetName = 'Verify', Mandatory = $true)]
    [switch]$Verify,

    [switch]$Json = $true
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'feature-id-lib.ps1')

$repoRoot = Find-ProjectRoot
if (-not $repoRoot) {
    [Console]::Error.WriteLine('ERROR: not inside a Spec Kit project (no .specify directory found).')
    exit 1
}

$specsDir = Join-Path $repoRoot 'specs'

function Get-ExistingFeatures {
    if (-not (Test-Path -LiteralPath $specsDir -PathType Container)) { return @() }
    Get-ChildItem -LiteralPath $specsDir -Directory | ForEach-Object { Get-FeatureIdInfo -DirectoryName $_.Name }
}

if ($PSCmdlet.ParameterSetName -eq 'Verify') {
    $failures = @()
    $report = foreach ($feature in Get-ExistingFeatures) {
        $status = switch ($feature.Kind) {
            'legacy' { 'legacy' }
            'modern' {
                $expected = Get-SlugHash -Slug $feature.Slug -Length $feature.Hash.Length
                if ($expected -eq $feature.Hash) { 'ok' } else { "MISMATCH: expected $expected" }
            }
            default { 'UNRECOGNISED: neither <yyyyMMdd>-<hash>-<slug> nor legacy NNN-<slug>' }
        }
        if ($status -notin @('ok', 'legacy')) { $failures += $feature.Name }
        [pscustomobject]@{ FEATURE_DIRECTORY = "specs/$($feature.Name)"; KIND = $feature.Kind; STATUS = $status }
    }

    if ($Json) {
        @{ OK = ($failures.Count -eq 0); FAILURES = $failures; FEATURES = @($report) } | ConvertTo-Json -Depth 6
    } else {
        $report | Format-Table -AutoSize | Out-String | Write-Output
    }

    if ($failures.Count -gt 0) { exit 1 }
    exit 0
}

try {
    $slug = Get-Slug -Text $Name
} catch {
    [Console]::Error.WriteLine("ERROR: $($_.Exception.Message)")
    exit 1
}

$date = if ($Date) { $Date } else { (Get-Date).ToString('yyyyMMdd') }
$existing = @(Get-ExistingFeatures)

# Idempotence first: the same name resolves to the spec that already exists,
# whatever date it was allocated on, rather than opening a second directory.
$sameSlug = $existing | Where-Object { $_.Kind -eq 'modern' -and $_.Slug -eq $slug } | Select-Object -First 1
if ($sameSlug) {
    $result = [ordered]@{
        FEATURE_ID        = $sameSlug.Name
        SLUG              = $sameSlug.Slug
        HASH              = $sameSlug.Hash
        DATE              = $sameSlug.Date
        FEATURE_DIRECTORY = "specs/$($sameSlug.Name)"
        EXISTING          = $true
    }
} else {
    $taken = @{}
    foreach ($feature in $existing | Where-Object { $_.Kind -eq 'modern' }) { $taken[$feature.Slug] = $feature.Hash }

    try {
        $hash = Resolve-FreeHash -Slug $slug -TakenBySlug $taken -StartLength $HashLength
    } catch {
        [Console]::Error.WriteLine("ERROR: $($_.Exception.Message)")
        exit 1
    }

    $featureId = "$date-$hash-$slug"
    $result = [ordered]@{
        FEATURE_ID        = $featureId
        SLUG              = $slug
        HASH              = $hash
        DATE              = $date
        FEATURE_DIRECTORY = "specs/$featureId"
        EXISTING          = $false
    }
}

if ($Json) {
    [pscustomobject]$result | ConvertTo-Json -Depth 4
} else {
    $result.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }
}
