#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Records or checks the hash of a spec's target: its Outcomes and Constraints sections.

.DESCRIPTION
    `plan` records the hash in the spec's frontmatter (`target_hash`) once the target is settled;
    `analyze` and `intent.verify` check it. A mismatch means the outcomes or constraints changed after
    planning without the step that changed them recording the change and the new hash, so an edit that
    moved the target shows up instead of passing silently.

    The hash is SHA-256 over "## outcomes\n" + N(Outcomes) + "\n## constraints\n" + N(Constraints), where
    N is the section's lines up to the next level-two heading, with HTML comments removed, line endings
    as LF, trailing whitespace trimmed and blank lines dropped. Formatting does not change it; any edit to
    an outcome, a check or a constraint does. It is computed here, never written by hand or by a model.

.PARAMETER Spec
    The spec file. Defaults to spec.md in the feature directory named by .specify/feature.json.

.PARAMETER Record
    Compute the hash and write it to the frontmatter as `target_hash`.

.PARAMETER Check
    Compare the recorded hash with the current one. Exit code 0: match; 1: changed; 2: none recorded.
#>
[CmdletBinding()]
param(
    [string]$Spec,
    [Parameter(ParameterSetName = 'Record', Mandatory = $true)][switch]$Record,
    [Parameter(ParameterSetName = 'Check', Mandatory = $true)][switch]$Check
)

$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
    [Console]::Error.WriteLine("ERROR: $Message")
    exit 3
}

if (-not $Spec) {
    $featureFile = '.specify/feature.json'
    if (-not (Test-Path -LiteralPath $featureFile)) { Fail 'no -Spec given and no .specify/feature.json here.' }
    $Spec = Join-Path (Get-Content -LiteralPath $featureFile -Raw | ConvertFrom-Json).feature_directory 'spec.md'
}
if (-not (Test-Path -LiteralPath $Spec)) { Fail "spec not found: $Spec" }

$text = [IO.File]::ReadAllText($Spec)
$lf = $text -replace "`r`n", "`n"

# Constraints may be removed when there are none; it then counts as empty. A spec without Outcomes has
# no target at all.
function Get-Section([string]$Name, [switch]$Optional) {
    $match = [regex]::Match($lf, "(?ims)^##[ \t]+$Name[ \t]*\n(.*?)(?=^##[ \t]|\z)")
    if (-not $match.Success) {
        if ($Optional) { return '' }
        Fail "the spec has no '## $Name' section."
    }
    $body = [regex]::Replace($match.Groups[1].Value, '(?s)<!--.*?-->', '')
    $lines = $body -split "`n" | ForEach-Object { $_.TrimEnd() } | Where-Object { $_ -ne '' }
    return ($lines -join "`n")
}

$canonical = "## outcomes`n" + (Get-Section 'Outcomes') + "`n## constraints`n" + (Get-Section 'Constraints' -Optional)
$hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($canonical))).ToLowerInvariant()

$frontmatter = [regex]::Match($text, '\A---\r?\n(.*?\r?\n)---\r?\n', 'Singleline')
if (-not $frontmatter.Success) { Fail 'the spec has no frontmatter block.' }
$stored = [regex]::Match($frontmatter.Groups[1].Value, '(?m)^target_hash:[ \t]*([0-9a-f]{64})[ \t]*\r?$')

if ($Record) {
    $newline = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
    $block = $frontmatter.Groups[1].Value
    $block = if ($stored.Success) {
        $block.Remove($stored.Groups[1].Index, 64).Insert($stored.Groups[1].Index, $hash)
    } else {
        $block + "target_hash: $hash$newline"
    }
    $updated = $text.Substring(0, $frontmatter.Groups[1].Index) + $block + $text.Substring($frontmatter.Groups[1].Index + $frontmatter.Groups[1].Length)
    [IO.File]::WriteAllText($Spec, $updated, [Text.UTF8Encoding]::new($false))
    [ordered]@{ HASH = $hash; RECORDED = $true; SPEC = $Spec } | ConvertTo-Json -Compress
    exit 0
}

$status = if (-not $stored.Success) { 'unrecorded' } elseif ($stored.Groups[1].Value -eq $hash) { 'match' } else { 'changed' }
[ordered]@{
    STATUS   = $status
    STORED   = if ($stored.Success) { $stored.Groups[1].Value } else { $null }
    COMPUTED = $hash
    SPEC     = $Spec
} | ConvertTo-Json -Compress
exit @{ match = 0; changed = 1; unrecorded = 2 }[$status]
