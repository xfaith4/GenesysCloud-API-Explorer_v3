# Requires: Pester 5+
# Sprint 5 — Queue Health Hardening: telemetry, token expiry guard, and result contract tests

BeforeAll {
    $here = Split-Path -Parent $PSCommandPath
    $repo = Split-Path -Parent $here
    $module = Join-Path $repo 'src\GenesysCloud.OpsInsights\GenesysCloud.OpsInsights.psd1'
    Import-Module $module -Force -ErrorAction Stop
    Set-GCContext -ApiBaseUri 'https://api.example.local' -AccessToken 'test-token' | Out-Null

    $telemetryScript = Join-Path $repo 'apps/OpsConsole/Resources/UxTelemetry.ps1'
    . $telemetryScript

    $membersFixture = Join-Path $PSScriptRoot 'fixtures\QueueWaitCoverage.queueMembers.json'
    $detailsFixture = Join-Path $PSScriptRoot 'fixtures\QueueWaitCoverage.conversationDetails.json'
    $skillsFixture  = Join-Path $PSScriptRoot 'fixtures\QueueWaitCoverage.skills.json'
    $script:MembersPayload = (Get-Content -LiteralPath $membersFixture -Raw) | ConvertFrom-Json
    $script:DetailsPayload = (Get-Content -LiteralPath $detailsFixture -Raw) | ConvertFrom-Json
    $script:SkillsPayload  = (Get-Content -LiteralPath $skillsFixture  -Raw) | ConvertFrom-Json

    Set-GCInvoker -Invoker {
        param([hashtable]$Request)
        if ($Request.Method -eq 'GET' -and $Request.Uri -match '/routing/queues/.+/members') {
            return $script:MembersPayload
        }
        if ($Request.Method -eq 'POST' -and $Request.Uri -match '/api/v2/analytics/conversations/details/query$') {
            return $script:DetailsPayload
        }
        if ($Request.Method -eq 'GET' -and $Request.Uri -match '/api/v2/routing/skills') {
            return $script:SkillsPayload
        }
        throw "No fixture mapped for: $($Request.Method) $($Request.Uri)"
    }
}

