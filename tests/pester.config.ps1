param(
    [ValidateSet('Fast', 'Full', 'Integration')]
    [string]$Profile = 'Fast',

    [switch]$EnableCoverage,

    [int]$MinimumCoverage = 0,

    [string]$RepoRoot
)

if (-not $RepoRoot) {
    $RepoRoot = Split-Path -Parent $PSScriptRoot
}

$testsPath = Join-Path -Path $RepoRoot -ChildPath 'tests'
$resultsDir = Join-Path -Path $RepoRoot -ChildPath 'artifacts/test-results'
if (-not (Test-Path -LiteralPath $resultsDir)) {
    New-Item -ItemType Directory -Path $resultsDir -Force | Out-Null
}

$config = [PesterConfiguration]::Default
$config.Run.Path = @($testsPath)
$config.Run.PassThru = $true
$config.Output.Verbosity = if ($Profile -eq 'Fast') { 'Normal' } else { 'Detailed' }

$config.TestResult.Enabled = $true
$config.TestResult.OutputFormat = 'JUnitXml'
$config.TestResult.OutputPath = Join-Path -Path $resultsDir -ChildPath "pester-$($Profile.ToLowerInvariant()).xml"

$excludeTags = New-Object System.Collections.Generic.List[string]
switch ($Profile) {
    'Fast' {
        $excludeTags.Add('Integration') | Out-Null
        $excludeTags.Add('Slow') | Out-Null
    }
    'Full' {
        $excludeTags.Add('Integration') | Out-Null
    }
    'Integration' {
        $config.Filter.Tag = @('Integration')
    }
}

if ($excludeTags.Count -gt 0) {
    $config.Filter.ExcludeTag = @($excludeTags)
}

if ($EnableCoverage.IsPresent) {
    $config.CodeCoverage.Enabled = $true
    $config.CodeCoverage.Path = @(
        (Join-Path -Path $RepoRoot -ChildPath 'src/GenesysCloud.OpsInsights/Public/*.ps1'),
        (Join-Path -Path $RepoRoot -ChildPath 'src/GenesysCloud.OpsInsights/Private/*.ps1'),
        (Join-Path -Path $RepoRoot -ChildPath 'apps/OpsConsole/Resources/UxTelemetry.ps1'),
        (Join-Path -Path $RepoRoot -ChildPath 'apps/OpsConsole/Resources/UI/UI.PreMain.ps1'),
        (Join-Path -Path $RepoRoot -ChildPath 'Scripts/GenesysCloud.NotificationsToolkit/GenesysCloud.NotificationsToolkit.psm1')
    )
    $config.CodeCoverage.OutputPath = Join-Path -Path $resultsDir -ChildPath "coverage-$($Profile.ToLowerInvariant()).xml"
    $config.CodeCoverage.OutputFormat = 'JaCoCo'
    if ($MinimumCoverage -gt 0) {
        $config.CodeCoverage.CoveragePercentTarget = [double]$MinimumCoverage
    }
}

return $config
