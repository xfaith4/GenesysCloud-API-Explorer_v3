# ============================================================
# Get-GenesysCloudAbandonTotals.ps1
#
# Retrieves total INBOUND and OUTBOUND abandon voice call
# counts for February 2026 via Genesys Cloud Analytics API.
#
# Notes:
#   - Analytics aggregates endpoint max interval = 7 days,
#     so February is split into four 7-day query windows.
#   - tAbandon is a duration metric; its stats.count is the
#     number of abandoned conversations in the interval.
#   - Authentication is assumed; set $AccessToken before running.
# ============================================================

#region --- CONFIGURATION ---

$AccessToken = "YOUR_ACCESS_TOKEN_HERE"        # Inject your Bearer token here
$GCDomain    = "mypurecloud.com"               # Change to your region:
                                               #   mypurecloud.com      (US East)
                                               #   mypurecloud.ie       (EMEA)
                                               #   mypurecloud.de       (EU Frankfurt)
                                               #   mypurecloud.com.au   (APAC Sydney)
                                               #   mypurecloud.jp       (APAC Tokyo)

$BaseUrl  = "https://api.$GCDomain"
$Endpoint = "$BaseUrl/api/v2/analytics/conversations/aggregates/query"

$Headers = @{
    "Authorization" = "Bearer $AccessToken"
    "Content-Type"  = "application/json"
    "Accept"        = "application/json"
}

#endregion

#region --- DATE INTERVALS ---
# February 2026 = 28 days, split into four <=7-day windows.
# Interval format: ISO 8601  start/end  (end is exclusive).

$DateIntervals = @(
    @{ Label = "Feb 01 - Feb 07"; Start = "2026-02-01T00:00:00.000Z"; End = "2026-02-08T00:00:00.000Z" },
    @{ Label = "Feb 08 - Feb 14"; Start = "2026-02-08T00:00:00.000Z"; End = "2026-02-15T00:00:00.000Z" },
    @{ Label = "Feb 15 - Feb 21"; Start = "2026-02-15T00:00:00.000Z"; End = "2026-02-22T00:00:00.000Z" },
    @{ Label = "Feb 22 - Feb 28"; Start = "2026-02-22T00:00:00.000Z"; End = "2026-03-01T00:00:00.000Z" }
)

#endregion

#region --- ACCUMULATORS ---

$TotalInboundAbandons  = 0
$TotalOutboundAbandons = 0

#endregion

#region --- MAIN QUERY LOOP ---

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "   Genesys Cloud  |  February 2026 Abandon Call Totals"      -ForegroundColor Cyan
Write-Host "   Region: $GCDomain"                                         -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

foreach ($Interval in $DateIntervals) {

    Write-Host ">> Querying interval: $($Interval.Label)" -ForegroundColor Yellow
    Write-Host "   [$($Interval.Start)  -->  $($Interval.End)]"          -ForegroundColor DarkGray

    # groupBy "direction" splits results into inbound vs outbound rows.
    # filter restricts to voice media type only.
    # tAbandon stats.count = number of abandoned conversations.
    $Body = @{
        interval = "$($Interval.Start)/$($Interval.End)"
        groupBy  = @("direction")
        filter   = @{
            type    = "and"
            clauses = @(
                @{
                    type       = "or"
                    predicates = @(
                        @{ dimension = "mediaType"; value = "voice" }
                    )
                }
            )
        }
        metrics  = @("tAbandon")
    } | ConvertTo-Json -Depth 10

    try {
        $Response = Invoke-RestMethod `
            -Uri         $Endpoint `
            -Method      POST `
            -Headers     $Headers `
            -Body        $Body `
            -ErrorAction Stop

        if ($null -eq $Response.results -or $Response.results.Count -eq 0) {
            Write-Host "   No data returned for this interval." -ForegroundColor DarkGray
            Write-Host ""
            continue
        }

        foreach ($ResultGroup in $Response.results) {

            $Direction   = if ($ResultGroup.group.direction) { $ResultGroup.group.direction } else { "unknown" }
            $PeriodCount = 0

            # Sum tAbandon counts across all data buckets in this group
            foreach ($DataBucket in $ResultGroup.data) {
                foreach ($MetricEntry in $DataBucket.metrics) {
                    if ($MetricEntry.metric -eq "tAbandon") {
                        $PeriodCount += [int]$MetricEntry.stats.count
                    }
                }
            }

            switch ($Direction.ToLower()) {
                "inbound"  {
                    $TotalInboundAbandons  += $PeriodCount
                    Write-Host ("   [INBOUND ]  Abandons: {0,6}" -f $PeriodCount) -ForegroundColor White
                }
                "outbound" {
                    $TotalOutboundAbandons += $PeriodCount
                    Write-Host ("   [OUTBOUND]  Abandons: {0,6}" -f $PeriodCount) -ForegroundColor White
                }
                default {
                    Write-Host ("   [UNKNOWN direction: $Direction]  Abandons: {0,6}" -f $PeriodCount) -ForegroundColor Magenta
                }
            }
        }
    }
    catch {
        Write-Host "   ERROR on interval $($Interval.Label): $($_.Exception.Message)" -ForegroundColor Red

        # Surface the API error body for troubleshooting
        if ($_.Exception.Response) {
            try {
                $Stream  = $_.Exception.Response.GetResponseStream()
                $Reader  = New-Object System.IO.StreamReader($Stream)
                $ErrBody = $Reader.ReadToEnd()
                Write-Host "   API Response Body: $ErrBody" -ForegroundColor Red
            }
            catch {
                Write-Host "   (Could not read API error response body)" -ForegroundColor DarkRed
            }
        }
    }

    Write-Host ""
}

#endregion

#region --- FINAL SUMMARY ---

$GrandTotal = $TotalInboundAbandons + $TotalOutboundAbandons

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "   FEBRUARY 2026  -  FINAL ABANDON TOTALS"                   -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ("   Total Inbound  Abandons : {0,8}" -f $TotalInboundAbandons)  -ForegroundColor Green
Write-Host ("   Total Outbound Abandons : {0,8}" -f $TotalOutboundAbandons) -ForegroundColor Green
Write-Host "   ------------------------------------------"               -ForegroundColor DarkGray
Write-Host ("   Combined Grand Total    : {0,8}" -f $GrandTotal)             -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

#endregion
