# Requires: Pester 5+

Describe 'Live API smoke tests' -Tag @('Integration', 'Slow') {
    BeforeAll {
        . "$PSScriptRoot\TestHelpers.ps1"
        Import-TestModuleManifest -ManifestRelativePath 'src/GenesysCloud.OpsInsights/GenesysCloud.OpsInsights.psd1' -StartPath $PSScriptRoot

        $script:LiveApiBaseUri = $env:GC_API_BASE_URI
        $script:LiveApiToken = $env:GC_ACCESS_TOKEN
        $script:CanRunLive = (-not [string]::IsNullOrWhiteSpace($script:LiveApiBaseUri)) -and (-not [string]::IsNullOrWhiteSpace($script:LiveApiToken))
    }

    It 'can set/get live context' {
        if (-not $script:CanRunLive) {
            Set-ItResult -Skipped -Because 'Set GC_API_BASE_URI and GC_ACCESS_TOKEN to run integration tests.'
            return
        }

        Set-GCContext -ApiBaseUri $script:LiveApiBaseUri -AccessToken $script:LiveApiToken | Out-Null
        $ctx = Get-GCContext
        $ctx.ApiBaseUri | Should -Be $script:LiveApiBaseUri
        $ctx.AccessToken | Should -Be $script:LiveApiToken
    }

    It 'can call /api/v2/users/me through Invoke-GCRequest' {
        if (-not $script:CanRunLive) {
            Set-ItResult -Skipped -Because 'Set GC_API_BASE_URI and GC_ACCESS_TOKEN to run integration tests.'
            return
        }

        $response = Invoke-GCRequest `
            -Method GET `
            -BaseUri $script:LiveApiBaseUri `
            -AccessToken $script:LiveApiToken `
            -Path '/api/v2/users/me' `
            -AsResponse

        $response.StatusCode | Should -BeIn @(200, 201)
        $response.Parsed.id | Should -Not -BeNullOrEmpty
    }
}
