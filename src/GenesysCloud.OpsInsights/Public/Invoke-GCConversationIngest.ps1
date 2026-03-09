function Invoke-GCConversationIngest {
    <#
    .SYNOPSIS
        Pulls conversation detail jobs for a given interval and appends results to the dashboard store.

    .DESCRIPTION
        Creates an analytics conversation details job, polls until completion, pages results, and writes each
        conversation as a JSONL entry to the dashboard store (default: artifacts/ops-dashboard/dashboard-store.jsonl).
        Each entry includes lightweight bucket metadata (DivisionId, QueueIds, AgentIds) to support rollups.

    .PARAMETER Interval
        Analytics interval string (e.g., "2026-01-01T00:00:00Z/2026-01-02T00:00:00Z").

    .PARAMETER StorePath
        Destination JSONL file. Defaults to artifacts/ops-dashboard/dashboard-store.jsonl under the current workspace.

    .PARAMETER PageSize
        Page size for job results (Genesys jobs typically allow up to 5000).

    .PARAMETER MaxPages
        Maximum pages to retrieve to avoid runaway pulls.

    .PARAMETER PollSeconds
        Seconds between job status polls.

    .PARAMETER TimeoutSeconds
        Overall timeout before giving up on the job.

    .PARAMETER ThrottleMilliseconds
        Delay between page fetches to respect rate limiting.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Interval,

        [string]$StorePath,

    [ValidateRange(1,5000)]
    [int]$PageSize = 1000,

    [int]$MaxPages = 200,

    [int]$PollSeconds = 5,

    [int]$TimeoutSeconds = 600,

    [int]$ThrottleMilliseconds = 250,

    [switch]$IncludeTranscripts,

    [string]$AccessToken
)

    $store = $StorePath
    if (-not $store) {
        $workspace = Get-Location
        $root = Join-Path -Path $workspace -ChildPath 'artifacts/ops-dashboard'
        if (-not (Test-Path -LiteralPath $root)) {
            New-Item -ItemType Directory -Path $root -Force | Out-Null
        }
        $store = Join-Path -Path $root -ChildPath 'dashboard-store.jsonl'
    }

    $body = [ordered]@{
        interval = $Interval
        order    = 'asc'
        paging   = @{ pageSize = $PageSize }
    }

    function Write-IngestAuditLog {
        param(
            [string]$Message
        )
        try {
            $root = Split-Path -Parent $store
            $log = Join-Path -Path $root -ChildPath 'ingest-audit.log'
            $line = "{0} | {1} | {2}" -f (Get-Date).ToString('o'), [Environment]::UserName, $Message
            Add-Content -LiteralPath $log -Value $line -Encoding utf8
        }
        catch { }
    }

    function Sanitize-ConvoDetail {
        param([psobject]$Detail)

        if (-not $Detail) { return $Detail }
        $clone = $Detail | ConvertTo-Json -Depth 15 | ConvertFrom-Json -Depth 15

        if (-not $IncludeTranscripts) {
            if ($clone.PSObject.Properties.Name -contains 'transcripts') {
                $clone.PSObject.Properties.Remove('transcripts') | Out-Null
            }
        }

        foreach ($p in @($clone.participants)) {
            foreach ($field in @('name','email','addressFrom','addressTo','ani','dnis','from','to','callbackNumber')) {
                if ($p.PSObject.Properties.Name -contains $field) { $p.$field = $null }
            }
            foreach ($s in @($p.sessions)) {
                foreach ($field in @('ani','dnis','addressFrom','addressTo','sourceName')) {
                    if ($s.PSObject.Properties.Name -contains $field) { $s.$field = $null }
                }
            }
        }

        return $clone
    }

    $job = Invoke-GCRequest -Method POST -Path '/api/v2/analytics/conversations/details/jobs' -Body $body -AccessToken $AccessToken
    $jobId = $job.jobid
    if ([string]::IsNullOrWhiteSpace([string]$jobId)) {
        throw "Conversation details job did not return an id."
    }

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $state = [string]$job.state
    while ($true) {
        if ($state -match 'Fulfilled|Completed|Succeeded') { break }
        if ($state -match 'Failed|Cancelled') { throw "Conversation job $jobId failed (state=$state)" }
        if ((Get-Date) -gt $deadline) { throw "Conversation job $jobId timed out after $TimeoutSeconds seconds (state=$state)" }
        Start-Sleep -Seconds $PollSeconds
        $status = Invoke-GCRequest -Method GET -Path "/api/v2/analytics/conversations/details/jobs/$jobId" -AccessToken $AccessToken
        $state = if ($status -and $status.state) { [string]$status.state } else { '' }
    }

    $page = 1
    $written = 0
    while ($page -le $MaxPages) {
        $path = "/api/v2/analytics/conversations/details/jobs/$jobId/results?pageNumber=$page&pageSize=$PageSize"
        $resp = Invoke-GCRequest -Method GET -Path $path -AccessToken $AccessToken
        if (-not $resp) { break }

        $convs = @()
        if ($resp.PSObject.Properties.Name -contains 'conversations') {
            $convs = @($resp.conversations)
        }
        if (-not $convs -or $convs.Count -eq 0) { break }

        foreach ($c in $convs) {
            $convId = $c.conversationId
            $divisionId = $c.divisionId

            $queueIds = New-Object System.Collections.Generic.HashSet[string]
            $agentIds = New-Object System.Collections.Generic.HashSet[string]
            foreach ($p in @($c.participants)) {
                $uid = $p.userId
                if ($uid) { $null = $agentIds.Add([string]$uid) }
                foreach ($s in @($p.sessions)) {
                    if ($s.queueId) { $null = $queueIds.Add([string]$s.queueId) }
                    foreach ($seg in @($s.segments)) {
                        if ($seg.queueId) { $null = $queueIds.Add([string]$seg.queueId) }
                    }
                }
            }

            $sanitized = Sanitize-ConvoDetail -Detail $c

            $record = [ordered]@{
                Type          = 'conversation.details'
                Interval      = $Interval
                ConversationId= $convId
                DivisionId    = $divisionId
                QueueIds      = @($queueIds)
                AgentIds      = @($agentIds)
                Source        = 'jobs.analytics.conversations.details'
                CreatedUtc    = (Get-Date).ToUniversalTime().ToString('o')
                Content       = $sanitized
            }

            ($record | ConvertTo-Json -Depth 10) | Add-Content -LiteralPath $store -Encoding utf8
            $written++
        }

        if ($convs.Count -lt $PageSize) { break }
        $page++
        if ($ThrottleMilliseconds -gt 0) { Start-Sleep -Milliseconds $ThrottleMilliseconds }
    }

    $result = [pscustomobject]@{
        JobId         = $jobId
        Interval      = $Interval
        RecordsWritten= $written
        StorePath     = $store
    }

    Write-IngestAuditLog "Ingest interval=$Interval jobId=$jobId records=$written store=$store"
    return $result
}
