### Module: GenesysCloud.NotificationsToolkit

$script:NotificationCaptureSessions = @{}

function Get-GCNotificationBaseUri {
    [CmdletBinding()]
    param(
        [string]$BaseUri
    )

    if (-not $BaseUri) {
        if (Get-Command -Name Get-GCContext -ErrorAction SilentlyContinue) {
            try {
                $ctx = Get-GCContext
                $BaseUri = $ctx.BaseUri
            }
            catch {
                $BaseUri = $null
            }
        }
    }

    if (-not $BaseUri) {
        $BaseUri = 'https://api.usw2.pure.cloud'
    }

    $notificationBase = $BaseUri -replace '^https://api\.', 'https://notifications.'
    if (-not ($notificationBase.StartsWith('https://'))) {
        $cleanHost = $BaseUri -replace '^https://', ''
        $notificationBase = "https://notifications.$cleanHost"
    }

    return $notificationBase.TrimEnd('/')
}

function Get-GCNotificationTopics {
    [CmdletBinding()]
    param(
        [string]$BaseUri,
        [string]$AccessToken
    )

    $notificationsUri = Get-GCNotificationBaseUri -BaseUri $BaseUri
    return Invoke-GCRequest -Method 'GET' -BaseUri $notificationsUri -AccessToken $AccessToken `
        -Path '/api/v2/notifications/topics' -AsResponse
}

function Save-GCNotificationTopicsCache {
    [CmdletBinding()]
    param(
        [string]$AccessToken,
        [string]$BaseUri,
        [string]$OutputPath = (Join-Path -Path (Get-Location) -ChildPath 'GenesysCloudNotificationTopics.json'),
        [switch]$Force
    )

    if (-not $AccessToken) {
        throw "Access token is required to retrieve notification topics."
    }

    $response = Get-GCNotificationTopics -BaseUri $BaseUri -AccessToken $AccessToken

    $payload = $response.Parsed
    if (-not $payload -and $response.Content) {
        try {
            $payload = $response.Content | ConvertFrom-Json -Depth 5
        }
        catch {
            $payload = $null
        }
    }

    if (-not $payload) {
        throw "Failed to parse notification topics from the response."
    }

    $topics = @()
    if ($payload.PSObject.Properties.Name -contains 'entities') {
        $topics = @($payload.entities)
    }
    elseif ($payload.PSObject.Properties.Name -contains 'topics') {
        $topics = @($payload.topics)
    }
    elseif ($payload -is [System.Collections.IEnumerable]) {
        $topics = @($payload)
    }

    if ($topics.Count -eq 0) {
        throw "No notification topics were returned from the API."
    }

    $cache = [ordered]@{
        topics = $topics
        generatedUtc = (Get-Date).ToUniversalTime().ToString("o")
    }

    $directory = Split-Path -Parent $OutputPath
    if (-not $directory) {
        $directory = (Get-Location)
    }
    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    if ((Test-Path -LiteralPath $OutputPath) -and (-not $Force)) {
        $existing = Get-Item -LiteralPath $OutputPath -ErrorAction SilentlyContinue
        if ($existing -and ($existing.LastWriteTimeUtc -gt (Get-Date).AddMinutes(-5))) {
            Write-Verbose "Cache already exists and Force was not specified."
        }
    }

    ($cache | ConvertTo-Json -Depth 5) | Set-Content -LiteralPath $OutputPath -Encoding utf8
    return $OutputPath
}

function New-GCNotificationChannel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [string]$Description,
        [ValidateSet('websocket','comet','iframedirect','webhook')]
        [string]$ChannelType = 'websocket',
        [hashtable]$Config,
        [string]$BaseUri,
        [string]$AccessToken
    )

    $body = @{
        name = $Name
        type = $ChannelType
    }

    if ($Description) { $body.description = $Description }
    if ($Config -and $Config.Count -gt 0) { $body.config = $Config }

    $notificationsUri = Get-GCNotificationBaseUri -BaseUri $BaseUri
    return Invoke-GCRequest -Method 'POST' -BaseUri $notificationsUri -AccessToken $AccessToken `
        -Path '/api/v2/notifications/channels' -Body $body -AsResponse
}

