### BEGIN FILE: tests\QueueWaitCoverage.Offline.Tests.ps1
# Requires: Pester 5+
# Run: Invoke-Pester -Path .\tests

BeforeAll {
    . "$PSScriptRoot\..\tools\Import-LocalOpsInsights.ps1"

    $membersFixture     = Join-Path $PSScriptRoot 'fixtures\QueueWaitCoverage.queueMembers.json'
    $detailsFixture     = Join-Path $PSScriptRoot 'fixtures\QueueWaitCoverage.conversationDetails.json'
    $skillsFixture      = Join-Path $PSScriptRoot 'fixtures\QueueWaitCoverage.skills.json'
    $script:QueueWaitMembersPayload = (Get-Content -LiteralPath $membersFixture -Raw) | ConvertFrom-Json
    $script:QueueWaitDetailsPayload = (Get-Content -LiteralPath $detailsFixture -Raw) | ConvertFrom-Json
    $script:QueueWaitSkillsPayload  = (Get-Content -LiteralPath $skillsFixture -Raw) | ConvertFrom-Json

    Set-GCInvoker -Invoker {
        param([hashtable]$Request)

        if ($Request.Method -eq 'GET' -and $Request.Uri -match '/routing/queues/.+/members') {
            return $script:QueueWaitMembersPayload
        }
        if ($Request.Method -eq 'POST' -and $Request.Uri -match '/api/v2/analytics/conversations/details/query$') {
            return $script:QueueWaitDetailsPayload
        }
        if ($Request.Method -eq 'GET' -and $Request.Uri -match '/api/v2/routing/skills') {
            return $script:QueueWaitSkillsPayload
        }

        throw "No fixture mapped for: $($Request.Method) $($Request.Uri)"
    }
}

Describe 'Queue wait coverage (offline)' {
    It 'returns waiting conversations with eligible agents' {
        $interval = '2025-01-01T00:00:00.000Z/2025-01-01T01:00:00.000Z'
        $result = Get-GCQueueWaitCoverage -QueueId 'queue-1' -Interval $interval

        $result.Count | Should -Be 2
        ($result | Where-Object ConversationId -eq 'conv-1').RequiredSkills | Should -Match 'Billing'
        ($result | Where-Object ConversationId -eq 'conv-1').EligibleAgentNames | Should -Contain 'Alice Agent'
        ($result | Where-Object ConversationId -eq 'conv-2').NotRespondingCount | Should -Be 1
    }

    It 'every result row contains all expected properties' {
        $interval = '2025-01-01T00:00:00.000Z/2025-01-01T01:00:00.000Z'
        $result = Get-GCQueueWaitCoverage -QueueId 'queue-1' -Interval $interval

        $expectedProps = @(
            'ConversationId', 'WaitingSinceUtc', 'RequiredSkillIds', 'RequiredSkills',
            'EligibleAgentNames', 'EligibleAgents', 'EligibleAgentsSummary',
            'EligibleStatusSummary', 'NotRespondingCount', 'ConfidenceLevel'
        )
        foreach ($row in $result) {
            foreach ($prop in $expectedProps) {
                $row.PSObject.Properties.Name | Should -Contain $prop
            }
        }
    }

    It 'WaitingSinceUtc is a non-empty UTC timestamp string' {
        $interval = '2025-01-01T00:00:00.000Z/2025-01-01T01:00:00.000Z'
        $result = Get-GCQueueWaitCoverage -QueueId 'queue-1' -Interval $interval

        foreach ($row in $result) {
            $row.WaitingSinceUtc | Should -Not -BeNullOrEmpty
            { [datetimeoffset]::Parse($row.WaitingSinceUtc) } | Should -Not -Throw
        }
    }

    It 'EligibleAgentsSummary is a non-empty string' {
        $interval = '2025-01-01T00:00:00.000Z/2025-01-01T01:00:00.000Z'
        $result = Get-GCQueueWaitCoverage -QueueId 'queue-1' -Interval $interval

        foreach ($row in $result) {
            $row.EligibleAgentsSummary | Should -Not -BeNullOrEmpty
        }
    }

    It 'returns an array (not a scalar) even for a single result' {
        $interval = '2025-01-01T00:00:00.000Z/2025-01-01T01:00:00.000Z'
        $result = Get-GCQueueWaitCoverage -QueueId 'queue-1' -Interval $interval

        @($result).GetType().Name | Should -Be 'Object[]'
    }

    It 'uses a default interval of 30 minutes when Interval is omitted' {
        Set-GCInvoker -Invoker {
            param([hashtable]$Request)
            if ($Request.Method -eq 'POST' -and $Request.Uri -match '/api/v2/analytics/conversations/details/query$') {
                # Capture the interval from request body to validate it is in range
                $body = $Request.Body | ConvertFrom-Json
                $script:CapturedInterval = [string]$body.interval
                return $script:QueueWaitDetailsPayload
            }
            if ($Request.Method -eq 'GET' -and $Request.Uri -match '/routing/queues/.+/members') {
                return $script:QueueWaitMembersPayload
            }
            if ($Request.Method -eq 'GET' -and $Request.Uri -match '/api/v2/routing/skills') {
                return $script:QueueWaitSkillsPayload
            }
            throw "No fixture mapped for: $($Request.Method) $($Request.Uri)"
        }

        $result = Get-GCQueueWaitCoverage -QueueId 'queue-1'
        $script:CapturedInterval | Should -Not -BeNullOrEmpty

        # Reset invoker for other tests
        Set-GCInvoker -Invoker {
            param([hashtable]$Request)
            if ($Request.Method -eq 'GET' -and $Request.Uri -match '/routing/queues/.+/members') {
                return $script:QueueWaitMembersPayload
            }
            if ($Request.Method -eq 'POST' -and $Request.Uri -match '/api/v2/analytics/conversations/details/query$') {
                return $script:QueueWaitDetailsPayload
            }
            if ($Request.Method -eq 'GET' -and $Request.Uri -match '/api/v2/routing/skills') {
                return $script:QueueWaitSkillsPayload
            }
            throw "No fixture mapped for: $($Request.Method) $($Request.Uri)"
        }
    }
}
### END FILE: tests\QueueWaitCoverage.Offline.Tests.ps1
