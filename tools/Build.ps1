### BEGIN FILE: tools\Build.ps1
[CmdletBinding()]
param()

$repoRoot = Split-Path -Parent $PSCommandPath | Split-Path -Parent
$moduleRoot = Join-Path $repoRoot 'src\GenesysCloud.OpsInsights'
$testScript = Join-Path $repoRoot 'tools\Test.ps1'

Write-Host "Module root: $moduleRoot"
if (-not (Test-Path -LiteralPath $testScript)) {
    throw "Test runner not found: $testScript"
}

Write-Host "Running Pester (Full profile)..."
& $testScript -Profile Full
Write-Host "Build checks completed."
### END FILE: tools\Build.ps1