function Add-GCNotificationSubscriptions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ChannelId,
        [Parameter(Mandatory)]
        [string[]]$Topics,
        [string]$BaseUri,
        [string]$AccessToken
    )

    $payload = @{
        channelId = $ChannelId
        topics = @()
    }

    foreach ($topic in $Topics) {
        $clean = [string]$topic
        if ([string]::IsNullOrWhiteSpace($clean)) { continue }
        $payload.topics += @{ topicName = $clean.Trim() }
    }

    if ($payload.topics.Count -eq 0) {
        throw "At least one topic must be specified."
    }

    $notificationsUri = Get-GCNotificationBaseUri -BaseUri $BaseUri
    return Invoke-GCRequest -Method 'POST' -BaseUri $notificationsUri -AccessToken $AccessToken `
        -Path "/api/v2/notifications/channels/$ChannelId/subscriptions" -Body $payload -AsResponse
}

function Remove-GCNotificationSubscriptions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ChannelId,
        [string[]]$TopicNames,
        [string[]]$SubscriptionIds,
        [string]$BaseUri,
        [string]$AccessToken
    )

    $notificationsUri = Get-GCNotificationBaseUri -BaseUri $BaseUri

    if ($SubscriptionIds -and $SubscriptionIds.Count -gt 0) {
        $results = [System.Collections.ArrayList]::new()
        foreach ($subId in $SubscriptionIds) {
            if ([string]::IsNullOrWhiteSpace($subId)) { continue }
            $resp = Invoke-GCRequest -Method 'DELETE' -BaseUri $notificationsUri -AccessToken $AccessToken `
                -Path "/api/v2/notifications/channels/$ChannelId/subscriptions/$subId" -AsResponse
            [void]$results.Add($resp)
        }
        return $results
    }

    if ($TopicNames -and $TopicNames.Count -gt 0) {
        $payload = @{
            topics = @()
        }
        foreach ($topic in $TopicNames) {
            $clean = [string]$topic
            if ([string]::IsNullOrWhiteSpace($clean)) { continue }
            $payload.topics += @{ topicName = $clean.Trim() }
        }

        if ($payload.topics.Count -eq 0) {
            throw "No valid topics provided for removal."
        }

        return Invoke-GCRequest -Method 'DELETE' -BaseUri $notificationsUri -AccessToken $AccessToken `
            -Path "/api/v2/notifications/channels/$ChannelId/subscriptions" -Body $payload -AsResponse
    }

    throw "Provide either TopicNames or SubscriptionIds to remove."
}

function Connect-GCNotificationWebSocket {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$ChannelId,
        [string]$BaseUri,
        [string]$AccessToken,
        [int]$ReceiveBufferSize = 8192,
        [int]$KeepAliveSeconds = 20
    )

    if (-not $ChannelId) { throw "ChannelId is required." }

    $notificationsUri = Get-GCNotificationBaseUri -BaseUri $BaseUri
    $wssUri = ($notificationsUri -replace '^https://', 'wss://').TrimEnd('/')
    $endpoint = "$wssUri/v2/notifications/channels/$ChannelId"

    $client = [System.Net.WebSockets.ClientWebSocket]::new()
    if ($KeepAliveSeconds -gt 0) {
        $client.Options.KeepAliveInterval = [TimeSpan]::FromSeconds($KeepAliveSeconds)
    }
    if ($AccessToken) {
        $client.Options.SetRequestHeader('Authorization', "Bearer $AccessToken")
    }
    $client.Options.SetRequestHeader('Accept', 'application/json')

    try {
        $client.ConnectAsync([System.Uri]$endpoint, [System.Threading.CancellationToken]::None).GetAwaiter().GetResult()
    }
    catch {
        throw "Failed to connect to notification websocket: $($_.Exception.Message)"
    }

    $queue = [System.Collections.Concurrent.ConcurrentQueue[psobject]]::new()
    $cts = [System.Threading.CancellationTokenSource]::new()
    $receiverAction = [System.Action]{
        $buffer = New-Object byte[] $ReceiveBufferSize
        $builder = New-Object System.Text.StringBuilder

        while (-not $cts.IsCancellationRequested) {
            try {
                $result = $client.ReceiveAsync($buffer, $cts.Token).GetAwaiter().GetResult()
            }
            catch {
                $connectionState.LastError = $_.Exception.Message
                $connectionState.ClosedAt = Get-Date
                $queue.Enqueue([pscustomobject]@{
                    Timestamp = (Get-Date)
                    Error     = $_.Exception.Message
                })
                break
            }

            if ($result.MessageType -eq [System.Net.WebSockets.WebSocketMessageType]::Close) {
                $connectionState.ClosedAt = Get-Date
                break
            }

            $segment = [System.Text.Encoding]::UTF8.GetString($buffer, 0, $result.Count)
            $builder.Append($segment) | Out-Null

            if ($result.EndOfMessage) {
                $payload = $builder.ToString()
                $builder.Clear()
                $parsed = $null
                try {
                    $parsed = $payload | ConvertFrom-Json -ErrorAction Stop
                }
                catch {
                    $parsed = $payload
                }

                $queue.Enqueue([pscustomobject]@{
                    Timestamp = (Get-Date)
                    Raw       = $payload
                    Parsed    = $parsed
                })
            }
        }

        if (-not $connectionState.ClosedAt) {
            $connectionState.ClosedAt = Get-Date
        }
    }
    $task = [System.Threading.Tasks.Task]::Run($receiverAction)

    $connectionState = [pscustomobject]@{
        ChannelId               = $ChannelId
        WebSocket               = $client
        CancellationTokenSource = $cts
        ReceiverTask            = $task
        Messages                = $queue
        ConnectedAt             = (Get-Date)
        ClosedAt                = $null
        LastError               = $null
        BaseUri                 = $notificationsUri
        AccessToken             = $AccessToken
    }

    return $connectionState
}

function Start-GCNotificationCapture {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [psobject]$Connection,
        [string]$CaptureRoot,
        [string]$TopicGroup = 'all',
        [string]$CapturePrefix = 'notification',
        [switch]$WriteSummary
    )

    if (-not $Connection -or -not $Connection.ChannelId) {
        throw "A valid connection object is required."
    }

    $captureRoot = if ($CaptureRoot) { $CaptureRoot } else { Join-Path -Path (Get-Location) -ChildPath 'captures' }
    $dateDir = Join-Path -Path $captureRoot -ChildPath (Get-Date).ToString('yyyy-MM-dd')
    New-Item -ItemType Directory -Path $dateDir -Force | Out-Null

    $fileName = "{0}_{1}_{2}.jsonl" -f $Connection.ChannelId, $TopicGroup, (Get-Date).ToString('HHmmss')
    $filePath = Join-Path -Path $dateDir -ChildPath $fileName
    $writer = [System.IO.StreamWriter]::new($filePath, $true, [System.Text.Encoding]::UTF8)

    $summary = [ordered]@{
        Topics    = @{}
        Events    = @{}
        Timeline  = @{}
        Entities  = @{}
        LastEntry = $null
    }

    $cts = [System.Threading.CancellationTokenSource]::new()
    $processorAction = [System.Action]{
        while (-not $cts.IsCancellationRequested) {
            $entry = $null
            if ($Connection.Messages.TryDequeue([ref]$entry)) {
                $line = $entry.Raw
                if ([string]::IsNullOrWhiteSpace($line) -and $entry.Parsed) {
                    $line = $entry.Parsed | ConvertTo-Json -Depth 10
                }
                if ($line) { $writer.WriteLine($line); $writer.Flush() }

                $summary.LastEntry = $entry.Timestamp
                if ($entry.Parsed -and $entry.Parsed.topicName) {
                    $topicKey = $entry.Parsed.topicName
                    $current = if ($summary.Topics.ContainsKey($topicKey)) { $summary.Topics[$topicKey] } else { 0 }
                    $summary.Topics[$topicKey] = $current + 1
                }

                if ($entry.Parsed -and $entry.Parsed.eventType) {
                    $eventKey = $entry.Parsed.eventType
                    $current = if ($summary.Events.ContainsKey($eventKey)) { $summary.Events[$eventKey] } else { 0 }
                    $summary.Events[$eventKey] = $current + 1
                }

                $slot = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm')
                $timelineCurrent = if ($summary.Timeline.ContainsKey($slot)) { $summary.Timeline[$slot] } else { 0 }
                $summary.Timeline[$slot] = $timelineCurrent + 1

                if ($entry.Parsed -and $entry.Parsed.entity) {
                    $entityKey = $entry.Parsed.entity.id
                    if (-not $entityKey) { $entityKey = $entry.Parsed.entity }
                    if ($entityKey) {
                        $entityCurrent = if ($summary.Entities.ContainsKey($entityKey)) { $summary.Entities[$entityKey] } else { 0 }
                        $summary.Entities[$entityKey] = $entityCurrent + 1
                    }
                }
            }
            else {
                Start-Sleep -Milliseconds 250
            }
        }

        $writer.Close()
    }
    $processor = [System.Threading.Tasks.Task]::Run($processorAction)

    $script:NotificationCaptureSessions[$Connection.ChannelId] = [pscustomobject]@{
        Connection   = $Connection
        CapturePath  = $filePath
        Summary      = $summary
        Processor    = $processor
        Cancellation = $cts
        TopicGroup   = $TopicGroup
        Prefix       = $CapturePrefix
        WriteSummary = $WriteSummary.IsPresent
    }

    return $script:NotificationCaptureSessions[$Connection.ChannelId]
}

function Stop-GCNotificationCapture {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$CaptureSession,
        [switch]$GenerateSummary
    )

    if (-not $CaptureSession) { throw "Capture session is required." }

    if ($CaptureSession.Cancellation) {
        $CaptureSession.Cancellation.Cancel()
    }

    if ($CaptureSession.Processor) {
        $CaptureSession.Processor.Wait()
    }

    $result = [pscustomobject]@{
        CapturePath = $CaptureSession.CapturePath
        SummaryPath = $null
        Summary     = $CaptureSession.Summary
    }

    if ($GenerateSummary.IsPresent -or $CaptureSession.WriteSummary) {
        $summaryPath = "$($CaptureSession.CapturePath).summary.json"
        ($CaptureSession.Summary | ConvertTo-Json -Depth 5) | Set-Content -LiteralPath $summaryPath -Encoding utf8
        $result.SummaryPath = $summaryPath
    }

    if ($CaptureSession.Connection -and $CaptureSession.Connection.CancellationTokenSource) {
        $CaptureSession.Connection.CancellationTokenSource.Cancel()
    }

    $script:NotificationCaptureSessions.Remove($CaptureSession.Connection.ChannelId) | Out-Null

    return $result
}

function Remove-GCNotificationChannel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ChannelId,
        [string]$BaseUri,
        [string]$AccessToken
    )

    if (-not $ChannelId) { throw "ChannelId is required to remove a notification channel." }

    $notificationsUri = Get-GCNotificationBaseUri -BaseUri $BaseUri
    return Invoke-GCRequest -Method 'DELETE' -BaseUri $notificationsUri -AccessToken $AccessToken `
        -Path "/api/v2/notifications/channels/$ChannelId" -AsResponse
}
