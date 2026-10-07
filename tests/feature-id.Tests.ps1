#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5' }

BeforeAll {
    $scripts = Join-Path $PSScriptRoot '../extensions/feature-id/scripts/powershell'
    . (Join-Path $scripts 'feature-id-lib.ps1')
    $allocator = Join-Path $scripts 'new-feature-id.ps1'
    $migrator = Join-Path $scripts 'migrate-feature-ids.ps1'

    # A throwaway Spec Kit project: .specify/ plus the given spec directories, each holding a spec.md.
    function New-Project {
        param([string[]]$Specs = @(), [switch]$Git)
        $root = Join-Path ([IO.Path]::GetTempPath()) "feature-id-test-$([Guid]::NewGuid().ToString('N'))"
        New-Item -ItemType Directory -Path (Join-Path $root '.specify') -Force | Out-Null
        foreach ($spec in $Specs) {
            New-Item -ItemType Directory -Path (Join-Path $root "specs/$spec") -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $root "specs/$spec/spec.md") -Value "# $spec"
        }
        if ($Git) {
            git -C $root init -q -b main
            git -C $root config user.email test@example.com
            git -C $root config user.name test
            git -C $root config core.autocrlf false
        }
        return $root
    }

    function Invoke-Script {
        param([string]$Root, [string]$Script, [string[]]$Arguments)
        Push-Location $Root
        try {
            $output = & pwsh -NoProfile -File $Script @Arguments 2>&1
            return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = ($output -join "`n") }
        } finally {
            Pop-Location
        }
    }

    function Get-Id {
        param([string]$Date, [string]$Name)
        $slug = Get-Slug -Text $Name
        return "$Date-$(Get-SlugHash -Slug $slug -Length 7)-$slug"
    }
}

Describe 'slug and hash rules' {
    # Every existing ID is derived from these rules; a change to them renames features retroactively.
    It 'folds accents and case to the same slug' {
        Get-Slug -Text 'Zone Fédération' | Should -Be 'zone-federation'
        Get-Slug -Text 'ZONE federation' | Should -Be 'zone-federation'
    }

    It 'cuts a long name at a word boundary within 48 characters' {
        $slug = Get-Slug -Text 'streaming raster ingest for very large geospatial tile pyramids'
        $slug | Should -Be 'streaming-raster-ingest-for-very-large'
    }

    It 'matches the hash published in the README example' {
        Get-SlugHash -Slug 'standard-geospatial-formats' -Length 7 | Should -Be '92526bb'
    }
}

Describe 'audit (-Verify)' {
    AfterEach { Remove-Item -Recurse -Force -LiteralPath $root -ErrorAction SilentlyContinue }

    It 'fails a directory whose hash does not match its slug' {
        $root = New-Project -Specs @('20261001-0000000-payments')
        $result = Invoke-Script $root $allocator @('-Verify')
        $result.ExitCode | Should -Be 1
        ($result.Output | ConvertFrom-Json).FAILURES | Should -Contain '20261001-0000000-payments'
    }

    It 'fails two directories that hold the same slug, as after merging two branches' {
        $first = Get-Id '20261001' 'payments'
        $second = Get-Id '20261005' 'payments'
        $root = New-Project -Specs @($first, $second)
        $result = Invoke-Script $root $allocator @('-Verify')
        $result.ExitCode | Should -Be 1
        $failures = ($result.Output | ConvertFrom-Json).FAILURES
        $failures | Should -Contain $first
        $failures | Should -Contain $second
    }

    It 'passes distinct dated IDs and reports legacy ones without failing' {
        $root = New-Project -Specs @((Get-Id '20261001' 'payments'), (Get-Id '20261002' 'refunds'), '003-legacy')
        $result = Invoke-Script $root $allocator @('-Verify')
        $result.ExitCode | Should -Be 0
        $legacy = ($result.Output | ConvertFrom-Json).FEATURES | Where-Object FEATURE_DIRECTORY -eq 'specs/003-legacy'
        $legacy.KIND | Should -Be 'legacy'
    }

    It 'reads Spec Kit timestamp directories as legacy, not as dated IDs with a bad hash' {
        $root = New-Project -Specs @('20260319-143022-user-auth')
        $result = Invoke-Script $root $allocator @('-Verify')
        $result.ExitCode | Should -Be 0 -Because $result.Output
        (($result.Output | ConvertFrom-Json).FEATURES)[0].KIND | Should -Be 'legacy'
    }

    It 'fails a dated ID whose slug a legacy directory already holds' {
        $dated = Get-Id '20261001' 'auth'
        $root = New-Project -Specs @('007-auth', $dated)
        $result = Invoke-Script $root $allocator @('-Verify')
        $result.ExitCode | Should -Be 1
        ($result.Output | ConvertFrom-Json).FAILURES | Should -Contain $dated
    }
}

