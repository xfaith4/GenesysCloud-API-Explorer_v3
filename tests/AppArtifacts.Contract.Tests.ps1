# Requires: Pester 5+

BeforeAll {
    . "$PSScriptRoot\TestHelpers.ps1"
    $script:RepoRoot = Get-TestRepoRoot -StartPath $PSScriptRoot
}

Describe 'Application artifact contracts' -Tag @('Contract', 'Artifacts') {
    It 'parses required JSON artifacts' {
        $jsonFiles = @(
            'apps/OpsConsole/Resources/DefaultTemplates.json',
            'apps/OpsConsole/Resources/ExamplePostBodies.json',
            'apps/OpsConsole/Resources/GenesysCloudAPIEndpoints.json',
            'GenesysCloudNotificationTopics.json'
        )

        foreach ($relativePath in $jsonFiles) {
            $path = Join-TestRepoPath -RelativePath $relativePath -StartPath $PSScriptRoot
            (Test-Path -LiteralPath $path) | Should -BeTrue
            { Get-Content -LiteralPath $path -Raw | ConvertFrom-Json | Out-Null } | Should -Not -Throw
        }
    }

    It 'validates default template object shape' {
        $path = Join-TestRepoPath -RelativePath 'apps/OpsConsole/Resources/DefaultTemplates.json' -StartPath $PSScriptRoot
        $templates = @(Get-Content -LiteralPath $path -Raw | ConvertFrom-Json)
        $templates.Count | Should -BeGreaterThan 0

        foreach ($template in $templates) {
            $template.Name | Should -Not -BeNullOrEmpty
            $template.Method | Should -Match '^(GET|POST|PUT|PATCH|DELETE)$'
            $template.Path | Should -Match '^/api/'
        }
    }

    It 'validates insight packs have ids, versions, and pipeline steps' {
        $packsDir = Join-TestRepoPath -RelativePath 'insights/packs' -StartPath $PSScriptRoot
        $packFiles = @(Get-ChildItem -LiteralPath $packsDir -Filter '*.json' -File)
        $packFiles.Count | Should -BeGreaterThan 0

        $ids = New-Object System.Collections.Generic.List[string]
        foreach ($file in $packFiles) {
            $pack = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
            $pack.id | Should -Not -BeNullOrEmpty
            $pack.version | Should -Not -BeNullOrEmpty
            @($pack.pipeline).Count | Should -BeGreaterThan 0 -Because $file.Name
            $ids.Add([string]$pack.id) | Out-Null
        }

        $duplicates = @($ids | Group-Object | Where-Object { $_.Count -gt 1 })
        $duplicateNames = @($duplicates | ForEach-Object { $_.Name })
        $duplicates.Count | Should -Be 0 -Because "Duplicate insight pack ids: $($duplicateNames -join ', ')"
    }

    It 'loads endpoint catalog and contains analytics conversation details path' {
        $path = Join-TestRepoPath -RelativePath 'apps/OpsConsole/Resources/GenesysCloudAPIEndpoints.json' -StartPath $PSScriptRoot
        $catalog = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json

        $openApiCache = $catalog.PSObject.Properties |
            Where-Object {
                $_.Name -like 'openapi-cache-*' -and
                $_.Value -is [System.Management.Automation.PSCustomObject]
            } |
            Select-Object -First 1

        $openApiCache | Should -Not -BeNullOrEmpty
        $openApi = $openApiCache.Value
        $openApi.paths.PSObject.Properties.Name.Count | Should -BeGreaterThan 100
        $openApi.paths.PSObject.Properties.Name | Should -Contain '/api/v2/analytics/conversations/details/query'
    }
}

Describe 'Audit artifact contracts' -Tag @('Contract', 'Artifacts', 'Audit') {
    It 'audit directory exists and contains required files' {
        $auditDir = Join-TestRepoPath -RelativePath 'docs/audit' -StartPath $PSScriptRoot
        (Test-Path -LiteralPath $auditDir -PathType Container) | Should -BeTrue

        $requiredFiles = @(
            'docs/audit/AUDIT_REPORT.md',
            'docs/audit/CAPABILITIES.md',
            'docs/audit/DEFECTS.md',
            'docs/audit/controls-and-workflows.json',
            'docs/audit/request-ledger.json'
        )
        foreach ($rel in $requiredFiles) {
            $p = Join-TestRepoPath -RelativePath $rel -StartPath $PSScriptRoot
            (Test-Path -LiteralPath $p) | Should -BeTrue -Because "$rel must exist"
        }
    }

    It 'controls-and-workflows.json parses and has required top-level keys' {
        $path = Join-TestRepoPath -RelativePath 'docs/audit/controls-and-workflows.json' -StartPath $PSScriptRoot
        $raw = Get-Content -LiteralPath $path -Raw
        { $raw | ConvertFrom-Json | Out-Null } | Should -Not -Throw
        $doc = $raw | ConvertFrom-Json

        $doc.schemaVersion | Should -Not -BeNullOrEmpty
        $doc.controls | Should -Not -BeNullOrEmpty
        $doc.workflows | Should -Not -BeNullOrEmpty
        @($doc.controls).Count | Should -BeGreaterThan 20
        @($doc.workflows).Count | Should -BeGreaterThan 5
    }

    It 'controls-and-workflows.json control entries have required shape' {
        $path = Join-TestRepoPath -RelativePath 'docs/audit/controls-and-workflows.json' -StartPath $PSScriptRoot
        $doc = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json

        foreach ($ctrl in $doc.controls) {
            $ctrl.name | Should -Not -BeNullOrEmpty -Because "control.name must not be empty"
            $ctrl.tab | Should -Not -BeNullOrEmpty -Because "control.tab must not be empty"
            $ctrl.classification | Should -Not -BeNullOrEmpty -Because "control.classification must not be empty"
        }
    }

    It 'request-ledger.json parses and has required top-level keys' {
        $path = Join-TestRepoPath -RelativePath 'docs/audit/request-ledger.json' -StartPath $PSScriptRoot
        $raw = Get-Content -LiteralPath $path -Raw
        { $raw | ConvertFrom-Json | Out-Null } | Should -Not -Throw
        $doc = $raw | ConvertFrom-Json

        $doc.schemaVersion | Should -Not -BeNullOrEmpty
        $doc.requests | Should -Not -BeNullOrEmpty
        @($doc.requests).Count | Should -BeGreaterThan 10
    }

    It 'request-ledger.json entries have required shape' {
        $path = Join-TestRepoPath -RelativePath 'docs/audit/request-ledger.json' -StartPath $PSScriptRoot
        $doc = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json

        foreach ($req in $doc.requests) {
            $req.workflowId | Should -Not -BeNullOrEmpty -Because "request.workflowId must not be empty"
            $req.method | Should -Not -BeNullOrEmpty -Because "request.method must not be empty"
            $req.endpointPath | Should -Not -BeNullOrEmpty -Because "request.endpointPath must not be empty"
            $req.sourceFunction | Should -Not -BeNullOrEmpty -Because "request.sourceFunction must not be empty"
        }
    }
}
