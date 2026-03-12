# Requires: Pester 5+
# Sprint 4 — S1-008: Audit Investigator offline tests

BeforeAll {
    $here = Split-Path -Parent $PSCommandPath
    $repo = Split-Path -Parent $here
    $module = Join-Path $repo 'src\GenesysCloud.OpsInsights\GenesysCloud.OpsInsights.psd1'
    Import-Module $module -Force -ErrorAction Stop
    Set-GCContext -ApiBaseUri 'https://api.example.local' -AccessToken 'test-token' | Out-Null

    $executionFixture = Join-Path $PSScriptRoot 'fixtures\AuditQuery.execution.json'
    $resultsFixture   = Join-Path $PSScriptRoot 'fixtures\AuditQuery.results.json'

    $script:ExecutionPayload = (Get-Content -LiteralPath $executionFixture -Raw) | ConvertFrom-Json
    $script:ResultsPayload   = (Get-Content -LiteralPath $resultsFixture   -Raw) | ConvertFrom-Json

    Set-GCInvoker -Invoker {
        param([hashtable]$Request)
        if ($Request.Method -eq 'POST' -and $Request.Uri -match '/api/v2/audits/query$') {
            return $script:ExecutionPayload
        }
        if ($Request.Method -eq 'GET' -and $Request.Uri -match '/api/v2/audits/query/[^/]+$') {
            return $script:ExecutionPayload
        }
        if ($Request.Method -eq 'GET' -and $Request.Uri -match '/api/v2/audits/query/[^/]+/results') {
            return $script:ResultsPayload
        }
        throw "No fixture mapped for: $($Request.Method) $($Request.Uri)"
    }
}

Describe 'Invoke-GCAuditQuery: result shape' -Tag @('Unit') {

    It 'returns a result object with ExecutionId, Interval, Count, and Entities' {
        $interval = '2025-01-01T00:00:00.000Z/2025-01-02T00:00:00.000Z'
        $result = Invoke-GCAuditQuery -Interval $interval
        $result | Should -Not -BeNullOrEmpty
        $result.PSObject.Properties.Name | Should -Contain 'ExecutionId'
        $result.PSObject.Properties.Name | Should -Contain 'Interval'
        $result.PSObject.Properties.Name | Should -Contain 'Count'
        $result.PSObject.Properties.Name | Should -Contain 'Entities'
    }

    It 'returns the correct count matching the fixture entities' {
        $interval = '2025-01-01T00:00:00.000Z/2025-01-02T00:00:00.000Z'
        $result = Invoke-GCAuditQuery -Interval $interval
        $result.Count | Should -Be 3
        @($result.Entities).Count | Should -Be 3
    }

    It 'preserves the interval in the result' {
        $interval = '2025-01-01T00:00:00.000Z/2025-01-02T00:00:00.000Z'
        $result = Invoke-GCAuditQuery -Interval $interval
        $result.Interval | Should -Be $interval
    }

    It 'populates the ExecutionId from the fixture' {
        $interval = '2025-01-01T00:00:00.000Z/2025-01-02T00:00:00.000Z'
        $result = Invoke-GCAuditQuery -Interval $interval
        $result.ExecutionId | Should -Not -BeNullOrEmpty
        $result.ExecutionId | Should -Be 'txn-audit-001'
    }
}

Describe 'Invoke-GCAuditQuery: entity content' -Tag @('Unit') {

    It 'each entity has an id and timestamp' {
        $interval = '2025-01-01T00:00:00.000Z/2025-01-02T00:00:00.000Z'
        $result = Invoke-GCAuditQuery -Interval $interval
        foreach ($entity in $result.Entities) {
            $entity.id | Should -Not -BeNullOrEmpty
            $entity.timestamp | Should -Not -BeNullOrEmpty
        }
    }

    It 'entities include expected service and action values from fixture' {
        $interval = '2025-01-01T00:00:00.000Z/2025-01-02T00:00:00.000Z'
        $result = Invoke-GCAuditQuery -Interval $interval
        $services = @($result.Entities | ForEach-Object { $_.service })
        $services | Should -Contain 'Routing'
        $services | Should -Contain 'Quality'
    }
}

Describe 'Invoke-GCAuditQuery: guard rails' -Tag @('Unit') {

    It 'throws when Interval is empty' {
        { Invoke-GCAuditQuery -Interval '' } | Should -Throw
    }

    It 'accepts a ServiceName filter without error' {
        $interval = '2025-01-01T00:00:00.000Z/2025-01-02T00:00:00.000Z'
        { Invoke-GCAuditQuery -Interval $interval -ServiceName 'Routing' } | Should -Not -Throw
    }

    It 'accepts MaxResults without error' {
        $interval = '2025-01-01T00:00:00.000Z/2025-01-02T00:00:00.000Z'
        { Invoke-GCAuditQuery -Interval $interval -MaxResults 100 } | Should -Not -Throw
    }
}

Describe 'Invoke-GCAuditQuery: pagination' -Tag @('Unit') {

    It 'follows a cursor to fetch a second page when cursor is present' {
        $script:AuditPageCalls = [System.Collections.Generic.List[string]]::new()

        Set-GCInvoker -Invoker {
            param([hashtable]$Request)
            if ($Request.Method -eq 'POST' -and $Request.Uri -match '/api/v2/audits/query$') {
                return [pscustomobject]@{ id = 'txn-page'; state = 'Succeeded' }
            }
            if ($Request.Method -eq 'GET' -and $Request.Uri -match '/api/v2/audits/query/[^/]+$') {
                return [pscustomobject]@{ id = 'txn-page'; state = 'Succeeded' }
            }
            if ($Request.Method -eq 'GET' -and $Request.Uri -match '/api/v2/audits/query/[^/]+/results') {
                $script:AuditPageCalls.Add($Request.Uri) | Out-Null
                if ($Request.Uri -notmatch 'cursor=') {
                    return [pscustomobject]@{
                        entities = @([pscustomobject]@{ id = 'e1'; timestamp = '2025-01-01T00:00:00.000Z' })
                        cursor   = 'next-page-cursor'
                    }
                }
                else {
                    return [pscustomobject]@{
                        entities = @([pscustomobject]@{ id = 'e2'; timestamp = '2025-01-01T01:00:00.000Z' })
                        cursor   = $null
                    }
                }
            }
            throw "Unexpected: $($Request.Method) $($Request.Uri)"
        }

        $interval = '2025-01-01T00:00:00.000Z/2025-01-02T00:00:00.000Z'
        $result = Invoke-GCAuditQuery -Interval $interval
        $result.Count | Should -Be 2
        $script:AuditPageCalls.Count | Should -Be 2
    }
}
