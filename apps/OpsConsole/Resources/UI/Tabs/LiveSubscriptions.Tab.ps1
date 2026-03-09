### BEGIN FILE: apps\OpsConsole\Resources\UI\Tabs\LiveSubscriptions.Tab.ps1
# Live Subscriptions + Operational Events tab helpers (script scope).

function Add-LiveSubscriptionEvent {
    param([pscustomobject]$Entry)

    if (-not $Entry) { return }
    $parsed = $Entry.Parsed
    $timestamp = if ($parsed -and $parsed.timestamp) {
        [DateTime]::Parse($parsed.timestamp).ToString("yyyy-MM-dd HH:mm:ss")
    }
    else {
        $Entry.Timestamp.ToString("yyyy-MM-dd HH:mm:ss")
    }
    $topic = if ($parsed -and $parsed.topicName) { $parsed.topicName } else { $parsed?.topic }
    $eventType = if ($parsed -and $parsed.eventType) { $parsed.eventType } else { $null }
    $message = ''
    if ($parsed) {
        if ($parsed.message) { $message = $parsed.message }
        elseif ($parsed.body) { $message = ($parsed.body | ConvertTo-Json -Depth 3) }
    }
    if (-not $message -and $Entry.Raw) { $message = $Entry.Raw }

    $display = [pscustomobject]@{
        Timestamp = $timestamp
        Topic     = $topic
        EventType = $eventType
        Summary   = if ($message -and $message.Length -gt 200) { $message.Substring(0, 200) + '...' } else { $message }
    }

    $script:LiveSubscriptionEvents.Add($display) | Out-Null
    if ($script:LiveSubscriptionEvents.Count -gt 400) {
        $script:LiveSubscriptionEvents.RemoveAt(0)
    }
}

function Resolve-NotificationRecords {
    param([pscustomobject]$Entry)

    if (-not $Entry) { return @() }

    $payload = $Entry.Parsed
    if (-not $payload -and $Entry.Raw) {
        try { $payload = $Entry.Raw | ConvertFrom-Json -Depth 5 } catch { $payload = $null }
    }

    if (-not $payload) { return @() }

    $records = @()
    if ($payload.PSObject.Properties.Name -contains 'entities') {
        $records = @($payload.entities)
    }
    elseif ($payload.PSObject.Properties.Name -contains 'data') {
        $records = @($payload.data)
    }
    elseif ($payload.PSObject.Properties.Name -contains 'body') {
        $records = @($payload.body)
    }
    elseif ($payload -is [System.Collections.IEnumerable] -and -not ($payload -is [string])) {
        $records = @($payload)
    }
    else {
        $records = @($payload)
    }

    return $records | Where-Object { $_ -ne $null }
}

