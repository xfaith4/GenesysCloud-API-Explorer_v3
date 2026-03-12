### BEGIN FILE: src\GenesysCloud.OpsInsights\Public\Set-GCContext.ps1
function Set-GCContext {
    <#
      .SYNOPSIS
        Sets module-scoped Genesys Cloud context (optional).
      .DESCRIPTION
        You do NOT need this if your GUI already sets $global:AccessToken.
        It's here for scripts that want an explicit context.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$RegionDomain = 'usw2.pure.cloud',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ApiBaseUri,

        [Parameter()]
        [string]$AccessToken,

        [Parameter()]
        [scriptblock]$TokenProvider,

        # Optional scriptblock invoked when a 401 response is received (auth expiry notification).
        [Parameter()]
        [scriptblock]$OnUnauthorized
    )

    if (-not $ApiBaseUri) {
        $ApiBaseUri = "https://api.$($RegionDomain)"
    }
    $traceEnabled    = $false
    $tracePath       = $null
    $connected       = $false
    $prevUnauthorized = $null

    if ($script:GCContext) {
        $traceEnabled = [bool]$script:GCContext.TraceEnabled
        $tracePath    = [string]$script:GCContext.TracePath
        $connected    = [bool]$script:GCContext.Connected
        # Preserve existing OnUnauthorized callback unless a new one is supplied
        if ($script:GCContext.PSObject.Properties.Name -contains 'OnUnauthorized') {
            $prevUnauthorized = $script:GCContext.OnUnauthorized
        }
    }

    $script:GCContext = [pscustomobject]@{
        RegionDomain    = $RegionDomain
        ApiBaseUri      = $ApiBaseUri
        AccessToken     = $AccessToken
        TokenProvider   = $TokenProvider
        OnUnauthorized  = if ($null -ne $OnUnauthorized) { $OnUnauthorized } else { $prevUnauthorized }
        SetUtc          = (Get-Date).ToUniversalTime()
        TraceEnabled    = $traceEnabled
        TracePath       = $tracePath
        Connected       = $connected
    }

    return $script:GCContext
}
### END FILE
