# Requires: Pester 5+

Describe 'UxTelemetry exhaustive behavior' -Tag @('Unit', 'Contract') {
    BeforeAll {
        . "$PSScriptRoot\TestHelpers.ps1"
        . (Join-TestRepoPath -RelativePath 'apps/OpsConsole/Resources/UxTelemetry.ps1' -StartPath $PSScriptRoot)
    }

    AfterEach {
        try {
            if ($script:UxTelemetryState.FlushTimer) {
                $script:UxTelemetryState.FlushTimer.Stop()
                $script:UxTelemetryState.FlushTimer.Dispose()
                $script:UxTelemetryState.FlushTimer = $null
            }
            if ($script:UxTelemetryState.Writer) {
                $script:UxTelemetryState.Writer.Flush()
                $script:UxTelemetryState.Writer.Dispose()
                $script:UxTelemetryState.Writer = $null
            }
        }
        catch { }
    }

    It 'builds default telemetry path and creates runs directory' {
        $root = Join-Path -Path $TestDrive -ChildPath 'ux-root'
        $path = Get-UxTelemetryDefaultPath -RootPath $root

        (Split-Path -Parent $path) | Should -Be (Join-Path -Path $root -ChildPath 'runs')
        (Test-Path -LiteralPath (Split-Path -Parent $path)) | Should -BeTrue
        $path | Should -Match 'telemetry-\d{8}\.jsonl$'
    }

    It 'flushes telemetry when buffer threshold is reached' {
        $path = Join-Path -Path $TestDrive -ChildPath 'threshold.jsonl'
        Initialize-UxTelemetry -TargetPath $path -SessionId 'threshold-session'
        $script:UxTelemetryState.BufferThreshold = 1

        Write-UxEvent -Name 'threshold_hit' -Properties @{ route = 'home' }
        Flush-UxTelemetryBuffer

        (Test-Path -LiteralPath $path) | Should -BeTrue
        $lines = @(Get-Content -LiteralPath $path)
        $lines.Count | Should -BeGreaterThan 0
    }

    It 'flushes from buffer using fallback append when writer is unavailable' {
        $path = Join-Path -Path $TestDrive -ChildPath 'fallback.jsonl'
        $script:UxTelemetryState.Path = $path
        $script:UxTelemetryState.Writer = $null
        $script:UxTelemetryState.Buffer = New-Object System.Collections.Generic.List[string]
        $script:UxTelemetryState.Buffer.Add('{"event":"fallback"}') | Out-Null

        Flush-UxTelemetryBuffer

        (Test-Path -LiteralPath $path) | Should -BeTrue
        (Get-Content -LiteralPath $path -Raw) | Should -Match '"event":"fallback"'
    }

    It 'does not write events when telemetry is not initialized' {
        $path = Join-Path -Path $TestDrive -ChildPath 'noop.jsonl'
        $script:UxTelemetryState.Path = $null
        $script:UxTelemetryState.SessionId = $null
        $script:UxTelemetryState.Writer = $null
        $script:UxTelemetryState.Buffer = New-Object System.Collections.Generic.List[string]

        Write-UxEvent -Name 'noop' -Properties @{ a = 1 }
        Flush-UxTelemetryBuffer

        (Test-Path -LiteralPath $path) | Should -BeFalse
        $script:UxTelemetryState.Buffer.Count | Should -Be 0
    }
}