function Add-OperationalEventEntry {
    param(
        [Parameter(Mandatory)]
        $Record,
        [array]$EventDefinitionIds
    )

    if (-not $Record) { return }

    $eventDefinitionId = $null
    if ($Record.PSObject.Properties.Name -contains 'eventDefinitionId') {
        $eventDefinitionId = $Record.eventDefinitionId
    }
    elseif ($Record.PSObject.Properties.Name -contains 'EventDefinitionId') {
        $eventDefinitionId = $Record.EventDefinitionId
    }

    if ($EventDefinitionIds -and $EventDefinitionIds.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($eventDefinitionId)) {
        if (-not ($EventDefinitionIds -contains $eventDefinitionId)) {
            return
        }
    }

    $timestampRaw = $null
    if ($Record.PSObject.Properties.Name -contains 'timestamp') {
        $timestampRaw = $Record.timestamp
    }
    elseif ($Record.PSObject.Properties.Name -contains 'Timestamp') {
        $timestampRaw = $Record.Timestamp
    }
    else {
        $timestampRaw = (Get-Date).ToString("o")
    }

    $timestamp = ''
    try { $timestamp = [DateTime]::Parse($timestampRaw).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss") } catch { $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") }

    $severity = ''
    if ($Record.PSObject.Properties.Name -contains 'severity') { $severity = $Record.severity }
    elseif ($Record.PSObject.Properties.Name -contains 'Severity') { $severity = $Record.Severity }

    $entityId = ''
    if ($Record.PSObject.Properties.Name -contains 'entityId') { $entityId = $Record.entityId }
    elseif ($Record.PSObject.Properties.Name -contains 'EntityId') { $entityId = $Record.EntityId }

    $message = ''
    if ($Record.PSObject.Properties.Name -contains 'message') {
        $message = $Record.message
    }
    elseif ($Record.PSObject.Properties.Name -contains 'Message') {
        $message = $Record.Message
    }
    else {
        try { $message = ($Record | ConvertTo-Json -Depth 3) } catch { $message = '' }
    }

    $entry = [pscustomobject]@{
        Timestamp         = $timestamp
        EventDefinitionId = $eventDefinitionId
        Severity          = $severity
        EntityId          = $entityId
        Message           = if ($message -and $message.Length -gt 250) { $message.Substring(0, 250) + '...' } else { $message }
    }

    $script:OperationalEvents.Add($entry) | Out-Null
    if ($script:OperationalEvents.Count -gt 600) {
        $script:OperationalEvents.RemoveAt(0)
    }

    if ($script:OperationalEventsRaw -isnot [System.Collections.ArrayList]) {
        $script:OperationalEventsRaw = New-Object System.Collections.ArrayList
    }
    $script:OperationalEventsRaw.Add($Record) | Out-Null
    if ($script:OperationalEventsRaw.Count -gt 1200) {
        $script:OperationalEventsRaw.RemoveAt(0)
    }
}

