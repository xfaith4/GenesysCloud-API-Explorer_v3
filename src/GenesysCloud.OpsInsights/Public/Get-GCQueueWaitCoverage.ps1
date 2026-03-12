### BEGIN FILE: src\GenesysCloud.OpsInsights\Public\Get-GCQueueWaitCoverage.ps1
function Get-GCQueueWaitCoverage {
    <#
        .SYNOPSIS
            Returns waiting conversations and eligible agents for a queue.

        .PARAMETER QueueId
            Queue identifier to query analytics/conversations/details for.

        .PARAMETER Interval
            ISO interval string (start/end). Defaults to last 30 minutes when omitted.

        .PARAMETER DefaultMinutes
            Minutes to include when -Interval is not provided (defaults to 30).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$QueueId,

        [Parameter()]
        [string]$Interval,

        [int]$DefaultMinutes = 30
    )

    $effectiveInterval = if ([string]::IsNullOrWhiteSpace($Interval)) {
        Get-GCDefaultAnalyticsInterval -Minutes $DefaultMinutes
    }
    else {
        $Interval
    }
    $normalizedInterval = Normalize-GCAnalyticsInterval -Interval $effectiveInterval

    $members = @(Get-GCQueueMembersWithSkills -QueueId $QueueId)
    $waitingConversations = @(Get-GCQueueWaitingConversations -QueueId $QueueId -Interval $normalizedInterval)

    $allSkillIds = @()
    $convSkillMap = @{}
    foreach ($m in $members) {
        foreach ($sid in @($m.SkillIds)) {
            if ($sid) { $allSkillIds += [string]$sid }
        }
    }
    foreach ($c in $waitingConversations) {
        $req = @(Get-GCConversationRequiredRoutingSkillIds -Conversation $c)
        $cid = $null
        try { $cid = [string]$c.conversationId } catch { $cid = $null }
        if ($cid) { $convSkillMap[$cid] = $req }
        foreach ($sid in $req) { if ($sid) { $allSkillIds += [string]$sid } }
    }

    $skillNameMap = @{}
    if ($allSkillIds.Count -gt 0) {
        $skillNameMap = Get-GCRoutingSkillNameMap -SkillIds $allSkillIds
    }

    $results = @()
    foreach ($c in $waitingConversations) {
        $cid = $null
        try { $cid = [string]$c.conversationId } catch { $cid = $null }
        if ([string]::IsNullOrWhiteSpace($cid)) { continue }

        $waitingSince = ''
        try { $waitingSince = [datetimeoffset]::Parse([string]$c.conversationStart).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') } catch { $waitingSince = '' }

        $requiredIds = @()
        if ($convSkillMap.ContainsKey($cid)) { $requiredIds = @($convSkillMap[$cid]) }

        $requiredNames = @(
            foreach ($sid in $requiredIds) {
                if ($skillNameMap.ContainsKey($sid)) { $skillNameMap[$sid] } else { $sid }
            }
        )
        $requiredText = if ($requiredNames.Count -gt 0) { ($requiredNames -join ', ') } else { '<none found>' }

        $eligibleAgentDetails = @()
        foreach ($m in $members) {
            if ($requiredIds.Count -eq 0) {
                $eligibleAgentDetails += [pscustomobject]@{
                        UserId        = $m.UserId
                        Name          = $m.Name
                        Presence      = $m.Presence
                        RoutingStatus = $m.RoutingStatus
                    }
                continue
            }
            $hasAll = $true
            foreach ($rid in $requiredIds) {
                if (-not ($m.SkillIds -contains $rid)) { $hasAll = $false; break }
            }
            if ($hasAll) {
                $eligibleAgentDetails += [pscustomobject]@{
                        UserId        = $m.UserId
                        Name          = $m.Name
                        Presence      = $m.Presence
                        RoutingStatus = $m.RoutingStatus
                    }
            }
        }

        $eligibleNames = @($eligibleAgentDetails | ForEach-Object { $_.Name })
        $eligibleCount = $eligibleNames.Count

        $notResponding = 0
        $statusCounts = @{}
        foreach ($a in @($eligibleAgentDetails)) {
            $code = ''
            try {
                if ($a.RoutingStatus -and ($a.RoutingStatus.PSObject.Properties.Name -contains 'status')) {
                    $code = [string]$a.RoutingStatus.status
                }
            }
            catch { $code = '' }
            if ([string]::IsNullOrWhiteSpace($code)) { $code = 'unknown' }
            if (-not $statusCounts.ContainsKey($code)) { $statusCounts[$code] = 0 }
            $statusCounts[$code] = [int]$statusCounts[$code] + 1
            if ($code -match '^NOT_RESPONDING$') { $notResponding++ }
        }

        $statusSummary = if ($statusCounts.Count -eq 0) {
            ''
        }
        else {
            ($statusCounts.Keys | Sort-Object | ForEach-Object { "$_=$($statusCounts[$_])" }) -join '; '
        }

        # Confidence marker: how likely is this conversation to be served soon?
        $confidenceLevel = if ($eligibleCount -eq 0) {
            'No Coverage'
        }
        elseif ($notResponding -ge $eligibleCount) {
            'Low'
        }
        elseif ($eligibleCount -gt 0 -and $notResponding -gt ($eligibleCount / 2)) {
            'Medium'
        }
        else {
            'High'
        }

        $previewLimit = 5
        $eligibleSummary = if ($eligibleCount -eq 0) { '0' } elseif ($eligibleCount -le $previewLimit) { "${eligibleCount}: $($eligibleNames -join ', ')" } else { "${eligibleCount}: $($eligibleNames[0..($previewLimit - 1)] -join ', '), ..." }

        $results += [pscustomobject]@{
            ConversationId        = $cid
            WaitingSinceUtc       = $waitingSince
            RequiredSkillIds      = $requiredIds
            RequiredSkills        = $requiredText
            EligibleAgentNames    = $eligibleNames
            EligibleAgents        = @($eligibleAgentDetails)
            EligibleAgentsSummary = $eligibleSummary
            EligibleStatusSummary = $statusSummary
            NotRespondingCount    = $notResponding
            ConfidenceLevel       = $confidenceLevel
        }
    }

    return @($results)
}
### END FILE: src\GenesysCloud.OpsInsights\Public\Get-GCQueueWaitCoverage.ps1
