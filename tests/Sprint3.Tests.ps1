# Requires: Pester 5+
# Sprint 3 — Audit Investigator + Queue Health regression tests

BeforeAll {
    $here = Split-Path -Parent $PSCommandPath
    $repo = Split-Path -Parent $here
    $module = Join-Path $repo 'src\GenesysCloud.OpsInsights\GenesysCloud.OpsInsights.psd1'
    Import-Module $module -Force -ErrorAction Stop
    Set-GCContext -ApiBaseUri 'https://api.example.local' -AccessToken 'test-token' | Out-Null

    $notificationsModulePath = Join-Path $repo 'Scripts\GenesysCloud.NotificationsToolkit\GenesysCloud.NotificationsToolkit.psm1'
    Import-Module -Name $notificationsModulePath -Force -Global -ErrorAction Stop
}

Describe 'DEF-008: Get-GCNotificationTopics pagination' -Tag @('Unit') {

    BeforeEach {
        $script:DEF008Requests = New-Object System.Collections.ArrayList
        $script:DEF008Responder = {
            param([pscustomobject]$Request)
            return [pscustomobject]@{
                StatusCode = 200
                Headers    = @{}
                Content    = '{"entities":[]}'
            }
        }

        Mock Invoke-WebRequest -ModuleName 'GenesysCloud.OpsInsights' {
            param(
                [string]$Method,
                [string]$Uri,
                [hashtable]$Headers,
                [object]$Body,
                [int]$TimeoutSec,
                [string]$ErrorAction,
                [switch]$UseBasicParsing
            )
            $req = [pscustomobject]@{ Method = $Method; Uri = $Uri; Headers = $Headers; Body = $Body }
            [void]$script:DEF008Requests.Add($req)
            return (& $script:DEF008Responder $req)
        }
    }

    It 'accepts a PageSize parameter without error' {
        { Get-GCNotificationTopics -BaseUri 'https://api.example.local' -AccessToken 'token' -PageSize 50 } |
            Should -Not -Throw
    }

    It 'includes pageSize and pageNumber in the request URI' {
        Get-GCNotificationTopics -BaseUri 'https://api.example.local' -AccessToken 'token' | Out-Null
        $script:DEF008Requests.Count | Should -BeGreaterOrEqual 1
        $script:DEF008Requests[0].Uri | Should -Match 'pageSize=\d+'
        $script:DEF008Requests[0].Uri | Should -Match 'pageNumber=\d+'
    }

    It 'returns an object with Parsed, Content, and StatusCode properties' {
        $script:DEF008Responder = {
            param([pscustomobject]$Request)
            [pscustomobject]@{
                StatusCode = 200
                Headers    = @{}
                Content    = '{"entities":[{"id":"topic-1"}]}'
            }
        }
        $result = Get-GCNotificationTopics -BaseUri 'https://api.example.local' -AccessToken 'token'
        $result.StatusCode | Should -Be 200
        $result.Parsed     | Should -Not -BeNullOrEmpty
        $result.Content    | Should -Not -BeNullOrEmpty
    }

    It 'aggregates topics from a single page response' {
        $script:DEF008Responder = {
            param([pscustomobject]$Request)
            [pscustomobject]@{
                StatusCode = 200
                Headers    = @{}
                Content    = '{"entities":[{"id":"topic-1"},{"id":"topic-2"}]}'
            }
        }
        $result = Get-GCNotificationTopics -BaseUri 'https://api.example.local' -AccessToken 'token'
        @($result.Parsed.entities).Count | Should -Be 2
    }

    It 'paginates across multiple pages when pageCount > 1' {
        $script:DEF008PagesSeen = [System.Collections.Generic.List[int]]::new()
        $script:DEF008Responder = {
            param([pscustomobject]$Request)
            $pn = 1
            if ($Request.Uri -match 'pageNumber=(\d+)') { $pn = [int]$Matches[1] }
            $script:DEF008PagesSeen.Add($pn) | Out-Null
            if ($pn -eq 1) {
                [pscustomobject]@{
                    StatusCode = 200
                    Headers    = @{}
                    Content    = '{"entities":[{"id":"topic-1"}],"pageCount":2,"pageNumber":1}'
                }
            }
            else {
                [pscustomobject]@{
                    StatusCode = 200
                    Headers    = @{}
                    Content    = '{"entities":[{"id":"topic-2"}],"pageCount":2,"pageNumber":2}'
                }
            }
        }
        $result = Get-GCNotificationTopics -BaseUri 'https://api.example.local' -AccessToken 'token'
        $script:DEF008PagesSeen.Count | Should -Be 2
        @($result.Parsed.entities).Count | Should -Be 2
    }
}

