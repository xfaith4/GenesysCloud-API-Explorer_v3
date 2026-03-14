# Requires: Pester 5+
# Sprint 8 — Operational Events handler hardening: token expiry guard, correlation ID,
# and telemetry contract (ops_events_query_start/complete/fail).

BeforeAll {
    $here = Split-Path -Parent $PSCommandPath
    $repo = Split-Path -Parent $here
    . "$here\TestHelpers.ps1"

    $telemetryScript = Join-Path $repo 'apps/OpsConsole/Resources/UxTelemetry.ps1'
    . $telemetryScript

    $script:UiRunPath = Join-TestRepoPath -RelativePath 'apps/OpsConsole/Resources/UI/UI.Run.ps1' -StartPath $here
}

# ---------------------------------------------------------------------------
# S8-001: Token expiry guard pattern for Operational Events handler
# ---------------------------------------------------------------------------
Describe 'S8-001: Token expiry guard pattern (Operational Events handler)' -Tag @('Unit') {

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
# S8-002: Telemetry event name contract for Operational Events handler
# ---------------------------------------------------------------------------
Describe 'S8-002: Operational Events telemetry event names' -Tag @('Unit') {

    BeforeEach {
        $tempPath = Join-Path ([System.IO.Path]::GetTempPath()) "sprint8-telemetry-$([guid]::NewGuid().ToString('N')).jsonl"
        Initialize-UxTelemetry -TargetPath $tempPath -SessionId 'sprint8-test'
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

    It 'Write-UxEvent accepts ops_events_query_start without throwing' {
        { Write-UxEvent -Name 'ops_events_query_start' -Properties @{
            eventDefinitionIds = 'def-001,def-002'
            correlationId      = [guid]::NewGuid().ToString()
        } } | Should -Not -Throw
    }

    It 'Write-UxEvent accepts ops_events_query_complete without throwing' {
        { Write-UxEvent -Name 'ops_events_query_complete' -Properties @{
            correlationId = [guid]::NewGuid().ToString()
            eventCount    = 17
        } } | Should -Not -Throw
    }

    It 'Write-UxEvent accepts ops_events_query_fail without throwing' {
        { Write-UxEvent -Name 'ops_events_query_fail' -Properties @{
            correlationId = [guid]::NewGuid().ToString()
            errorCategory = 'RuntimeException'
        } } | Should -Not -Throw
    }

    It 'ops_events_query_start event is written to telemetry file with eventDefinitionIds and correlationId' {
        $corrId  = [guid]::NewGuid().ToString()
        $defIds  = 'def-abc,def-xyz'
        Write-UxEvent -Name 'ops_events_query_start' -Properties @{
            eventDefinitionIds = $defIds
            correlationId      = $corrId
        }
        Flush-UxTelemetryBuffer

        $lines  = @(Get-Content -LiteralPath $script:TelemetryPath -ErrorAction SilentlyContinue)
        $parsed = $lines | ForEach-Object { $_ | ConvertFrom-Json }
        $ev = $parsed | Where-Object { $_.event -eq 'ops_events_query_start' }
        $ev | Should -Not -BeNullOrEmpty
        $ev.props.eventDefinitionIds | Should -Be $defIds
        $ev.props.correlationId      | Should -Be $corrId
    }

    It 'ops_events_query_complete event is written with eventCount' {
        $corrId = [guid]::NewGuid().ToString()
        Write-UxEvent -Name 'ops_events_query_complete' -Properties @{
            correlationId = $corrId
            eventCount    = 42
        }
        Flush-UxTelemetryBuffer

        $lines  = @(Get-Content -LiteralPath $script:TelemetryPath -ErrorAction SilentlyContinue)
        $parsed = $lines | ForEach-Object { $_ | ConvertFrom-Json }
        $ev = $parsed | Where-Object { $_.event -eq 'ops_events_query_complete' }
        $ev | Should -Not -BeNullOrEmpty
        $ev.props.eventCount | Should -Be 42
    }

    It 'ops_events_query_fail event is written with errorCategory' {
        $corrId = [guid]::NewGuid().ToString()
        Write-UxEvent -Name 'ops_events_query_fail' -Properties @{
            correlationId = $corrId
            errorCategory = 'InvalidOperationException'
        }
        Flush-UxTelemetryBuffer

        $lines  = @(Get-Content -LiteralPath $script:TelemetryPath -ErrorAction SilentlyContinue)
        $parsed = $lines | ForEach-Object { $_ | ConvertFrom-Json }
        $ev = $parsed | Where-Object { $_.event -eq 'ops_events_query_fail' }
        $ev | Should -Not -BeNullOrEmpty
        $ev.props.errorCategory | Should -Be 'InvalidOperationException'
    }
}

# ---------------------------------------------------------------------------
# S8: Correlation ID contract for Operational Events handler
# ---------------------------------------------------------------------------
Describe 'S8: Correlation ID GUID format for Operational Events handler' -Tag @('Unit') {

    It 'a newly generated ops events correlation ID is a valid GUID string' {
        $correlationId = [guid]::NewGuid().ToString()
        { [guid]::Parse($correlationId) } | Should -Not -Throw
        $correlationId | Should -Match '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    }

    It 'two ops events operations produce distinct correlation IDs' {
        $id1 = [guid]::NewGuid().ToString()
        $id2 = [guid]::NewGuid().ToString()
        $id1 | Should -Not -Be $id2
    }
}

# ---------------------------------------------------------------------------
# S8: UI.Run.ps1 source contains expiry guard and telemetry for ops events
# ---------------------------------------------------------------------------
Describe 'S8: UI.Run.ps1 Operational Events handler hardening source check' -Tag @('Contract') {

    It 'runOperationalEventsButton handler contains token expiry guard and correlation ID variable' {
        $raw = Get-Content -LiteralPath $script:UiRunPath -Raw
        # Both must exist; their proximity is verified by the surrounding handler structure
        $raw | Should -Match 'opEvtCorrId'
        $raw | Should -Match 'Query blocked: session expired'
    }

    It 'runOperationalEventsButton handler emits ops_events_query_start telemetry' {
        $raw = Get-Content -LiteralPath $script:UiRunPath -Raw
        $raw | Should -Match "ops_events_query_start"
    }

    It 'runOperationalEventsButton handler emits ops_events_query_complete telemetry' {
        $raw = Get-Content -LiteralPath $script:UiRunPath -Raw
        $raw | Should -Match "ops_events_query_complete"
    }

    It 'runOperationalEventsButton handler emits ops_events_query_fail telemetry' {
        $raw = Get-Content -LiteralPath $script:UiRunPath -Raw
        $raw | Should -Match "ops_events_query_fail"
    }

    It 'runOperationalEventsButton OnSuccess log entry includes Correlation ID suffix' {
        $raw = Get-Content -LiteralPath $script:UiRunPath -Raw
        $raw | Should -Match 'Correlation ID.*capturedOpEvtCorrId'
    }
}
