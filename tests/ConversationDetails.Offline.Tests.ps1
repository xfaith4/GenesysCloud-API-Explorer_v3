# Requires: Pester 5+
# Sprint 6 — S6-001: Comprehensive offline tests for Get-GCConversationDetails

BeforeAll {
    . "$PSScriptRoot\..\tools\Import-LocalOpsInsights.ps1"

    $fixturePath = Join-Path $PSScriptRoot 'fixtures\ConversationDetails.sample.json'
    $script:DetailsPayload = (Get-Content -LiteralPath $fixturePath -Raw) | ConvertFrom-Json

    Set-GCInvoker -Invoker {
        param([hashtable]$Request)
        if ($Request.Method -eq 'POST' -and $Request.Uri -match '/api/v2/analytics/conversations/details/query$') {
            return $script:DetailsPayload
        }
        throw "No fixture mapped for: $($Request.Method) $($Request.Uri)"
    }
}

Describe 'Get-GCConversationDetails: result shape' -Tag @('Unit') {

    It 'returns conversations and cursor from fixture' {
        $q = @{
            interval = '2024-02-06T00:00:00.000Z/2024-02-07T00:00:00.000Z'
            order    = 'asc'
            orderBy  = 'conversationStart'
            paging   = @{ pageSize = 10; pageNumber = 1 }
        }
        $resp = Get-GCConversationDetails -Query $q
        $resp.conversations.Count | Should -Be 10
        $resp.cursor | Should -Not -BeNullOrEmpty
    }

    It 'ByInterval parameter set returns conversations and cursor' {
        $resp = Get-GCConversationDetails -Interval '2024-02-06T00:00:00.000Z/2024-02-07T00:00:00.000Z'
        $resp.conversations.Count | Should -Be 10
        $resp.cursor | Should -Not -BeNullOrEmpty
    }

    It 'cursor value matches fixture' {
        $resp = Get-GCConversationDetails -Interval '2024-02-06T00:00:00.000Z/2024-02-07T00:00:00.000Z'
        $resp.cursor | Should -Be 'Y3Vyc29yX3YyMzIxOTA1MjE='
    }
}

Describe 'Get-GCConversationDetails: conversation content' -Tag @('Unit') {

    It 'each conversation has a conversationId' {
        $resp = Get-GCConversationDetails -Interval '2024-02-06T00:00:00.000Z/2024-02-07T00:00:00.000Z'
        foreach ($conv in $resp.conversations) {
            $conv.conversationId | Should -Not -BeNullOrEmpty
        }
    }

    It 'each conversation has conversationStart and conversationEnd' {
        $resp = Get-GCConversationDetails -Interval '2024-02-06T00:00:00.000Z/2024-02-07T00:00:00.000Z'
        foreach ($conv in $resp.conversations) {
            $conv.conversationStart | Should -Not -BeNullOrEmpty
            $conv.conversationEnd   | Should -Not -BeNullOrEmpty
        }
    }

    It 'first conversation ID matches the known fixture value' {
        $resp = Get-GCConversationDetails -Interval '2024-02-06T00:00:00.000Z/2024-02-07T00:00:00.000Z'
        $resp.conversations[0].conversationId | Should -Be '232a4f22-80a0-4bf3-8c41-db0d8029a24e'
    }

    It 'each conversation has at least one participant' {
        $resp = Get-GCConversationDetails -Interval '2024-02-06T00:00:00.000Z/2024-02-07T00:00:00.000Z'
        foreach ($conv in $resp.conversations) {
            @($conv.participants).Count | Should -BeGreaterOrEqual 1
        }
    }

    It 'participants have participantId and purpose' {
        $resp = Get-GCConversationDetails -Interval '2024-02-06T00:00:00.000Z/2024-02-07T00:00:00.000Z'
        foreach ($conv in $resp.conversations) {
            foreach ($p in $conv.participants) {
                $p.participantId | Should -Not -BeNullOrEmpty
                $p.purpose       | Should -Not -BeNullOrEmpty
            }
        }
    }

    It 'first conversation has a customer participant' {
        $resp = Get-GCConversationDetails -Interval '2024-02-06T00:00:00.000Z/2024-02-07T00:00:00.000Z'
        $purposes = @($resp.conversations[0].participants | ForEach-Object { $_.purpose })
        $purposes | Should -Contain 'customer'
    }

    It 'MOS stats are present on the first conversation' {
        $resp = Get-GCConversationDetails -Interval '2024-02-06T00:00:00.000Z/2024-02-07T00:00:00.000Z'
        $conv = $resp.conversations[0]
        $conv.mediaStatsMinConversationMos | Should -Not -BeNullOrEmpty
        [double]$conv.mediaStatsMinConversationMos | Should -BeGreaterThan 0
    }
}