function Start-OperationalEventsLiveSubscription {
    param(
        [Parameter(Mandatory)]
        [string[]]$Topics,
        [Parameter()]
        [string[]]$EventDefinitionIds = @()
    )

    if (-not $Topics -or $Topics.Count -eq 0) {
        throw "At least one notification topic is required for live operational events."
    }

    $token = Get-ExplorerAccessToken
    if (-not $token) { throw "An OAuth token is required to start live operational events." }

    Stop-OperationalEventsLiveSubscription

    $channelName = "OpEventsLive_$((Get-Date).ToUniversalTime().ToString('yyyyMMddHHmmss'))"
    $chanResp = New-GCNotificationChannel -Name $channelName -ChannelType websocket -Description "Operational Event stream from API Explorer" `
        -BaseUri $ApiBaseUrl -AccessToken $token
    $channel = $chanResp.Parsed
    if (-not $channel) { $channel = ($chanResp.Content | ConvertFrom-Json -ErrorAction SilentlyContinue) }
    if (-not $channel -or -not $channel.id) {
        throw "Unable to obtain channel ID from the Notifications API."
    }

    Add-GCNotificationSubscriptions -ChannelId $channel.id -Topics $Topics -BaseUri $ApiBaseUrl -AccessToken $token | Out-Null
    $connection = Connect-GCNotificationWebSocket -ChannelId $channel.id -BaseUri $ApiBaseUrl -AccessToken $token
    $captureRoot = if ($workspaceRoot) { Join-Path -Path $workspaceRoot -ChildPath 'captures' } else { Join-Path -Path (Get-Location) -ChildPath 'captures' }
    $captureSession = Start-GCNotificationCapture -Connection $connection -CaptureRoot $captureRoot -TopicGroup 'operational' -WriteSummary

    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(500)
    $timer.Add_Tick({
        if (-not $connection -or -not $connection.Messages) { return }
        $item = $null
        while ($connection.Messages.TryDequeue([ref]$item)) {
            foreach ($record in Resolve-NotificationRecords -Entry $item) {
                Add-OperationalEventEntry -Record $record -EventDefinitionIds $EventDefinitionIds
            }
        }
    })
    $timer.Start()

    $script:OperationalEventsLiveSubscription = [pscustomobject]@{
        Channel        = $channel
        Connection     = $connection
        CaptureSession = $captureSession
        Timer          = $timer
        EventDefinitions = $EventDefinitionIds
        Topics          = $Topics
        AccessToken    = $token
        BaseUri        = $ApiBaseUrl
    }

    if ($stopOperationalEventsLiveButton) { $stopOperationalEventsLiveButton.IsEnabled = $true }
    if ($operationalEventsStatusText) {
        $operationalEventsStatusText.Text = "Live events subscribed to: $($Topics -join ', ')"
    }
}

function Stop-OperationalEventsLiveSubscription {
    if (-not $script:OperationalEventsLiveSubscription) { return }

    $session = $script:OperationalEventsLiveSubscription
    if ($session.Timer) {
        $session.Timer.Stop()
    }

    $summaryPath = $null
    try {
        $result = Stop-GCNotificationCapture -CaptureSession $session.CaptureSession -GenerateSummary
        if ($result.SummaryPath) {
            $script:OperationalEventsSummaryPath = $result.SummaryPath
            $summaryPath = $result.SummaryPath
        }
    }
    catch { }

    if ($session.Connection -and $session.Connection.CancellationTokenSource) {
        $session.Connection.CancellationTokenSource.Cancel()
    }

    try {
        if ($session.Channel -and $session.Channel.id -and $session.AccessToken) {
            if ($session.Topics -and $session.Topics.Count -gt 0) {
                Remove-GCNotificationSubscriptions -ChannelId $session.Channel.id -TopicNames $session.Topics -BaseUri $session.BaseUri -AccessToken $session.AccessToken | Out-Null
            }
            Remove-GCNotificationChannel -ChannelId $session.Channel.id -BaseUri $session.BaseUri -AccessToken $session.AccessToken | Out-Null
        }
    }
    catch { Add-LogEntry "Operational events channel cleanup failed: $($_.Exception.Message)" }

    $script:OperationalEventsLiveSubscription = $null
    if ($stopOperationalEventsLiveButton) { $stopOperationalEventsLiveButton.IsEnabled = $false }

    if ($operationalEventsStatusText) {
        $operationalEventsStatusText.Text = if ($summaryPath) { "Live capture summary saved to $summaryPath" } else { "Live operational event subscription stopped." }
    }
}

function Reset-LiveSubscriptionPresetCombo {
    if (-not $liveSubTopicPresetCombo) { return }

    $liveSubTopicPresetCombo.Items.Clear()
    $liveSubTopicPresetCombo.DisplayMemberPath = 'Label'
    $liveSubTopicPresetCombo.SelectedValuePath = 'Topic'

    foreach ($preset in $script:LiveSubscriptionPresets) {
        if (-not $preset.Topic) { continue }
        $liveSubTopicPresetCombo.Items.Add($preset) | Out-Null
    }

    if ($liveSubTopicPresetCombo.Items.Count -gt 0) {
        $liveSubTopicPresetCombo.SelectedIndex = 0
    }
}

function Cleanup-LiveSubscriptionChannel {
    if (-not $script:LiveSubscriptionSession -or -not $script:LiveSubscriptionSession.Channel) { return }

    $channelId = $script:LiveSubscriptionSession.Channel.id
    $topics = @($script:LiveSubscriptionSession.Topics)
    $token = $script:LiveSubscriptionSession.AccessToken
    if (-not $channelId -or -not $token) {
        $script:LiveSubscriptionSession = $null
        return
    }

    try {
        if ($topics -and $topics.Count -gt 0) {
            Remove-GCNotificationSubscriptions -ChannelId $channelId -TopicNames $topics -BaseUri $ApiBaseUrl -AccessToken $token | Out-Null
        }
    }
    catch { Add-LogEntry "Failed to remove notification subscriptions for channel $($channelId): $($_.Exception.Message)" }

    try {
        Remove-GCNotificationChannel -ChannelId $channelId -BaseUri $ApiBaseUrl -AccessToken $token | Out-Null
    }
    catch { Add-LogEntry "Failed to remove notification channel $($channelId): $($_.Exception.Message)" }
    finally { $script:LiveSubscriptionSession = $null }
}

function Start-LiveSubscriptionRefreshTimer {
    if ($script:LiveSubscriptionRefreshTimer -and $script:LiveSubscriptionRefreshTimer.IsEnabled) { return }

    if (-not $script:LiveSubscriptionRefreshTimer) {
        $timer = New-Object System.Windows.Threading.DispatcherTimer
        $timer.Interval = [TimeSpan]::FromMilliseconds(500)
        $timer.Add_Tick({
            if ($script:LiveSubscriptionConnection -and $script:LiveSubscriptionConnection.Messages) {
                while ($script:LiveSubscriptionConnection.Messages.TryDequeue([ref]$item)) {
                    Add-LiveSubscriptionEvent -Entry $item
                }
            }

            if ($script:LiveSubscriptionConnection -and $script:LiveSubscriptionConnection.ClosedAt) {
                if ($liveSubscriptionStatusText) {
                    $closed = $script:LiveSubscriptionConnection.ClosedAt.ToString("yyyy-MM-dd HH:mm:ss")
                    $err = if ($script:LiveSubscriptionConnection.LastError) { ": $($script:LiveSubscriptionConnection.LastError)" } else { '' }
                    $liveSubscriptionStatusText.Text = "Subscription connection closed at $closed$err"
                }
                if ($startLiveSubscriptionButton) { $startLiveSubscriptionButton.IsEnabled = $true }
                if ($stopLiveSubscriptionButton) { $stopLiveSubscriptionButton.IsEnabled = ($script:LiveSubscriptionCapture -ne $null) }
            }
        })
        $script:LiveSubscriptionRefreshTimer = $timer
    }

    $script:LiveSubscriptionRefreshTimer.Start()
}

function Stop-LiveSubscriptionRefreshTimer {
    if ($script:LiveSubscriptionRefreshTimer) {
        $script:LiveSubscriptionRefreshTimer.Stop()
    }
}

function Convert-LiveSubscriptionSummarySection {
    param([object]$Section)

    $result = [hashtable]::new()
    if (-not $Section) { return $result }

    if ($Section -is [System.Collections.IDictionary]) {
        foreach ($key in $Section.Keys) {
            $result[$key] = $Section[$key]
        }
        return $result
    }

    if ($Section -is [pscustomobject]) {
        foreach ($prop in $Section.PSObject.Properties) {
            $result[$prop.Name] = $prop.Value
        }
        return $result
    }

    try {
        $wrapper = $Section | ConvertTo-Json -Depth 5 | ConvertFrom-Json
        foreach ($prop in $wrapper.PSObject.Properties) {
            $result[$prop.Name] = $prop.Value
        }
    }
    catch { }

    return $result
}

function Reload-LiveSubscriptionSummaryFromFile {
    if (-not $script:LiveSubscriptionLastSummaryPath) { return $script:LiveSubscriptionLastSummary }
    if (-not (Test-Path -LiteralPath $script:LiveSubscriptionLastSummaryPath)) { return $script:LiveSubscriptionLastSummary }

    $item = Get-Item -LiteralPath $script:LiveSubscriptionLastSummaryPath -ErrorAction SilentlyContinue
    if (-not $item) { return $script:LiveSubscriptionLastSummary }

    $stamp = $item.LastWriteTimeUtc
    if ($script:LiveSubscriptionSummaryFileStamp -and $script:LiveSubscriptionSummaryFileStamp -eq $stamp -and $script:LiveSubscriptionLastSummary) {
        return $script:LiveSubscriptionLastSummary
    }

    try {
        $json = Get-Content -LiteralPath $script:LiveSubscriptionLastSummaryPath -Raw -Encoding utf8
        $summary = $json | ConvertFrom-Json -Depth 5
        $script:LiveSubscriptionLastSummary = $summary
        $script:LiveSubscriptionSummaryFileStamp = $stamp
        return $summary
    }
    catch {
        Add-LogEntry "Live subscription summary reload failed: $($_.Exception.Message)"
        return $script:LiveSubscriptionLastSummary
    }
}

function Get-LiveSubscriptionSummaryData {
    if ($script:LiveSubscriptionCapture -and $script:LiveSubscriptionCapture.Summary) {
        return $script:LiveSubscriptionCapture.Summary
    }

    return Reload-LiveSubscriptionSummaryFromFile
}

function Update-LiveSubscriptionAnalyticsCollections {
    param(
        [hashtable]$Topics,
        [hashtable]$Events
    )

    if ($script:LiveSubscriptionTopicTotals) {
        $script:LiveSubscriptionTopicTotals.Clear()
        foreach ($entry in ($Topics.GetEnumerator() | Sort-Object @{ Expression = { $_.Value }; Descending = $true } | Select-Object -First 8)) {
            $script:LiveSubscriptionTopicTotals.Add([pscustomobject]@{
                Topic = [string]$entry.Key
                Count = $entry.Value
            }) | Out-Null
        }
    }

    if ($script:LiveSubscriptionEventTypeTotals) {
        $script:LiveSubscriptionEventTypeTotals.Clear()
        foreach ($entry in ($Events.GetEnumerator() | Sort-Object @{ Expression = { $_.Value }; Descending = $true } | Select-Object -First 8)) {
            $script:LiveSubscriptionEventTypeTotals.Add([pscustomobject]@{
                EventType = [string]$entry.Key
                Count     = $entry.Value
            }) | Out-Null
        }
    }
}

function Refresh-LiveSubscriptionAnalytics {
    $summary = Get-LiveSubscriptionSummaryData
    if (-not $summary) {
        if ($script:LiveSubscriptionAnalyticsStatusText) {
            $script:LiveSubscriptionAnalyticsStatusText.Text = "No live summary available yet."
        }
        return
    }

    $topics = Convert-LiveSubscriptionSummarySection -Section $summary.Topics
    $events = Convert-LiveSubscriptionSummarySection -Section $summary.Events

    Update-LiveSubscriptionAnalyticsCollections -Topics $topics -Events $events

    if ($script:LiveSubscriptionAnalyticsStatusText) {
        $topicTotal = ($topics.Values | Measure-Object -Sum).Sum
        $eventTotal = ($events.Values | Measure-Object -Sum).Sum
        $topicCount = $topics.Count
        $eventCount = $events.Count
        $updatedText = "Updated {0:T}: {1} topics / {2} events" -f (Get-Date), $topicTotal, $eventTotal
        $script:LiveSubscriptionAnalyticsStatusText.Text = $updatedText
    }
}

function Start-LiveSubscriptionAnalyticsTimer {
    if ($script:LiveSubscriptionAnalyticsTimer -and $script:LiveSubscriptionAnalyticsTimer.IsEnabled) {
        return
    }

    if (-not $script:LiveSubscriptionAnalyticsTimer) {
        $timer = New-Object System.Windows.Threading.DispatcherTimer
        $timer.Interval = [TimeSpan]::FromSeconds(6)
        $timer.Add_Tick({
            Invoke-RefreshLiveSubscriptionAnalyticsSafe
        })
        $script:LiveSubscriptionAnalyticsTimer = $timer
    }

    Invoke-RefreshLiveSubscriptionAnalyticsSafe
    $script:LiveSubscriptionAnalyticsTimer.Start()
}

function Stop-LiveSubscriptionAnalyticsTimer {
    if ($script:LiveSubscriptionAnalyticsTimer) {
        $script:LiveSubscriptionAnalyticsTimer.Stop()
    }
}

function Get-LiveSubscriptionTopicNameFromItem {
    param([object]$Item)

    if (-not $Item) { return $null }
    foreach ($prop in $Item.PSObject.Properties) {
        if ($prop.Name -in @('Name','name','Topic','topic','topicName','TopicName')) {
            $value = $prop.Value
            if (-not [string]::IsNullOrWhiteSpace($value)) {
                return [string]$value
            }
        }
    }

    return $null
}

function Set-LiveSubscriptionTopicCatalogStatus {
    param([string]$Message)

    if ($script:LiveSubscriptionTopicCatalogStatusText) {
        $script:LiveSubscriptionTopicCatalogStatusText.Text = $Message
    }
}

function Get-AudioHookTopicsFromCatalog {
    return @($script:LiveSubscriptionTopicCatalog | Where-Object { $_.Name -match 'audiohook' } | Select-Object -ExpandProperty Name)
}

function Resolve-LiveSubscriptionTopics {
    param(
        [Parameter(Mandatory)]
        [string[]]$Topics
    )

    $resolved = @()
    $audioHookAvailable = Get-AudioHookTopicsFromCatalog
    $didExpandAudioHook = $false

    foreach ($topic in $Topics) {
        $clean = [string]$topic
        if ([string]::IsNullOrWhiteSpace($clean)) { continue }

        if ($clean -eq 'v2.audiohook' -and $audioHookAvailable.Count -gt 0) {
            $resolved += $audioHookAvailable
            $didExpandAudioHook = $true
            continue
        }
        $resolved += $clean
    }

    $resolved = $resolved | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique
    if ($didExpandAudioHook -and $liveSubscriptionStatusText) {
        $liveSubscriptionStatusText.Text = "Expanded AudioHook preset to: $($audioHookAvailable -join ', ')"
    }
    if ($didExpandAudioHook) {
        Add-LogEntry "AudioHook preset expanded to: $($audioHookAvailable -join ', ')"
    }

    return $resolved
}

function Refresh-LiveSubscriptionTopicCatalog {
    param([switch]$Force)

    $token = Get-ExplorerAccessToken
    if (-not $token) {
        Set-LiveSubscriptionTopicCatalogStatus "Provide an OAuth token to refresh topics."
        return
    }

    Set-LiveSubscriptionTopicCatalogStatus "Refreshing topics..."
    try {
        $result = Get-GCNotificationTopics -BaseUri $ApiBaseUrl -AccessToken $token
        $payload = $result.Parsed
        if (-not $payload -and $result.Content) {
            try {
                $payload = $result.Content | ConvertFrom-Json -Depth 5
            }
            catch {
                $payload = $null
            }
        }

        $entities = @()
        if ($payload) {
            if ($payload.entities) {
                $entities = $payload.entities
            }
            elseif ($payload.topics) {
                $entities = $payload.topics
            }
        }

        if (-not $entities -and $result.Parsed -and $result.Parsed.entities) {
            $entities = $result.Parsed.entities
        }

        $script:LiveSubscriptionTopicCatalog.Clear()
        foreach ($topic in @($entities)) {
            $name = Get-LiveSubscriptionTopicNameFromItem -Item $topic
            if (-not $name) { continue }
            $description = if ($topic.description) { $topic.description } else { '' }
            $script:LiveSubscriptionTopicCatalog.Add([pscustomobject]@{
                    Name        = $name
                    Description = [string]$description
                }) | Out-Null
        }

        $script:AudioHookTopics = Get-AudioHookTopicsFromCatalog
        foreach ($topic in $script:AudioHookTopics) {
            if (-not ($script:LiveSubscriptionPresets | Where-Object { $_.Topic -eq $topic })) {
                $script:LiveSubscriptionPresets += [pscustomobject]@{ Label = "AudioHook: $topic"; Topic = $topic }
            }
        }
        Reset-LiveSubscriptionPresetCombo

        $count = $script:LiveSubscriptionTopicCatalog.Count
        $script:LiveSubscriptionTopicCatalogLastUpdated = Get-Date
        $message = "Loaded $count topics (last refreshed {0:T})." -f $script:LiveSubscriptionTopicCatalogLastUpdated
        Set-LiveSubscriptionTopicCatalogStatus $message
    }
    catch {
        $err = $_.Exception.Message
        Set-LiveSubscriptionTopicCatalogStatus "Failed to refresh topics: $err"
        Add-LogEntry "Live subscription topic refresh failed: $err"
    }
}

function Load-LiveSubscriptionTopicCatalogCache {
    if (-not $script:LiveSubscriptionTopicCatalogCachePath) { return }
    if (-not (Test-Path -LiteralPath $script:LiveSubscriptionTopicCatalogCachePath)) { return }

    try {
        $content = Get-Content -LiteralPath $script:LiveSubscriptionTopicCatalogCachePath -Raw -Encoding utf8
        $json = $content | ConvertFrom-Json -Depth 5
        $items = @()
        if ($json -and $json.PSObject.Properties.Name -contains 'topics') {
            $items = @($json.topics)
        }
        elseif ($json -and $json.PSObject.Properties.Name -contains 'entities') {
            $items = @($json.entities)
        }
        elseif ($json -is [System.Collections.IEnumerable]) {
            $items = @($json)
        }

        foreach ($topic in @($items)) {
            $name = Get-LiveSubscriptionTopicNameFromItem -Item $topic
            if (-not $name) { continue }
            $description = if ($topic.description) { $topic.description } elseif ($topic.topicDescription) { $topic.topicDescription } else { '' }
            $script:LiveSubscriptionTopicCatalog.Add([pscustomobject]@{
                    Name        = $name
                    Description = [string]$description
                }) | Out-Null
        }

        $script:AudioHookTopics = Get-AudioHookTopicsFromCatalog
        foreach ($topic in $script:AudioHookTopics) {
            if (-not ($script:LiveSubscriptionPresets | Where-Object { $_.Topic -eq $topic })) {
                $script:LiveSubscriptionPresets += [pscustomobject]@{ Label = "AudioHook: $topic"; Topic = $topic }
            }
        }
        Reset-LiveSubscriptionPresetCombo

        if ($script:LiveSubscriptionTopicCatalogStatusText) {
            $count = $script:LiveSubscriptionTopicCatalog.Count
            $script:LiveSubscriptionTopicCatalogStatusText.Text = "Loaded $count cached topics."
        }
    }
    catch {
        Add-LogEntry "Failed to load cached topics: $($_.Exception.Message)"
    }
}

function Build-OperationalEventsSummaryTables {
    param(
        [Parameter(Mandatory)]
        [array]$Events
    )

    $defCounts = @{}
    $severityCounts = @{}
    $timeline = @{}
    $entityCounts = @{}

    foreach ($event in $Events) {
        $defId = if ($event.EventDefinitionId) { $event.EventDefinitionId } elseif ($event.eventDefinitionId) { $event.eventDefinitionId } else { 'unknown' }
        $defCounts[$defId] = ($defCounts[$defId] + 1)

        $severity = if ($event.Severity) { $event.Severity } elseif ($event.severity) { $event.severity } else { 'unknown' }
        $severityCounts[$severity] = ($severityCounts[$severity] + 1)

        $ts = if ($event.Timestamp) {
            [DateTime]::Parse($event.Timestamp)
        }
        elseif ($event.timestamp) {
            [DateTime]::Parse($event.timestamp)
        }
        else {
            (Get-Date)
        }
        $key = $ts.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm")
        $timeline[$key] = ($timeline[$key] + 1)

        $entity = if ($event.EntityId) { $event.EntityId } elseif ($event.entityId) { $event.entityId } else { '' }
        if ($entity) {
            $entityCounts[$entity] = ($entityCounts[$entity] + 1)
        }
    }

    $tables = @()
    $tables += [pscustomobject]@{
        Title = 'Event Definition Totals'
        Headers = @('EventDefinitionId','Count')
        Rows = $defCounts.Keys | Sort-Object | ForEach-Object { [pscustomobject]@{ EventDefinitionId = $_; Count = $defCounts[$_] } }
    }
    $tables += [pscustomobject]@{
        Title = 'Severity Totals'
        Headers = @('Severity','Count')
        Rows = $severityCounts.Keys | Sort-Object | ForEach-Object { [pscustomobject]@{ Severity = $_; Count = $severityCounts[$_] } }
    }
    $tables += [pscustomobject]@{
        Title = 'Timeline (per minute)'
        Headers = @('Minute','Count')
        Rows = $timeline.Keys | Sort-Object | ForEach-Object { [pscustomobject]@{ Minute = $_; Count = $timeline[$_] } }
    }
    $tables += [pscustomobject]@{
        Title = 'Top Entities'
        Headers = @('EntityId','Count')
        Rows = $entityCounts.Keys | Sort-Object -Descending | ForEach-Object { [pscustomobject]@{ EntityId = $_; Count = $entityCounts[$_] } }
    }

    return $tables
}

function Build-LiveSubscriptionSummaryTables {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Summary
    )

    $topics = @()
    foreach ($k in $Summary.Topics.Keys | Sort-Object) {
        $topics += [pscustomobject]@{ Topic = $k; Count = $Summary.Topics[$k] }
    }

    $events = @()
    foreach ($k in $Summary.Events.Keys | Sort-Object) {
        $events += [pscustomobject]@{ EventType = $k; Count = $Summary.Events[$k] }
    }

    $timeline = @()
    foreach ($k in $Summary.Timeline.Keys | Sort-Object) {
        $timeline += [pscustomobject]@{ Minute = $k; Count = $Summary.Timeline[$k] }
    }

    $entities = @()
    foreach ($k in $Summary.Entities.Keys | Sort-Object) {
        $entities += [pscustomobject]@{ Entity = $k; Count = $Summary.Entities[$k] }
    }

    $tables = @(
        [pscustomobject]@{
            Title = 'Topic Totals'
            Headers = @('Topic','Count')
            Rows = $topics
        },
        [pscustomobject]@{
            Title = 'Event Type Totals'
            Headers = @('EventType','Count')
            Rows = $events
        },
        [pscustomobject]@{
            Title = 'Timeline (per minute)'
            Headers = @('Minute','Count')
            Rows = $timeline
        },
        [pscustomobject]@{
            Title = 'Top Entities'
            Headers = @('Entity','Count')
            Rows = $entities
        }
    )

    $conversationRows = @()
    foreach ($row in $entities) {
        if ($row.Entity -match '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') {
            $conversationRows += $row
        }
    }
    if ($conversationRows.Count -gt 0) {
        $tables += [pscustomobject]@{
            Title   = 'Conversation IDs'
            Headers = @('ConversationId','Count')
            Rows    = $conversationRows
        }
    }

    return $tables
}

function Build-AudioHookRollupTables {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Summary
    )

    if (-not $Summary) { return @() }
    $topicMatches = @()
    foreach ($k in $Summary.Topics.Keys | Where-Object { $_ -match 'audiohook' } | Sort-Object) {
        $topicMatches += [pscustomobject]@{ Topic = $k; Count = $Summary.Topics[$k] }
    }

    $eventMatches = @()
    foreach ($k in $Summary.Events.Keys | Where-Object { $_ -match 'audiohook' } | Sort-Object) {
        $eventMatches += [pscustomobject]@{ EventType = $k; Count = $Summary.Events[$k] }
    }

    if ($topicMatches.Count -eq 0 -and $eventMatches.Count -eq 0) { return @() }

    $tables = @()
    if ($topicMatches.Count -gt 0) {
        $tables += [pscustomobject]@{
            Title   = 'AudioHook Topics'
            Headers = @('Topic','Count')
            Rows    = $topicMatches
        }
    }
    if ($eventMatches.Count -gt 0) {
        $tables += [pscustomobject]@{
            Title   = 'AudioHook Event Types'
            Headers = @('EventType','Count')
            Rows    = $eventMatches
        }
    }

    $convRows = @()
    foreach ($k in $Summary.Entities.Keys | Where-Object { $_ -match 'audiohook' -or $_ -match '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' } | Sort-Object) {
        $convRows += [pscustomobject]@{ ConversationId = $k; Count = $Summary.Entities[$k] }
    }
    if ($convRows.Count -gt 0) {
        $tables += [pscustomobject]@{
            Title   = 'AudioHook Conversations'
            Headers = @('ConversationId','Count')
            Rows    = $convRows
        }
    }

    return $tables
}
### END FILE: apps\OpsConsole\Resources\UI\Tabs\LiveSubscriptions.Tab.ps1
