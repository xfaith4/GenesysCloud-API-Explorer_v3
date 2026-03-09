function Get-GCConversationRollup {
    <#
    .SYNOPSIS
        Builds Division/Queue/Agent rollups from the dashboard store conversation records.

    .DESCRIPTION
        Reads the JSONL dashboard store, filters for conversation.details records, and computes KPI rollups:
        - Count
        - MOS average/median (when available)
        - WebRTC disconnect count
        - Degraded % (MOS < threshold)

    .PARAMETER StorePath
        Path to the dashboard store JSONL file.

    .PARAMETER MosThreshold
        Threshold to count a conversation as degraded.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$StorePath,

        [double]$MosThreshold = 3.5
    )

    if (-not (Test-Path -LiteralPath $StorePath)) {
        throw "Store path not found: $StorePath"
    }

    $content = Get-Content -LiteralPath $StorePath -Raw -Encoding utf8
    if ([string]::IsNullOrWhiteSpace($content)) { return @() }

    $records = @()
    foreach ($line in ($content -split '[\r\n]+')) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try {
            $obj = $line | ConvertFrom-Json -Depth 8
            if ($obj -and $obj.Type -eq 'conversation.details') {
                $records += $obj
            }
        }
        catch { }
    }
    if ($records.Count -eq 0) { return @() }

    $makeRollup = {
        param($items, $keySelector, $label)

        $grouped = @($items | Group-Object -Property $keySelector)
        $rows = @()
        foreach ($g in $grouped) {
            $id = if ($g.Name) { $g.Name } else { '(none)' }
            $mosValues = @()
            $webrtc = 0

            foreach ($entry in $g.Group) {
                $detail = $entry.Content
                if ($detail -and $detail.conversationEndpoints -and $detail.conversationEndpoints.webrtc) {
                    $webrtc++
                }
                if ($detail -and $detail.conversationMetrics -and $detail.conversationMetrics.averageMos) {
                    try { $mosValues += [double]$detail.conversationMetrics.averageMos } catch { }
                }
            }

            $count = $g.Count
            $avgMos = if ($mosValues.Count -gt 0) { ($mosValues | Measure-Object -Average).Average } else { $null }
            $medMos = if ($mosValues.Count -gt 0) {
                $sorted = $mosValues | Sort-Object
                $mid = [int]([math]::Floor($sorted.Count / 2))
                if ($sorted.Count % 2 -eq 0) {
                    ($sorted[$mid-1] + $sorted[$mid]) / 2
                }
                else { $sorted[$mid] }
            } else { $null }
            $degradedCount = ($mosValues | Where-Object { $_ -lt $MosThreshold }).Count
            $degradedPct = if ($count -gt 0) { [math]::Round(($degradedCount / $count) * 100, 2) } else { 0 }

            $rows += [pscustomobject]@{
                Bucket    = $id
                Conversations = $count
                AvgMos    = if ($avgMos) { "{0:N2}" -f $avgMos } else { '-' }
                MedianMos = if ($medMos) { "{0:N2}" -f $medMos } else { '-' }
                DegradedPct = $degradedPct
                WebRtcDisconnects = $webrtc
            }
        }

        return [pscustomobject]@{
            Title = $label
            Rows  = $rows | Sort-Object -Property Conversations -Descending
        }
    }

    $divisionItems = @()
    $queueItems = @()
    $agentItems = @()

    foreach ($rec in $records) {
        if ($rec.DivisionId) {
            $divisionItems += $rec
        }
        foreach ($qid in @($rec.QueueIds)) {
            $clone = $rec | Select-Object * -ExcludeProperty QueueIds,AgentIds
            $clone | Add-Member -NotePropertyName QueueId -NotePropertyValue $qid -Force
            $queueItems += $clone
        }
        foreach ($aid in @($rec.AgentIds)) {
            $clone = $rec | Select-Object * -ExcludeProperty QueueIds,AgentIds
            $clone | Add-Member -NotePropertyName AgentId -NotePropertyValue $aid -Force
            $agentItems += $clone
        }
    }

    $divisionRollup = $makeRollup.Invoke($divisionItems, { $_.DivisionId }, 'Division KPIs')
    $queueRollup    = $makeRollup.Invoke($queueItems,    { $_.QueueId },    'Queue KPIs')
    $agentRollup    = $makeRollup.Invoke($agentItems,    { $_.AgentId },    'Agent KPIs')

    return @($divisionRollup, $queueRollup, $agentRollup)
}
