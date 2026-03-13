# Requires: Pester 5+
# Sprint 7 — Ops ingest hardening: token expiry guard, telemetry contract,
# ExportRedactedKpiButton XAML presence, and correlation ID contract.

BeforeAll {
    $here = Split-Path -Parent $PSCommandPath
    $repo = Split-Path -Parent $here
    . "$here\TestHelpers.ps1"

    $telemetryScript = Join-Path $repo 'apps/OpsConsole/Resources/UxTelemetry.ps1'
    . $telemetryScript

    $script:XamlPath    = Join-TestRepoPath -RelativePath 'apps/OpsConsole/Resources/UI/MainWindow.xaml' -StartPath $here
    $script:UiRunPath   = Join-TestRepoPath -RelativePath 'apps/OpsConsole/Resources/UI/UI.Run.ps1'      -StartPath $here
    $script:XamlTargets = Get-XamlNamedTargets -XamlPath $script:XamlPath
}

# ---------------------------------------------------------------------------
# S7-XAML: ExportRedactedKpiButton is now a first-class XAML element
# ---------------------------------------------------------------------------
Describe 'S7-XAML: ExportRedactedKpiButton is present in MainWindow.xaml' -Tag @('UI', 'Contract') {

    It 'ExportRedactedKpiButton element exists in MainWindow.xaml' {
        $script:XamlTargets | Should -Contain 'ExportRedactedKpiButton'
    }

    It 'ExportRedactedKpiButton is no longer listed as an optional FindName target in UI contracts' {
        $raw = Get-Content -LiteralPath (Join-TestRepoPath -RelativePath 'tests/OpsConsole.UiContracts.Tests.ps1' -StartPath $here) -Raw
        # The button should NOT appear inside an optionalTargets array in the contracts test
        $raw | Should -Not -Match "optionalTargets.*ExportRedactedKpiButton"
    }
}

# ---------------------------------------------------------------------------
# S7-001: Token expiry guard pattern for Ops Dashboard export handlers
# ---------------------------------------------------------------------------
Describe 'S7-001: Token expiry guard pattern (Ops Dashboard exports)' -Tag @('Unit') {

    It 'expiry check fires when TokenExpiresAt is in the past' {
        $script:TokenExpiresAt = (Get-Date).AddHours(-1)
        $blocked = $false

        if ($script:TokenExpiresAt -and (Get-Date) -gt $script:TokenExpiresAt) {
            $blocked = $true
        }

        $blocked | Should -Be $true
    }

    It 'expiry check does not fire when TokenExpiresAt is in the future' {
        $script:TokenExpiresAt = (Get-Date).AddHours(22)
        $blocked = $false

        if ($script:TokenExpiresAt -and (Get-Date) -gt $script:TokenExpiresAt) {
            $blocked = $true
        }

        $blocked | Should -Be $false
    }

    It 'expiry check does not fire when TokenExpiresAt is null' {
        $script:TokenExpiresAt = $null
        $blocked = $false

        if ($script:TokenExpiresAt -and (Get-Date) -gt $script:TokenExpiresAt) {
            $blocked = $true
        }

        $blocked | Should -Be $false
    }
}

# ---------------------------------------------------------------------------
# S7-002: Telemetry event name contract for Ops Conversation Ingest
# ---------------------------------------------------------------------------
Describe 'S7-002: Ops ingest telemetry event names' -Tag @('Unit') {

    BeforeEach {
        $tempPath = Join-Path ([System.IO.Path]::GetTempPath()) "sprint7-telemetry-$([guid]::NewGuid().ToString('N')).jsonl"
        Initialize-UxTelemetry -TargetPath $tempPath -SessionId 'sprint7-test'
        $script:TelemetryPath = $tempPath
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

    It 'Write-UxEvent accepts ops_ingest_start without throwing' {
        { Write-UxEvent -Name 'ops_ingest_start' -Properties @{
            interval      = 'Last24Hours'
            correlationId = [guid]::NewGuid().ToString()
        } } | Should -Not -Throw
    }

    It 'Write-UxEvent accepts ops_ingest_complete without throwing' {
        { Write-UxEvent -Name 'ops_ingest_complete' -Properties @{
            correlationId  = [guid]::NewGuid().ToString()
            recordsWritten = 42
        } } | Should -Not -Throw
    }

    It 'Write-UxEvent accepts ops_ingest_fail without throwing' {
        { Write-UxEvent -Name 'ops_ingest_fail' -Properties @{
            correlationId = [guid]::NewGuid().ToString()
            errorCategory = 'RuntimeException'
        } } | Should -Not -Throw
    }

    It 'ops_ingest_start event is written to telemetry file with interval and correlationId' {
        $corrId   = [guid]::NewGuid().ToString()
        $interval = 'Last24Hours'
        Write-UxEvent -Name 'ops_ingest_start' -Properties @{
            interval      = $interval
            correlationId = $corrId
        }
        Flush-UxTelemetryBuffer

        $lines  = @(Get-Content -LiteralPath $script:TelemetryPath -ErrorAction SilentlyContinue)
        $parsed = $lines | ForEach-Object { $_ | ConvertFrom-Json }
        $ev = $parsed | Where-Object { $_.event -eq 'ops_ingest_start' }
        $ev | Should -Not -BeNullOrEmpty
        $ev.props.interval      | Should -Be $interval
        $ev.props.correlationId | Should -Be $corrId
    }

    It 'ops_ingest_complete event is written with recordsWritten' {
        $corrId = [guid]::NewGuid().ToString()
        Write-UxEvent -Name 'ops_ingest_complete' -Properties @{
            correlationId  = $corrId
            recordsWritten = 7
        }
        Flush-UxTelemetryBuffer

        $lines  = @(Get-Content -LiteralPath $script:TelemetryPath -ErrorAction SilentlyContinue)
        $parsed = $lines | ForEach-Object { $_ | ConvertFrom-Json }
        $ev = $parsed | Where-Object { $_.event -eq 'ops_ingest_complete' }
        $ev | Should -Not -BeNullOrEmpty
        $ev.props.recordsWritten | Should -Be 7
    }

    It 'ops_ingest_fail event is written with errorCategory' {
        $corrId = [guid]::NewGuid().ToString()
        Write-UxEvent -Name 'ops_ingest_fail' -Properties @{
            correlationId = $corrId
            errorCategory = 'InvalidOperationException'
        }
        Flush-UxTelemetryBuffer

        $lines  = @(Get-Content -LiteralPath $script:TelemetryPath -ErrorAction SilentlyContinue)
        $parsed = $lines | ForEach-Object { $_ | ConvertFrom-Json }
        $ev = $parsed | Where-Object { $_.event -eq 'ops_ingest_fail' }
        $ev | Should -Not -BeNullOrEmpty
        $ev.props.errorCategory | Should -Be 'InvalidOperationException'
    }
}

# ---------------------------------------------------------------------------
# S7: Correlation ID contract for Ops ingest handler
# ---------------------------------------------------------------------------
Describe 'S7: Correlation ID GUID format for ops ingest' -Tag @('Unit') {

    It 'a newly generated ingest correlation ID is a valid GUID string' {
        $correlationId = [guid]::NewGuid().ToString()
        { [guid]::Parse($correlationId) } | Should -Not -Throw
        $correlationId | Should -Match '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    }

    It 'two ingest operations produce distinct correlation IDs' {
        $id1 = [guid]::NewGuid().ToString()
        $id2 = [guid]::NewGuid().ToString()
        $id1 | Should -Not -Be $id2
    }
}
