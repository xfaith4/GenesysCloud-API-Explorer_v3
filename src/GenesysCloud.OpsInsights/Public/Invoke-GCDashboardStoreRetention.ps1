function Invoke-GCDashboardStoreRetention {
    <#
    .SYNOPSIS
        Purges dashboard store entries older than the retention window.

    .PARAMETER StorePath
        Path to the dashboard store JSONL file.

    .PARAMETER RetainDays
        Number of days to retain (records older than this are removed).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$StorePath,

        [int]$RetainDays = 90
    )

    if (-not (Test-Path -LiteralPath $StorePath)) {
        throw "Store path not found: $StorePath"
    }
    if ($RetainDays -lt 1) { throw "RetainDays must be at least 1." }

    $threshold = (Get-Date).AddDays(-1 * $RetainDays)
    $temp = [System.IO.Path]::GetTempFileName()
    Remove-Item -LiteralPath $temp -Force
    $written = 0
    $dropped = 0

    $writer = New-Object System.IO.StreamWriter($temp, $false, [System.Text.Encoding]::UTF8)
    try {
        foreach ($line in Get-Content -LiteralPath $StorePath -Encoding utf8) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $keep = $true
            try {
                $obj = $line | ConvertFrom-Json -Depth 6
                $created = $null
                if ($obj -and $obj.CreatedUtc) { $created = [datetime]::Parse($obj.CreatedUtc) }
                elseif ($obj -and $obj.Interval) {
                    $parts = [string]$obj.Interval -split '/'
                    if ($parts.Count -gt 0) { $created = [datetime]::Parse($parts[0]) }
                }
                if ($created -and $created -lt $threshold) { $keep = $false }
            }
            catch { }

            if ($keep) {
                $writer.WriteLine($line)
                $written++
            }
            else {
                $dropped++
            }
        }
    }
    finally {
        $writer.Flush()
        $writer.Close()
    }

    Move-Item -LiteralPath $temp -Destination $StorePath -Force

    $logLine = "{0} | {1} | retention applied to {2} (kept={3}, dropped={4}, threshold={5:o})" -f (Get-Date).ToString('o'), [Environment]::UserName, $StorePath, $written, $dropped, $threshold
    try {
        $root = Split-Path -Parent $StorePath
        $log = Join-Path -Path $root -ChildPath 'ingest-audit.log'
        Add-Content -LiteralPath $log -Value $logLine -Encoding utf8
    }
    catch { }

    return [pscustomobject]@{
        StorePath = $StorePath
        RetainDays= $RetainDays
        Kept      = $written
        Dropped   = $dropped
        Threshold = $threshold
    }
}
