# StartupDiagnostics.ps1
# Pure-PowerShell startup pre-flight checks (no WPF dependency).
# Returns a result object: { Ok, CorrelationId, Checks: [{Name, Pass, Detail}] }
# Wrap in try/catch at the call site so a bug here never prevents app launch.

function Invoke-StartupChecks {
    [CmdletBinding()]
    param(
        [string]$RepoRoot
    )

    if (-not $RepoRoot) {
        # Derive from script location; fall back to current directory.
        $RepoRoot = if ($PSScriptRoot) {
            Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
        } else {
            (Get-Location).Path
        }
    }

    $correlationId = [guid]::NewGuid().ToString()
    $checks = [System.Collections.Generic.List[hashtable]]::new()

    # ---- Check 1: PowerShell 7+ ----
    $psMajor = $PSVersionTable.PSVersion.Major
    $checks.Add(@{
        Name   = 'PowerShell version'
        Pass   = ($psMajor -ge 7)
        Detail = "Detected PS $($PSVersionTable.PSVersion); required: 7+"
    })

    # ---- Check 2: Start-ThreadJob / ThreadJob module ----
    $hasThreadJob = $false
    try {
        $hasThreadJob = [bool](Get-Command Start-ThreadJob -ErrorAction SilentlyContinue)
    } catch { }
    $checks.Add(@{
        Name   = 'ThreadJob module'
        Pass   = $hasThreadJob
        Detail = if ($hasThreadJob) { 'Start-ThreadJob is available' } else { 'Start-ThreadJob not found; install ThreadJob module' }
    })

    # ---- Check 3: Critical resource files ----
    $resourceFiles = @(
        'apps/OpsConsole/Resources/GenesysCloudAPIEndpoints.json',
        'apps/OpsConsole/Resources/DefaultTemplates.json',
        'apps/OpsConsole/Resources/ExamplePostBodies.json'
    )
    foreach ($rel in $resourceFiles) {
        $full = Join-Path $RepoRoot $rel
        $exists = Test-Path -LiteralPath $full
        $checks.Add(@{
            Name   = "Resource: $rel"
            Pass   = $exists
            Detail = if ($exists) { "Found: $full" } else { "Missing: $full" }
        })
    }

    # ---- Check 4: Critical UI scripts ----
    $uiScripts = @(
        'apps/OpsConsole/Resources/UxTelemetry.ps1',
        'apps/OpsConsole/Resources/UI/UI.PreMain.ps1',
        'apps/OpsConsole/Resources/UI/UI.Run.ps1'
    )
    foreach ($rel in $uiScripts) {
        $full = Join-Path $RepoRoot $rel
        $exists = Test-Path -LiteralPath $full
        $checks.Add(@{
            Name   = "Script: $rel"
            Pass   = $exists
            Detail = if ($exists) { "Found: $full" } else { "Missing: $full" }
        })
    }

    $allPass = -not ($checks | Where-Object { -not $_.Pass })

    return [pscustomobject]@{
        Ok            = $allPass
        CorrelationId = $correlationId
        Checks        = @($checks)
    }
}
