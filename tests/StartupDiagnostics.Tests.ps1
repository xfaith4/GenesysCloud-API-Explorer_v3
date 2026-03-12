# Requires: Pester 5+
# Sprint 4 — S1-004: Startup Diagnostics unit tests

BeforeAll {
    $here = Split-Path -Parent $PSCommandPath
    $repo = Split-Path -Parent $here
    $diagnosticsScript = Join-Path $repo 'apps/OpsConsole/Resources/StartupDiagnostics.ps1'
    . $diagnosticsScript
    # Cross-platform temp directory
    $script:TempRoot = [System.IO.Path]::GetTempPath()
    $script:FakeRoot  = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), 'gc-nonexistent-root-xyz')
}

Describe 'Invoke-StartupChecks — result shape' -Tag @('Unit') {

    It 'returns an object with Ok, CorrelationId, and Checks properties' {
        $result = Invoke-StartupChecks -RepoRoot $script:TempRoot
        $result | Should -Not -BeNullOrEmpty
        $result.PSObject.Properties.Name | Should -Contain 'Ok'
        $result.PSObject.Properties.Name | Should -Contain 'CorrelationId'
        $result.PSObject.Properties.Name | Should -Contain 'Checks'
    }

    It 'CorrelationId is a non-empty GUID string' {
        $result = Invoke-StartupChecks -RepoRoot $script:TempRoot
        $result.CorrelationId | Should -Not -BeNullOrEmpty
        { [guid]::Parse($result.CorrelationId) } | Should -Not -Throw
    }

    It 'Checks is a non-empty array' {
        $result = Invoke-StartupChecks -RepoRoot $script:TempRoot
        @($result.Checks).Count | Should -BeGreaterThan 0
    }

    It 'each Check entry has Name, Pass, and Detail keys' {
        $result = Invoke-StartupChecks -RepoRoot $script:TempRoot
        foreach ($check in $result.Checks) {
            $check.Keys | Should -Contain 'Name'
            $check.Keys | Should -Contain 'Pass'
            $check.Keys | Should -Contain 'Detail'
        }
    }
}

Describe 'Invoke-StartupChecks — PS version check' -Tag @('Unit') {

    It 'includes a PowerShell version check entry' {
        $result = Invoke-StartupChecks -RepoRoot $script:TempRoot
        $psCheck = $result.Checks | Where-Object { $_.Name -eq 'PowerShell version' }
        $psCheck | Should -Not -BeNullOrEmpty
    }

    It 'PowerShell version check passes on PS 7+' {
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            $result = Invoke-StartupChecks -RepoRoot $script:TempRoot
            $psCheck = $result.Checks | Where-Object { $_.Name -eq 'PowerShell version' }
            $psCheck.Pass | Should -Be $true
        }
        else {
            Set-ItResult -Skipped -Because 'Not running on PS 7+'
        }
    }
}

Describe 'Invoke-StartupChecks — missing resource file detection' -Tag @('Unit') {

    It 'returns Ok = $false when a resource file is missing' {
        $result = Invoke-StartupChecks -RepoRoot $script:FakeRoot
        $result.Ok | Should -Be $false
    }

    It 'names the failing check correctly when GenesysCloudAPIEndpoints.json is absent' {
        $result = Invoke-StartupChecks -RepoRoot $script:FakeRoot
        $failing = $result.Checks | Where-Object { -not $_.Pass }
        $failing | Should -Not -BeNullOrEmpty
        $checkNames = @($failing | ForEach-Object { $_.Name })
        $checkNames | Where-Object { $_ -like '*GenesysCloudAPIEndpoints.json*' } | Should -Not -BeNullOrEmpty
    }

    It 'returns no failing resource checks when pointed at the real repo root' {
        $here = Split-Path -Parent $PSCommandPath
        $repo = Split-Path -Parent $here
        $result = Invoke-StartupChecks -RepoRoot $repo
        $resourceFailing = $result.Checks | Where-Object { $_.Name -like 'Resource:*' -and -not $_.Pass }
        $resourceFailing | Should -BeNullOrEmpty -Because "All resource files should be present in the repo"
    }
}

Describe 'Invoke-StartupChecks — UI script checks' -Tag @('Unit') {

    It 'includes checks for UxTelemetry.ps1, UI.PreMain.ps1, and UI.Run.ps1' {
        $here = Split-Path -Parent $PSCommandPath
        $repo = Split-Path -Parent $here
        $result = Invoke-StartupChecks -RepoRoot $repo
        $scriptCheckNames = @($result.Checks | Where-Object { $_.Name -like 'Script:*' } | ForEach-Object { $_.Name })
        $scriptCheckNames | Where-Object { $_ -like '*UxTelemetry.ps1*' } | Should -Not -BeNullOrEmpty
        $scriptCheckNames | Where-Object { $_ -like '*UI.PreMain.ps1*' } | Should -Not -BeNullOrEmpty
        $scriptCheckNames | Where-Object { $_ -like '*UI.Run.ps1*' } | Should -Not -BeNullOrEmpty
    }

    It 'all UI script checks pass when pointed at the real repo root' {
        $here = Split-Path -Parent $PSCommandPath
        $repo = Split-Path -Parent $here
        $result = Invoke-StartupChecks -RepoRoot $repo
        $scriptFailing = $result.Checks | Where-Object { $_.Name -like 'Script:*' -and -not $_.Pass }
        $scriptFailing | Should -BeNullOrEmpty -Because "All UI scripts should be present in the repo"
    }
}