Describe 'Get-GCConversationDetails: guard rails' -Tag @('Unit') {

    It 'accepts a non-empty Query hashtable without error' {
        { Get-GCConversationDetails -Query @{ interval = '2024-02-06T00:00:00.000Z/2024-02-07T00:00:00.000Z' } } | Should -Not -Throw
    }

    It 'throws when Interval is an empty string' {
        { Get-GCConversationDetails -Interval '' } | Should -Throw
    }

    It 'accepts a Cursor parameter without error' {
        { Get-GCConversationDetails -Interval '2024-02-06T00:00:00.000Z/2024-02-07T00:00:00.000Z' -Cursor 'Y3Vyc29yX3YyMzIxOTA1MjE=' } | Should -Not -Throw
    }

    It 'accepts a custom PageSize without error' {
        { Get-GCConversationDetails -Interval '2024-02-06T00:00:00.000Z/2024-02-07T00:00:00.000Z' -PageSize 25 } | Should -Not -Throw
    }
}

Describe 'Get-GCConversationDetails: pagination cursor' -Tag @('Unit') {

    It 'passes cursor to the downstream request body' {
        $script:CapturedCursor = $null

        Set-GCInvoker -Invoker {
            param([hashtable]$Request)
            if ($Request.Method -eq 'POST' -and $Request.Uri -match '/api/v2/analytics/conversations/details/query$') {
                $body = $Request.Body | ConvertFrom-Json
                $script:CapturedCursor = $body.cursor
                return $script:DetailsPayload
            }
            throw "No fixture mapped for: $($Request.Method) $($Request.Uri)"
        }

        Get-GCConversationDetails -Interval '2024-02-06T00:00:00.000Z/2024-02-07T00:00:00.000Z' -Cursor 'test-cursor-value' | Out-Null
        $script:CapturedCursor | Should -Be 'test-cursor-value'

        # Restore default invoker
        Set-GCInvoker -Invoker {
            param([hashtable]$Request)
            if ($Request.Method -eq 'POST' -and $Request.Uri -match '/api/v2/analytics/conversations/details/query$') {
                return $script:DetailsPayload
            }
            throw "No fixture mapped for: $($Request.Method) $($Request.Uri)"
        }
    }

    It 'omits cursor from request when not supplied' {
        $script:CapturedBodyHasCursor = $null

        Set-GCInvoker -Invoker {
            param([hashtable]$Request)
            if ($Request.Method -eq 'POST' -and $Request.Uri -match '/api/v2/analytics/conversations/details/query$') {
                $body = $Request.Body | ConvertFrom-Json
                $script:CapturedBodyHasCursor = ($null -ne $body.cursor)
                return $script:DetailsPayload
            }
            throw "No fixture mapped for: $($Request.Method) $($Request.Uri)"
        }

        Get-GCConversationDetails -Interval '2024-02-06T00:00:00.000Z/2024-02-07T00:00:00.000Z' | Out-Null
        $script:CapturedBodyHasCursor | Should -Be $false

        # Restore default invoker
        Set-GCInvoker -Invoker {
            param([hashtable]$Request)
            if ($Request.Method -eq 'POST' -and $Request.Uri -match '/api/v2/analytics/conversations/details/query$') {
                return $script:DetailsPayload
            }
            throw "No fixture mapped for: $($Request.Method) $($Request.Uri)"
        }
    }
}
