### BEGIN FILE: Public\Get-GCConversationTimeline.ps1
function Get-GCConversationTimeline {
    <#
        .SYNOPSIS
        Pulls multiple Genesys Cloud APIs for a single conversation and returns
        both the raw payloads and a normalized, time-ordered event list.

        .DESCRIPTION
        Calls:
          - GET  /api/v2/conversations/{conversationId}
          - GET  /api/v2/analytics/conversations/{conversationId}/details
          - GET  /api/v2/speechandtextanalytics/conversations/{conversationId}
          - GET  /api/v2/conversations/{conversationId}/recordingmetadata
          - GET  /api/v2/speechandtextanalytics/conversations/{conversationId}/sentiments
          - GET  /api/v2/telephony/sipmessages/conversations/{conversationId}

        Then normalizes them into TimelineEvents you can sort / export / visualize.

        .PARAMETER BaseUri
        Base API URI for your region, e.g. https://api.usw2.pure.cloud

        .PARAMETER AccessToken
        OAuth Bearer token.

        .PARAMETER ConversationId
        Target conversationId.

        .OUTPUTS
        PSCustomObject with:
          - ConversationId
          - Core (GET /conversations/{id})
          - AnalyticsDetails (GET /analytics/conversations/{id}/details)
          - SpeechText
          - RecordingMeta
          - Sentiments
          - SipMessages
          - TimelineEvents (normalized list)
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$BaseUri,

        [Parameter()]
        [string]$AccessToken,

        [Parameter(Mandatory = $true)]
        [string]$ConversationId
    )

    # Resolve connection details from either explicit parameters or Connect-GCCloud context
    $auth = Resolve-GCAuth -BaseUri $BaseUri -AccessToken $AccessToken
    $BaseUri = $auth.BaseUri
    $AccessToken = $auth.AccessToken


    Write-Verbose "Pulling core conversation for $ConversationId ..."
    $coreConversation = Invoke-GCRequest -BaseUri $BaseUri -AccessToken $AccessToken -Method 'GET' -Path "/api/v2/conversations/$ConversationId"

    Write-Verbose "Pulling analytics details for $ConversationId ..."
    $analyticsDetails = Invoke-GCRequest -BaseUri $BaseUri -AccessToken $AccessToken -Method 'GET' -Path "/api/v2/analytics/conversations/$ConversationId/details"

    Write-Verbose "Pulling speech & text analytics for $ConversationId ..."
    $speechText = $null
    try {
        $speechText = Invoke-GCRequest -BaseUri $BaseUri -AccessToken $AccessToken -Method 'GET' -Path "/api/v2/speechandtextanalytics/conversations/$ConversationId"
    }
    catch {
        Write-Verbose "Speech/Text analytics not available for $($ConversationId): $($_.Exception.Message)"
    }

    Write-Verbose "Pulling recording metadata for $ConversationId ..."
    $recordingMeta = $null
    try {
        $recordingMeta = Invoke-GCRequest -BaseUri $BaseUri -AccessToken $AccessToken -Method 'GET' -Path "/api/v2/conversations/$ConversationId/recordingmetadata"
    }
    catch {
        Write-Verbose "Recording metadata not available for $($ConversationId): $($_.Exception.Message)"
    }

    Write-Verbose "Pulling sentiment data for $ConversationId ..."
    $sentiments = $null
    try {
        $sentiments = Invoke-GCRequest -BaseUri $BaseUri -AccessToken $AccessToken -Method 'GET' -Path "/api/v2/speechandtextanalytics/conversations/$ConversationId/sentiments"
    }
    catch {
        Write-Verbose "Sentiments not available for $($ConversationId): $($_.Exception.Message)"
    }

    Write-Verbose "Pulling SIP messages for $ConversationId ..."
    $sipMessages = $null
    try {
        $sipMessages = Invoke-GCRequest -BaseUri $BaseUri -AccessToken $AccessToken -Method 'GET' -Path "/api/v2/telephony/sipmessages/conversations/$ConversationId"
    }
    catch {
        Write-Verbose "SIP messages not available for $($ConversationId): $($_.Exception.Message)"
    }

    # --- Normalize into timeline rows ----------------------------------------
    $events = [System.Collections.Generic.List[object]]::new()

    # Helper to add a timeline row
    function Add-TimelineEvent {
        param(
            [Parameter(Mandatory = $true)]
            [datetime]$StartTime,

            [Parameter(Mandatory = $false)]
            [datetime]$EndTime,

            [Parameter(Mandatory = $true)]
            [string]$Source,

            [Parameter(Mandatory = $true)]
            [string]$EventType,

            [Parameter(Mandatory = $false)]
            [string]$Participant,

            [Parameter(Mandatory = $false)]
            [string]$Queue,

            [Parameter(Mandatory = $false)]
            [string]$User,

            [Parameter(Mandatory = $false)]
            [string]$Direction,

            [Parameter(Mandatory = $false)]
            [string]$DisconnectType,

            [Parameter(Mandatory = $false)]
            [hashtable]$Extra
        )

        $events.Add([pscustomobject]@{
            ConversationId = $ConversationId
            StartTime      = $StartTime
            EndTime        = $EndTime
            Source         = $Source
            EventType      = $EventType
            Participant    = $Participant
            Queue          = $Queue
            User           = $User
            Direction      = $Direction
            DisconnectType = $DisconnectType
            Extra          = $Extra
        }) | Out-Null
    }

    # 1) Core participants/segments
    if ($coreConversation.participants) {
        foreach ($p in $coreConversation.participants) {
            $participantName = $p.name
            $userId          = $p.userId
            $queueId         = $p.queueId

            foreach ($seg in $p.segments) {
                $segStart = $null
                $segEnd   = $null

                if ($seg.segmentStart) {
                    $segStart = [datetime]$seg.segmentStart
                }
                if ($seg.segmentEnd) {
                    $segEnd = [datetime]$seg.segmentEnd
                }

                Add-TimelineEvent `
                    -StartTime $segStart `
                    -EndTime   $segEnd `
                    -Source    'Core' `
                    -EventType $seg.segmentType `
                    -Participant $participantName `
                    -Queue     $queueId `
                    -User      $userId `
                    -Direction $seg.direction `
                    -DisconnectType $seg.disconnectType `
                    -Extra ([ordered]@{
                        SegmentId     = $seg.segmentId
                        Ani           = $seg.ani
                        Dnis          = $seg.dnis
                        Purpose       = $seg.purpose
                        Conference    = $seg.conference
                        SegmentType   = $seg.segmentType
                        WrapUpCode    = $seg.wrapUpCode
                        WrapUpNote    = $seg.wrapUpNote
                        Recording     = $seg.recording
                    })
            }
        }
    }

    # 2) Analytics details - we treat each segment as an event as well
    if ($analyticsDetails.conversationId) {
        $aConv = $analyticsDetails
        if ($aConv.participants) {
            foreach ($p in $aConv.participants) {
                $participantName = $p.participantId

                foreach ($seg in $p.segments) {
                    $segStart = $null
                    $segEnd   = $null

                    if ($seg.segmentStart) {
                        $segStart = [datetime]$seg.segmentStart
                    }
                    if ($seg.segmentEnd) {
                        $segEnd = [datetime]$seg.segmentEnd
                    }

                    Add-TimelineEvent `
                        -StartTime $segStart `
                        -EndTime   $segEnd `
                        -Source    'Analytics' `
                        -EventType $seg.segmentType `
                        -Participant $participantName `
                        -Queue     $seg.queueId `
                        -User      $seg.userId `
                        -Direction $seg.direction `
                        -DisconnectType $seg.disconnectType `
                        -Extra ([ordered]@{
                            SegmentType     = $seg.segmentType
                            MediaType       = $seg.mediaType
                            FlowType        = $seg.flowType
                            FlowVersion     = $seg.flowVersion
                            Provider        = $seg.provider
                            TransferType    = $seg.transferType
                            ErrorCode       = $seg.errorCode
                            DispositionCodes = $seg.dispositionCodes
                        })
                }
            }
        }
    }

    # 3) Speech & Text analytics sections (phrases, topics, etc.)
    if ($speechText) {
        if ($speechText.conversation) {
            $convStart = $null
            if ($speechText.conversation.startTime) {
                $convStart = [datetime]$speechText.conversation.startTime
            }

            if ($speechText.conversation.topics) {
                foreach ($topic in $speechText.conversation.topics) {
                    Add-TimelineEvent `
                        -StartTime $convStart `
                        -EndTime   $null `
                        -Source    'SpeechText' `
                        -EventType 'Topic' `
                        -Participant $null `
                        -Queue     $null `
                        -User      $null `
                        -Direction $null `
                        -DisconnectType $null `
                        -Extra ([ordered]@{
                            TopicName    = $topic.name
                            TopicType    = $topic.type
                            Sentiment    = $topic.sentimentScore
                            Dialect      = $topic.dialect
                        })
                }
            }
        }
    }

    # 4) Sentiments timeline, if available
    if ($sentiments) {
        if ($sentiments.sentiment) {
            foreach ($entry in $sentiments.sentiment) {
                $time = $null
                if ($entry.time) {
                    $time = [datetime]$entry.time
                }

                Add-TimelineEvent `
                    -StartTime $time `
                    -EndTime   $null `
                    -Source    'Sentiment' `
                    -EventType 'SentimentSample' `
                    -Participant $entry.participantId `
                    -Queue     $null `
                    -User      $entry.userId `
                    -Direction $null `
                    -DisconnectType $null `
                    -Extra ([ordered]@{
                        Score = $entry.score
                        Label = $entry.label
                    })
            }
        }
    }

    # 5) Recording metadata as a coarse event
    if ($recordingMeta) {
        foreach ($rec in $recordingMeta) {
            $recStart = $null
            $recEnd   = $null

            if ($rec.startTime) {
                $recStart = [datetime]$rec.startTime
            }
            if ($rec.endTime) {
                $recEnd = [datetime]$rec.endTime
            }

            Add-TimelineEvent `
                -StartTime $recStart `
                -EndTime   $recEnd `
                -Source    'Recording' `
                -EventType 'Recording' `
                -Participant $rec.participantId `
                -Queue     $null `
                -User      $rec.agentId `
                -Direction $null `
                -DisconnectType $null `
                -Extra ([ordered]@{
                    RecordingId = $rec.id
                    ArchiveDate = $rec.archiveDate
                    DeletedDate = $rec.deleteDate
                    MediaUris   = $rec.mediaUris
                })
        }
    }

    # 6) SIP messages as low-level events
    ### BEGIN: SIP parse message string -> fields (timestamp/method/status/reason/raw)
    if ($sipMessages) {

        # Genesys endpoint may return one or many; normalize to an array of strings
        $msgItems = @()
        if ($sipMessages.message -is [System.Collections.IEnumerable] -and -not ($sipMessages.message -is [string])) {
            $msgItems = @($sipMessages.message)
        }
        else {
            $msgItems = @($sipMessages.message)
        }

        foreach ($msgText0 in $msgItems) {

            # Ensure string
            $msgText = if ($msgText0 -is [string]) { $msgText0 } else { ($msgText0 | Out-String) }

            # ----------------------------
            # TimeStamp: <unix epoch>
            # ----------------------------
            $msgTime = $null
            if ($msgText -match '(?im)^\s*TimeStamp\s*:\s*(?<epoch>\d+(?:\.\d+)?)\s*$') {
                $epoch = [double]$matches['epoch']

                # Heuristic: very large -> milliseconds
                if ($epoch -ge 100000000000) { $epoch = $epoch / 1000.0 }

                $msgTime = [DateTimeOffset]::FromUnixTimeSeconds([int64][math]::Floor($epoch)).LocalDateTime

                $fraction = $epoch - [math]::Floor($epoch)
                if ($fraction -gt 0) { $msgTime = $msgTime.AddSeconds($fraction) }
            }

            # ----------------------------
            # SIP "start line" parsing
            # - Request:  INVITE sip:... SIP/2.0
            # - Response: SIP/2.0 200 OK
            # ----------------------------
            $method = $null
            $statusCode = $null
            $reasonPhrase = $null

            # Grab the first non-empty line as the "start line" (skipping TimeStamp lines if they precede it)
            $lines = ($msgText -split "`r?`n")
            $startLine = $lines | Where-Object { $_ -and $_.Trim() -ne '' -and $_ -notmatch '^\s*TimeStamp\s*:' } | Select-Object -First 1

            if ($startLine) {
                # Response: SIP/2.0 200 OK
                if ($startLine -match '^\s*SIP/2\.0\s+(?<code>\d{3})(?:\s+(?<reason>.*?))?\s*$') {
                    $statusCode = [int]$matches['code']
                    $reasonPhrase = $matches['reason']
                    if ([string]::IsNullOrWhiteSpace($reasonPhrase)) { $reasonPhrase = $null }

                    # For timeline "EventType", make it readable
                    $method = "SIP/2.0 $($statusCode)"
                }
                # Request: INVITE sip:... SIP/2.0
                elseif ($startLine -match '^\s*(?<method>[A-Z]+)\s+\S+\s+SIP/2\.0\s*$') {
                    $method = $matches['method']
                }
            }

            # ----------------------------
            # Optional: participantId/direction if present as headers (best-effort)
            # If your blobs never contain these, these will stay $null.
            # ----------------------------
            $participantId = $null
            if ($msgText -match '(?im)^\s*Participant(?:Id)?\s*:\s*(?<pid>[^\r\n]+)\s*$') {
                $participantId = $matches['pid'].Trim()
            }

            $direction = $null
            if ($msgText -match '(?im)^\s*Direction\s*:\s*(?<dir>[^\r\n]+)\s*$') {
                $direction = $matches['dir'].Trim()
            }

            # ----------------------------
            # Build timeline event
            # ----------------------------
            Add-TimelineEvent `
                -StartTime $msgTime `
                -EndTime $null `
                -Source 'SIP' `
                -EventType $method `
                -Participant $participantId `
                -Queue $null `
                -User $null `
                -Direction $direction `
                -DisconnectType $null `
                -Extra ([ordered]@{
                    StatusCode = $statusCode
                    Reason     = $reasonPhrase
                    Raw        = $msgText
                })
        }
    }
    ### END: SIP parse message string -> fields (timestamp/method/status/reason/raw)

    # Sort the aggregated events by time, then by source/event type so the
    # timeline reads sensibly in a grid or export.
    $sortedEvents =
        $events |
        Sort-Object StartTime, EndTime, Source, EventType

    return [pscustomobject]@{
        ConversationId   = $ConversationId
        Core             = $coreConversation
        AnalyticsDetails = $analyticsDetails
        SpeechText       = $speechText
        RecordingMeta    = $recordingMeta
        Sentiments       = $sentiments
        SipMessages      = $sipMessages
        TimelineEvents   = $sortedEvents
    }
}
### END FILE: Public\Get-GCConversationTimeline.ps1
