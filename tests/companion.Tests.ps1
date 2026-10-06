#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5' }

BeforeAll {
    $scripts = Join-Path $PSScriptRoot '../extensions/companion/scripts/powershell'
    $start = Join-Path $scripts 'start-companion.ps1'
    $stop = Join-Path $scripts 'stop-companion.ps1'

    $root = Join-Path ([IO.Path]::GetTempPath()) "companion-test-$([Guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path (Join-Path $root '.specify') -Force | Out-Null

    # Captured the way an agent's shell tool captures it. Before the fix the server inherited the
    # caller's stdout pipe and this never returned; the job's timeout turns that hang into a failure.
    $job = Start-Job -ScriptBlock {
        param($Root, $Start)
        Set-Location $Root
        # Upstream drops its remote logo when any of these is set; clear them so the test sees what a
        # default environment gets.
        foreach ($name in 'SUPERPOWERS_DISABLE_TELEMETRY', 'DISABLE_TELEMETRY', 'CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC') {
            Remove-Item "Env:$name" -ErrorAction SilentlyContinue
        }
        pwsh -NoProfile -File $Start
    } -ArgumentList $root, $start
    $null = Wait-Job $job -Timeout 30
    $captured = if ($job.State -eq 'Completed') { (Receive-Job $job) -join "`n" } else { $null }
    Remove-Job $job -Force
    $server = if ($captured) { $captured | ConvertFrom-Json } else { $null }
}

AfterAll {
    # Every session, including one whose launcher hung before reporting where it was.
    foreach ($session in Get-ChildItem -Path (Join-Path $root '.specify/companion') -Directory -ErrorAction SilentlyContinue) {
        & pwsh -NoProfile -File $stop -SessionDir $session.FullName | Out-Null
    }
    Remove-Item -Recurse -Force -LiteralPath $root -ErrorAction SilentlyContinue
}

Describe 'visual companion' {
    It 'returns its connection JSON when the caller captures its output' {
        $captured | Should -Not -BeNullOrEmpty -Because 'the launcher must not hold the caller''s output pipe open'
        $server.type | Should -Be 'server-started'
    }

    It 'serves the newest screen to a client with the key, and nothing without it' {
        Set-Content -LiteralPath (Join-Path $server.screen_dir 'choice.html') -Value '<h2>Pick one</h2>'
        $null = Invoke-WebRequest $server.url -SessionVariable web
        (Invoke-WebRequest "http://localhost:$($server.port)/" -WebSession $web).Content | Should -Match 'Pick one'
        (Invoke-WebRequest "http://localhost:$($server.port)/" -SkipHttpErrorCheck).StatusCode | Should -Be 403
    }

    It 'serves pages that load nothing from outside the local server' {
        $null = Invoke-WebRequest $server.url -SessionVariable web
        $page = (Invoke-WebRequest "http://localhost:$($server.port)/" -WebSession $web).Content
        # Anything the browser fetches on load: src attributes, stylesheet links, CSS url() and @import.
        $loads = '\bsrc\s*=\s*["'']?(https?:)?//|<link\b[^>]*\bhref\s*=\s*["'']?(https?:)?//|url\(\s*["'']?(https?:)?//|@import\s+["'']?(url\()?\s*["'']?(https?:)?//'
        [regex]::Matches($page, $loads).Value | Should -BeNullOrEmpty
        $page | Should -Not -Match 'primeradiant'
    }

    It 'keeps its session files out of git' {
        Get-Content -LiteralPath (Join-Path $root '.specify/companion/.gitignore') -Raw | Should -Be '*'
    }

    It 'refuses to stop a process that is not this session''s server' {
        $session = Join-Path $root '.specify/companion/stale'
        New-Item -ItemType Directory -Path (Join-Path $session 'state') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $session 'state/server.pid') -Value $PID
        Set-Content -LiteralPath (Join-Path $session 'state/server-instance-id') -Value ('a' * 48)
        (& pwsh -NoProfile -File $stop -SessionDir $session | ConvertFrom-Json).status | Should -Be 'stale_pid'
        Get-Process -Id $PID | Should -Not -BeNullOrEmpty
    }
}
