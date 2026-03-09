function Get-GCDefaultAnalyticsInterval {
    param(
        [int]$Minutes = 30
    )

    if ($Minutes -lt 1) { $Minutes = 1 }
    $end = (Get-Date).ToUniversalTime()
    $start = $end.AddMinutes(-1 * $Minutes)
    return ("{0}/{1}" -f $start.ToString('yyyy-MM-ddTHH:mm:ss.fffZ'), $end.ToString('yyyy-MM-ddTHH:mm:ss.fffZ'))
}

function Normalize-GCAnalyticsInterval {
    param(
        [Parameter(Mandatory)]
        [string]$Interval
    )

    $value = $Interval.Trim()
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "Interval is required."
    }

    $parts = $value -split '/'
    if ($parts.Count -ne 2) {
        throw "Interval must be in the form start/end (UTC), e.g. 2025-12-01T00:00:00.000Z/2025-12-08T00:00:00.000Z"
    }

    $start = [datetimeoffset]::Parse($parts[0].Trim(), [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal).ToUniversalTime()
    $end = [datetimeoffset]::Parse($parts[1].Trim(), [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal).ToUniversalTime()
    if ($end -le $start) { throw "Interval end must be greater than start." }

    return ("{0}/{1}" -f $start.ToString('yyyy-MM-ddTHH:mm:ss.fffZ'), $end.ToString('yyyy-MM-ddTHH:mm:ss.fffZ'))
}

function Get-GCRoutingSkillNameMap {
    param(
        [string[]]$SkillIds
    )

    $map = @{}
    $unique = @($SkillIds | Where-Object { $_ } | ForEach-Object { [string]$_ } | Sort-Object -Unique)
    if ($unique.Count -eq 0) { return $map }

    $batchSize = 50
    for ($i = 0; $i -lt $unique.Count; $i += $batchSize) {
        $batch = $unique[$i..([Math]::Min($i + $batchSize - 1, $unique.Count - 1))]
        $qs = ($batch | ForEach-Object { "id=$([uri]::EscapeDataString($_))" }) -join '&'
        $path = "/api/v2/routing/skills?pageSize=100&$qs"
        try {
            $resp = Invoke-GCRequest -Method 'GET' -Path $path
            $entities = @()
            try { $entities = @($resp.entities) } catch { $entities = @() }
            foreach ($ent in $entities) {
                $id = $null
                $name = $null
                try { $id = [string]$ent.id } catch { $id = $null }
                try { $name = [string]$ent.name } catch { $name = $null }
                if ($id -and $name) { $map[$id] = $name }
            }
        }
        catch {
            Write-Verbose -Message "Get-GCRoutingSkillNameMap failed: $($_.Exception.Message)"
        }
    }

    return $map
}

function Get-GCQueueMembersWithSkills {
    param(
        [Parameter(Mandatory)]
        [string]$QueueId
    )

    $members = @()
    $page = 1
    $pageSize = 100
    $maxPages = 25

    for ($i = 0; $i -lt $maxPages; $i++) {
        $path = "/api/v2/routing/queues/$QueueId/members?pageSize=$pageSize&pageNumber=$page&sortOrder=asc&expand=skills&expand=routingStatus&expand=presence"
        $resp = Invoke-GCRequest -Method 'GET' -Path $path
        $entities = @()
        try { $entities = @($resp.entities) } catch { $entities = @() }

        foreach ($entity in $entities) {
            $userObj = $null
            if ($entity.PSObject.Properties.Name -contains 'member' -and $entity.member) { $userObj = $entity.member }
            elseif ($entity.PSObject.Properties.Name -contains 'user' -and $entity.user) { $userObj = $entity.user }
            else { $userObj = $entity }

            $userId = $null
            $userName = $null
            try { $userId = [string]$userObj.id } catch { $userId = $null }
            try { $userName = [string]$userObj.name } catch { $userName = $null }
            if ([string]::IsNullOrWhiteSpace($userId)) { continue }
            if ([string]::IsNullOrWhiteSpace($userName)) { $userName = $userId }

            $skillIds = @()
            foreach ($s in @($userObj.skills)) {
                if (-not $s) { continue }
                $sid = $null
                try { $sid = [string]$s.id } catch { $sid = $null }
                if (-not $sid) {
                    try { $sid = [string]$s.skillId } catch { $sid = $null }
                }
                if ($sid) { $skillIds += $sid }
            }

            $routingStatus = $null
            try {
                if ($entity.PSObject.Properties.Name -contains 'routingStatus') { $routingStatus = $entity.routingStatus }
                elseif ($userObj.PSObject.Properties.Name -contains 'routingStatus') { $routingStatus = $userObj.routingStatus }
            }
            catch { $routingStatus = $null }

            $presence = $null
            try {
                if ($entity.PSObject.Properties.Name -contains 'presence') { $presence = $entity.presence }
                elseif ($userObj.PSObject.Properties.Name -contains 'presence') { $presence = $userObj.presence }
            }
            catch { $presence = $null }

            $members += [pscustomobject]@{
                    UserId        = $userId
                    Name          = $userName
                    SkillIds      = $skillIds
                    RoutingStatus = $routingStatus
                    Presence      = $presence
                }
        }

        $pageCount = 0
        try { $pageCount = [int]$resp.pageCount } catch { $pageCount = 0 }
        if ($pageCount -le 0 -and $entities.Count -lt $pageSize) { break }
        if ($pageCount -gt 0 -and $page -ge $pageCount) { break }
        if ($entities.Count -lt $pageSize) { break }
        $page++
    }

    return @($members)
}

function Get-GCConversationRequiredRoutingSkillIds {
    param(
        [Parameter(Mandatory)]
        $Conversation
    )

    $ids = New-Object System.Collections.Generic.HashSet[string] ([StringComparer]::OrdinalIgnoreCase)

    $participants = @()
    try { $participants = @($Conversation.participants) } catch { $participants = @() }
    foreach ($p in $participants) {
        if (-not $p) { continue }
        $segments = @()
        try { $segments = @($p.segments) } catch { $segments = @() }
        foreach ($seg in $segments) {
            if (-not $seg) { continue }
            foreach ($propName in @('requestedRoutingSkillIds', 'routingSkillIds', 'requestedSkillIds')) {
                if (-not ($seg.PSObject.Properties.Name -contains $propName)) { continue }
                foreach ($v in @($seg.$propName)) {
                    $text = [string]$v
                    if ($text -match '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') { [void]$ids.Add($text) }
                }
            }
        }
    }

    return @($ids)
}

function Get-GCQueueWaitingConversations {
    param(
        [Parameter(Mandatory)]
        [string]$QueueId,

        [Parameter(Mandatory)]
        [string]$Interval
    )

    $body = @{
        interval = $Interval
        order    = 'asc'
        orderBy  = 'conversationStart'
        paging   = @{
            pageSize   = 250
            pageNumber = 1
        }
        conversationFilters = @(
            @{
                type       = 'or'
                predicates = @(
                    @{
                        dimension = 'queueId'
                        value     = $QueueId
                    }
                )
            }
        )
        segmentFilters = @()
    }

    $resp = Invoke-GCRequest -Method 'POST' -Path '/api/v2/analytics/conversations/details/query' -Body $body
    $conversations = @()
    try { $conversations = @($resp.conversations) } catch { $conversations = @() }

    $waiting = @()
    foreach ($c in $conversations) {
        if (-not $c) { continue }
        $end = $null
        try { $end = $c.conversationEnd } catch { $end = $null }
        if ($end) { continue }
        $waiting += $c
    }

    return @($waiting)
}
