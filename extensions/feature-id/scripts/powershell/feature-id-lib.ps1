#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Shared slug and hash derivation for feature IDs.

.DESCRIPTION
    Sourced by new-feature-id.ps1 (allocation, audit) and migrate-feature-ids.ps1
    (renaming legacy sequential IDs), so the two cannot disagree: a second copy of
    the hash rule is the same mistake as a second copy of a wire format.

    Feature ID shape: <yyyyMMdd>-<hash>-<slug>.
#>

# The project root is the nearest directory holding .specify, searched upward from
# the current directory, so these scripts do not depend on core Spec Kit helpers.
function Find-ProjectRoot {
    $dir = (Get-Location).Path
    while ($dir) {
        if (Test-Path -LiteralPath (Join-Path $dir '.specify') -PathType Container) { return $dir }
        $parent = Split-Path -Parent $dir
        if ($parent -eq $dir) { break }
        $dir = $parent
    }
    return $null
}

# Shape of a modern ID. The hash is at least 4 hex characters so a short
# lowercase word cannot be mistaken for one.
$script:ModernIdPattern = '^(?<date>\d{8})-(?<hash>[0-9a-f]{4,})-(?<slug>[a-z0-9]+(?:-[a-z0-9]+)*)$'
$script:LegacyIdPattern = '^(?<num>\d{3})-(?<slug>.+)$'

function Get-FeatureIdPatterns {
    return [pscustomobject]@{
        Modern = $script:ModernIdPattern
        Legacy = $script:LegacyIdPattern
    }
}

function Get-Slug {
    param([Parameter(Mandatory = $true)][string]$Text)

    # Decompose accents so "Zone Fédération" and "Zone Federation" slug alike,
    # then keep only ASCII alphanumerics as word characters.
    $normalized = $Text.Normalize([Text.NormalizationForm]::FormD)
    $stripped = ($normalized.ToCharArray() | Where-Object {
        [Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne [Globalization.UnicodeCategory]::NonSpacingMark
    }) -join ''

    $slug = $stripped.ToLowerInvariant()
    $slug = [Text.RegularExpressions.Regex]::Replace($slug, '[^a-z0-9]+', '-')
    $slug = $slug.Trim('-')

    if ([string]::IsNullOrEmpty($slug)) {
        throw "'$Text' contains no characters usable in a feature slug."
    }

    # Bounded so a pasted sentence cannot produce a path near the Windows limit.
    # Cut on a word boundary rather than mid-word.
    $maxLength = 48
    if ($slug.Length -gt $maxLength) {
        $slug = $slug.Substring(0, $maxLength)
        $lastDash = $slug.LastIndexOf('-')
        if ($lastDash -ge 12) { $slug = $slug.Substring(0, $lastDash) }
        $slug = $slug.Trim('-')
    }

    return $slug
}

function Get-SlugHash {
    param(
        [Parameter(Mandatory = $true)][string]$Slug,
        [Parameter(Mandatory = $true)][int]$Length
    )

    # SHA-1 over the slug's UTF-8 bytes, truncated -- the same reason git uses a
    # short hex digest: stable, readable, and a property of the content rather
    # than of allocation order. Nothing here is a security boundary; a real
    # prefix collision is handled by widening the prefix.
    $sha1 = [Security.Cryptography.SHA1]::Create()
    try {
        $digest = $sha1.ComputeHash([Text.Encoding]::UTF8.GetBytes($Slug))
    } finally {
        $sha1.Dispose()
    }

    $hex = -join ($digest | ForEach-Object { $_.ToString('x2') })
    return $hex.Substring(0, $Length)
}

function Get-FeatureIdInfo {
    param([Parameter(Mandatory = $true)][string]$DirectoryName)

    if ($DirectoryName -match $script:ModernIdPattern) {
        return [pscustomobject]@{
            Name = $DirectoryName
            Kind = 'modern'
            Date = $Matches['date']
            Hash = $Matches['hash']
            Slug = $Matches['slug']
        }
    }

    if ($DirectoryName -match $script:LegacyIdPattern) {
        return [pscustomobject]@{
            Name = $DirectoryName
            Kind = 'legacy'
            Date = $null
            Hash = $null
            Slug = $Matches['slug']
        }
    }

    return [pscustomobject]@{
        Name = $DirectoryName
        Kind = 'unknown'
        Date = $null
        Hash = $null
        Slug = $null
    }
}

function Resolve-FreeHash {
    <#
    .SYNOPSIS
        Shortest hash prefix for $Slug that no *different* slug already holds.
    .DESCRIPTION
        $TakenBySlug maps an existing slug to its existing hash. Same-slug is the
        caller's business (it means the feature already exists); this only widens
        against a genuine prefix collision between two distinct names.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Slug,
        [hashtable]$TakenBySlug = @{},
        [int]$StartLength = 7
    )

    $length = $StartLength
    while ($length -le 40) {
        $candidate = Get-SlugHash -Slug $Slug -Length $length
        $clash = $false
        foreach ($key in $TakenBySlug.Keys) {
            if ($key -eq $Slug) { continue }
            if ([string]$TakenBySlug[$key] -and ([string]$TakenBySlug[$key]).StartsWith($candidate)) {
                $clash = $true
                break
            }
        }
        if (-not $clash) { return $candidate }
        $length += 2
    }

    throw "Could not find a free hash prefix for slug '$Slug'. Inspect specs/ by hand."
}
