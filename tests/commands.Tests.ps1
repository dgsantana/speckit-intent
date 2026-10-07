#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5' }

BeforeDiscovery {
    $repo = Join-Path $PSScriptRoot '..'
    $commands = @(Get-ChildItem -Path (Join-Path $repo 'preset'), (Join-Path $repo 'extensions') -Filter '*.md' -Recurse |
        Where-Object { $_.Directory.Name -eq 'commands' } |
        ForEach-Object { @{ Name = $_.BaseName; Path = $_.FullName } })
    # Commands that ask nothing beyond a yes/no go-ahead. A new command either carries the rule or is listed here.
    $silent = @('speckit.feature-id.allocate', 'speckit.converge', 'speckit.analyze')
    $asking = @($commands | Where-Object { $_.Name -notin $silent })
    # Commands that may edit a spec's Outcomes or Constraints after planning.
    $editing = @('speckit.clarify', 'speckit.plan', 'speckit.tasks', 'speckit.intent.verify', 'speckit.companion.show')
    $targetEditors = @($commands | Where-Object { $_.Name -in $editing })
    # Commands that order tasks or judge checks, and so state the red-first rule.
    $ordering = @('speckit.tasks', 'speckit.analyze', 'speckit.converge', 'speckit.intent.verify')
    $redFirst = @($commands | Where-Object { $_.Name -in $ordering })
}

BeforeAll {
    $repo = Join-Path $PSScriptRoot '..'
    function Get-Section([string]$Path, [string]$Heading) {
        $text = (Get-Content -LiteralPath $Path -Raw) -replace "`r`n", "`n"
        $match = [regex]::Match($text, "(?ms)^## $Heading\n.*?(?=^## )")
        if ($match.Success) { $match.Value.Trim() } else { $null }
    }
    function Get-AskSection([string]$Path) { Get-Section $Path 'Asking the user' }
    $reference = Get-AskSection (Join-Path $repo 'preset/commands/speckit.specify.md')
    $targetReference = Get-Section (Join-Path $repo 'preset/commands/speckit.plan.md') 'Changing the target'

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

Describe 'changing the target' {
    It '<Name> carries the same Changing the target rule as every command that may edit the target' -ForEach $targetEditors {
        $targetReference | Should -Not -BeNullOrEmpty
        Get-Section $Path 'Changing the target' | Should -BeExactly $targetReference
    }
}

Describe 'red-first' {
    It '<Name> states the red-first rule in the same words as the others' -ForEach $redFirst {
        $text = (Get-Content -LiteralPath $Path -Raw) -replace '\s+', ' '
        $match = [regex]::Match($text, 'Red-first: .*?would occur\.')
        $match.Success | Should -BeTrue
        $tasks = (Get-Content -LiteralPath (Join-Path $repo 'preset/commands/speckit.tasks.md') -Raw) -replace '\s+', ' '
        $match.Value | Should -BeExactly ([regex]::Match($tasks, 'Red-first: .*?would occur\.').Value)
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