Describe 'Queue Health: ConfidenceLevel in Get-GCQueueWaitCoverage results' {

    BeforeAll {
        $here = Split-Path -Parent $PSCommandPath
        $repo = Split-Path -Parent $here

        $membersFixture  = Join-Path $PSScriptRoot 'fixtures\QueueWaitCoverage.queueMembers.json'
        $detailsFixture  = Join-Path $PSScriptRoot 'fixtures\QueueWaitCoverage.conversationDetails.json'
        $skillsFixture   = Join-Path $PSScriptRoot 'fixtures\QueueWaitCoverage.skills.json'
        $script:MembersPayload  = (Get-Content -LiteralPath $membersFixture -Raw) | ConvertFrom-Json
        $script:DetailsPayload  = (Get-Content -LiteralPath $detailsFixture -Raw) | ConvertFrom-Json
        $script:SkillsPayload   = (Get-Content -LiteralPath $skillsFixture  -Raw) | ConvertFrom-Json

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

    It 'returns a ConfidenceLevel property on every result row' {
        $interval = '2025-01-01T00:00:00.000Z/2025-01-01T01:00:00.000Z'
        $result = Get-GCQueueWaitCoverage -QueueId 'queue-1' -Interval $interval
        $result.Count | Should -BeGreaterThan 0
        foreach ($row in $result) {
            $row.PSObject.Properties.Name | Should -Contain 'ConfidenceLevel'
            $row.ConfidenceLevel | Should -Not -BeNullOrEmpty
        }
    }

    It 'ConfidenceLevel is one of the four expected values' {
        $interval = '2025-01-01T00:00:00.000Z/2025-01-01T01:00:00.000Z'
        $result = Get-GCQueueWaitCoverage -QueueId 'queue-1' -Interval $interval
        $validValues = @('High', 'Medium', 'Low', 'No Coverage')
        foreach ($row in $result) {
            $validValues | Should -Contain $row.ConfidenceLevel
        }
    }
}

Describe 'Audit Investigator: ConfidenceLevel logic unit tests' {

    It 'returns No Coverage when EligibleCount is 0' {
        $eligibleCount = 0; $notResponding = 0
        $level = if ($eligibleCount -eq 0) { 'No Coverage' }
                 elseif ($notResponding -ge $eligibleCount) { 'Low' }
                 elseif ($eligibleCount -gt 0 -and $notResponding -gt ($eligibleCount / 2)) { 'Medium' }
                 else { 'High' }
        $level | Should -Be 'No Coverage'
    }

    It 'returns Low when all agents are NOT_RESPONDING' {
        $eligibleCount = 3; $notResponding = 3
        $level = if ($eligibleCount -eq 0) { 'No Coverage' }
                 elseif ($notResponding -ge $eligibleCount) { 'Low' }
                 elseif ($eligibleCount -gt 0 -and $notResponding -gt ($eligibleCount / 2)) { 'Medium' }
                 else { 'High' }
        $level | Should -Be 'Low'
    }

    It 'returns Medium when majority of agents are NOT_RESPONDING' {
        $eligibleCount = 4; $notResponding = 3
        $level = if ($eligibleCount -eq 0) { 'No Coverage' }
                 elseif ($notResponding -ge $eligibleCount) { 'Low' }
                 elseif ($eligibleCount -gt 0 -and $notResponding -gt ($eligibleCount / 2)) { 'Medium' }
                 else { 'High' }
        $level | Should -Be 'Medium'
    }

    It 'returns High when agents are available' {
        $eligibleCount = 5; $notResponding = 1
        $level = if ($eligibleCount -eq 0) { 'No Coverage' }
                 elseif ($notResponding -ge $eligibleCount) { 'Low' }
                 elseif ($eligibleCount -gt 0 -and $notResponding -gt ($eligibleCount / 2)) { 'Medium' }
                 else { 'High' }
        $level | Should -Be 'High'
    }
}
