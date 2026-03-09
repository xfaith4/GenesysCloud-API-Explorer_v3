[CmdletBinding()]
param(
    [ValidateSet('Fast', 'Full', 'Integration')]
    [string]$Profile = 'Fast',

    [switch]$EnableCoverage,

    [int]$MinimumCoverage = 0
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$configScript = Join-Path -Path $repoRoot -ChildPath 'tests/pester.config.ps1'
if (-not (Test-Path -LiteralPath $configScript)) {
    throw "Pester configuration script not found: $configScript"
}

if (-not (Get-Module -ListAvailable -Name Pester)) {
    throw "Pester 5+ is required. Install with: Install-Module Pester -Scope CurrentUser -Force"
}

Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop

$config = & $configScript -Profile $Profile -EnableCoverage:$EnableCoverage.IsPresent -MinimumCoverage $MinimumCoverage -RepoRoot $repoRoot
$result = Invoke-Pester -Configuration $config

if ($result.FailedCount -gt 0) {
    throw "Pester reported $($result.FailedCount) failing test(s)."
}

Write-Host "Pester profile '$Profile' completed. Total: $($result.TotalCount), Failed: $($result.FailedCount), Skipped: $($result.SkippedCount)."
