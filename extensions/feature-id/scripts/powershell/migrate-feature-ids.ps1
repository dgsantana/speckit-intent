#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Renames legacy sequential spec directories (NNN-slug) to <yyyyMMdd>-<hash>-<slug>
    and rewrites every reference to them in tracked text files.

.DESCRIPTION
    One run migrates one branch's working tree. The same specification must end up
    with the same directory name on every branch, or the rename becomes the merge
    conflict this scheme exists to prevent. Two mechanisms enforce that:

    1. `.specify/feature-id-migration.json` is the authoritative mapping. When it
       lists a legacy name, the target is taken from the file and nothing is
       derived. The first run writes it; commit it, and every later branch reuses
       identical names.

    2. A legacy name absent from the mapping takes its date from `git log --all`:
       the oldest commit on any ref that added that spec's spec.md. A query scoped
       to the current branch can return different dates on different branches.

    The slug is the legacy slug unchanged; the hash comes from feature-id-lib.ps1.

    Reference rewriting replaces the whole directory-name token, which covers
    `specs/<old>/spec.md`, a bare `<old>`, and a link with a trailing slash alike.
    It runs over tracked text files, skipping paths matched by -Keep, and reports
    every file it touched. `.specify/feature.json` is updated too when it names a
    renamed directory, tracked or not.

    Dry run by default. Nothing is moved or edited without -Apply.

    Not migrated: git branch names, commit messages, and paths matched by -Keep
    (changelogs and history by default), because they record what happened at
    the time. Requirement IDs inside specs (FR-001 and similar) are untouched.

.PARAMETER Apply
    Perform the renames and rewrites. Without it, report what would change.

.PARAMETER Keep
    Wildcard patterns, matched against forward-slash repository paths, for files
    whose references to the old names are left as they are.

.PARAMETER AllowDirty
    Run with tracked modifications present. The migration diff then mixes with
    whatever else is uncommitted.

.PARAMETER Json
    Emit a JSON report instead of text.

.EXAMPLE
    pwsh -NoProfile -File .specify/extensions/feature-id/scripts/powershell/migrate-feature-ids.ps1

.EXAMPLE
    pwsh -NoProfile -File .specify/extensions/feature-id/scripts/powershell/migrate-feature-ids.ps1 -Apply
#>
[CmdletBinding()]
param(
    [switch]$Apply,
    [string[]]$Keep = @('CHANGELOG*', '*/CHANGELOG*', '*/history/*', 'history/*'),
    [switch]$Json,
    [switch]$AllowDirty
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'feature-id-lib.ps1')

$repoRoot = Find-ProjectRoot
if (-not $repoRoot) {
    [Console]::Error.WriteLine('ERROR: not inside a Spec Kit project (no .specify directory found).')
    exit 1
}