Describe 'allocation' {
    AfterEach { Remove-Item -Recurse -Force -LiteralPath $root -ErrorAction SilentlyContinue }

    It 'reports an existing legacy spec of the same name instead of allocating a second one' {
        $root = New-Project -Specs @('007-auth')
        $result = (Invoke-Script $root $allocator @('-Name', 'Auth')).Output | ConvertFrom-Json
        $result.EXISTING | Should -BeTrue
        $result.FEATURE_DIRECTORY | Should -Be 'specs/007-auth'
    }
}

Describe 'migration' {
    AfterEach { Remove-Item -Recurse -Force -LiteralPath $root -ErrorAction SilentlyContinue }

    It 'rewrites a legacy name without corrupting another legacy name it prefixes' {
        $root = New-Project -Git -Specs @('007-auth', '007-auth-tokens')
        Set-Content -LiteralPath (Join-Path $root 'index.md') -Value @(
            'See specs/007-auth/spec.md and specs/007-auth-tokens/spec.md.'
        )
        git -C $root add -A
        git -C $root commit -q -m 'specs' --date '2026-09-01T12:00:00'

        $result = Invoke-Script $root $migrator @('-Apply')
        $result.ExitCode | Should -Be 0 -Because $result.Output

        $date = git -C $root log -1 --format=%ad --date=format:%Y%m%d
        $auth = Get-Id $date 'auth'
        $tokens = Get-Id $date 'auth-tokens'
        Get-Content -LiteralPath (Join-Path $root 'index.md') |
            Should -Be "See specs/$auth/spec.md and specs/$tokens/spec.md."
        Test-Path -LiteralPath (Join-Path $root "specs/$tokens/spec.md") | Should -BeTrue
    }

    It 'rewrites short specs/NNN references and lists the ones it cannot resolve' {
        $root = New-Project -Git -Specs @('021-launcher-page', '007-auth', '007-auth-tokens')
        Set-Content -LiteralPath (Join-Path $root 'notes.md') -Value @(
            'Done in specs/021 (T005), see specs/021-launcher-page/spec.md.'
            'Also specs\021 on Windows, and specs/0210 is something else.'
            'Overlap: specs/007 is ambiguous.'
            'Prose: spec 021 shipped, as specification 021 says.'
            'Elsewhere: ../acme/specs/021 belongs to another repository.'
            'Foreign: ACME specs/021 is theirs.'
            'Same line, not adjacent: the ACME world data bundle is described in specs/021.'
        )
        $tool = Join-Path $root '.specify/extensions/feature-id/scripts/powershell'
        New-Item -ItemType Directory -Path $tool -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $tool 'example.ps1') -Value '# `specs/021` means 021-launcher-page.'
        git -C $root add -A
        git -C $root commit -q -m 'specs' --date '2026-09-01T12:00:00'

        $result = Invoke-Script $root $migrator @('-Apply', '-Json', '-Foreign', 'ACME')
        $result.ExitCode | Should -Be 0 -Because $result.Output
        $date = git -C $root log -1 --format=%ad --date=format:%Y%m%d
        $launcher = Get-Id $date 'launcher-page'

        $lines = Get-Content -LiteralPath (Join-Path $root 'notes.md')
        $lines[0] | Should -Be "Done in specs/$launcher (T005), see specs/$launcher/spec.md."
        $lines[1] | Should -Be "Also specs\$launcher on Windows, and specs/0210 is something else."
        $lines[2] | Should -Be 'Overlap: specs/007 is ambiguous.'
        $lines[3] | Should -Be 'Prose: spec 021 shipped, as specification 021 says.'
        $lines[4] | Should -Be 'Elsewhere: ../acme/specs/021 belongs to another repository.'
        $lines[5] | Should -Be 'Foreign: ACME specs/021 is theirs.'
        $lines[6] | Should -Be "Same line, not adjacent: the ACME world data bundle is described in specs/$launcher."
        Get-Content -LiteralPath (Join-Path $tool 'example.ps1') | Should -Be '# `specs/021` means 021-launcher-page.'

        $unresolved = ($result.Output | ConvertFrom-Json).UNRESOLVED
        ($unresolved | Where-Object { $_.FILE -eq 'notes.md' }).LINE | Sort-Object | Should -Be @(3, 4, 5, 6)
    }

    It 'refuses two legacy directories that would take the same name, and moves nothing' {
        $root = New-Project -Git -Specs @('007-auth', '012-auth')
        git -C $root add -A
        git -C $root commit -q -m 'specs'

        $result = Invoke-Script $root $migrator @('-Apply')
        $result.ExitCode | Should -Be 1
        $result.Output | Should -Match '007-auth'
        $result.Output | Should -Match '012-auth'
        Test-Path -LiteralPath (Join-Path $root 'specs/007-auth/spec.md') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $root 'specs/012-auth/spec.md') | Should -BeTrue
    }

    It 'migrates a Spec Kit timestamp directory using the date in its name' {
        $root = New-Project -Git -Specs @('20250319-143022-user-auth')
        git -C $root add -A
        git -C $root commit -q -m 'spec'

        $result = Invoke-Script $root $migrator @('-Json')
        $result.ExitCode | Should -Be 0 -Because $result.Output
        ($result.Output | ConvertFrom-Json).RENAMES[0].TO | Should -Be "specs/$(Get-Id '20250319' 'user-auth')"
    }

    It 'keeps a byte order mark and leaves files that are not UTF-8 untouched' {
        $root = New-Project -Git -Specs @('005-export')
        $bom = Join-Path $root 'bom.md'
        $latin = Join-Path $root 'latin.md'
        [IO.File]::WriteAllText($bom, 'See specs/005-export/spec.md', [Text.UTF8Encoding]::new($true))
        [IO.File]::WriteAllBytes($latin, [Text.Encoding]::Latin1.GetBytes("Caf$([char]0xE9): specs/005-export/"))
        $latinBefore = [IO.File]::ReadAllBytes($latin)
        git -C $root add -A
        git -C $root commit -q -m 'spec'

        $result = Invoke-Script $root $migrator @('-Apply')
        $result.ExitCode | Should -Be 0 -Because $result.Output

        $bytes = [IO.File]::ReadAllBytes($bom)
        $bytes[0..2] | Should -Be @(0xEF, 0xBB, 0xBF)
        [IO.File]::ReadAllText($bom) | Should -Match ([regex]::Escape((Get-Id (git -C $root log -1 --format=%ad --date=format:%Y%m%d) 'export')))
        [IO.File]::ReadAllBytes($latin) | Should -Be $latinBefore
        $result.Output | Should -Match 'latin\.md'
    }

    It 'takes names from the committed mapping instead of deriving them again' {
        $root = New-Project -Git -Specs @('004-search')
        git -C $root add -A
        git -C $root commit -q -m 'spec'
        $mapped = Get-Id '20250101' 'search'
        Set-Content -LiteralPath (Join-Path $root '.specify/feature-id-migration.json') -Value "{ `"004-search`": `"$mapped`" }"

        $result = Invoke-Script $root $migrator @('-Json')
        $result.ExitCode | Should -Be 0 -Because $result.Output
        ($result.Output | ConvertFrom-Json).RENAMES[0].TO | Should -Be "specs/$mapped"
    }
}
