#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5' }

BeforeDiscovery {
    $repo = Join-Path $PSScriptRoot '..'
    $commands = @(Get-ChildItem -Path (Join-Path $repo 'preset'), (Join-Path $repo 'extensions') -Filter '*.md' -Recurse |
        Where-Object { $_.Directory.Name -eq 'commands' } |
        ForEach-Object { @{ Name = $_.BaseName; Path = $_.FullName } })
    # Commands that never ask the user anything. A new command either carries the rule or is listed here.
    $silent = @('speckit.feature-id.allocate')
    $asking = @($commands | Where-Object { $_.Name -notin $silent })
}

BeforeAll {
    $repo = Join-Path $PSScriptRoot '..'
    function Get-AskSection([string]$Path) {
        $text = (Get-Content -LiteralPath $Path -Raw) -replace "`r`n", "`n"
        $match = [regex]::Match($text, '(?ms)^## Asking the user\n.*?(?=^## )')
        if ($match.Success) { $match.Value.Trim() } else { $null }
    }
    $reference = Get-AskSection (Join-Path $repo 'preset/commands/speckit.specify.md')

    # Core Spec Kit 1.1.1 command names, plus every command this repository provides.
    $known = @('speckit.implement', 'speckit.constitution', 'speckit.taskstoissues') +
        @(Get-ChildItem -Path (Join-Path $repo 'preset'), (Join-Path $repo 'extensions') -Filter '*.md' -Recurse |
            Where-Object { $_.Directory.Name -eq 'commands' } | ForEach-Object BaseName)
}

Describe 'asking the user' {
    It '<Name> carries the same Asking the user rule as every other command' -ForEach $asking {
        $reference | Should -Not -BeNullOrEmpty
        Get-AskSection $Path | Should -BeExactly $reference
    }

    It '<Name> prescribes no table of options' -ForEach $commands {
        Get-Content -LiteralPath $Path -Raw | Should -Not -Match '\|\s*Option\s*\|'
    }
}

Describe 'command references' {
    It '<Name> refers only to commands that exist' -ForEach $commands {
        $text = Get-Content -LiteralPath $Path -Raw
        foreach ($m in [regex]::Matches($text, '__SPECKIT_COMMAND_([A-Z][A-Z0-9_-]*)__')) {
            # Spec Kit maps underscores to dots and lower-cases: COMPANION_SHOW -> speckit.companion.show.
            $name = 'speckit.' + $m.Groups[1].Value.ToLowerInvariant().Replace('_', '.')
            $known | Should -Contain $name -Because "$($m.Value) in $Name must resolve to an installed command"
        }
    }
}
