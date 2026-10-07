#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5' }

BeforeAll {
    $script = Join-Path $PSScriptRoot '../extensions/intent/scripts/powershell/target-hash.ps1'

    $base = @'
---
id: 001-session-timeout
status: draft
---

# Session timeout

## Goal

Active users stay signed in.

## Outcomes

| ID | Outcome | Check |
|----|---------|-------|
| O1 | Active users stay signed in for 8 h | test session.spec: 8 h of activity, no sign-out |

## Constraints

- No new runtime dependencies.

## Edge cases

- Clock skew of 2 min -> still signed in
'@

    function New-Spec([string]$Text) {
        $path = Join-Path ([IO.Path]::GetTempPath()) "target-hash-$([Guid]::NewGuid().ToString('N')).md"
        [IO.File]::WriteAllText($path, $Text)
        return $path
    }

    function Invoke-Hash([string]$Spec, [string]$Mode) {
        $output = & pwsh -NoProfile -File $script -Spec $Spec "-$Mode" 2>&1
        return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Result = (($output -join "`n") | ConvertFrom-Json) }
    }
}

Describe 'target hash' {
    AfterEach { Remove-Item -LiteralPath $spec -ErrorAction SilentlyContinue }

    It 'hashes the normalised Outcomes and Constraints sections' {
        $spec = New-Spec $base
        $expectedText = "## outcomes`n" +
            "| ID | Outcome | Check |`n|----|---------|-------|`n" +
            "| O1 | Active users stay signed in for 8 h | test session.spec: 8 h of activity, no sign-out |" +
            "`n## constraints`n- No new runtime dependencies."
        $expected = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($expectedText))).ToLowerInvariant()
        (Invoke-Hash $spec 'Record').Result.HASH | Should -Be $expected
    }

    It 'records the hash in the frontmatter and leaves the rest of the spec as it was' {
        $spec = New-Spec $base
        $null = Invoke-Hash $spec 'Record'
        $after = [IO.File]::ReadAllText($spec)
        $after | Should -Match '(?m)^target_hash: [0-9a-f]{64}$'
        ($after -replace '(?m)^target_hash: [0-9a-f]{64}\r?\n', '') | Should -BeExactly $base
    }

    It 'still matches after changes that only touch whitespace, line endings, comments or other sections' {
        $spec = New-Spec $base
        $null = Invoke-Hash $spec 'Record'
        $text = [IO.File]::ReadAllText($spec)
        $text = $text.Replace("`n", "`r`n").Replace('- No new runtime dependencies.', "- No new runtime dependencies.   `r`n`r`n<!-- reviewed -->")
        $text = $text.Replace('Clock skew of 2 min', 'Clock skew of 5 min')
        [IO.File]::WriteAllText($spec, $text)
        $check = Invoke-Hash $spec 'Check'
        $check.ExitCode | Should -Be 0
        $check.Result.STATUS | Should -Be 'match'
    }

    It 'reports a changed threshold in an outcome' {
        $spec = New-Spec $base
        $null = Invoke-Hash $spec 'Record'
        [IO.File]::WriteAllText($spec, [IO.File]::ReadAllText($spec).Replace('for 8 h', 'for 4 h'))
        $check = Invoke-Hash $spec 'Check'
        $check.ExitCode | Should -Be 1
        $check.Result.STATUS | Should -Be 'changed'
    }

    It 'reports a changed constraint' {
        $spec = New-Spec $base
        $null = Invoke-Hash $spec 'Record'
        [IO.File]::WriteAllText($spec, [IO.File]::ReadAllText($spec).Replace('No new runtime dependencies.', 'One new runtime dependency allowed.'))
        (Invoke-Hash $spec 'Check').Result.STATUS | Should -Be 'changed'
    }

    It 'hashes a spec whose empty Constraints section was removed' {
        $spec = New-Spec ($base -replace '(?s)## Constraints.*?(?=## Edge cases)', '')
        $result = Invoke-Hash $spec 'Record'
        $result.ExitCode | Should -Be 0
        [IO.File]::WriteAllText($spec, [IO.File]::ReadAllText($spec).Replace('for 8 h', 'for 4 h'))
        (Invoke-Hash $spec 'Check').Result.STATUS | Should -Be 'changed'
    }

    It 'reports a spec whose target was never recorded' {
        $spec = New-Spec $base
        $check = Invoke-Hash $spec 'Check'
        $check.ExitCode | Should -Be 2
        $check.Result.STATUS | Should -Be 'unrecorded'
    }
}