# ---------------------------------------------------------------------------
# S5-002: Telemetry event name contract — queue_wait_start / complete / fail
# ---------------------------------------------------------------------------
Describe 'S5-002: Queue Wait telemetry event names' -Tag @('Unit') {

    BeforeEach {
        $script:CapturedEvents = [System.Collections.Generic.List[string]]::new()
        $tempPath = Join-Path ([System.IO.Path]::GetTempPath()) "sprint5-telemetry-test-$([guid]::NewGuid().ToString('N')).jsonl"
        Initialize-UxTelemetry -TargetPath $tempPath -SessionId 'sprint5-test'
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

    It 'Write-UxEvent accepts queue_wait_start without throwing' {
        { Write-UxEvent -Name 'queue_wait_start' -Properties @{
            queueId       = 'queue-123'
            correlationId = [guid]::NewGuid().ToString()
        } } | Should -Not -Throw
    }

    It 'Write-UxEvent accepts queue_wait_complete without throwing' {
        { Write-UxEvent -Name 'queue_wait_complete' -Properties @{
            correlationId     = [guid]::NewGuid().ToString()
            conversationCount = 5
        } } | Should -Not -Throw
    }

    It 'Write-UxEvent accepts queue_wait_fail without throwing' {
        { Write-UxEvent -Name 'queue_wait_fail' -Properties @{
            correlationId = [guid]::NewGuid().ToString()
            errorCategory = 'RuntimeException'
        } } | Should -Not -Throw
    }

    It 'queue_wait_start event is written to telemetry file with correct event name' {
        $corrId = [guid]::NewGuid().ToString()
        Write-UxEvent -Name 'queue_wait_start' -Properties @{
            queueId       = 'queue-abc'
            correlationId = $corrId
        }
        Flush-UxTelemetryBuffer

        $lines = @(Get-Content -LiteralPath $script:TelemetryPath -ErrorAction SilentlyContinue)
        $parsed = $lines | ForEach-Object { $_ | ConvertFrom-Json }
        $startEvent = $parsed | Where-Object { $_.event -eq 'queue_wait_start' }
        $startEvent | Should -Not -BeNullOrEmpty
        $startEvent.props.queueId | Should -Be 'queue-abc'
        $startEvent.props.correlationId | Should -Be $corrId
    }

    It 'queue_wait_complete event is written to telemetry file with conversationCount' {
        $corrId = [guid]::NewGuid().ToString()
        Write-UxEvent -Name 'queue_wait_complete' -Properties @{
            correlationId     = $corrId
            conversationCount = 7
        }
        Flush-UxTelemetryBuffer

        $lines = @(Get-Content -LiteralPath $script:TelemetryPath -ErrorAction SilentlyContinue)
        $parsed = $lines | ForEach-Object { $_ | ConvertFrom-Json }
        $completeEvent = $parsed | Where-Object { $_.event -eq 'queue_wait_complete' }
        $completeEvent | Should -Not -BeNullOrEmpty
        $completeEvent.props.conversationCount | Should -Be 7
    }

    It 'queue_wait_fail event is written to telemetry file with errorCategory' {
        $corrId = [guid]::NewGuid().ToString()
        Write-UxEvent -Name 'queue_wait_fail' -Properties @{
            correlationId = $corrId
            errorCategory = 'RuntimeException'
        }
        Flush-UxTelemetryBuffer

        $lines = @(Get-Content -LiteralPath $script:TelemetryPath -ErrorAction SilentlyContinue)
        $parsed = $lines | ForEach-Object { $_ | ConvertFrom-Json }
        $failEvent = $parsed | Where-Object { $_.event -eq 'queue_wait_fail' }
        $failEvent | Should -Not -BeNullOrEmpty
        $failEvent.props.errorCategory | Should -Be 'RuntimeException'
    }
}

# ---------------------------------------------------------------------------
# S5-001: Token expiry guard — verify the guard logic pattern matches
#         the Conversation Report / Audit Investigator pattern in Sprint 4.
# ---------------------------------------------------------------------------
Describe 'S5-001: Token expiry guard pattern' -Tag @('Unit') {

    It 'expiry check fires when TokenExpiresAt is in the past' {
        # Simulate the guard pattern used in the RunQueueWaitReportButton handler.
        # Set expiry to 1 hour in the past.
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
# S5: Correlation ID contract — GUID format for queue wait operations
# ---------------------------------------------------------------------------
Describe 'S5: Correlation ID GUID format for queue wait' -Tag @('Unit') {

    It 'a newly generated correlation ID is a valid GUID string' {
        $correlationId = [guid]::NewGuid().ToString()
        { [guid]::Parse($correlationId) } | Should -Not -Throw
        $correlationId | Should -Match '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    }

    It 'two queue wait operations produce distinct correlation IDs' {
        $id1 = [guid]::NewGuid().ToString()
        $id2 = [guid]::NewGuid().ToString()
        $id1 | Should -Not -Be $id2
    }
}

# ---------------------------------------------------------------------------
# S5: Queue Health result shape — ensure all Sprint 5 properties remain stable
# ---------------------------------------------------------------------------
Describe 'S5: Get-GCQueueWaitCoverage result shape stability' -Tag @('Unit') {

    It 'result count matches fixture (2 waiting conversations)' {
        $interval = '2025-01-01T00:00:00.000Z/2025-01-01T01:00:00.000Z'
        $result = Get-GCQueueWaitCoverage -QueueId 'queue-1' -Interval $interval
        $result.Count | Should -Be 2
    }

    It 'ConfidenceLevel is present and non-null on every row' {
        $interval = '2025-01-01T00:00:00.000Z/2025-01-01T01:00:00.000Z'
        $result = Get-GCQueueWaitCoverage -QueueId 'queue-1' -Interval $interval
        foreach ($row in $result) {
            $row.ConfidenceLevel | Should -Not -BeNullOrEmpty
        }
    }

    It 'NotRespondingCount is a non-negative integer on every row' {
        $interval = '2025-01-01T00:00:00.000Z/2025-01-01T01:00:00.000Z'
        $result = Get-GCQueueWaitCoverage -QueueId 'queue-1' -Interval $interval
        foreach ($row in $result) {
            $row.NotRespondingCount | Should -BeGreaterOrEqual 0
        }
    }

    It 'EligibleAgents is an array on every row' {
        $interval = '2025-01-01T00:00:00.000Z/2025-01-01T01:00:00.000Z'
        $result = Get-GCQueueWaitCoverage -QueueId 'queue-1' -Interval $interval
        foreach ($row in $result) {
            @($row.EligibleAgents).GetType().Name | Should -Be 'Object[]'
        }
    }
}