Push-Location $repoRoot
try {
    $specsDir = Join-Path $repoRoot 'specs'
    if (-not (Test-Path -LiteralPath $specsDir -PathType Container)) {
        [Console]::Error.WriteLine('ERROR: no specs/ directory in this tree.')
        exit 1
    }

    $mappingRelative = '.specify/feature-id-migration.json'
    $mappingPath = Join-Path $repoRoot $mappingRelative
    $mapping = [ordered]@{}
    if (Test-Path -LiteralPath $mappingPath) {
        $loaded = Get-Content -LiteralPath $mappingPath -Raw | ConvertFrom-Json
        foreach ($property in $loaded.PSObject.Properties) {
            $mapping[$property.Name] = [string]$property.Value
        }
    }

    # A rename plus a repository-wide rewrite over unrelated uncommitted work would
    # become one diff nobody can review.
    $dirty = @(git status --porcelain -- . | Where-Object { $_ -notmatch '^\?\? ' })
    if ($Apply -and $dirty.Count -gt 0 -and -not $AllowDirty) {
        [Console]::Error.WriteLine('ERROR: working tree has tracked modifications. Commit or stash them first so the migration is its own diff, or pass -AllowDirty:')
        $dirty | ForEach-Object { [Console]::Error.WriteLine("  $_") }
        exit 1
    }
    if ($Apply -and $dirty.Count -gt 0) {
        [Console]::Error.WriteLine("WARNING: applying over $($dirty.Count) tracked modification(s); the migration will not be a separate diff.")
    }

    function Get-SpecAddDate {
        param([Parameter(Mandatory = $true)][string]$DirectoryName)

        $path = "specs/$DirectoryName/spec.md"
        $dates = @(git log --all --diff-filter=A --format='%ad' --date=format:'%Y%m%d' -- $path 2>$null | Where-Object { $_ })
        if ($dates.Count -gt 0) { return $dates[-1] }

        $dates = @(git log --all --format='%ad' --date=format:'%Y%m%d' -- "specs/$DirectoryName" 2>$null | Where-Object { $_ })
        if ($dates.Count -gt 0) { return $dates[-1] }

        return $null
    }

    $features = Get-ChildItem -LiteralPath $specsDir -Directory | ForEach-Object { Get-FeatureIdInfo -DirectoryName $_.Name }

    $unknown = @($features | Where-Object { $_.Kind -eq 'unknown' })
    if ($unknown.Count -gt 0) {
        [Console]::Error.WriteLine('ERROR: spec directories match neither naming rule; resolve them by hand before migrating:')
        $unknown | ForEach-Object { [Console]::Error.WriteLine("  specs/$($_.Name)") }
        exit 1
    }

    # Hashes already in use, so a legacy slug that prefix-collides with a dated one
    # widens instead of clashing.
    $taken = @{}
    foreach ($feature in $features | Where-Object { $_.Kind -eq 'modern' }) { $taken[$feature.Slug] = $feature.Hash }

    $plan = @()
    foreach ($feature in $features | Where-Object { $_.Kind -eq 'legacy' } | Sort-Object Name) {
        if ($mapping.Contains($feature.Name)) {
            $newName = $mapping[$feature.Name]
            $info = Get-FeatureIdInfo -DirectoryName $newName
            if ($info.Kind -ne 'modern') {
                [Console]::Error.WriteLine("ERROR: mapping entry '$($feature.Name)' -> '$newName' is not a valid feature ID.")
                exit 1
            }
            $expected = Get-SlugHash -Slug $info.Slug -Length $info.Hash.Length
            if ($expected -ne $info.Hash) {
                [Console]::Error.WriteLine("ERROR: mapping entry '$newName' has a hash that does not match its slug (expected $expected). Refusing to propagate a hand-edited mapping.")
                exit 1
            }
            $taken[$info.Slug] = $info.Hash
            $plan += [pscustomobject]@{ OldName = $feature.Name; NewName = $newName; Source = 'mapping' }
            continue
        }

        $slug = Get-Slug -Text $feature.Slug
        $hash = Resolve-FreeHash -Slug $slug -TakenBySlug $taken
        $taken[$slug] = $hash
        $addDate = if ($feature.Date) { $feature.Date } else { Get-SpecAddDate -DirectoryName $feature.Name }
        if (-not $addDate) {
            [Console]::Error.WriteLine("ERROR: no allocation date for specs/$($feature.Name) in git history, and no mapping entry. Add one to $mappingRelative rather than letting the clock decide, or the name will differ per machine.")
            exit 1
        }

        $plan += [pscustomobject]@{ OldName = $feature.Name; NewName = "$addDate-$hash-$slug"; Source = 'derived' }
    }

    # Two legacy directories with one slug (two branches that took different numbers for the same
    # feature) would get one target, and the second `git mv` would move one into the other. A target
    # slug that a dated directory already holds is the same collision. Both need a person to decide.
    $bySlug = @{}
    foreach ($feature in $features | Where-Object { $_.Kind -eq 'modern' }) { $bySlug[$feature.Slug] = @("specs/$($feature.Name)") }
    foreach ($item in $plan) {
        $targetSlug = (Get-FeatureIdInfo -DirectoryName $item.NewName).Slug
        $bySlug[$targetSlug] = @($bySlug[$targetSlug]) + "specs/$($item.OldName)" | Where-Object { $_ }
    }
    $collisions = @($bySlug.GetEnumerator() | Where-Object { $_.Value.Count -gt 1 })
    if ($collisions.Count -gt 0) {
        [Console]::Error.WriteLine('ERROR: these directories hold the same feature name; merge or rename them by hand, then run again. Nothing was changed.')
        foreach ($collision in $collisions) { [Console]::Error.WriteLine("  $($collision.Key): $($collision.Value -join ', ')") }
        exit 1
    }

    if ($plan.Count -eq 0) {
        $message = 'No legacy spec directories found; nothing to migrate.'
        if ($Json) { @{ OK = $true; RENAMES = @(); FILES = @(); MESSAGE = $message } | ConvertTo-Json -Depth 5 } else { Write-Output $message }
        exit 0
    }

    $binaryExtensions = @(
        '.png', '.jpg', '.jpeg', '.gif', '.bmp', '.ico', '.webp', '.pdf', '.zip', '.gz', '.br', '.7z',
        '.dll', '.exe', '.pdb', '.so', '.dylib', '.woff', '.woff2', '.ttf', '.otf', '.eot', '.wasm',
        '.sqlite', '.db', '.bin', '.tif', '.tiff', '.onnx', '.snk', '.glb', '.b3dm', '.pnts', '.las',
        '.laz', '.ply', '.terrain', '.terraindb', '.imagerydb', '.gpkg', '.uasset', '.umap'
    )

    function Test-Kept {
        param([string]$Relative)
        foreach ($pattern in $Keep) { if ($Relative -like $pattern) { return $true } }
        return $false
    }

    # The mapping records the rename; rewriting it would turn each key into its own target.
    $candidates = @(git ls-files | Where-Object { $_ -and $_ -ne $mappingRelative })
    if (-not ($candidates -contains '.specify/feature.json')) { $candidates += '.specify/feature.json' }

    # Whole directory-name tokens only: `007-auth` must not match inside `007-auth-tokens`.
    $tokenPatterns = @{}
    foreach ($item in $plan) {
        $tokenPatterns[$item.OldName] = [regex]::new("(?<![A-Za-z0-9_-])$([regex]::Escape($item.OldName))(?![A-Za-z0-9_-])")
    }

    $strictUtf8 = [Text.UTF8Encoding]::new($false, $true)
    $edits = @()
    $kept = @()
    $notUtf8 = @()
    foreach ($relative in $candidates) {
        if ($binaryExtensions -contains [IO.Path]::GetExtension($relative).ToLowerInvariant()) { continue }

        $full = Join-Path $repoRoot $relative
        if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { continue }

        # Rewrite UTF-8 only, keeping a byte order mark where there was one; any other encoding would be
        # garbled by a round trip, so such a file is reported for a person to edit instead.
        $bytes = [IO.File]::ReadAllBytes($full)
        $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
        $offset = if ($hasBom) { 3 } else { 0 }
        try {
            $content = $strictUtf8.GetString($bytes, $offset, $bytes.Length - $offset)
        } catch [Text.DecoderFallbackException] {
            $raw = [Text.Encoding]::Latin1.GetString($bytes)
            if (@($plan | Where-Object { $raw.Contains($_.OldName) }).Count -gt 0) { $notUtf8 += $relative }
            continue
        }
        $updated = $content
        $hits = @()
        foreach ($item in $plan) {
            $pattern = $tokenPatterns[$item.OldName]
            $count = $pattern.Matches($updated).Count
            if ($count -gt 0) {
                $updated = $pattern.Replace($updated, $item.NewName)
                $hits += "$($item.OldName) x$count"
            }
        }
        if ($hits.Count -eq 0) { continue }

        if (Test-Kept -Relative $relative) {
            $kept += $relative
            continue
        }

        $edits += [pscustomobject]@{ FILE = $relative; REPLACEMENTS = $hits }
        if ($Apply) {
            [IO.File]::WriteAllText($full, $updated, [Text.UTF8Encoding]::new($hasBom))
        }
    }

    if ($Apply) {
        foreach ($item in $plan) {
            git mv -- "specs/$($item.OldName)" "specs/$($item.NewName)"
            if ($LASTEXITCODE -ne 0) {
                [Console]::Error.WriteLine("ERROR: git mv failed for specs/$($item.OldName)")
                exit 1
            }
            $mapping[$item.OldName] = $item.NewName
        }

        $ordered = [ordered]@{}
        foreach ($key in ($mapping.Keys | Sort-Object)) { $ordered[$key] = $mapping[$key] }
        # Not $json: variable names are case-insensitive, and $Json is this script's switch.
        $mappingText = ([pscustomobject]$ordered | ConvertTo-Json -Depth 4)
        [IO.File]::WriteAllText($mappingPath, $mappingText + "`n", [Text.UTF8Encoding]::new($false))
    }

    $report = [ordered]@{
        OK      = $true
        APPLIED = [bool]$Apply
        MAPPING = $mappingRelative
        RENAMES = @($plan | ForEach-Object { [pscustomobject]@{ FROM = "specs/$($_.OldName)"; TO = "specs/$($_.NewName)"; SOURCE = $_.Source } })
        FILES   = @($edits)
        KEPT    = @($kept)
        NOT_UTF8 = @($notUtf8)
    }

    if ($Json) {
        [pscustomobject]$report | ConvertTo-Json -Depth 6
    } else {
        if ($Apply) { Write-Output 'Applied:' } else { Write-Output 'Dry run (use -Apply):' }
        foreach ($item in $plan) { Write-Output "  specs/$($item.OldName)  ->  specs/$($item.NewName)   [$($item.Source)]" }
        Write-Output ''
        Write-Output "Files rewritten: $($edits.Count)"
        foreach ($edit in $edits) { Write-Output "  $($edit.FILE)  [$($edit.REPLACEMENTS -join '; ')]" }
        if ($kept.Count -gt 0) {
            Write-Output ''
            Write-Output "Files left with old names (-Keep): $($kept.Count)"
            foreach ($path in $kept) { Write-Output "  $path" }
        }
        if ($notUtf8.Count -gt 0) {
            Write-Output ''
            Write-Output "Files not rewritten because they are not UTF-8; update their references by hand: $($notUtf8.Count)"
            foreach ($path in $notUtf8) { Write-Output "  $path" }
        }
        Write-Output ''
        Write-Output 'Then: commit the renames and the mapping together, and run new-feature-id.ps1 -Verify.'
    }
} finally {
    Pop-Location
}
