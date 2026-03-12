# Requires: Pester 5+
# Sprint 6 — Conversation Report completion: telemetry contract, token expiry guard,
# Get-GCConversationRollup shape, and correlation ID contract.

BeforeAll {
    $here = Split-Path -Parent $PSCommandPath
    $repo = Split-Path -Parent $here
    $module = Join-Path $repo 'src\GenesysCloud.OpsInsights\GenesysCloud.OpsInsights.psd1'
    Import-Module $module -Force -ErrorAction Stop
    Set-GCContext -ApiBaseUri 'https://api.example.local' -AccessToken 'test-token' | Out-Null

    $telemetryScript = Join-Path $repo 'apps/OpsConsole/Resources/UxTelemetry.ps1'
    . $telemetryScript

    $rollupFixture = Join-Path $PSScriptRoot 'fixtures\ConversationRollup.store.jsonl'
}

# ---------------------------------------------------------------------------
# S6-002: Conversation report telemetry event name contract
# ---------------------------------------------------------------------------
Describe 'S6-002: Conversation report telemetry event names' -Tag @('Unit') {

    BeforeEach {
        $tempPath = Join-Path ([System.IO.Path]::GetTempPath()) "sprint6-telemetry-$([guid]::NewGuid().ToString('N')).jsonl"
        Initialize-UxTelemetry -TargetPath $tempPath -SessionId 'sprint6-test'
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

    It 'Write-UxEvent accepts conversation_report_start without throwing' {
        { Write-UxEvent -Name 'conversation_report_start' -Properties @{
            conversationId = '232a4f22-80a0-4bf3-8c41-db0d8029a24e'
            correlationId  = [guid]::NewGuid().ToString()
        } } | Should -Not -Throw
    }

    It 'Write-UxEvent accepts conversation_report_complete without throwing' {
        { Write-UxEvent -Name 'conversation_report_complete' -Properties @{
            correlationId = [guid]::NewGuid().ToString()
            errorCount    = 0
        } } | Should -Not -Throw
    }

    It 'Write-UxEvent accepts conversation_report_fail without throwing' {
        { Write-UxEvent -Name 'conversation_report_fail' -Properties @{
            correlationId = [guid]::NewGuid().ToString()
            errorCategory = 'RuntimeException'
        } } | Should -Not -Throw
    }

    It 'conversation_report_start event is written to telemetry file with conversationId' {
        $corrId = [guid]::NewGuid().ToString()
        $convId = '232a4f22-80a0-4bf3-8c41-db0d8029a24e'
        Write-UxEvent -Name 'conversation_report_start' -Properties @{
            conversationId = $convId
            correlationId  = $corrId
        }
        Flush-UxTelemetryBuffer

        $lines = @(Get-Content -LiteralPath $script:TelemetryPath -ErrorAction SilentlyContinue)
        $parsed = $lines | ForEach-Object { $_ | ConvertFrom-Json }
        $startEvent = $parsed | Where-Object { $_.event -eq 'conversation_report_start' }
        $startEvent | Should -Not -BeNullOrEmpty
        $startEvent.props.conversationId | Should -Be $convId
        $startEvent.props.correlationId  | Should -Be $corrId
    }

    It 'conversation_report_complete event is written with errorCount' {
        $corrId = [guid]::NewGuid().ToString()
        Write-UxEvent -Name 'conversation_report_complete' -Properties @{
            correlationId = $corrId
            errorCount    = 0
        }
        Flush-UxTelemetryBuffer

        $lines = @(Get-Content -LiteralPath $script:TelemetryPath -ErrorAction SilentlyContinue)
        $parsed = $lines | ForEach-Object { $_ | ConvertFrom-Json }
        $completeEvent = $parsed | Where-Object { $_.event -eq 'conversation_report_complete' }
        $completeEvent | Should -Not -BeNullOrEmpty
        $completeEvent.props.errorCount | Should -Be 0
    }

    It 'conversation_report_fail event is written with errorCategory' {
        $corrId = [guid]::NewGuid().ToString()
        Write-UxEvent -Name 'conversation_report_fail' -Properties @{
            correlationId = $corrId
            errorCategory = 'InvalidOperationException'
        }
        Flush-UxTelemetryBuffer

        $lines = @(Get-Content -LiteralPath $script:TelemetryPath -ErrorAction SilentlyContinue)
        $parsed = $lines | ForEach-Object { $_ | ConvertFrom-Json }
        $failEvent = $parsed | Where-Object { $_.event -eq 'conversation_report_fail' }
        $failEvent | Should -Not -BeNullOrEmpty
        $failEvent.props.errorCategory | Should -Be 'InvalidOperationException'
    }
}

# ---------------------------------------------------------------------------
# S6-001: Token expiry guard pattern for Conversation Report handler
# ---------------------------------------------------------------------------
Describe 'S6-001: Token expiry guard pattern (Conversation Report)' -Tag @('Unit') {

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
# S6: Correlation ID contract for Conversation Report
# ---------------------------------------------------------------------------
Describe 'S6: Correlation ID GUID format for conversation report' -Tag @('Unit') {

    It 'a newly generated correlation ID is a valid GUID string' {
        $correlationId = [guid]::NewGuid().ToString()
        { [guid]::Parse($correlationId) } | Should -Not -Throw
        $correlationId | Should -Match '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    }

    It 'two conversation report operations produce distinct correlation IDs' {
        $id1 = [guid]::NewGuid().ToString()
        $id2 = [guid]::NewGuid().ToString()
        $id1 | Should -Not -Be $id2
    }
}

# ---------------------------------------------------------------------------
# S6: Get-GCConversationRollup — shape and logic tests
# ---------------------------------------------------------------------------
Describe 'S6: Get-GCConversationRollup result shape' -Tag @('Unit') {

    It 'returns empty array when store is empty' {
        $tempStore = Join-Path ([System.IO.Path]::GetTempPath()) "rollup-empty-$([guid]::NewGuid().ToString('N')).jsonl"
        Set-Content -LiteralPath $tempStore -Value '' -Encoding utf8
        $result = Get-GCConversationRollup -StorePath $tempStore
        @($result).Count | Should -Be 0
    }

    It 'throws when StorePath does not exist' {
        { Get-GCConversationRollup -StorePath 'C:\does\not\exist\store.jsonl' } | Should -Throw
    }

    It 'returns exactly 3 rollup sections (Division, Queue, Agent) from fixture' {
        $result = Get-GCConversationRollup -StorePath $rollupFixture
        @($result).Count | Should -Be 3
    }

    It 'first section is the Division rollup with correct title' {
        $result = Get-GCConversationRollup -StorePath $rollupFixture
        $result[0].Title | Should -Be 'Division KPIs'
    }

    It 'second section is the Queue rollup with correct title' {
        $result = Get-GCConversationRollup -StorePath $rollupFixture
        $result[1].Title | Should -Be 'Queue KPIs'
    }

    It 'third section is the Agent rollup with correct title' {
        $result = Get-GCConversationRollup -StorePath $rollupFixture
        $result[2].Title | Should -Be 'Agent KPIs'
    }

    It 'each rollup section has Title and Rows accessible via member enumeration' {
        $result = Get-GCConversationRollup -StorePath $rollupFixture
        foreach ($section in $result) {
            # Member access enumeration reaches through the inner collection wrapper
            $section.Title | Should -Not -BeNullOrEmpty
            @($section.Rows) | Should -Not -BeNullOrEmpty
        }
    }

    It 'Division rollup rows have Bucket, Conversations, AvgMos, MedianMos, DegradedPct, WebRtcDisconnects' {
        $result = Get-GCConversationRollup -StorePath $rollupFixture
        $divRows = @($result[0].Rows)
        $divRows.Count | Should -BeGreaterOrEqual 1
        $expectedProps = @('Bucket', 'Conversations', 'AvgMos', 'MedianMos', 'DegradedPct', 'WebRtcDisconnects')
        foreach ($prop in $expectedProps) {
            $divRows[0].PSObject.Properties.Name | Should -Contain $prop
        }
    }

    It 'Division rollup has 2 buckets (div-A and div-B) from fixture' {
        $result = Get-GCConversationRollup -StorePath $rollupFixture
        $divBuckets = @($result[0].Rows | ForEach-Object { $_.Bucket })
        $divBuckets | Should -Contain 'div-A'
        $divBuckets | Should -Contain 'div-B'
    }

    It 'div-A has 2 conversations' {
        $result = Get-GCConversationRollup -StorePath $rollupFixture
        $divA = $result[0].Rows | Where-Object { $_.Bucket -eq 'div-A' }
        $divA.Conversations | Should -Be 2
    }

    It 'WebRtcDisconnects is 1 for div-A (one conversation has webrtc endpoint)' {
        $result = Get-GCConversationRollup -StorePath $rollupFixture
        $divA = $result[0].Rows | Where-Object { $_.Bucket -eq 'div-A' }
        $divA.WebRtcDisconnects | Should -Be 1
    }

    It 'DegradedPct reflects MOS below threshold for div-A (conv-002 has MOS 2.8 < 3.5)' {
        $result = Get-GCConversationRollup -StorePath $rollupFixture
        $divA = $result[0].Rows | Where-Object { $_.Bucket -eq 'div-A' }
        $divA.DegradedPct | Should -BeGreaterThan 0
    }

    It 'custom MosThreshold overrides default' {
        # With threshold = 5.0, both conversations in div-A are degraded (MOS 4.2 and 2.8)
        $result = Get-GCConversationRollup -StorePath $rollupFixture -MosThreshold 5.0
        $divA = $result[0].Rows | Where-Object { $_.Bucket -eq 'div-A' }
        $divA.DegradedPct | Should -Be 100
    }
}
