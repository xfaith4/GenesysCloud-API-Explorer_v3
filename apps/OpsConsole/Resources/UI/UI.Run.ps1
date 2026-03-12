# Auto-generated refactor split: main window XAML moved to UI/MainWindow.xaml
# This file contains the runtime portion of the OpsConsole UI.

# When dot-sourced, $PSScriptRoot is empty. Use the UI directory path relative to where we were loaded from.
$uiDir = if ($PSScriptRoot) { 
    $PSScriptRoot 
} elseif ($script:ResourcesRoot) { 
    Join-Path -Path $script:ResourcesRoot -ChildPath "UI" 
} else { 
    Split-Path -Parent $MyInvocation.MyCommand.Definition 
}

$Xaml = Get-Content -Raw -LiteralPath (Join-Path $uiDir "MainWindow.xaml")
$Window = [System.Windows.Markup.XamlReader]::Parse($Xaml)
if (-not $Window) {
    Write-Error "Failed to create the WPF UI."
    return
}

Ensure-ApiCatalogLoaded

Set-DesignSystemResources -Window $Window
Ensure-UxDebugHud -Window $Window
Write-UxEvent -Name "time_to_interactive" -Properties @{ route = "home"; ready = $true }

$groupCombo = $Window.FindName("GroupCombo")
$pathCombo = $Window.FindName("PathCombo")
$methodCombo = $Window.FindName("MethodCombo")
$parameterPanel = $Window.FindName("ParameterPanel")
$btnSubmit = $Window.FindName("SubmitButton")
$btnSave = $Window.FindName("SaveButton")
$responseBox = $Window.FindName("ResponseText")
$logBox = $Window.FindName("LogText")
$loginButton = $Window.FindName("LoginButton")
$testTokenButton = $Window.FindName("TestTokenButton")
$tokenStatusText = $Window.FindName("TokenStatusText")
$progressIndicator = $Window.FindName("ProgressIndicator")
$statusText = $Window.FindName("StatusText")
$favoritesList = $Window.FindName("FavoritesList")

Update-AuthUiState
$favoriteNameInput = $Window.FindName("FavoriteNameInput")
$saveFavoriteButton = $Window.FindName("SaveFavoriteButton")
$inspectResponseButton = $Window.FindName("InspectResponseButton")
$toggleResponseViewButton = $Window.FindName("ToggleResponseViewButton")
$fetchJobResultsButton = $Window.FindName("FetchJobResultsButton")
$exportJobResultsButton = $Window.FindName("ExportJobResultsButton")
$helpMenuItem = $Window.FindName("HelpMenuItem")
$helpDevLink = $Window.FindName("HelpDevLink")
$helpSupportLink = $Window.FindName("HelpSupportLink")
$conversationReportIdInput = $Window.FindName("ConversationReportIdInput")
$runConversationReportButton = $Window.FindName("RunConversationReportButton")
$inspectConversationReportButton = $Window.FindName("InspectConversationReportButton")
$exportConversationReportJsonButton = $Window.FindName("ExportConversationReportJsonButton")
$exportConversationReportTextButton = $Window.FindName("ExportConversationReportTextButton")
$conversationReportText = $Window.FindName("ConversationReportText")
$conversationReportStatus = $Window.FindName("ConversationReportStatus")
$conversationReportProgressBar = $Window.FindName("ConversationReportProgressBar")
$conversationReportProgressText = $Window.FindName("ConversationReportProgressText")
$conversationReportEndpointLog = $Window.FindName("ConversationReportEndpointLog")
$cancelConversationReportButton = $Window.FindName("CancelConversationReportButton")
$convReportErrorBanner = $Window.FindName("ConvReportErrorBanner")
$convReportErrorText = $Window.FindName("ConvReportErrorText")
$convReportWarningBanner = $Window.FindName("ConvReportWarningBanner")
$convReportWarningText = $Window.FindName("ConvReportWarningText")
$queueWaitQueueIdInput = $Window.FindName("QueueWaitQueueIdInput")
$queueWaitIntervalInput = $Window.FindName("QueueWaitIntervalInput")
$runQueueWaitReportButton = $Window.FindName("RunQueueWaitReportButton")
$queueWaitReportStatus = $Window.FindName("QueueWaitReportStatus")
$queueWaitResultsList = $Window.FindName("QueueWaitResultsList")
$queueWaitDetailsText = $Window.FindName("QueueWaitDetailsText")
$liveSubTopicPresetCombo = $Window.FindName("LiveSubTopicPresetCombo")
$liveSubTopicInput = $Window.FindName("LiveSubTopicInput")
$startLiveSubscriptionButton = $Window.FindName("StartLiveSubscriptionButton")
$stopLiveSubscriptionButton = $Window.FindName("StopLiveSubscriptionButton")
$liveSubFilterInput = $Window.FindName("LiveSubFilterInput")
$liveSubscriptionEventsList = $Window.FindName("LiveSubscriptionEventsList")
$liveSubscriptionStatusText = $Window.FindName("LiveSubscriptionStatusText")
$liveSubscriptionCapturePathText = $Window.FindName("LiveSubscriptionCapturePathText")
$refreshLiveSubTopicsButton = $Window.FindName("RefreshLiveSubTopicsButton")
$liveSubTopicCatalogList = $Window.FindName("LiveSubTopicCatalogList")
$liveSubscriptionTopicCatalogStatusText = $Window.FindName("LiveSubscriptionTopicCatalogStatusText")
$liveSubscriptionAnalyticsStatusText = $Window.FindName("LiveSubscriptionAnalyticsStatusText")
$script:LiveSubscriptionTopicCatalogStatusText = $liveSubscriptionTopicCatalogStatusText
$script:LiveSubscriptionAnalyticsStatusText = $liveSubscriptionAnalyticsStatusText
$liveSubscriptionTopicTotalsList = $Window.FindName("LiveSubscriptionTopicTotalsList")
$liveSubscriptionEventTypeTotalsList = $Window.FindName("LiveSubscriptionEventTypeTotalsList")
$exportLiveSubscriptionRawButton = $Window.FindName("ExportLiveSubscriptionRawButton")
$exportLiveSubscriptionSummaryButton = $Window.FindName("ExportLiveSubscriptionSummaryButton")
$operationalEventDefinitionsInput = $Window.FindName("OperationalEventDefinitionsInput")
$operationalEventLiveModeCheckbox = $Window.FindName("OperationalEventLiveModeCheckbox")
$operationalEventTopicPresetCombo = $Window.FindName("OperationalEventTopicPresetCombo")
$runOperationalEventsButton = $Window.FindName("RunOperationalEventsButton")
$importOperationalEventsButton = $Window.FindName("ImportOperationalEventsButton")
$stopOperationalEventsLiveButton = $Window.FindName("StopOperationalEventsLiveButton")
$operationalEventsList = $Window.FindName("OperationalEventsList")
$operationalEventsStatusText = $Window.FindName("OperationalEventsStatusText")
$operationalEventsCatalogLink = $Window.FindName("OperationalEventsCatalogLink")
$exportOperationalEventsJsonButton = $Window.FindName("ExportOperationalEventsJsonButton")
$exportOperationalEventsSummaryButton = $Window.FindName("ExportOperationalEventsSummaryButton")
$auditStartInput = $Window.FindName("AuditStartInput")
$auditEndInput = $Window.FindName("AuditEndInput")
$auditServiceInput = $Window.FindName("AuditServiceInput")
$auditEntityInput = $Window.FindName("AuditEntityInput")
$auditUserInput = $Window.FindName("AuditUserInput")
$runAuditInvestigatorButton = $Window.FindName("RunAuditInvestigatorButton")
$auditEventsList = $Window.FindName("AuditEventsList")
$auditTimelineText = $Window.FindName("AuditTimelineText")
$opsIngestIntervalCombo = $Window.FindName("OpsIngestIntervalCombo")
$runOpsConversationIngestButton = $Window.FindName("RunOpsConversationIngestButton")
$scheduleOpsConversationIngestButton = $Window.FindName("ScheduleOpsConversationIngestButton")
$opsIngestStatusText = $Window.FindName("OpsIngestStatusText")
$auditLogList = $Window.FindName("AuditLogList")
$refreshAuditLogButton = $Window.FindName("RefreshAuditLogButton")
$exportRedactedKpiButton = $Window.FindName("ExportRedactedKpiButton")
$exportDivisionQosButton = $Window.FindName("ExportDivisionQosButton")
$exportWebRtcButton = $Window.FindName("ExportWebRtcButton")
$exportDataActionButton = $Window.FindName("ExportDataActionButton")
$exportIncidentPacketButton = $Window.FindName("ExportIncidentPacketButton")
$auditStatusText = $Window.FindName("AuditStatusText")
$exportAuditJsonButton = $Window.FindName("ExportAuditJsonButton")
$exportAuditSummaryButton = $Window.FindName("ExportAuditSummaryButton")
$auditSummaryPathText = $Window.FindName("AuditSummaryPathText")
$appSettingsMenuItem = $Window.FindName("AppSettingsMenuItem")
$traceMenuItem = $Window.FindName("TraceMenuItem")
$settingsMenuItem = $Window.FindName("SettingsMenuItem")
$exportLogButton = $Window.FindName("ExportLogButton")
$clearLogButton = $Window.FindName("ClearLogButton")
$resetEndpointsMenuItem = $Window.FindName("ResetEndpointsMenuItem")
$requestHistoryList = $Window.FindName("RequestHistoryList")
$replayRequestButton = $Window.FindName("ReplayRequestButton")
$clearHistoryButton = $Window.FindName("ClearHistoryButton")
$mainTabControl = $Window.FindName("MainTabControl")
$workspaceNavigatorPanel = $Window.FindName("WorkspaceNavigatorPanel")
$workspaceApiButton = $Window.FindName("WorkspaceApiButton")
$workspaceInsightsButton = $Window.FindName("WorkspaceInsightsButton")
$workspaceMonitoringButton = $Window.FindName("WorkspaceMonitoringButton")
$responseTab = $Window.FindName("ResponseTab")
$opsInsightsTab = $Window.FindName("OpsInsightsTab")
$liveSubscriptionsTab = $Window.FindName("LiveSubscriptionsTab")
$requestSelectorGrid = $Window.FindName("RequestSelectorGrid")
$favoritesBorder = $Window.FindName("FavoritesBorder")
$actionButtonsPanel = $Window.FindName("ActionButtonsPanel")
$mainContentGrid = $Window.FindName("MainContentGrid")
$leftControlPane = $Window.FindName("LeftControlPane")
$mainContentSplitter = $Window.FindName("MainContentSplitter")
$runQueueSmokePackButton = $Window.FindName("RunQueueSmokePackButton")
$runDataActionsPackButton = $Window.FindName("RunDataActionsPackButton")
$runDataActionsEnrichedPackButton = $Window.FindName("RunDataActionsEnrichedPackButton")
$runPeakConcurrencyPackButton = $Window.FindName("RunPeakConcurrencyPackButton")
$runMosMonthlyPackButton = $Window.FindName("RunMosMonthlyPackButton")
$runSelectedInsightPackButton = $Window.FindName("RunSelectedInsightPackButton")
$compareSelectedInsightPackButton = $Window.FindName("CompareSelectedInsightPackButton")
$insightBaselineModeCombo = $Window.FindName("InsightBaselineModeCombo")
$dryRunSelectedInsightPackButton = $Window.FindName("DryRunSelectedInsightPackButton")
$useInsightCacheCheckbox = $Window.FindName("UseInsightCacheCheckbox")
$strictInsightValidationCheckbox = $Window.FindName("StrictInsightValidationCheckbox")
$insightCacheTtlInput = $Window.FindName("InsightCacheTtlInput")
$insightPackCombo = $Window.FindName("InsightPackCombo")
$refreshInsightPacksButton = $Window.FindName("RefreshInsightPacksButton")
$insightPackDescriptionText = $Window.FindName("InsightPackDescriptionText")
$insightPackMetaText = $Window.FindName("InsightPackMetaText")
$insightPackWarningsText = $Window.FindName("InsightPackWarningsText")
$insightPackParametersPanel = $Window.FindName("InsightPackParametersPanel")
$insightTimePresetCombo = $Window.FindName("InsightTimePresetCombo")
$applyInsightTimePresetButton = $Window.FindName("ApplyInsightTimePresetButton")
$insightPackExampleCombo = $Window.FindName("InsightPackExampleCombo")
$loadInsightPackExampleButton = $Window.FindName("LoadInsightPackExampleButton")
$insightGlobalStartInput = $Window.FindName("InsightGlobalStartInput")
$insightGlobalEndInput = $Window.FindName("InsightGlobalEndInput")
$exportInsightBriefingButton = $Window.FindName("ExportInsightBriefingButton")
$insightEvidenceSummary = $Window.FindName("InsightEvidenceSummary")
$insightMetricsList = $Window.FindName("InsightMetricsList")
$insightDrilldownsList = $Window.FindName("InsightDrilldownsList")
$insightBriefingPathText = $Window.FindName("InsightBriefingPathText")
$insightBriefingsList = $Window.FindName("InsightBriefingsList")
$refreshInsightBriefingsButton = $Window.FindName("RefreshInsightBriefingsButton")
$openBriefingsFolderButton = $Window.FindName("OpenBriefingsFolderButton")
$openBriefingHtmlButton = $Window.FindName("OpenBriefingHtmlButton")
$openBriefingSnapshotButton = $Window.FindName("OpenBriefingSnapshotButton")
$opsDashboardStatusText = $Window.FindName("OpsDashboardStatusText")
$opsDashboardStorePathText = $Window.FindName("OpsDashboardStorePathText")
$refreshOpsDashboardButton = $Window.FindName("RefreshOpsDashboardButton")
$browseOpsDashboardStoreButton = $Window.FindName("BrowseOpsDashboardStoreButton")
$opsDashboardMosList = $Window.FindName("OpsDashboardMosList")
$opsDashboardDataActionList = $Window.FindName("OpsDashboardDataActionList")
$opsDashboardWebRtcList = $Window.FindName("OpsDashboardWebRtcList")
$opsDashboardDataActionSummaryText = $Window.FindName("OpsDashboardDataActionSummaryText")
$opsDashboardWebRtcSummaryText = $Window.FindName("OpsDashboardWebRtcSummaryText")
$exportDivisionQosButton = $Window.FindName("ExportDivisionQosButton")
$exportWebRtcButton = $Window.FindName("ExportWebRtcButton")
$exportDataActionButton = $Window.FindName("ExportDataActionButton")
$exportIncidentPacketButton = $Window.FindName("ExportIncidentPacketButton")
$exportRedactedKpiButton = $Window.FindName("ExportRedactedKpiButton")
$auditLogList = $Window.FindName("AuditLogList")
$refreshAuditLogButton = $Window.FindName("RefreshAuditLogButton")
$opsDashboardTimePresetCombo = $Window.FindName("OpsDashboardTimePresetCombo")
$opsDashboardEndInput = $Window.FindName("OpsDashboardEndInput")
$opsDashboardDivisionFilterInput = $Window.FindName("OpsDashboardDivisionFilterInput")
$opsDashboardQueueFilterInput = $Window.FindName("OpsDashboardQueueFilterInput")
$opsDashboardDisconnectReasonInput = $Window.FindName("OpsDashboardDisconnectReasonInput")
$opsDashboardSipErrorFilterInput = $Window.FindName("OpsDashboardSipErrorFilterInput")
$opsDashboardDataActionFilterInput = $Window.FindName("OpsDashboardDataActionFilterInput")
$opsDashboardMosThresholdSlider = $Window.FindName("OpsDashboardMosThresholdSlider")
$opsDashboardMosThresholdText = $Window.FindName("OpsDashboardMosThresholdText")
$opsDashboardApplyFiltersButton = $Window.FindName("OpsDashboardApplyFiltersButton")
$script:OpsDashboardStatusText = $opsDashboardStatusText
$script:OpsDashboardStorePathText = $opsDashboardStorePathText
$script:OpsDashboardDataActionSummaryText = $opsDashboardDataActionSummaryText
$script:OpsDashboardWebRtcSummaryText = $opsDashboardWebRtcSummaryText
$script:AuditLogEntries = New-Object System.Collections.ObjectModel.ObservableCollection[object]
$exportPowerShellButton = $Window.FindName("ExportPowerShellButton")
$powerShellExportModeCombo = $Window.FindName("PowerShellExportModeCombo")
$exportCurlButton = $Window.FindName("ExportCurlButton")
$templatesList = $Window.FindName("TemplatesList")
$saveTemplateButton = $Window.FindName("SaveTemplateButton")
$loadTemplateButton = $Window.FindName("LoadTemplateButton")
$deleteTemplateButton = $Window.FindName("DeleteTemplateButton")
$exportTemplatesButton = $Window.FindName("ExportTemplatesButton")
$importTemplatesButton = $Window.FindName("ImportTemplatesButton")
$operationsTimelineList = $Window.FindName("OperationsTimelineList")
$forensicTimelineSummaryText = $Window.FindName("ForensicTimelineSummaryText")
$forensicTimelineStatusText = $Window.FindName("ForensicTimelineStatusText")
$investigateTimelineEntryButton = $Window.FindName("InvestigateTimelineEntryButton")
$exportTimelineEntryButton = $Window.FindName("ExportTimelineEntryButton")
$ForensicTimelineSummaryText = $forensicTimelineSummaryText
$ForensicTimelineStatusText = $forensicTimelineStatusText
$filterBuilderBorder = $Window.FindName("FilterBuilderBorder")
$filterBuilderHintText = $Window.FindName("FilterBuilderHintText")
$filterBuilderExpander = $Window.FindName("FilterBuilderExpander")
$parametersExpander = $Window.FindName("ParametersExpander")
$filterIntervalInput = $Window.FindName("FilterIntervalInput")
$refreshFiltersButton = $Window.FindName("RefreshFiltersButton")
$resetFiltersButton = $Window.FindName("ResetFiltersButton")
$conversationFiltersList = $Window.FindName("ConversationFiltersList")
$conversationFilterTypeCombo = $Window.FindName("ConversationFilterTypeCombo")
$conversationPredicateTypeCombo = $Window.FindName("ConversationPredicateTypeCombo")
$conversationFieldCombo = $Window.FindName("ConversationFieldCombo")
$conversationOperatorCombo = $Window.FindName("ConversationOperatorCombo")
$conversationValueInput = $Window.FindName("ConversationValueInput")
$addConversationPredicateButton = $Window.FindName("AddConversationPredicateButton")
$removeConversationPredicateButton = $Window.FindName("RemoveConversationPredicateButton")
$segmentFiltersList = $Window.FindName("SegmentFiltersList")
$segmentFilterTypeCombo = $Window.FindName("SegmentFilterTypeCombo")
$segmentPredicateTypeCombo = $Window.FindName("SegmentPredicateTypeCombo")
$segmentFieldCombo = $Window.FindName("SegmentFieldCombo")
$segmentOperatorCombo = $Window.FindName("SegmentOperatorCombo")
$segmentPropertyInput = $Window.FindName("SegmentPropertyInput")
$segmentPropertyTypeCombo = $Window.FindName("SegmentPropertyTypeCombo")
$segmentValueInput = $Window.FindName("SegmentValueInput")
$addSegmentPredicateButton = $Window.FindName("AddSegmentPredicateButton")
$removeSegmentPredicateButton = $Window.FindName("RemoveSegmentPredicateButton")

$Window.Add_Closing({
        Flush-UxTelemetryBuffer
        if ($script:UxTelemetryState.Writer) {
            $script:UxTelemetryState.Writer.Flush()
            $script:UxTelemetryState.Writer.Dispose()
            $script:UxTelemetryState.Writer = $null
        }
        if ($script:UxTelemetryState.FlushTimer) {
            $script:UxTelemetryState.FlushTimer.Stop()
            $script:UxTelemetryState.FlushTimer.Dispose()
            $script:UxTelemetryState.FlushTimer = $null
        }
        if ($script:UxDebugWindow) {
            $script:UxDebugWindow.Close()
            $script:UxDebugWindow = $null
        }
    })

if ($mainTabControl) {
    $mainTabControl.Add_SelectionChanged({
            if ($mainTabControl.SelectedItem) {
                $route = $mainTabControl.SelectedItem.Header.ToString()
                Write-UxEvent -Name "page_view" -Properties @{ route = $route; ts = (Get-Date).ToString('o') }
                Update-UxDebugHud -Route $route -Status $statusText.Text -LastEvent "tab-change"
            }
        })
    if ($workspaceApiButton -and $responseTab) {
        $workspaceApiButton.Add_Click({
                $mainTabControl.SelectedItem = $responseTab
            })
    }
    if ($workspaceInsightsButton -and $opsInsightsTab) {
        $workspaceInsightsButton.Add_Click({
                $mainTabControl.SelectedItem = $opsInsightsTab
            })
    }
    if ($workspaceMonitoringButton -and $liveSubscriptionsTab) {
        $workspaceMonitoringButton.Add_Click({
                $mainTabControl.SelectedItem = $liveSubscriptionsTab
            })
    }
}

if ($filterBuilderBorder) {
    Initialize-FilterBuilderControl
    Reset-FilterBuilderData
    Set-FilterBuilderVisibility -Visible $false
    Update-FilterBuilderHint

    if ($conversationPredicateTypeCombo) {
        $conversationPredicateTypeCombo.Add_SelectionChanged({
                Update-FilterFieldOptions -Scope "Conversation" -PredicateType $conversationPredicateTypeCombo.SelectedItem -ComboBox $conversationFieldCombo
            })
    }
    if ($segmentPredicateTypeCombo) {
        $segmentPredicateTypeCombo.Add_SelectionChanged({
                Update-FilterFieldOptions -Scope "Segment" -PredicateType $segmentPredicateTypeCombo.SelectedItem -ComboBox $segmentFieldCombo
            })
    }

    if ($addConversationPredicateButton) {
        $addConversationPredicateButton.Add_Click({
                $filter = Build-FilterFromInput -Scope "Conversation" -FilterTypeCombo $conversationFilterTypeCombo -PredicateTypeCombo $conversationPredicateTypeCombo -FieldCombo $conversationFieldCombo -OperatorCombo $conversationOperatorCombo -ValueInput $conversationValueInput
                if ($filter) {
                    Add-FilterEntry -Scope "Conversation" -FilterObject $filter
                    if ($conversationValueInput) { $conversationValueInput.Clear() }
                }
            })
    }

    if ($addSegmentPredicateButton) {
        $addSegmentPredicateButton.Add_Click({
                $filter = Build-FilterFromInput -Scope "Segment" -FilterTypeCombo $segmentFilterTypeCombo -PredicateTypeCombo $segmentPredicateTypeCombo -FieldCombo $segmentFieldCombo -OperatorCombo $segmentOperatorCombo -ValueInput $segmentValueInput -PropertyTypeCombo $segmentPropertyTypeCombo
                if ($filter) {
                    Add-FilterEntry -Scope "Segment" -FilterObject $filter
                    if ($segmentValueInput) { $segmentValueInput.Clear() }
                }
            })
    }

    if ($conversationFiltersList -and $removeConversationPredicateButton) {
        $conversationFiltersList.Add_SelectionChanged({
                $removeConversationPredicateButton.IsEnabled = ($conversationFiltersList.SelectedIndex -ge 0)
            })
        $removeConversationPredicateButton.Add_Click({
                $index = $conversationFiltersList.SelectedIndex
                if ($index -ge 0) {
                    $script:FilterBuilderData.ConversationFilters.RemoveAt($index)
                    Refresh-FilterList -Scope "Conversation"
                    $removeConversationPredicateButton.IsEnabled = $false
                }
            })
    }

    if ($segmentFiltersList -and $removeSegmentPredicateButton) {
        $segmentFiltersList.Add_SelectionChanged({
                $removeSegmentPredicateButton.IsEnabled = ($segmentFiltersList.SelectedIndex -ge 0)
            })
        $removeSegmentPredicateButton.Add_Click({
                $index = $segmentFiltersList.SelectedIndex
                if ($index -ge 0) {
                    $script:FilterBuilderData.SegmentFilters.RemoveAt($index)
                    Refresh-FilterList -Scope "Segment"
                    $removeSegmentPredicateButton.IsEnabled = $false
                }
            })
    }

    if ($refreshFiltersButton) {
        $refreshFiltersButton.Add_Click({
                Invoke-FilterBuilderBody
            })
    }
    if ($resetFiltersButton) {
        $resetFiltersButton.Add_Click({
                Reset-FilterBuilderData
                Refresh-FilterList -Scope "Conversation"
                Refresh-FilterList -Scope "Segment"
            })
    }
}

#region UI helpers
function Get-WorkspaceGroupForHeader {
    param([string]$Header)

    $normalized = if ($Header) { $Header.Trim() } else { '' }
    switch ($normalized) {
        'Ops Insights' { return 'Insights' }
        'Ops Dashboard' { return 'Insights' }
        'Forensic Timeline' { return 'Insights' }
        'Live Subscriptions' { return 'Monitoring' }
        'Operational Events' { return 'Monitoring' }
        'Audit Investigator' { return 'Monitoring' }
        'Audit Log' { return 'Monitoring' }
        'Conversation Report' { return 'Monitoring' }
        'Queue Wait Coverage' { return 'Monitoring' }
        default { return 'Api' }
    }
}

function Get-WorkspaceNavButtonForHeader {
    param([string]$Header)

    $workspaceGroup = Get-WorkspaceGroupForHeader -Header $Header
    switch ($workspaceGroup) {
        'Insights' { return $workspaceInsightsButton }
        'Monitoring' { return $workspaceMonitoringButton }
        default { return $workspaceApiButton }
    }
}

function Update-WorkspaceNavigatorState {
    param([string]$Header)

    if (-not $workspaceNavigatorPanel) { return }

    $selectedButton = Get-WorkspaceNavButtonForHeader -Header $Header
    if (-not $selectedButton) { return }

    $buttons = @($workspaceApiButton, $workspaceInsightsButton, $workspaceMonitoringButton) | Where-Object { $_ }

    $surfaceBrush = if ($Window.Resources.Contains('SurfaceBrush')) { $Window.Resources['SurfaceBrush'] } else { [System.Windows.Media.Brushes]::White }
    $surfaceMutedBrush = if ($Window.Resources.Contains('SurfaceMutedBrush')) { $Window.Resources['SurfaceMutedBrush'] } else { [System.Windows.Media.Brushes]::LightGray }
    $accentBrush = if ($Window.Resources.Contains('AccentBrush')) { $Window.Resources['AccentBrush'] } else { $surfaceBrush }
    $textPrimaryBrush = if ($Window.Resources.Contains('TextPrimaryBrush')) { $Window.Resources['TextPrimaryBrush'] } else { [System.Windows.Media.Brushes]::Black }
    $textSecondaryBrush = if ($Window.Resources.Contains('TextSecondaryBrush')) { $Window.Resources['TextSecondaryBrush'] } else { [System.Windows.Media.Brushes]::Gray }

    foreach ($btn in $buttons) {
        if ($btn -eq $selectedButton) {
            $btn.Background = $accentBrush
            $btn.BorderBrush = $accentBrush
            $btn.Foreground = $textPrimaryBrush
            $btn.FontWeight = 'SemiBold'
        }
        else {
            $btn.Background = $surfaceBrush
            $btn.BorderBrush = $surfaceMutedBrush
            $btn.Foreground = $textSecondaryBrush
            $btn.FontWeight = 'Normal'
        }
    }
}

if (-not $script:LayoutDefaultsCaptured) {
    $script:LayoutDefaultsCaptured = $true
    $script:LayoutDefaults = [pscustomobject]@{
        RequestSelectorVisibility = if ($requestSelectorGrid) { $requestSelectorGrid.Visibility } else { $null }
        FavoritesVisibility       = if ($favoritesBorder) { $favoritesBorder.Visibility } else { $null }
        ActionButtonsVisibility   = if ($actionButtonsPanel) { $actionButtonsPanel.Visibility } else { $null }
        ParametersVisibility      = if ($parametersExpander) { $parametersExpander.Visibility } else { $null }
        ParametersExpanded        = if ($parametersExpander) { [bool]$parametersExpander.IsExpanded } else { $false }
        FilterBuilderVisibility   = if ($filterBuilderExpander) { $filterBuilderExpander.Visibility } else { $null }
        FilterBuilderExpanded     = if ($filterBuilderExpander) { [bool]$filterBuilderExpander.IsExpanded } else { $false }
        LeftPaneVisibility        = if ($leftControlPane) { $leftControlPane.Visibility } else { $null }
        SplitterVisibility        = if ($mainContentSplitter) { $mainContentSplitter.Visibility } else { $null }
        LeftColumnWidth           = if ($mainContentGrid -and $mainContentGrid.ColumnDefinitions.Count -gt 0) { $mainContentGrid.ColumnDefinitions[0].Width } else { $null }
        SplitterColumnWidth       = if ($mainContentGrid -and $mainContentGrid.ColumnDefinitions.Count -gt 1) { $mainContentGrid.ColumnDefinitions[1].Width } else { $null }
        RightColumnWidth          = if ($mainContentGrid -and $mainContentGrid.ColumnDefinitions.Count -gt 2) { $mainContentGrid.ColumnDefinitions[2].Width } else { $null }
    }
}

function Set-FocusLayoutForMainTab {
    param(
        [Parameter(Mandatory)]
        [string]$Header
    )

    Update-WorkspaceNavigatorState -Header $Header

    $workspaceGroup = Get-WorkspaceGroupForHeader -Header $Header
    $isApiWorkspace = ($workspaceGroup -eq 'Api')

    if (-not $isApiWorkspace) {
        if ($requestSelectorGrid) { $requestSelectorGrid.Visibility = 'Collapsed' }
        if ($favoritesBorder) { $favoritesBorder.Visibility = 'Collapsed' }
        if ($actionButtonsPanel) { $actionButtonsPanel.Visibility = 'Collapsed' }
        if ($parametersExpander) {
            $parametersExpander.IsExpanded = $false
            $parametersExpander.Visibility = 'Collapsed'
        }
        if ($filterBuilderExpander) {
            $filterBuilderExpander.IsExpanded = $false
            $filterBuilderExpander.Visibility = 'Collapsed'
        }
        if ($leftControlPane) { $leftControlPane.Visibility = 'Collapsed' }
        if ($mainContentSplitter) { $mainContentSplitter.Visibility = 'Collapsed' }
        if ($mainContentGrid -and $mainContentGrid.ColumnDefinitions.Count -gt 2) {
            $mainContentGrid.ColumnDefinitions[0].Width = New-Object System.Windows.GridLength(0)
            $mainContentGrid.ColumnDefinitions[1].Width = New-Object System.Windows.GridLength(0)
            $mainContentGrid.ColumnDefinitions[2].Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
        }
        return
    }

    # Restore defaults for non-Ops Insights tabs
    if ($script:LayoutDefaults) {
        if ($requestSelectorGrid -and $null -ne $script:LayoutDefaults.RequestSelectorVisibility) { $requestSelectorGrid.Visibility = $script:LayoutDefaults.RequestSelectorVisibility }
        if ($favoritesBorder -and $null -ne $script:LayoutDefaults.FavoritesVisibility) { $favoritesBorder.Visibility = $script:LayoutDefaults.FavoritesVisibility }
        if ($actionButtonsPanel -and $null -ne $script:LayoutDefaults.ActionButtonsVisibility) { $actionButtonsPanel.Visibility = $script:LayoutDefaults.ActionButtonsVisibility }

        if ($parametersExpander -and $null -ne $script:LayoutDefaults.ParametersVisibility) {
            $parametersExpander.Visibility = $script:LayoutDefaults.ParametersVisibility
            $parametersExpander.IsExpanded = [bool]$script:LayoutDefaults.ParametersExpanded
        }

        if ($filterBuilderExpander -and $null -ne $script:LayoutDefaults.FilterBuilderVisibility) {
            $filterBuilderExpander.Visibility = $script:LayoutDefaults.FilterBuilderVisibility
            $filterBuilderExpander.IsExpanded = [bool]$script:LayoutDefaults.FilterBuilderExpanded
        }
        if ($leftControlPane -and $null -ne $script:LayoutDefaults.LeftPaneVisibility) {
            $leftControlPane.Visibility = $script:LayoutDefaults.LeftPaneVisibility
        }
        if ($mainContentSplitter -and $null -ne $script:LayoutDefaults.SplitterVisibility) {
            $mainContentSplitter.Visibility = $script:LayoutDefaults.SplitterVisibility
        }
        if ($mainContentGrid -and $mainContentGrid.ColumnDefinitions.Count -gt 2) {
            if ($null -ne $script:LayoutDefaults.LeftColumnWidth) {
                $mainContentGrid.ColumnDefinitions[0].Width = $script:LayoutDefaults.LeftColumnWidth
            }
            if ($null -ne $script:LayoutDefaults.SplitterColumnWidth) {
                $mainContentGrid.ColumnDefinitions[1].Width = $script:LayoutDefaults.SplitterColumnWidth
            }
            if ($null -ne $script:LayoutDefaults.RightColumnWidth) {
                $mainContentGrid.ColumnDefinitions[2].Width = $script:LayoutDefaults.RightColumnWidth
            }
        }
    }
}
#endregion UI helpers

if ($mainTabControl) {
    $mainTabControl.Add_SelectionChanged({
            param($src, $e)
            try {
                if ($e.OriginalSource -ne $src) { return }
                $selected = $src.SelectedItem
                if (-not $selected) { return }
                $header = [string]$selected.Header
                if ([string]::IsNullOrWhiteSpace($header)) { return }
                Set-FocusLayoutForMainTab -Header $header
            }
            catch {
                # Don't break the UI for layout issues
            }
        })

    try {
        $initial = $mainTabControl.SelectedItem
        if ($initial) { Set-FocusLayoutForMainTab -Header ([string]$initial.Header) }
    }
    catch { }
}
#region State + Models
$script:LastConversationReport = $null
$script:LastConversationReportJson = ""
$script:RequestHistory = New-Object System.Collections.ObjectModel.ObservableCollection[Object]
$script:ResponseViewMode = "Formatted"  # Can be "Formatted" or "Raw"
$script:Templates = New-Object System.Collections.ObjectModel.ObservableCollection[Object]
$script:TemplatesFilePath = Join-Path -Path $env:USERPROFILE -ChildPath "GenesysApiExplorerTemplates.json"
$script:CurrentBodyControl = $null
$script:CurrentBodySchema = $null
$script:InsightMetrics = New-Object System.Collections.ObjectModel.ObservableCollection[Object]
$script:InsightDrilldowns = New-Object System.Collections.ObjectModel.ObservableCollection[Object]
$script:LastInsightResult = $null
$script:InsightBriefingsHistory = New-Object System.Collections.ObjectModel.ObservableCollection[Object]
$script:QueueWaitResults = New-Object System.Collections.ObjectModel.ObservableCollection[Object]
#endregion State + Models

#region Transport/API
function Invoke-ReloadEndpoints {
    param (
        [string]$JsonPath
    )

    try {
        if (-not (Test-Path -Path $JsonPath)) {
            [System.Windows.MessageBox]::Show("The endpoints file does not exist at: $JsonPath", "File Not Found", "OK", "Error")
            return $false
        }

        $newCatalog = Load-PathsFromJson -JsonPath $JsonPath

        if (-not $newCatalog) {
            [System.Windows.MessageBox]::Show("Failed to load endpoints from the selected file.", "Load Error", "OK", "Error")
            return $false
        }

        # Update global variables
        $script:ApiCatalog = $newCatalog
        $script:ApiPaths = $newCatalog.Paths
        $script:Definitions = if ($newCatalog.Definitions) { $newCatalog.Definitions } else { @{} }
        $script:GroupMap = Build-GroupMap -Paths $script:ApiPaths
        $script:CurrentJsonPath = $JsonPath

        Initialize-FilterBuilderEnum
        Reset-FilterBuilderData
        Update-FilterBuilderHint
        Set-FilterBuilderVisibility -Visible $false

        # Refresh UI
        $groupCombo.Items.Clear()
        $pathCombo.Items.Clear()
        $methodCombo.Items.Clear()
        $parameterPanel.Children.Clear()
        $paramInputs.Clear()
        $responseBox.Text = ""
        $btnSave.IsEnabled = $false

        foreach ($group in ($script:GroupMap.Keys | Sort-Object)) {
            $groupCombo.Items.Add($group) | Out-Null
        }

        $statusText.Text = "Endpoints reloaded successfully from: $(Split-Path -Leaf $JsonPath)"
        Add-LogEntry "Endpoints reloaded from: $JsonPath"

        return $true
    }
    catch {
        [System.Windows.MessageBox]::Show("Error loading endpoints: $($_.Exception.Message)", "Load Error", "OK", "Error")
        Add-LogEntry "Error reloading endpoints: $($_.Exception.Message)"
        return $false
    }
}
#endregion Transport/API

function Test-RageClick {
    param([datetime]$Now)

    $script:SubmitClickTimes.Enqueue($Now)
    while ($script:SubmitClickTimes.Count -gt 0 -and ($Now - $script:SubmitClickTimes.Peek()).TotalSeconds -gt $script:RageClickWindowSeconds) {
        $null = $script:SubmitClickTimes.Dequeue()
    }
    if ($script:SubmitClickTimes.Count -gt 20) {
        $null = $script:SubmitClickTimes.Dequeue()
    }
    return ($script:SubmitClickTimes.Count -ge 3)
}

#region Logging
function Add-LogEntry {
    param ([string]$Message)

    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    if ($logBox) {
        $logBox.AppendText("[$timestamp] $Message`r`n")
        $logBox.ScrollToEnd()
    }
    Write-UxEvent -Name "log" -Properties @{ message = $Message; ts = $timestamp }
}
#endregion Logging

function Set-ConvReportUiState {
    param(
        [ValidateSet('Idle','Loading','Complete','Partial','Error')]
        [string]$State,
        [string]$StatusText = '',
        [int]$ProgressPercent = 0,
        [string]$ProgressLabel = '',
        [string]$ErrorText = '',
        [string]$WarningText = '',
        [bool]$ExportEnabled = $false
    )

    if ($conversationReportStatus) { $conversationReportStatus.Text = $StatusText }
    if ($conversationReportProgressBar) { $conversationReportProgressBar.Value = $ProgressPercent }
    if ($conversationReportProgressText) { $conversationReportProgressText.Text = $ProgressLabel }

    if ($convReportErrorBanner) { $convReportErrorBanner.Visibility = if ($ErrorText) { 'Visible' } else { 'Collapsed' } }
    if ($convReportErrorText -and $ErrorText) { $convReportErrorText.Text = $ErrorText }
    if ($convReportWarningBanner) { $convReportWarningBanner.Visibility = if ($WarningText) { 'Visible' } else { 'Collapsed' } }
    if ($convReportWarningText -and $WarningText) { $convReportWarningText.Text = $WarningText }

    if ($runConversationReportButton) { $runConversationReportButton.IsEnabled = ($State -ne 'Loading') }
    if ($cancelConversationReportButton) { $cancelConversationReportButton.Visibility = if ($State -eq 'Loading') { 'Visible' } else { 'Collapsed' } }

    foreach ($btn in @($inspectConversationReportButton, $exportConversationReportJsonButton, $exportConversationReportTextButton)) {
        if ($btn) { $btn.IsEnabled = $ExportEnabled }
    }
}

function Get-ExcelColumnName {
    param([int]$Index)

    if ($Index -lt 1) { throw "Excel column index must be 1 or greater." }

    $name = ''
    while ($Index -gt 0) {
        $Index--
        $name = [char]([int]'A' + ($Index % 26)) + $name
        $Index = [math]::Floor($Index / 26)
    }

    return $name
}

function Export-SimpleExcelWorkbook {
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter(Mandatory)]
        [array]$Tables
    )

    if (-not $Tables -or $Tables.Count -eq 0) {
        throw "At least one table is required to build an Excel workbook."
    }

    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue

    $escape = {
        param($value)
        $text = if ($null -eq $value) { '' } else { [string]$value }
        [System.Security.SecurityElement]::Escape($text)
    }

    $sheetBuilder = [System.Text.StringBuilder]::new()
    $rowIndex = 1

    foreach ($table in $Tables) {
        $title = if ($table.Title) { $table.Title } else { 'Table' }
        $sheetBuilder.AppendLine("<row r='$rowIndex'><c r='A$rowIndex' t='inlineStr'><is><t>$($escape.Invoke($title))</t></is></c></row>") > $null
        $rowIndex++

        $headers = @()
        if ($table.Headers) {
            $headers = @($table.Headers)
        }
        elseif ($table.Rows -and $table.Rows.Count -gt 0 -and ($table.Rows[0] -is [System.Collections.IDictionary])) {
            $headers = @($table.Rows[0].Keys)
        }
        else {
            $headers = @('Value')
        }

        $colCount = $headers.Count
        $cellBuilder = [System.Text.StringBuilder]::new()
        foreach ($headerIndex in 0..($headers.Count - 1)) {
            $headerValue = $headers[$headerIndex]
            $columnName = Get-ExcelColumnName -Index ($headerIndex + 1)
            $cellBuilder.Append("<c r='$columnName$rowIndex' t='inlineStr'><is><t>$($escape.Invoke($headerValue))</t></is></c>") > $null
        }
        $sheetBuilder.AppendLine("<row r='$rowIndex'>$($cellBuilder.ToString())</row>")
        $rowIndex++

        foreach ($row in @($table.Rows)) {
            $cellBuilder.Clear()
            $values = @()

            if ($row -is [System.Collections.IDictionary]) {
                foreach ($header in $headers) {
                    $values += $row[$header]
                }
            }
            elseif ($row -is [System.Collections.IEnumerable] -and -not ($row -is [string])) {
                $values = @($row)
            }
            else {
                $values = @($row)
            }

            for ($col = 0; $col -lt $headers.Count; $col++) {
                $columnName = Get-ExcelColumnName -Index ($col + 1)
                $value = if ($col -lt $values.Count) { $values[$col] } else { '' }
                $cellBuilder.Append("<c r='$columnName$rowIndex' t='inlineStr'><is><t>$($escape.Invoke($value))</t></is></c>") > $null
            }

            $sheetBuilder.AppendLine("<row r='$rowIndex'>$($cellBuilder.ToString())</row>")
            $rowIndex++
        }

        $rowIndex++  # blank spacer row
    }

    $sheetXml = @"
<?xml version="1.0" encoding="utf-8"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <sheetData>
$($sheetBuilder.ToString())
  </sheetData>
</worksheet>
"@

    $workbookXml = @"
<?xml version="1.0" encoding="utf-8"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
          xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>
    <sheet name="Summary" sheetId="1" r:id="rId1"/>
  </sheets>
</workbook>
"@

    $relsXml = @"
<?xml version="1.0" encoding="utf-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1"
                Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet"
                Target="worksheets/sheet1.xml"/>
  <Relationship Id="rId2"
                Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles"
                Target="styles.xml"/>
</Relationships>
"@

    $relRootXml = @"
<?xml version="1.0" encoding="utf-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1"
                Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument"
                Target="xl/workbook.xml"/>
</Relationships>
"@

    $contentTypesXml = @"
<?xml version="1.0" encoding="utf-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
  <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
</Types>
"@

    $stylesXml = @"
<?xml version="1.0" encoding="utf-8"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <fonts count="1">
    <font>
      <sz val="11"/>
      <color theme="1"/>
      <name val="Calibri"/>
    </font>
  </fonts>
  <fills count="1">
    <fill>
      <patternFill patternType="none"/>
    </fill>
  </fills>
  <borders count="1">
    <border/>
  </borders>
  <cellStyleXfs count="1">
    <xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>
  </cellStyleXfs>
  <cellXfs count="1">
    <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
  </cellXfs>
</styleSheet>
"@

    $tempPath = [System.IO.Path]::GetTempFileName()
    Remove-Item -LiteralPath $tempPath -Force
    $fileStream = [System.IO.File]::Open($tempPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
    $zip = [System.IO.Compression.ZipArchive]::new($fileStream, [System.IO.Compression.ZipArchiveMode]::Create, $true)

    $addEntry = {
        param($name, $content)
        $entry = $zip.CreateEntry($name)
        $writer = New-Object System.IO.StreamWriter($entry.Open(), [System.Text.Encoding]::UTF8)
        $writer.Write($content)
        $writer.Flush()
        $writer.Dispose()
    }

    $addEntry.Invoke('[Content_Types].xml', $contentTypesXml)
    $addEntry.Invoke('_rels/.rels', $relRootXml)
    $addEntry.Invoke('xl/workbook.xml', $workbookXml)
    $addEntry.Invoke('xl/_rels/workbook.xml.rels', $relsXml)
    $addEntry.Invoke('xl/worksheets/sheet1.xml', $sheetXml)
    $addEntry.Invoke('xl/styles.xml', $stylesXml)

    $zip.Dispose()
    $fileStream.Dispose()

    Move-Item -LiteralPath $tempPath -Destination $Path -Force
}

#region Feature tabs (Conversation, Audit, Live Sub, Ops Dash, etc.)
function Build-AuditSummaryTables {
    param(
        [Parameter(Mandatory)]
        [array]$Events
    )

    $userCounts = @{}
    $serviceCounts = @{}
    $timeline = @{}

    foreach ($event in $Events) {
        $user = if ($event.UserId) { $event.UserId } elseif ($event.userId) { $event.userId } else { 'unknown' }
        $userCounts[$user] = ($userCounts[$user] + 1)

        $service = if ($event.Service) { $event.Service } elseif ($event.service) { $event.service } else { 'unknown' }
        $serviceCounts[$service] = ($serviceCounts[$service] + 1)

        $ts = if ($event.Timestamp) { [DateTime]::Parse($event.Timestamp) } elseif ($event.timestamp) { [DateTime]::Parse($event.timestamp) } else { (Get-Date) }
        $slot = $ts.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm")
        $timeline[$slot] = ($timeline[$slot] + 1)
    }

    $tables = @()
    $tables += [pscustomobject]@{
        Title   = 'Actions by User'
        Headers = @('User', 'Count')
        Rows    = $userCounts.Keys | Sort-Object | ForEach-Object { [pscustomobject]@{ User = $_; Count = $userCounts[$_] } }
    }
    $tables += [pscustomobject]@{
        Title   = 'Per-Service Activity'
        Headers = @('Service', 'Count')
        Rows    = $serviceCounts.Keys | Sort-Object | ForEach-Object { [pscustomobject]@{ Service = $_; Count = $serviceCounts[$_] } }
    }
    $tables += [pscustomobject]@{
        Title   = 'Timeline (per minute)'
        Headers = @('Minute', 'Count')
        Rows    = $timeline.Keys | Sort-Object | ForEach-Object { [pscustomobject]@{ Minute = $_; Count = $timeline[$_] } }
    }

    return $tables
}

function Format-AuditTimelineText {
    param(
        [Parameter(Mandatory)]
        [array]$Events
    )

    $sb = [System.Text.StringBuilder]::new()
    foreach ($event in $Events) {
        $time = if ($event.Timestamp) { $event.Timestamp } elseif ($event.timestamp) { $event.timestamp } else { (Get-Date).ToString("o") }
        $user = if ($event.UserId) { $event.UserId } elseif ($event.userId) { $event.userId } else { '(unknown)' }
        $action = if ($event.Action) { $event.Action } elseif ($event.action) { $event.action } else { '(unknown)' }
        $entity = if ($event.EntityId) { $event.EntityId } elseif ($event.entityId) { $event.entityId } else { '(none)' }
        [void]$sb.AppendLine("$time | user=$user | action=$action | entity=$entity")
    }
    return $sb.ToString()
}


function Refresh-FavoritesList {
    if (-not $favoritesList) { return }
    $favoritesList.Items.Clear()

    foreach ($favorite in $Favorites) {
        $favoritesList.Items.Add($favorite) | Out-Null
    }

    $favoritesList.SelectedIndex = -1
    if ($Favorites.Count -eq 0) {
        Write-UxEvent -Name "empty_state_seen" -Properties @{ target = "favorites"; route = "home" }
    }
}

function Get-InsightPackPath {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        $FileName
    )

    if (-not $insightPackRoot) {
        throw "Insight pack root path is not configured."
    }

    $packName = $FileName
    if ($packName -is [System.Collections.IEnumerable] -and -not ($packName -is [string])) {
        $packName = $packName | Select-Object -First 1
    }

    $packName = [string]$packName
    if ([string]::IsNullOrWhiteSpace($packName)) {
        throw "Insight pack file name is required."
    }

    $candidate = Join-Path -Path $insightPackRoot -ChildPath $packName
    if (Test-Path -LiteralPath $candidate) { return $candidate }

    return $candidate
}

function Get-InsightBriefingDirectory {
    $targetDir = $insightBriefingRoot

    if (-not $targetDir) {
        throw "Insight briefing root path is not configured."
    }

    if (-not (Test-Path -LiteralPath $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }

    return $targetDir
}

function Update-InsightPackUi {
    param(
        [Parameter(Mandatory)]
        $Result
    )

    $script:InsightMetrics.Clear()
    $script:InsightDrilldowns.Clear()

    $metrics = @($Result.Metrics)
    $drilldowns = @($Result.Drilldowns)

    $index = 0
    foreach ($metric in $metrics) {
        $index++
        $title = if ($metric.PSObject.Properties.Name -contains 'title') { $metric.title } else { "Metric $index" }
        $value = if ($metric.PSObject.Properties.Name -contains 'value') { $metric.value } else { $null }
        $itemsCount = if ($metric.PSObject.Properties.Name -contains 'items') { (@($metric.items)).Count } else { 0 }
        $script:InsightMetrics.Add([pscustomobject]@{
                Title   = $title
                Value   = $value
                Items   = $itemsCount
                Details = if ($metric.PSObject.Properties.Name -contains 'items') { ($metric.items | ConvertTo-Json -Depth 4) } else { $null }
            }) | Out-Null
    }

    foreach ($drilldown in $drilldowns) {
        $title = if ($drilldown.PSObject.Properties.Name -contains 'title') { $drilldown.title } elseif (($drilldown.PSObject.Properties.Name -contains 'Id') -and $drilldown.Id) { $drilldown.Id } else { 'drilldown' }
        $rowCount = if ($drilldown.PSObject.Properties.Name -contains 'items') { (@($drilldown.items)).Count } else { 0 }
        $summary = if ($rowCount -gt 0) { "$rowCount rows" } else { '' }
        $script:InsightDrilldowns.Add([pscustomobject]@{
                Title    = $title
                RowCount = $rowCount
                Summary  = $summary
            }) | Out-Null
    }

    if ($insightEvidenceSummary) {
        $evidence = $Result.Evidence
        $severity = if ($evidence -and ($evidence.PSObject.Properties.Name -contains 'Severity')) { $evidence.Severity } else { 'Info' }
        $impact = if ($evidence -and ($evidence.PSObject.Properties.Name -contains 'Impact')) { $evidence.Impact } else { '' }
        $narrative = if ($evidence) { $evidence.Narrative } else { '(No narrative available)' }
        $drillNotes = if ($evidence) { $evidence.DrilldownNotes } else { '' }
        $insightEvidenceSummary.Text = "Severity: $severity`nImpact: $impact`nNarrative: $narrative`nDrilldowns: $drillNotes"
    }
}

function Run-InsightPackWorkflow {
    param(
        [Parameter(Mandatory)]
        [string]$Label,

        [Parameter(Mandatory)]
        [string]$FileName,

        [Parameter()]
        [string]$TimePresetKey
    )

    try {
        # Prefer selecting the pack in the UI so parameter controls exist and start/end can be applied.
        if ($insightPackCombo -and $script:InsightPackCatalog -and $script:InsightPackCatalog.Count -gt 0) {
            $target = @($script:InsightPackCatalog | Where-Object { $_.FileName -eq $FileName } | Select-Object -First 1)
            if ($target) {
                $insightPackCombo.SelectedItem = $target
            }
        }

        if ($TimePresetKey) {
            try { Apply-InsightTimePresetToUi -PresetKey $TimePresetKey } catch { }
        }

        if ($runQueueSmokePackButton) { $runQueueSmokePackButton.IsEnabled = $false }
        if ($runDataActionsPackButton) { $runDataActionsPackButton.IsEnabled = $false }
        if ($runDataActionsEnrichedPackButton) { $runDataActionsEnrichedPackButton.IsEnabled = $false }
        if ($runPeakConcurrencyPackButton) { $runPeakConcurrencyPackButton.IsEnabled = $false }
        if ($runMosMonthlyPackButton) { $runMosMonthlyPackButton.IsEnabled = $false }

        $statusText.Text = "Running insight pack: $Label..."

        Run-SelectedInsightPack -Compare:$false -DryRun:$false | Out-Null
        $statusText.Text = "Insight pack '$Label' completed."
    }
    catch {
        $statusText.Text = "Insight pack '$Label' failed."
        Add-LogEntry "Insight pack '$Label' failed: $($_.Exception.Message)"
        [System.Windows.MessageBox]::Show("Insight pack '$Label' failed: $($_.Exception.Message)", "Insight Pack Error", "OK", "Error")
    }
    finally {
        if ($runQueueSmokePackButton) { $runQueueSmokePackButton.IsEnabled = $true }
        if ($runDataActionsPackButton) { $runDataActionsPackButton.IsEnabled = $true }
        if ($runDataActionsEnrichedPackButton) { $runDataActionsEnrichedPackButton.IsEnabled = $true }
        if ($runPeakConcurrencyPackButton) { $runPeakConcurrencyPackButton.IsEnabled = $true }
        if ($runMosMonthlyPackButton) { $runMosMonthlyPackButton.IsEnabled = $true }
    }
}

function Export-InsightBriefingWorkflow {
    if (-not $script:LastInsightResult) {
        [System.Windows.MessageBox]::Show("Run an insight pack before exporting a briefing.", "Insight Briefing", "OK", "Information")
        return
    }

    $outputDir = Get-InsightBriefingDirectory
    $exportResult = Export-GCInsightBriefing -Result $script:LastInsightResult -Directory $outputDir -Force:$true

    $statusText.Text = "Insight briefing exported: $($exportResult.HtmlPath)"
    Add-LogEntry "Insight briefing exported: $($exportResult.HtmlPath)"

    if ($insightBriefingPathText) {
        $insightBriefingPathText.Text = "Briefings folder: $outputDir`nLast export: $($exportResult.HtmlPath)"
    }

    Refresh-InsightBriefingHistory

    if ($insightBriefingsList -and $script:InsightBriefingsHistory.Count -gt 0) {
        $insightBriefingsList.SelectedIndex = $script:InsightBriefingsHistory.Count - 1
        $insightBriefingsList.ScrollIntoView($insightBriefingsList.SelectedItem)
    }

    [System.Windows.MessageBox]::Show("Briefing exported to:`n$($exportResult.HtmlPath)", "Insight Briefing", "OK", "Information")
}

foreach ($group in ($script:GroupMap.Keys | Sort-Object)) {
    $groupCombo.Items.Add($group) | Out-Null
}

$statusText.Text = "Select a group to begin."
Refresh-FavoritesList

Update-JobPanel -Status "" -Updated ""

if ($Favorites.Count -gt 0) {
    Add-LogEntry "Loaded $($Favorites.Count) favorites from $FavoritesFile."
}
else {
    Add-LogEntry "No favorites saved yet; create one from your current request."
}

Show-SplashScreen

$groupCombo.Add_SelectionChanged({
        $parameterPanel.Children.Clear()
        $paramInputs.Clear()
        $pathCombo.Items.Clear()
        $methodCombo.Items.Clear()
        $responseBox.Text = ""
        $btnSave.IsEnabled = $false

        $selectedGroup = $groupCombo.SelectedItem
        if (-not $selectedGroup) {
            return
        }

        $paths = $script:GroupMap[$selectedGroup]
        if (-not $paths) { return }
        foreach ($path in ($paths | Sort-Object)) {
            $pathCombo.Items.Add($path) | Out-Null
        }

        $statusText.Text = "Group '$selectedGroup' selected. Choose a path."
    })

$pathCombo.Add_SelectionChanged({
        $methodCombo.Items.Clear()
        $parameterPanel.Children.Clear()
        $paramInputs.Clear()
        $responseBox.Text = ""
        $btnSave.IsEnabled = $false

        $selectedPath = $pathCombo.SelectedItem
        if (-not $selectedPath) { return }

        $pathObject = Get-PathObject -ApiPaths $script:ApiPaths -Path $selectedPath
        if (-not $pathObject) { return }

        # Filter methods to only include GET and POST (read-only mode)
        $allowedMethods = @('get', 'post')
        foreach ($method in $pathObject.PSObject.Properties | Select-Object -ExpandProperty Name) {
            if ($allowedMethods -contains $method.ToLower()) {
                $methodCombo.Items.Add($method) | Out-Null
            }
        }

        $statusText.Text = "Path '$selectedPath' loaded. Select a method."
    })

$methodCombo.Add_SelectionChanged({
        $parameterPanel.Children.Clear()
        $paramInputs.Clear()
        $responseBox.Text = ""
        $btnSave.IsEnabled = $false

        $selectedPath = $pathCombo.SelectedItem
        $selectedMethod = $methodCombo.SelectedItem
        if (-not $selectedPath -or -not $selectedMethod) {
            return
        }

        $script:CurrentBodyControl = $null
        $script:CurrentBodySchema = $null
        Reset-FilterBuilderData
        Set-FilterBuilderVisibility -Visible $false

        $pathObject = Get-PathObject -ApiPaths $script:ApiPaths -Path $selectedPath
        $methodObject = Get-MethodObject -PathObject $pathObject -MethodName $selectedMethod
        if (-not $methodObject) {
            return
        }

        $params = $methodObject.parameters
        if (-not $params) { return }

        foreach ($param in $params) {
            $row = New-Object System.Windows.Controls.Grid
            $row.Margin = New-Object System.Windows.Thickness 0, 0, 0, 8

            $col0 = New-Object System.Windows.Controls.ColumnDefinition
            $col0.Width = New-Object System.Windows.GridLength 240
            $row.ColumnDefinitions.Add($col0)

            $col1 = New-Object System.Windows.Controls.ColumnDefinition
            $col1.Width = New-Object System.Windows.GridLength 1, ([System.Windows.GridUnitType]::Star)
            $row.ColumnDefinitions.Add($col1)

            $label = New-Object System.Windows.Controls.TextBlock
            $label.Text = "$($param.name) ($($param.in))"
            if ($param.required) {
                $label.Text += " (required)"
            }
            $label.VerticalAlignment = "Center"
            $label.ToolTip = $param.description
            $label.Margin = New-Object System.Windows.Thickness 0, 0, 10, 0
            [System.Windows.Controls.Grid]::SetColumn($label, 0)

            # Check if parameter has enum values (dropdown)
            if ($param.enum -and $param.enum.Count -gt 0) {
                $comboBox = New-Object System.Windows.Controls.ComboBox
                $comboBox.MinWidth = 360
                $comboBox.HorizontalAlignment = "Stretch"
                $comboBox.Height = 28
                if ($param.required) {
                    $comboBox.Background = [System.Windows.Media.Brushes]::LightYellow
                }
                $comboBox.ToolTip = $param.description

                # Add empty option for optional parameters
                if (-not $param.required) {
                    $comboBox.Items.Add("") | Out-Null
                }

                # Add enum values
                foreach ($enumValue in $param.enum) {
                    $comboBox.Items.Add($enumValue) | Out-Null
                }

                # Set default value if exists
                if ($param.default) {
                    $comboBox.SelectedItem = $param.default
                }

                [System.Windows.Controls.Grid]::SetColumn($comboBox, 1)
                $inputControl = $comboBox
            }
            # Check if parameter is boolean type (checkbox)
            elseif ($param.type -eq "boolean") {
                $checkBoxPanel = New-Object System.Windows.Controls.StackPanel
                $checkBoxPanel.Orientation = "Horizontal"

                $checkBox = New-Object System.Windows.Controls.CheckBox
                $checkBox.VerticalAlignment = "Center"
                $checkBox.ToolTip = $param.description
                $checkBox.Margin = New-Object System.Windows.Thickness 0, 0, 10, 0

                # Set default value if exists
                if ($param.default -ne $null) {
                    if ($param.default -eq $true -or $param.default -eq "true") {
                        $checkBox.IsChecked = $true
                    }
                }

                $checkBoxLabel = New-Object System.Windows.Controls.TextBlock
                $checkBoxLabel.Text = if ($param.default -ne $null) { "(default: $($param.default))" } else { "" }
                $checkBoxLabel.VerticalAlignment = "Center"
                $checkBoxLabel.Foreground = [System.Windows.Media.Brushes]::Gray
                $checkBoxLabel.FontSize = 11

                $checkBoxPanel.Children.Add($checkBox) | Out-Null
                $checkBoxPanel.Children.Add($checkBoxLabel) | Out-Null

                [System.Windows.Controls.Grid]::SetColumn($checkBoxPanel, 1)
                $inputControl = $checkBoxPanel
                # Store reference to the checkbox itself for value retrieval
                $inputControl | Add-Member -NotePropertyName "ValueControl" -NotePropertyValue $checkBox
            }
            # Check if parameter is array type
            elseif ($param.type -eq "array") {
                # Create a container for textbox and hint
                $arrayPanel = New-Object System.Windows.Controls.StackPanel
                $arrayPanel.Orientation = "Vertical"

                $textbox = New-Object System.Windows.Controls.TextBox
                $textbox.MinWidth = 360
                $textbox.HorizontalAlignment = "Stretch"
                $textbox.Height = 28
                if ($param.required) {
                    $textbox.Background = [System.Windows.Media.Brushes]::LightYellow
                }
                $textbox.ToolTip = $param.description

                # Store array metadata for validation
                $textbox | Add-Member -NotePropertyName "IsArrayType" -NotePropertyValue $true
                $textbox | Add-Member -NotePropertyName "ArrayItems" -NotePropertyValue $param.items

                # Add hint text
                $hintText = New-Object System.Windows.Controls.TextBlock
                $itemTypeStr = if ($param.items -and $param.items.type) { $param.items.type } else { "string" }
                $hintText.Text = "Enter comma-separated values (type: $itemTypeStr)"
                $hintText.FontSize = 10
                $hintText.Foreground = [System.Windows.Media.Brushes]::Gray
                $hintText.Margin = New-Object System.Windows.Thickness 0, 2, 0, 0

                # Add validation indicator
                $validationText = New-Object System.Windows.Controls.TextBlock
                $validationText.FontSize = 10
                $validationText.Margin = New-Object System.Windows.Thickness 0, 2, 0, 0
                $validationText.Visibility = "Collapsed"

                # Store reference to validation text for later updates
                $textbox | Add-Member -NotePropertyName "ValidationText" -NotePropertyValue $validationText

                # Add real-time validation for array parameters
                $textbox.Add_TextChanged({
                        param($textBox, $changeEvent)
                        $text = $textBox.Text.Trim()
                        $validationTextBlock = $textBox.ValidationText

                        if ([string]::IsNullOrWhiteSpace($text)) {
                            $textBox.BorderBrush = $null
                            $textBox.BorderThickness = New-Object System.Windows.Thickness 1
                            $validationTextBlock.Visibility = "Collapsed"
                        }
                        else {
                            $testResult = Test-ArrayValue -Value $text -ItemType $textBox.ArrayItems
                            if ($testResult.IsValid) {
                                $textBox.BorderBrush = [System.Windows.Media.Brushes]::Green
                                $textBox.BorderThickness = New-Object System.Windows.Thickness 2
                                $validationTextBlock.Visibility = "Collapsed"
                            }
                            else {
                                $textBox.BorderBrush = [System.Windows.Media.Brushes]::Red
                                $textBox.BorderThickness = New-Object System.Windows.Thickness 2
                                $validationTextBlock.Text = "$([char]0x2717) " + $testResult.ErrorMessage
                                $validationTextBlock.Foreground = [System.Windows.Media.Brushes]::Red
                                $validationTextBlock.Visibility = "Visible"
                            }
                        }
                    })

                $arrayPanel.Children.Add($textbox) | Out-Null
                $arrayPanel.Children.Add($hintText) | Out-Null
                $arrayPanel.Children.Add($validationText) | Out-Null

                [System.Windows.Controls.Grid]::SetColumn($arrayPanel, 1)
                $inputControl = $arrayPanel
                # Store reference to the textbox itself for value retrieval
                $inputControl | Add-Member -NotePropertyName "ValueControl" -NotePropertyValue $textbox
            }
            # Default: use textbox
            else {
                $textbox = New-Object System.Windows.Controls.TextBox
                $textbox.MinWidth = 360
                $textbox.HorizontalAlignment = "Stretch"
                $textbox.TextWrapping = "Wrap"
                $textbox.AcceptsReturn = ($param.in -eq "body")
                $textbox.Height = if ($param.in -eq "body") { 80 } else { 28 }
                if ($param.required) {
                    $textbox.Background = [System.Windows.Media.Brushes]::LightYellow
                }

                # Build enhanced tooltip with validation constraints
                $enhancedTooltip = $param.description
                if ($param.type -eq "integer" -or $param.type -eq "number") {
                    if ($param.minimum -ne $null) {
                        $enhancedTooltip += "`n`nMinimum: $($param.minimum)"
                    }
                    if ($param.maximum -ne $null) {
                        $enhancedTooltip += "`n`nMaximum: $($param.maximum)"
                    }
                    if ($param.format) {
                        $enhancedTooltip += "`n`nFormat: $($param.format)"
                    }
                }
                if ($param.default -ne $null) {
                    $enhancedTooltip += "`n`nDefault: $($param.default)"
                }
                $textbox.ToolTip = $enhancedTooltip

                # Store parameter metadata for validation
                if ($param.in -eq "body") {
                    $textbox.Tag = "body"
                }
                else {
                    # Store type and validation constraints
                    $textbox.Tag = @{
                        Type    = $param.type
                        Format  = $param.format
                        Minimum = $param.minimum
                        Maximum = $param.maximum
                    }
                }

                # Add real-time JSON validation for body parameters
                if ($param.in -eq "body") {
                    $textbox.Tag = "body"

                    # Create container for body textbox with character count
                    $bodyPanel = New-Object System.Windows.Controls.StackPanel
                    $bodyPanel.Orientation = "Vertical"

                    # Add line number and character count info
                    $infoText = New-Object System.Windows.Controls.TextBlock
                    $infoText.FontSize = 10
                    $infoText.Foreground = [System.Windows.Media.Brushes]::Gray
                    $infoText.Margin = New-Object System.Windows.Thickness 0, 2, 0, 0
                    $infoText.Text = "Lines: 0 | Characters: 0"

                    # Store reference for updates
                    $textbox | Add-Member -NotePropertyName "InfoText" -NotePropertyValue $infoText

                    $textbox.Add_TextChanged({
                            param($textBox, $eventArgs)
                            $text = $textBox.Text.Trim()
                            $infoTextBlock = $textBox.InfoText

                            # Update character count and line count
                            $charCount = $textBox.Text.Length
                            $lineCount = ($textBox.Text -split "`n").Count
                            $infoTextBlock.Text = "Lines: $lineCount | Characters: $charCount"

                            if ([string]::IsNullOrWhiteSpace($text)) {
                                # Empty is OK - will be checked as required field
                                $textBox.BorderBrush = $null
                                $textBox.BorderThickness = New-Object System.Windows.Thickness 1
                                $infoTextBlock.Foreground = [System.Windows.Media.Brushes]::Gray
                            }
                            elseif (Test-JsonString -JsonString $text) {
                                # Valid JSON - green border and checkmark
                                $textBox.BorderBrush = [System.Windows.Media.Brushes]::Green
                                $textBox.BorderThickness = New-Object System.Windows.Thickness 2
                                $infoTextBlock.Foreground = [System.Windows.Media.Brushes]::Green
                            }
                            else {
                                # Invalid JSON - red border and X
                                $textBox.BorderBrush = [System.Windows.Media.Brushes]::Red
                                $textBox.BorderThickness = New-Object System.Windows.Thickness 2
                                $infoTextBlock.Foreground = [System.Windows.Media.Brushes]::Red
                            }
                        })

                    # Replace the textbox with the panel containing textbox and info
                    $bodyPanel.Children.Add($textbox) | Out-Null
                    $bodyPanel.Children.Add($infoText) | Out-Null
                    [System.Windows.Controls.Grid]::SetColumn($bodyPanel, 1)
                    $inputControl = $bodyPanel
                    # Store reference to the textbox for value retrieval
                    $inputControl | Add-Member -NotePropertyName "ValueControl" -NotePropertyValue $textbox
                }
                # Add real-time validation for numeric and format parameters
                elseif ($param.type -in @("integer", "number") -or $param.format -or $param.pattern) {
                    # Create container for textbox and validation message
                    $validatedPanel = New-Object System.Windows.Controls.StackPanel
                    $validatedPanel.Orientation = "Vertical"

                    $validationText = New-Object System.Windows.Controls.TextBlock
                    $validationText.FontSize = 10
                    $validationText.Margin = New-Object System.Windows.Thickness 0, 2, 0, 0
                    $validationText.Visibility = "Collapsed"

                    # Store reference to validation text
                    $textbox | Add-Member -NotePropertyName "ValidationText" -NotePropertyValue $validationText

                    $textbox.Add_TextChanged({
                            param($zsender, $e)
                            $text = $zsender.Text.Trim()
                            $validationTextBlock = $zsender.ValidationText

                            if ([string]::IsNullOrWhiteSpace($text)) {
                                $zsender.BorderBrush = $null
                                $zsender.BorderThickness = New-Object System.Windows.Thickness 1
                                $validationTextBlock.Visibility = "Collapsed"
                            }
                            else {
                                $isValid = $true
                                $errorMsg = ""

                                # Validate numeric types
                                if ($zsender.ParamType -in @("integer", "number")) {
                                    $testResult = Test-NumericValue -Value $text -Type $zsender.ParamType -Minimum $zsender.ParamMinimum -Maximum $zsender.ParamMaximum
                                    $isValid = $testResult.IsValid
                                    $errorMsg = $testResult.ErrorMessage
                                }
                                # Validate string formats
                                elseif ($zsender.ParamFormat -or $zsender.ParamPattern) {
                                    $testResult = Test-StringFormat -Value $text -Format $zsender.ParamFormat -Pattern $zsender.ParamPattern
                                    $isValid = $testResult.IsValid
                                    $errorMsg = $testResult.ErrorMessage
                                }

                                if ($isValid) {
                                    $zsender.BorderBrush = [System.Windows.Media.Brushes]::Green
                                    $zsender.BorderThickness = New-Object System.Windows.Thickness 2
                                    $validationTextBlock.Visibility = "Collapsed"
                                }
                                else {
                                    $zsender.BorderBrush = [System.Windows.Media.Brushes]::Red
                                    $zsender.BorderThickness = New-Object System.Windows.Thickness 2
                                    $validationTextBlock.Text = "$([char]0x2717) " + $errorMsg
                                    $validationTextBlock.Foreground = [System.Windows.Media.Brushes]::Red
                                    $validationTextBlock.Visibility = "Visible"
                                }
                            }
                        })

                    $validatedPanel.Children.Add($textbox) | Out-Null
                    $validatedPanel.Children.Add($validationText) | Out-Null
                    [System.Windows.Controls.Grid]::SetColumn($validatedPanel, 1)
                    $inputControl = $validatedPanel
                    # Store reference to the textbox for value retrieval
                    $inputControl | Add-Member -NotePropertyName "ValueControl" -NotePropertyValue $textbox
                }
                else {
                    [System.Windows.Controls.Grid]::SetColumn($textbox, 1)
                    $inputControl = $textbox
                }
            }

            $row.Children.Add($label) | Out-Null
            $row.Children.Add($inputControl) | Out-Null

            $parameterPanel.Children.Add($row) | Out-Null
            $paramInputs[$param.name] = $inputControl
            if ($param.in -eq "body") {
                $script:CurrentBodyControl = $inputControl
                $script:CurrentBodySchema = $param.schema
            }

            # Add event handlers for conditional parameter visibility updates
            # This infrastructure is ready for future use when API schema includes parameter dependencies
            try {
                $actualControl = $inputControl

                # Get the actual input control (unwrap if in panel)
                if ($inputControl.ValueControl) {
                    $actualControl = $inputControl.ValueControl
                }

                # Add change handler to trigger visibility updates
                if ($actualControl -is [System.Windows.Controls.ComboBox]) {
                    $actualControl.Add_SelectionChanged({
                            # Update-ParameterVisibility would be called here when dependencies exist
                            # Currently a no-op as API schema doesn't define conditional parameters
                        })
                }
                elseif ($actualControl -is [System.Windows.Controls.CheckBox]) {
                    $actualControl.Add_Checked({
                            # Update-ParameterVisibility would be called here when dependencies exist
                        })
                    $actualControl.Add_Unchecked({
                            # Update-ParameterVisibility would be called here when dependencies exist
                        })
                }
                elseif ($actualControl -is [System.Windows.Controls.TextBox]) {
                    # TextChanged would be too frequent; use LostFocus instead
                    $actualControl.Add_LostFocus({
                            # Update-ParameterVisibility would be called here when dependencies exist
                        })
                }
            }
            catch {
                # Silently continue if event handler setup fails
            }
        }

        $bodySchemaResolved = Resolve-SchemaReference -Schema $script:CurrentBodySchema -Definitions $script:Definitions
        $builderActive = $bodySchemaResolved -and $bodySchemaResolved.properties `
            -and ($bodySchemaResolved.properties.conversationFilters -or $bodySchemaResolved.properties.segmentFilters)

        if ($builderActive) {
            Set-FilterBuilderVisibility -Visible $true
            Update-FilterBuilderHint
        }
        else {
            Set-FilterBuilderVisibility -Visible $false
            if ($filterBuilderHintText) {
                $filterBuilderHintText.Text = ""
            }
        }

        $statusText.Text = "Provide values for the parameters and submit."
        if ($pendingFavoriteParameters) {
            Populate-ParameterValues -ParameterSet $pendingFavoriteParameters
            $pendingFavoriteParameters = $null
        }
        else {
            # Try to populate body parameter with example template if available
            $exampleBody = Get-ExamplePostBody -Path $selectedPath -Method $selectedMethod
            if ($exampleBody) {
                # Find the body parameter input and populate it
                foreach ($param in $params) {
                    if ($param.in -eq "body") {
                        $bodyInput = $paramInputs[$param.name]
                        if ($bodyInput) {
                            $bodyTextControl = if ($bodyInput.ValueControl) { $bodyInput.ValueControl } else { $bodyInput }
                            if ($bodyTextControl -is [System.Windows.Controls.TextBox]) {
                                $bodyTextControl.Text = $exampleBody
                            }
                            $statusText.Text = "Example body template loaded. Modify as needed and submit."
                        }
                        break
                    }
                }
            }
        }
        $responseSchema = Get-ResponseSchema -MethodObject $methodObject
        Update-SchemaList -Schema $responseSchema
    })

if ($favoritesList) {
    $favoritesList.Add_SelectionChanged({
            $favorite = $favoritesList.SelectedItem
            if (-not $favorite) { return }

            $favoritePath = $favorite.Path
            $favoriteMethod = $favorite.Method
            $favoriteGroup = if ($favorite.Group) { $favorite.Group } else { Get-GroupForPath -Path $favoritePath }

            if ($favoriteGroup -and $GroupMap.ContainsKey($favoriteGroup)) {
                $groupCombo.SelectedItem = $favoriteGroup
            }

            if ($favoritePath) {
                $pathCombo.SelectedItem = $favoritePath
            }

            if ($favoriteMethod) {
                $pendingFavoriteParameters = $favorite.Parameters
                $methodCombo.SelectedItem = $favoriteMethod
            }

            $statusText.Text = "Favorite '$($favorite.Name)' loaded."
            Add-LogEntry "Favorite applied: $($favorite.Name)"
        })
}

if ($saveFavoriteButton) {
    $saveFavoriteButton.Add_Click({
            $favoriteName = if ($favoriteNameInput) { $favoriteNameInput.Text.Trim() } else { "" }

            if (-not $favoriteName) {
                $statusText.Text = "Enter a name before saving a favorite."
                return
            }

            $selectedPath = $pathCombo.SelectedItem
            $selectedMethod = $methodCombo.SelectedItem
            if (-not $selectedPath -or -not $selectedMethod) {
                $statusText.Text = "Pick an endpoint and method before saving."
                return
            }

            $pathObject = Get-PathObject -ApiPaths $ApiPaths -Path $selectedPath
            $methodObject = Get-MethodObject -PathObject $pathObject -MethodName $selectedMethod
            if (-not $methodObject) {
                $statusText.Text = "Unable to read the selected method metadata."
                return
            }

            $params = $methodObject.parameters
            $paramData = @()
            foreach ($param in $params) {
                $value = ""
                $paramControl = $paramInputs[$param.name]
                if ($paramControl) {
                    $value = Get-ParameterControlValue -Control $paramControl
                    if ($value -is [string]) {
                        $value = $value.Trim()
                    }
                }

                $paramData += [PSCustomObject]@{
                    name  = $param.name
                    in    = $param.in
                    value = $value
                }
            }

            $favoriteRecord = [PSCustomObject]@{
                Name       = $favoriteName
                Path       = $selectedPath
                Method     = $selectedMethod
                Group      = Get-GroupForPath -Path $selectedPath
                Parameters = $paramData
                Timestamp  = (Get-Date).ToString("o")
            }

            $filteredFavorites = [System.Collections.ArrayList]::new()
            foreach ($fav in $Favorites) {
                if ($fav.Name -ne $favoriteRecord.Name) {
                    $filteredFavorites.Add($fav) | Out-Null
                }
            }

            $filteredFavorites.Add($favoriteRecord) | Out-Null
            $Favorites = $filteredFavorites

            Save-FavoritesToDisk -Path $FavoritesFile -Favorites $Favorites
            Refresh-FavoritesList

            if ($favoriteNameInput) {
                $favoriteNameInput.Text = ""
            }

            $statusText.Text = "Favorite '$favoriteName' saved."
            Add-LogEntry "Saved favorite '$favoriteName'."
        })
}

if ($toggleResponseViewButton) {
    $toggleResponseViewButton.Add_Click({
            if ($script:ResponseViewMode -eq "Formatted") {
                # Switch to raw
                $script:ResponseViewMode = "Raw"
                if ($script:LastResponseRaw) {
                    $statusCode = if ($responseBox.Text -match "Status\s+(\d+)") { $matches[1] } else { "" }
                    if ($statusCode) {
                        $newLine = [System.Environment]::NewLine
                        $responseBox.Text = "Status $statusCode (Raw):$newLine$($script:LastResponseRaw)"
                    }
                    else {
                        $responseBox.Text = $script:LastResponseRaw
                    }
                }
                Add-LogEntry "Response view switched to Raw."
            }
            else {
                # Switch to formatted
                $script:ResponseViewMode = "Formatted"
                if ($script:LastResponseText) {
                    $statusCode = if ($responseBox.Text -match "Status\s+(\d+)") { $matches[1] } else { "" }
                    if ($statusCode) {
                        $newLine = [System.Environment]::NewLine
                        $responseBox.Text = "Status ${statusCode}:$newLine$($script:LastResponseText)"
                    }
                    else {
                        $responseBox.Text = $script:LastResponseText
                    }
                }
                Add-LogEntry "Response view switched to Formatted."
            }
        })
}

if ($inspectResponseButton) {
    $inspectResponseButton.Add_Click({
            Show-DataInspector -JsonText $script:LastResponseRaw
        })
}

if ($settingsMenuItem) {
    $settingsMenuItem.Add_Click({
            $selectedFile = Show-SettingsDialog -CurrentJsonPath $script:CurrentJsonPath
            if ($selectedFile) {
                Invoke-ReloadEndpoints -JsonPath $selectedFile
            }
        })
}

if ($appSettingsMenuItem) {
    $appSettingsMenuItem.Add_Click({
            $result = Show-AppSettingsDialog -CurrentRegion $script:Region -CurrentOAuthType $script:OAuthType -CurrentToken (Get-ExplorerAccessToken)
            if (-not $result) { return }

            Set-ExplorerRegion -Region ([string]$result.Region)
            $saved = Load-ExplorerSettings
            $saved.Region = $script:Region
            Save-ExplorerSettings -Settings $saved

            $tokenValue = if ($result.Token) { [string]$result.Token } else { '' }
            if ([string]::IsNullOrWhiteSpace($tokenValue)) {
                Set-ExplorerAccessToken -Token '' -OAuthType '(none)'
            }
            else {
                $type = if ($result.OAuthType) { [string]$result.OAuthType } else { 'Manual' }
                Set-ExplorerAccessToken -Token $tokenValue -OAuthType $type
            }

            Update-AuthUiState
            Add-LogEntry "App settings updated (region=$($script:Region), oauth=$($script:OAuthType))."
        })
}

if ($traceMenuItem) {
    try { $traceMenuItem.IsChecked = [bool]$script:TraceEnabled } catch { }
    $traceMenuItem.Add_Click({
            try {
                $enabled = [bool]$traceMenuItem.IsChecked
                if ($enabled) {
                    $script:TraceEnabled = $true
                    $env:GENESYS_API_EXPLORER_TRACE = '1'
                    if ([string]::IsNullOrWhiteSpace($script:TraceLogPath)) {
                        $script:TraceLogPath = Get-TraceLogPath
                    }
                    Write-TraceLog "Tracing enabled from Settings menu."
                    Add-LogEntry "Tracing enabled. Log: $script:TraceLogPath"
                    try { $traceMenuItem.ToolTip = "Tracing enabled. Log: $script:TraceLogPath" } catch { }
                }
                else {
                    Write-TraceLog "Tracing disabled from Settings menu."
                    $script:TraceEnabled = $false
                    $env:GENESYS_API_EXPLORER_TRACE = '0'
                    Add-LogEntry "Tracing disabled."
                    try { $traceMenuItem.ToolTip = "Tracing disabled. Toggle to write a temp log file." } catch { }
                }
            }
            catch {
                Add-LogEntry "Failed to toggle tracing: $($_.Exception.Message)"
            }
        })
}

if ($resetEndpointsMenuItem) {
    $resetEndpointsMenuItem.Add_Click({
            $defaultPath = Join-Path -Path $ScriptRoot -ChildPath "GenesysCloudAPIEndpoints.json"
            if (Test-Path -Path $defaultPath) {
                if (Invoke-ReloadEndpoints -JsonPath $defaultPath) {
                    [System.Windows.MessageBox]::Show("Endpoints reset to default configuration.", "Reset Complete", "OK", "Information")
                }
            }
            else {
                [System.Windows.MessageBox]::Show("Default endpoints file not found at: $defaultPath", "File Not Found", "OK", "Error")
            }
        })
}

if ($loginButton) {
    $loginButton.Add_Click({
            $newToken = Show-LoginWindow
            if ($newToken) {
                if ($script:LastLoginRegion) {
                    Set-ExplorerRegion -Region ([string]$script:LastLoginRegion)
                    $saved = Load-ExplorerSettings
                    $saved.Region = $script:Region
                    Save-ExplorerSettings -Settings $saved
                }

                $oauthType = if ($script:LastLoginOAuthType) { [string]$script:LastLoginOAuthType } else { 'Login' }
                Set-ExplorerAccessToken -Token ([string]$newToken) -OAuthType $oauthType
                Update-AuthUiState
                Add-LogEntry "Token updated via Login ($oauthType)."
            }
        })
}

if ($testTokenButton) {
    $testTokenButton.Add_Click({
            $token = Get-ExplorerAccessToken
            if (-not $token) {
                $script:TokenValidated = $false
                Update-AuthUiState
                Add-LogEntry "Token test failed: No token provided."
                return
            }

            $testTokenButton.IsEnabled = $false
            if ($tokenStatusText) {
                $tokenStatusText.Text = "Testing..."
                $tokenStatusText.Foreground = "Gray"
            }
            Add-LogEntry "Testing OAuth token validity..."

            try {
                # Test token with a simple API call to /api/v2/users/me
                $headers = @{
                    "Authorization" = "Bearer $token"
                    "Content-Type"  = "application/json"
                }
                $testUrl = "$ApiBaseUrl/api/v2/users/me"

                $response = Invoke-GCRequest -Method GET -Uri $testUrl -Headers $headers -AsResponse

                if ($response.StatusCode -eq 200) {
                    $script:TokenValidated = $true
                    Update-AuthUiState
                    Add-LogEntry "Token test successful: Token is valid."
                }
                else {
                    $script:TokenValidated = $false
                    Update-AuthUiState
                    Add-LogEntry "Token test returned unexpected status: $($response.StatusCode)"
                }
            }
            catch {
                $script:TokenValidated = $false
                Update-AuthUiState
                $errorMsg = $_.Exception.Message
                Add-LogEntry "Token test failed: $errorMsg"
            }
            finally {
                $testTokenButton.IsEnabled = $true
            }
        })
}

if ($helpMenuItem) {
    $helpMenuItem.Add_Click({
            Show-HelpWindow
        })
}

if ($helpDevLink) {
    $helpDevLink.Add_Click({
            Launch-Url -Url $DeveloperDocsUrl
        })
}

if ($helpSupportLink) {
    $helpSupportLink.Add_Click({
            Launch-Url -Url $SupportDocsUrl
        })
}

if ($fetchJobResultsButton) {
    $fetchJobResultsButton.Add_Click({
            Fetch-JobResults -Force
        })
}

if ($exportJobResultsButton) {
    $exportJobResultsButton.Add_Click({
            if (-not $JobTracker.ResultFile -or -not (Test-Path -Path $JobTracker.ResultFile)) {
                $statusText.Text = "No job result file to export."
                return
            }

            $dialog = New-Object Microsoft.Win32.SaveFileDialog
            $dialog.Filter = "JSON Files (*.json)|*.json|All Files (*.*)|*.*"
            $dialog.Title = "Export Job Results"
            $dialog.FileName = [System.IO.Path]::GetFileName($JobTracker.ResultFile)
            if ($dialog.ShowDialog() -eq $true) {
                Copy-Item -Path $JobTracker.ResultFile -Destination $dialog.FileName -Force
                $statusText.Text = "Job results exported to $($dialog.FileName)"
                Add-LogEntry "Job results exported to $($dialog.FileName)"
            }
        })
}

if ($runConversationReportButton) {
    $runConversationReportButton.Add_Click({
            $correlationId = [guid]::NewGuid().ToString()
            $convId = if ($conversationReportIdInput) { $conversationReportIdInput.Text.Trim() } else { "" }

            if (-not $convId) {
                Set-ConvReportUiState -State 'Error' -StatusText "No conversation ID." -ErrorText "Please enter a conversation ID. [Correlation ID: $correlationId]"
                Add-LogEntry "Conversation report blocked: no conversation ID. [Correlation ID: $correlationId]"
                return
            }
            if ($convId -notmatch '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') {
                Set-ConvReportUiState -State 'Error' -StatusText "Invalid ID format." -ErrorText "Conversation ID does not look like a valid UUID. [Correlation ID: $correlationId]"
                Add-LogEntry "Conversation report blocked: invalid conversation ID format. [Correlation ID: $correlationId]"
                return
            }

            $token = Get-ExplorerAccessToken
            if (-not $token) {
                Set-ConvReportUiState -State 'Error' -StatusText "No token." -ErrorText "Please provide an OAuth token before running a report. [Correlation ID: $correlationId]"
                Add-LogEntry "Conversation report blocked: no OAuth token. [Correlation ID: $correlationId]"
                return
            }

            $headers = @{ "Content-Type" = "application/json"; "Authorization" = "Bearer $token" }

            # Capture all inputs and resources before launching background task
            $capturedConvId        = $convId
            $capturedHeaders       = $headers
            $capturedBaseUrl       = $ApiBaseUrl
            $capturedCorrelationId = $correlationId
            $capturedModuleManifest = $script:OpsInsightsManifest
            $capturedConvReportScript = ${function:Get-ConversationReport}

            # Thread-safe queue: background thread enqueues progress events;
            # OnTick callback drains them on the UI thread (DEF-001 / no UI freeze).
            $progressQueue = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()

            Invoke-UIBackgroundTask `
                -OnStart {
                    Set-ConvReportUiState -State 'Loading' `
                        -StatusText "Fetching report... [Correlation ID: $capturedCorrelationId]" `
                        -ProgressPercent 0 -ProgressLabel "Initializing..." -ExportEnabled $false
                    if ($conversationReportEndpointLog) { $conversationReportEndpointLog.Text = "" }
                    Add-LogEntry "Generating conversation report for: $capturedConvId [Correlation ID: $capturedCorrelationId]"
                } `
                -WorkParams @{
                    ConvId          = $capturedConvId
                    Headers         = $capturedHeaders
                    BaseUrl         = $capturedBaseUrl
                    ModuleManifest  = $capturedModuleManifest
                    ProgressQueue   = $progressQueue
                    ConvReportScript = $capturedConvReportScript
                } `
                -WorkScript {
                    Import-Module -Name $ModuleManifest -Force -ErrorAction Stop

                    # Define Get-ConversationReport in this runspace from the captured scriptblock
                    # (avoids Invoke-Expression / dynamic string evaluation)
                    New-Item -Path 'Function:\Get-ConversationReport' -Value $ConvReportScript -Force | Out-Null

                    $progressCallback = {
                        param($PercentComplete, $Status, $EndpointName, $IsStarting, $IsSuccess, $IsOptional)
                        $ProgressQueue.Enqueue([pscustomobject]@{
                            Pct      = $PercentComplete
                            Status   = $Status
                            Name     = $EndpointName
                            Starting = [bool]$IsStarting
                            Success  = [bool]$IsSuccess
                            Optional = [bool]$IsOptional
                        })
                    }

                    Get-ConversationReport `
                        -ConversationId $ConvId `
                        -Headers $Headers `
                        -BaseUrl $BaseUrl `
                        -ProgressCallback $progressCallback
                } `
                -OnTick {
                    # Drain progress events on the UI thread
                    $ev = $null
                    while ($progressQueue.TryDequeue([ref]$ev)) {
                        if ($conversationReportProgressBar) { $conversationReportProgressBar.Value = $ev.Pct }
                        if ($conversationReportProgressText) { $conversationReportProgressText.Text = $ev.Status }
                        if ($conversationReportEndpointLog) {
                            $timestamp = (Get-Date).ToString("HH:mm:ss")
                            $logLine = if ($ev.Starting) {
                                "[$timestamp] Querying: $($ev.Name)..."
                            }
                            elseif ($ev.Success) {
                                "[$timestamp] $([char]0x2713) $($ev.Name) - Retrieved successfully"
                            }
                            elseif ($ev.Optional) {
                                "[$timestamp] [WARN] $($ev.Name) - Optional, not available"
                            }
                            else {
                                "[$timestamp] $([char]0x2717) $($ev.Name) - Failed"
                            }
                            $conversationReportEndpointLog.AppendText("$logLine`r`n")
                            $conversationReportEndpointLog.ScrollToEnd()
                        }
                    }
                } `
                -OnSuccess {
                    param($output)
                    $report = $output | Select-Object -Last 1
                    $script:LastConversationReport = $report
                    $script:LastConversationReportJson = $report | ConvertTo-Json -Depth 20
                    if ($conversationReportText) {
                        $conversationReportText.Text = (Format-ConversationReportText -Report $report)
                    }

                    $errorCount = if ($report -and $report.Errors) { $report.Errors.Count } else { 0 }
                    if ($errorCount -gt 0) {
                        Set-ConvReportUiState -State 'Partial' -ExportEnabled $true `
                            -StatusText "Report generated with $errorCount error(s). [Correlation ID: $capturedCorrelationId]" `
                            -ProgressPercent 100 -ProgressLabel "Complete" `
                            -WarningText "Report completed with partial data. [Correlation ID: $capturedCorrelationId]"
                        Add-LogEntry "Conversation report completed with $errorCount error(s). [Correlation ID: $capturedCorrelationId]"
                    }
                    else {
                        Set-ConvReportUiState -State 'Complete' -ExportEnabled $true `
                            -StatusText "Report generated successfully. [Correlation ID: $capturedCorrelationId]" `
                            -ProgressPercent 100 -ProgressLabel "Complete"
                        Add-LogEntry "Conversation report generated successfully. [Correlation ID: $capturedCorrelationId]"
                    }
                } `
                -OnError {
                    param($err)
                    $errMsg = if ($err -is [System.Management.Automation.ErrorRecord]) {
                        $err.Exception.Message
                    }
                    else { [string]$err }
                    Set-ConvReportUiState -State 'Error' `
                        -StatusText "Report failed. [Correlation ID: $capturedCorrelationId]" `
                        -ErrorText "Report failed: $errMsg [Correlation ID: $capturedCorrelationId]" `
                        -ExportEnabled $false
                    Add-LogEntry "Conversation report failed: $errMsg [Correlation ID: $capturedCorrelationId]"
                }
        })
}

if ($inspectConversationReportButton) {
    $inspectConversationReportButton.Add_Click({
            if ($script:LastConversationReport) {
                Show-ConversationTimelineReport -Report $script:LastConversationReport
            }
            else {
                Add-LogEntry "No conversation report data to inspect."
            }
        })
}

if ($exportConversationReportJsonButton) {
    $exportConversationReportJsonButton.Add_Click({
            if (-not $script:LastConversationReportJson) {
                if ($conversationReportStatus) {
                    $conversationReportStatus.Text = "No report data to export."
                }
                return
            }

            $dialog = New-Object Microsoft.Win32.SaveFileDialog
            $dialog.Filter = "JSON Files (*.json)|*.json|All Files (*.*)|*.*"
            $dialog.Title = "Export Conversation Report JSON"
            $dialog.FileName = "ConversationReport_$($script:LastConversationReport.ConversationId).json"
            if ($dialog.ShowDialog() -eq $true) {
                $jsonPayload = [ordered]@{
                    ExportMeta = [ordered]@{ ExportedAt = (Get-Date).ToString('o'); Format = 'JSON'; ContainsPii = $true }
                    Report = $script:LastConversationReport
                }
                $jsonPayload | ConvertTo-Json -Depth 20 | Out-File -FilePath $dialog.FileName -Encoding utf8
                if ($conversationReportStatus) {
                    $conversationReportStatus.Text = "JSON exported to $($dialog.FileName)"
                }
                Add-LogEntry "Conversation report JSON exported to $($dialog.FileName)"
            }
        })
}

if ($exportConversationReportTextButton) {
    $exportConversationReportTextButton.Add_Click({
            if (-not $script:LastConversationReport) {
                if ($conversationReportStatus) {
                    $conversationReportStatus.Text = "No report data to export."
                }
                return
            }

            $dialog = New-Object Microsoft.Win32.SaveFileDialog
            $dialog.Filter = "Text Files (*.txt)|*.txt|All Files (*.*)|*.*"
            $dialog.Title = "Export Conversation Report Text"
            $dialog.FileName = "ConversationReport_$($script:LastConversationReport.ConversationId).txt"
            if ($dialog.ShowDialog() -eq $true) {
                $reportText = Format-ConversationReportText -Report $script:LastConversationReport
                $reportText | Out-File -FilePath $dialog.FileName -Encoding utf8
                if ($conversationReportStatus) {
                    $conversationReportStatus.Text = "Text exported to $($dialog.FileName)"
                }
                Add-LogEntry "Conversation report text exported to $($dialog.FileName)"
            }
        })
}

if ($requestHistoryList) {
    $requestHistoryList.ItemsSource = $script:RequestHistory

    $requestHistoryList.Add_SelectionChanged({
            if ($requestHistoryList.SelectedItem) {
                $replayRequestButton.IsEnabled = $true
            }
            else {
                $replayRequestButton.IsEnabled = $false
            }
        })
}

if ($replayRequestButton) {
    $replayRequestButton.Add_Click({
            $selectedHistory = $requestHistoryList.SelectedItem
            if (-not $selectedHistory) {
                Add-LogEntry "No request selected to replay."
                return
            }

            # Set the group, path, and method
            $groupCombo.SelectedItem = $selectedHistory.Group
            $pathCombo.SelectedItem = $selectedHistory.Path
            $methodCombo.SelectedItem = $selectedHistory.Method

            # Restore parameters
            if ($selectedHistory.Parameters) {
                # Use Dispatcher.Invoke to ensure UI is updated before setting parameters
                $Window.Dispatcher.Invoke([Action] {
                        foreach ($paramName in $selectedHistory.Parameters.Keys) {
                            if ($paramInputs.ContainsKey($paramName)) {
                                Set-ParameterControlValue -Control $paramInputs[$paramName] -Value $selectedHistory.Parameters[$paramName]
                            }
                        }
                    }, [System.Windows.Threading.DispatcherPriority]::Background)
            }

            Add-LogEntry "Request loaded from history: $($selectedHistory.Method) $($selectedHistory.Path)"
            $statusText.Text = "Request loaded from history."
        })
}

if ($clearHistoryButton) {
    $clearHistoryButton.Add_Click({
            $result = [System.Windows.MessageBox]::Show(
                "Are you sure you want to clear all request history?",
                "Clear History",
                [System.Windows.MessageBoxButton]::YesNo,
                [System.Windows.MessageBoxImage]::Question
            )

            if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
                $script:RequestHistory.Clear()
                Add-LogEntry "Request history cleared."
                $statusText.Text = "History cleared."
            }
        })
}

if ($insightMetricsList) {
    $insightMetricsList.ItemsSource = $script:InsightMetrics
}
if ($insightDrilldownsList) {
    $insightDrilldownsList.ItemsSource = $script:InsightDrilldowns
}
if ($insightBriefingsList) {
    $insightBriefingsList.ItemsSource = $script:InsightBriefingsHistory
}
if ($insightBriefingPathText -and $insightBriefingRoot) {
    $insightBriefingPathText.Text = "Briefings folder: $insightBriefingRoot"
}

if ($queueWaitResultsList) {
    $queueWaitResultsList.ItemsSource = $script:QueueWaitResults
}

if ($queueWaitIntervalInput -and [string]::IsNullOrWhiteSpace($queueWaitIntervalInput.Text)) {
    try { $queueWaitIntervalInput.Text = Get-DefaultAnalyticsIntervalLastMinutes -Minutes 30 } catch { }
}

if ($queueWaitResultsList -and $queueWaitDetailsText) {
    $queueWaitResultsList.Add_SelectionChanged({
            try {
                $selected = $queueWaitResultsList.SelectedItem
                if (-not $selected) { $queueWaitDetailsText.Text = ''; return }

                $lines = New-Object System.Collections.Generic.List[string]
                $lines.Add("ConversationId: $($selected.ConversationId)") | Out-Null
                $lines.Add("WaitingSinceUtc: $($selected.WaitingSinceUtc)") | Out-Null
                $lines.Add("RequiredSkills: $($selected.RequiredSkills)") | Out-Null
                $lines.Add("EligibleAgents ($(@($selected.EligibleAgentNames).Count)):" ) | Out-Null
                if ($selected.EligibleStatusSummary) { $lines.Add("Eligible RoutingStatus: $($selected.EligibleStatusSummary)") | Out-Null }
                if ($null -ne $selected.NotRespondingCount) { $lines.Add("NOT_RESPONDING count: $($selected.NotRespondingCount)") | Out-Null }
                foreach ($a in @($selected.EligibleAgents | Select-Object -First 50)) {
                    $name = $a.Name
                    $rs = ''
                    try { if ($a.RoutingStatus -and ($a.RoutingStatus.PSObject.Properties.Name -contains 'status')) { $rs = [string]$a.RoutingStatus.status } } catch { $rs = '' }
                    $pr = ''
                    try { if ($a.Presence -and ($a.Presence.PSObject.Properties.Name -contains 'presenceDefinition')) { $pr = [string]$a.Presence.presenceDefinition.systemPresence } } catch { $pr = '' }
                    if ([string]::IsNullOrWhiteSpace($rs)) { $rs = 'unknown' }
                    $suffix = ''
                    if ($pr) { $suffix = " | presence=$pr" }
                    $lines.Add("  - $name | routingStatus=$rs$suffix") | Out-Null
                }
                if (@($selected.EligibleAgents).Count -gt 50) { $lines.Add("  ...") | Out-Null }
                $queueWaitDetailsText.Text = ($lines -join "`n")
            }
            catch {
                $queueWaitDetailsText.Text = "Failed to render details: $($_.Exception.Message)"
            }
        })
}

function Refresh-InsightBriefingHistory {
    $outputDir = Get-InsightBriefingDirectory
    $indexPath = Join-Path -Path $outputDir -ChildPath 'index.json'

    $script:InsightBriefingsHistory.Clear()

    if (-not (Test-Path -LiteralPath $indexPath)) { return }

    try {
        $raw = Get-Content -LiteralPath $indexPath -Raw
        if ([string]::IsNullOrWhiteSpace($raw)) { return }

        $entries = @($raw | ConvertFrom-Json)
        foreach ($entry in $entries) {
            $timestamp = if ($entry.TimestampUtc) { [string]$entry.TimestampUtc } else { '' }
            $packLabel = if ($entry.PackName) { "$($entry.PackName)" } elseif ($entry.PackId) { "$($entry.PackId)" } else { '' }

            $snapshotLeaf = [string]$entry.Snapshot
            $htmlLeaf = [string]$entry.Html

            $historyEntry = [pscustomobject]@{
                Timestamp    = $timestamp
                Pack         = $packLabel
                Snapshot     = $snapshotLeaf
                Html         = $htmlLeaf
                SnapshotPath = if ($snapshotLeaf) { Join-Path -Path $outputDir -ChildPath $snapshotLeaf } else { $null }
                HtmlPath     = if ($htmlLeaf) { Join-Path -Path $outputDir -ChildPath $htmlLeaf } else { $null }
            }
            $script:InsightBriefingsHistory.Add($historyEntry) | Out-Null
        }
    }
    catch {
        Add-LogEntry "Failed to load insight briefing index: $($_.Exception.Message)"
    }
}

if ($refreshInsightBriefingsButton) {
    $refreshInsightBriefingsButton.Add_Click({
            Refresh-InsightBriefingHistory
        })
}

if ($openBriefingsFolderButton) {
    $openBriefingsFolderButton.Add_Click({
            try {
                $dir = Get-InsightBriefingDirectory
                if ($dir) { Start-Process -FilePath $dir }
            }
            catch {}
        })
}

if ($insightBriefingsList) {
    $insightBriefingsList.Add_SelectionChanged({
            $selected = $insightBriefingsList.SelectedItem
            $has = ($null -ne $selected)
            if ($openBriefingHtmlButton) { $openBriefingHtmlButton.IsEnabled = $has -and $selected.HtmlPath }
            if ($openBriefingSnapshotButton) { $openBriefingSnapshotButton.IsEnabled = $has -and $selected.SnapshotPath }
        })
}

if ($openBriefingHtmlButton) {
    $openBriefingHtmlButton.Add_Click({
            $selected = if ($insightBriefingsList) { $insightBriefingsList.SelectedItem } else { $null }
            if ($selected -and $selected.HtmlPath -and (Test-Path -LiteralPath $selected.HtmlPath)) {
                Start-Process -FilePath $selected.HtmlPath
            }
        })
}

if ($openBriefingSnapshotButton) {
    $openBriefingSnapshotButton.Add_Click({
            $selected = if ($insightBriefingsList) { $insightBriefingsList.SelectedItem } else { $null }
            if ($selected -and $selected.SnapshotPath -and (Test-Path -LiteralPath $selected.SnapshotPath)) {
                Start-Process -FilePath $selected.SnapshotPath
            }
        })
}

Refresh-InsightBriefingHistory

if (-not $script:InsightParamInputs) { $script:InsightParamInputs = @{} }
$script:InsightPackCatalog = @()

function Refresh-InsightPackCatalogUi {
    if (-not $insightPackCombo) { return }
    $script:InsightPackCatalog = @(Get-InsightPackCatalog -PackDirectory $insightPackRoot ) #-LegacyPackDirectory $legacyInsightPackRoot
    $insightPackCombo.ItemsSource = $script:InsightPackCatalog
    $insightPackCombo.DisplayMemberPath = 'Display'

    $packExists = Test-Path -LiteralPath $insightPackRoot
    #$legacyExists = Test-Path -LiteralPath $legacyInsightPackRoot
    $count = if ($script:InsightPackCatalog) { $script:InsightPackCatalog.Count } else { 0 }

    if ($count -le 0) {
        $msg = "No insight packs found. Checked:`n- $insightPackRoot (exists=$packExists)`n- $legacyInsightPackRoot (exists=$legacyExists)"
        if ($insightPackDescriptionText) { $insightPackDescriptionText.Text = $msg }
        Add-LogEntry $msg
        Add-LogEntry "Insight pack discovery context: workspaceRoot=$workspaceRoot; scriptRoot=$ScriptRoot; override=$([string]$env:GENESYS_API_EXPLORER_PACKS_DIR)"

        if ($script:InsightPackCatalogErrors -and $script:InsightPackCatalogErrors.Count -gt 0) {
            Add-LogEntry "Insight pack parse errors (first 3):"
            foreach ($line in @($script:InsightPackCatalogErrors | Select-Object -First 3)) {
                Add-LogEntry "  $line"
            }
        }
    }
    else {
        if ($insightPackDescriptionText) {
            $insightPackDescriptionText.Text = "Loaded $count pack(s) from:`n- $insightPackRoot`n- $legacyInsightPackRoot"
        }
    }
}

if ($insightPackCombo) {
    Refresh-InsightPackCatalogUi

    $insightPackCombo.Add_SelectionChanged({
            $selected = $insightPackCombo.SelectedItem
            if (-not $selected) { return }

            if ($insightPackDescriptionText) {
                $insightPackDescriptionText.Text = if ($selected.Description) { $selected.Description } else { $selected.Id }
            }
            if ($insightPackMetaText) {
                $tags = if ($selected.Tags -and $selected.Tags.Count -gt 0) { ($selected.Tags -join ', ') } else { '' }
                $scopes = if ($selected.Scopes -and $selected.Scopes.Count -gt 0) { ($selected.Scopes -join ', ') } else { '' }
                $endpoints = if ($selected.Endpoints -and $selected.Endpoints.Count -gt 0) { ($selected.Endpoints -join "`n") } else { '' }

                $lines = New-Object System.Collections.Generic.List[string]
                if ($selected.Version) { $lines.Add("Version: $($selected.Version)") | Out-Null }
                if ($selected.Maturity) { $lines.Add("Maturity: $($selected.Maturity)") | Out-Null }
                if ($selected.Owner) { $lines.Add("Owner: $($selected.Owner)") | Out-Null }
                if ($null -ne $selected.ExpectedRuntimeSec) { $lines.Add("Expected runtime: $($selected.ExpectedRuntimeSec)s") | Out-Null }
                if ($tags) { $lines.Add("Tags: $tags") | Out-Null }
                if ($scopes) { $lines.Add("Scopes: $scopes") | Out-Null }
                if ($selected.FullPath) { $lines.Add("Path: $($selected.FullPath)") | Out-Null }
                if ($endpoints) {
                    $lines.Add("Endpoints:") | Out-Null
                    $lines.Add($endpoints) | Out-Null
                }
                if ($selected.Examples -and $selected.Examples.Count -gt 0) {
                    $lines.Add("Examples:") | Out-Null
                    foreach ($ex in @($selected.Examples)) {
                        if (-not $ex) { continue }
                        $note = if ($ex.Notes) { " - $($ex.Notes)" } else { '' }
                        $lines.Add("  - $($ex.Title)$note") | Out-Null
                    }
                }
                $insightPackMetaText.Text = ($lines -join "`n")
            }
            if ($insightPackParametersPanel) {
                Render-InsightPackParameters -Pack $selected.Pack -Panel $insightPackParametersPanel
            }

            if ($insightPackWarningsText) {
                $warnings = New-Object System.Collections.Generic.List[string]
                if ($selected.Scopes -and $selected.Scopes.Count -gt 0) {
                    $warnings.Add("Requires OAuth scopes: $($selected.Scopes -join ', ')") | Out-Null
                }
                if ($warnings.Count -eq 0) {
                    $warnings.Add("No required scopes declared by this pack.") | Out-Null
                }

                # Optional strict validation (surface issues early without blocking selection)
                try {
                    Ensure-OpsInsightsModuleLoaded
                    $strict = $false
                    if ($strictInsightValidationCheckbox) { $strict = [bool]$strictInsightValidationCheckbox.IsChecked }
                    $validation = Test-GCInsightPack -PackPath $selected.FullPath -Strict:$strict
                    if ($validation -and -not $validation.IsValid -and $validation.Errors -and $validation.Errors.Count -gt 0) {
                        $warnings.Add("Validation: $($validation.Errors[0])") | Out-Null
                    }
                }
                catch {
                    $warnings.Add("Validation: $($_.Exception.Message)") | Out-Null
                }
                $insightPackWarningsText.Text = ($warnings -join "`n")
            }

            if ($insightPackExampleCombo) {
                $insightPackExampleCombo.ItemsSource = @($selected.Examples)
                $insightPackExampleCombo.DisplayMemberPath = 'Title'
                $insightPackExampleCombo.IsEnabled = ($selected.Examples -and $selected.Examples.Count -gt 0)
                if ($insightPackExampleCombo.IsEnabled) { $insightPackExampleCombo.SelectedIndex = 0 }
            }
            if ($loadInsightPackExampleButton) {
                $loadInsightPackExampleButton.IsEnabled = ($selected.Examples -and $selected.Examples.Count -gt 0)
            }

            # Apply global defaults (only if the pack defines these params and the controls are empty)
            if ($script:InsightParamInputs.ContainsKey('startDate') -and $insightGlobalStartInput -and -not [string]::IsNullOrWhiteSpace($insightGlobalStartInput.Text)) {
                $ctrl = $script:InsightParamInputs['startDate']
                if ($ctrl -is [System.Windows.Controls.TextBox] -and [string]::IsNullOrWhiteSpace($ctrl.Text)) {
                    $ctrl.Text = $insightGlobalStartInput.Text.Trim()
                }
            }
            if ($script:InsightParamInputs.ContainsKey('endDate') -and $insightGlobalEndInput -and -not [string]::IsNullOrWhiteSpace($insightGlobalEndInput.Text)) {
                $ctrl = $script:InsightParamInputs['endDate']
                if ($ctrl -is [System.Windows.Controls.TextBox] -and [string]::IsNullOrWhiteSpace($ctrl.Text)) {
                    $ctrl.Text = $insightGlobalEndInput.Text.Trim()
                }
            }
        })

    if ($script:InsightPackCatalog.Count -gt 0) {
        $insightPackCombo.SelectedIndex = 0
    }
}

if ($insightTimePresetCombo) {
    $insightTimePresetCombo.ItemsSource = @(Get-InsightTimePresets)
    $insightTimePresetCombo.DisplayMemberPath = 'Name'
    $insightTimePresetCombo.SelectedValuePath = 'Key'
    $insightTimePresetCombo.SelectedValue = 'last7'
}

if ($insightBaselineModeCombo) {
    $insightBaselineModeCombo.ItemsSource = @(
        [pscustomobject]@{ Key = 'PreviousWindow'; Name = 'Prev window' },
        [pscustomobject]@{ Key = 'ShiftDays7'; Name = 'Shift -7 days' },
        [pscustomobject]@{ Key = 'ShiftDays30'; Name = 'Shift -30 days' }
    )
    $insightBaselineModeCombo.DisplayMemberPath = 'Name'
    $insightBaselineModeCombo.SelectedValuePath = 'Key'
    $insightBaselineModeCombo.SelectedValue = 'PreviousWindow'
}

function Apply-InsightTimePresetToUi {
    param(
        [Parameter(Mandatory)]
        [string]$PresetKey
    )

    function Format-InsightUtcIso {
        param([Parameter(Mandatory)]$Value)

        try {
            $dt = $Value
            if ($dt -isnot [datetime]) { $dt = [datetime]$dt }
            $utc = $dt.ToUniversalTime()
            return $utc.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
        }
        catch {
            try { return [string]$Value } catch { return '' }
        }
    }

    $window = Resolve-InsightUtcWindowFromPreset -PresetKey $PresetKey
    $startIso = Format-InsightUtcIso -Value $window.StartUtc
    $endIso = Format-InsightUtcIso -Value $window.EndUtc

    if ($insightGlobalStartInput) { $insightGlobalStartInput.Text = $startIso }
    if ($insightGlobalEndInput) { $insightGlobalEndInput.Text = $endIso }

    if ($script:InsightParamInputs.ContainsKey('startDate')) {
        $ctrl = $script:InsightParamInputs['startDate']
        if ($ctrl -is [System.Windows.Controls.TextBox]) { $ctrl.Text = $startIso }
    }
    if ($script:InsightParamInputs.ContainsKey('endDate')) {
        $ctrl = $script:InsightParamInputs['endDate']
        if ($ctrl -is [System.Windows.Controls.TextBox]) { $ctrl.Text = $endIso }
    }
}

if ($insightTimePresetCombo -and $insightGlobalStartInput -and $insightGlobalEndInput) {
    if ([string]::IsNullOrWhiteSpace($insightGlobalStartInput.Text) -and [string]::IsNullOrWhiteSpace($insightGlobalEndInput.Text)) {
        try {
            $key = [string]$insightTimePresetCombo.SelectedValue
            if (-not [string]::IsNullOrWhiteSpace($key)) {
                Apply-InsightTimePresetToUi -PresetKey $key
            }
        }
        catch {
            # ignore default preset failures
        }
    }
}

if ($applyInsightTimePresetButton) {
    $applyInsightTimePresetButton.Add_Click({
            try {
                $key = if ($insightTimePresetCombo) { [string]$insightTimePresetCombo.SelectedValue } else { '' }
                if ([string]::IsNullOrWhiteSpace($key)) { return }
                Apply-InsightTimePresetToUi -PresetKey $key
            }
            catch {
                Add-LogEntry "Failed to apply time preset: $($_.Exception.Message)"
            }
        })
}

if ($refreshInsightPacksButton) {
    $refreshInsightPacksButton.Add_Click({
            Refresh-InsightPackCatalogUi
        })
}

if ($loadInsightPackExampleButton) {
    $loadInsightPackExampleButton.Add_Click({
            try {
                if (-not $insightPackExampleCombo -or -not $insightPackExampleCombo.SelectedItem) { return }
                $example = $insightPackExampleCombo.SelectedItem
                if (-not $example -or -not $example.Parameters) { return }

                $paramObject = $example.Parameters
                foreach ($prop in @($paramObject.PSObject.Properties)) {
                    $name = $prop.Name
                    $value = $prop.Value
                    if (-not $script:InsightParamInputs.ContainsKey($name)) { continue }
                    $ctrl = $script:InsightParamInputs[$name]

                    if ($ctrl -is [System.Windows.Controls.CheckBox]) {
                        $ctrl.IsChecked = [bool]$value
                        continue
                    }
                    if ($ctrl -is [System.Windows.Controls.TextBox]) {
                        if ($null -eq $value) { $ctrl.Text = '' }
                        else { $ctrl.Text = [string]$value }
                    }
                }
            }
            catch {
                Add-LogEntry "Failed to load pack example: $($_.Exception.Message)"
            }
        })
}

function Run-SelectedInsightPack {
    param(
        [Parameter(Mandatory)]
        [bool]$Compare,

        [Parameter()]
        [bool]$DryRun = $false
    )

    if (-not $insightPackCombo -or -not $insightPackCombo.SelectedItem) {
        throw "Select an Insight Pack first."
    }

    $selected = $insightPackCombo.SelectedItem
    $packPath = $selected.FullPath
    if (-not (Test-Path -LiteralPath $packPath)) {
        $packPath = Get-InsightPackPath -FileName $selected.FileName
    }

    Ensure-OpsInsightsModuleLoaded
    Ensure-OpsInsightsContext
    $packParams = Get-InsightPackParameterValues

    # Normalize common timestamp parameters to millisecond precision (Genesys endpoints often reject >3 fractional digits).
    foreach ($k in @('startDate', 'endDate')) {
        try {
            if (-not $packParams.ContainsKey($k)) { continue }
            $raw = $packParams[$k]
            if ($null -eq $raw) { continue }
            $text = [string]$raw
            if ([string]::IsNullOrWhiteSpace($text)) { continue }

            $dto = [datetimeoffset]::Parse($text, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal)
            $packParams[$k] = $dto.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
            Write-TraceLog "Run-SelectedInsightPack: normalized $k='$text' -> '$($packParams[$k])'"
        }
        catch {
            Write-TraceLog "Run-SelectedInsightPack: could not normalize $k='$($packParams[$k])' ($($_.Exception.Message))"
        }
    }

    $useCache = $false
    if ($useInsightCacheCheckbox) { $useCache = [bool]$useInsightCacheCheckbox.IsChecked }
    $strictValidate = $false
    if ($strictInsightValidationCheckbox) { $strictValidate = [bool]$strictInsightValidationCheckbox.IsChecked }
    $cacheTtl = 60
    if ($insightCacheTtlInput -and -not [string]::IsNullOrWhiteSpace($insightCacheTtlInput.Text)) {
        try { $cacheTtl = [int]$insightCacheTtlInput.Text.Trim() } catch { $cacheTtl = 60 }
    }
    if ($cacheTtl -lt 1) { $cacheTtl = 1 }

    $cacheDir = Join-Path -Path $UserProfileBase -ChildPath "GenesysApiExplorerCache\\OpsInsights"
    if (-not (Test-Path -LiteralPath $cacheDir)) {
        New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
    }

    if ($Compare) {
        $baselineKey = if ($insightBaselineModeCombo) { [string]$insightBaselineModeCombo.SelectedValue } else { 'PreviousWindow' }
        if ($baselineKey -eq 'ShiftDays7') {
            $result = Invoke-GCInsightPackCompare -PackPath $packPath -Parameters $packParams -BaselineMode ShiftDays -BaselineShiftDays 7 -StrictValidation:$strictValidate
        }
        elseif ($baselineKey -eq 'ShiftDays30') {
            $result = Invoke-GCInsightPackCompare -PackPath $packPath -Parameters $packParams -BaselineMode ShiftDays -BaselineShiftDays 30 -StrictValidation:$strictValidate
        }
        else {
            $result = Invoke-GCInsightPackCompare -PackPath $packPath -Parameters $packParams -BaselineMode PreviousWindow -StrictValidation:$strictValidate
        }
    }
    else {
        if ($DryRun) {
            $result = Invoke-GCInsightPack -PackPath $packPath -Parameters $packParams -DryRun -StrictValidation:$strictValidate
        }
        else {
            if ($useCache) {
                $result = Invoke-GCInsightPack -PackPath $packPath -Parameters $packParams -UseCache -CacheTtlMinutes $cacheTtl -CacheDirectory $cacheDir -StrictValidation:$strictValidate
            }
            else {
                $result = Invoke-GCInsightPack -PackPath $packPath -Parameters $packParams -StrictValidation:$strictValidate
            }
        }
    }

    $script:LastInsightResult = $result
    Update-InsightPackUi -Result $result
    if ($exportInsightBriefingButton) { $exportInsightBriefingButton.IsEnabled = $true }
    return $result
}

function Get-DefaultAnalyticsIntervalLastMinutes {
    param(
        [Parameter()]
        [int]$Minutes = 30
    )

    if ($Minutes -lt 1) { $Minutes = 1 }
    $end = (Get-Date).ToUniversalTime()
    $start = $end.AddMinutes(-1 * $Minutes)
    return ("{0}/{1}" -f $start.ToString('yyyy-MM-ddTHH:mm:ss.fffZ'), $end.ToString('yyyy-MM-ddTHH:mm:ss.fffZ'))
}

if ($runSelectedInsightPackButton) {
    $runSelectedInsightPackButton.Add_Click({
            # DEF-003: pre-flight guards
            if (-not $insightPackCombo -or -not $insightPackCombo.SelectedItem) {
                $statusText.Text = "Select an Insight Pack first."
                Add-LogEntry "Insight pack blocked: no pack selected."
                return
            }
            $token = Get-ExplorerAccessToken
            if (-not $token) {
                $statusText.Text = "Provide an OAuth token before running an Insight Pack."
                Add-LogEntry "Insight pack blocked: no OAuth token."
                return
            }

            # Capture all UI state before going to background thread (DEF-001)
            $capturedModuleManifest = $script:OpsInsightsManifest
            $capturedBaseUrl        = $ApiBaseUrl
            $capturedToken          = $token
            $capturedPack           = $insightPackCombo.SelectedItem
            $capturedPackPath       = $capturedPack.FullPath
            if (-not (Test-Path -LiteralPath $capturedPackPath -ErrorAction SilentlyContinue)) {
                $capturedPackPath = Get-InsightPackPath -FileName $capturedPack.FileName
            }
            $capturedPackParams = Get-InsightPackParameterValues
            foreach ($k in @('startDate', 'endDate')) {
                try {
                    if (-not $capturedPackParams.ContainsKey($k)) { continue }
                    $raw = $capturedPackParams[$k]
                    if ([string]::IsNullOrWhiteSpace([string]$raw)) { continue }
                    $dto = [datetimeoffset]::Parse([string]$raw, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal)
                    $capturedPackParams[$k] = $dto.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
                }
                catch { }
            }
            $capturedUseCache     = if ($useInsightCacheCheckbox) { [bool]$useInsightCacheCheckbox.IsChecked } else { $false }
            $capturedStrict       = if ($strictInsightValidationCheckbox) { [bool]$strictInsightValidationCheckbox.IsChecked } else { $false }
            $capturedCacheTtl     = 60
            if ($insightCacheTtlInput -and -not [string]::IsNullOrWhiteSpace($insightCacheTtlInput.Text)) {
                try { $capturedCacheTtl = [int]$insightCacheTtlInput.Text.Trim() } catch { }
            }
            if ($capturedCacheTtl -lt 1) { $capturedCacheTtl = 1 }
            $capturedCacheDir = Join-Path -Path $UserProfileBase -ChildPath "GenesysApiExplorerCache\\OpsInsights"
            if (-not (Test-Path -LiteralPath $capturedCacheDir -ErrorAction SilentlyContinue)) {
                New-Item -ItemType Directory -Path $capturedCacheDir -Force -ErrorAction SilentlyContinue | Out-Null
            }

            Invoke-UIBackgroundTask `
                -OnStart {
                    $statusText.Text = "Running insight pack..."
                    if ($runSelectedInsightPackButton) { $runSelectedInsightPackButton.IsEnabled = $false }
                    if ($dryRunSelectedInsightPackButton) { $dryRunSelectedInsightPackButton.IsEnabled = $false }
                    if ($compareSelectedInsightPackButton) { $compareSelectedInsightPackButton.IsEnabled = $false }
                } `
                -WorkParams @{
                    ModuleManifest = $capturedModuleManifest
                    BaseUrl        = $capturedBaseUrl
                    Token          = $capturedToken
                    PackPath       = $capturedPackPath
                    PackParams     = $capturedPackParams
                    UseCache       = $capturedUseCache
                    StrictValidate = $capturedStrict
                    CacheTtl       = $capturedCacheTtl
                    CacheDir       = $capturedCacheDir
                } `
                -WorkScript {
                    Import-Module -Name $ModuleManifest -Force -ErrorAction Stop
                    Set-GCContext -ApiBaseUri $BaseUrl -AccessToken $Token | Out-Null
                    if ($UseCache) {
                        Invoke-GCInsightPack -PackPath $PackPath -Parameters $PackParams `
                            -UseCache -CacheTtlMinutes $CacheTtl -CacheDirectory $CacheDir `
                            -StrictValidation:$StrictValidate
                    }
                    else {
                        Invoke-GCInsightPack -PackPath $PackPath -Parameters $PackParams `
                            -StrictValidation:$StrictValidate
                    }
                } `
                -OnSuccess {
                    param($output)
                    $result = $output | Select-Object -Last 1
                    $script:LastInsightResult = $result
                    Update-InsightPackUi -Result $result
                    if ($exportInsightBriefingButton) { $exportInsightBriefingButton.IsEnabled = $true }
                    $statusText.Text = "Insight pack completed."
                    if ($runSelectedInsightPackButton) { $runSelectedInsightPackButton.IsEnabled = $true }
                    if ($dryRunSelectedInsightPackButton) { $dryRunSelectedInsightPackButton.IsEnabled = $true }
                    if ($compareSelectedInsightPackButton) { $compareSelectedInsightPackButton.IsEnabled = $true }
                } `
                -OnError {
                    param($err)
                    $errMsg = if ($err -is [System.Management.Automation.ErrorRecord]) { $err.Exception.Message } else { [string]$err }
                    $statusText.Text = "Insight pack failed."
                    Add-LogEntry "Insight pack failed: $errMsg"
                    [System.Windows.MessageBox]::Show("Insight pack failed: $errMsg", "Insight Pack Error", "OK", "Error")
                    if ($runSelectedInsightPackButton) { $runSelectedInsightPackButton.IsEnabled = $true }
                    if ($dryRunSelectedInsightPackButton) { $dryRunSelectedInsightPackButton.IsEnabled = $true }
                    if ($compareSelectedInsightPackButton) { $compareSelectedInsightPackButton.IsEnabled = $true }
                }
        })
}

if ($compareSelectedInsightPackButton) {
    $compareSelectedInsightPackButton.Add_Click({
            try {
                $statusText.Text = "Running insight pack (compare)..."
                Run-SelectedInsightPack -Compare:$true -DryRun:$false | Out-Null
                $statusText.Text = "Insight pack comparison completed."
            }
            catch {
                $statusText.Text = "Insight pack comparison failed."
                Add-LogEntry "Insight pack compare failed: $($_.Exception.Message)"
                [System.Windows.MessageBox]::Show("Insight pack compare failed: $($_.Exception.Message)", "Insight Pack Error", "OK", "Error")
            }
        })
}

if ($runQueueWaitReportButton) {
    $runQueueWaitReportButton.Add_Click({
            # DEF-003: pre-flight guards
            $qid = if ($queueWaitQueueIdInput) { [string]$queueWaitQueueIdInput.Text } else { '' }
            $qid = $qid.Trim()
            if ([string]::IsNullOrWhiteSpace($qid)) {
                if ($queueWaitReportStatus) { $queueWaitReportStatus.Text = "Queue ID is required." }
                $statusText.Text = "Queue ID is required."
                Add-LogEntry "Queue wait report blocked: no Queue ID."
                return
            }

            $token = Get-ExplorerAccessToken
            if (-not $token) {
                if ($queueWaitReportStatus) { $queueWaitReportStatus.Text = "Provide an OAuth token first." }
                $statusText.Text = "Provide an OAuth token first."
                Add-LogEntry "Queue wait report blocked: no OAuth token."
                return
            }

            $intervalText = if ($queueWaitIntervalInput) { [string]$queueWaitIntervalInput.Text } else { '' }
            $intervalText = $intervalText.Trim()
            if ([string]::IsNullOrWhiteSpace($intervalText)) {
                $intervalText = Get-DefaultAnalyticsIntervalLastMinutes -Minutes 30
                if ($queueWaitIntervalInput) { $queueWaitIntervalInput.Text = $intervalText }
            }

            # Capture inputs before background task (DEF-001)
            $capturedQid            = $qid
            $capturedInterval       = $intervalText
            $capturedModuleManifest = $script:OpsInsightsManifest
            $capturedBaseUrl        = $ApiBaseUrl
            $capturedToken          = $token

            Invoke-UIBackgroundTask `
                -OnStart {
                    if ($queueWaitReportStatus) { $queueWaitReportStatus.Text = "Running queue wait coverage report..." }
                    $statusText.Text = "Running queue wait coverage report..."
                    $script:QueueWaitResults.Clear()
                    if ($queueWaitDetailsText) { $queueWaitDetailsText.Text = '' }
                    if ($runQueueWaitReportButton) { $runQueueWaitReportButton.IsEnabled = $false }
                } `
                -WorkParams @{
                    QueueId        = $capturedQid
                    Interval       = $capturedInterval
                    ModuleManifest = $capturedModuleManifest
                    BaseUrl        = $capturedBaseUrl
                    Token          = $capturedToken
                } `
                -WorkScript {
                    Import-Module -Name $ModuleManifest -Force -ErrorAction Stop
                    Set-GCContext -ApiBaseUri $BaseUrl -AccessToken $Token | Out-Null
                    Get-GCQueueWaitCoverage -QueueId $QueueId -Interval $Interval
                } `
                -OnSuccess {
                    param($output)
                    $rows = @($output)
                    foreach ($r in $rows) { $script:QueueWaitResults.Add($r) | Out-Null }
                    $msg = "Queue wait coverage complete. Conversations=$($rows.Count)."
                    if ($queueWaitReportStatus) { $queueWaitReportStatus.Text = $msg }
                    $statusText.Text = $msg
                    Add-LogEntry $msg
                    if ($runQueueWaitReportButton) { $runQueueWaitReportButton.IsEnabled = $true }
                } `
                -OnError {
                    param($err)
                    $errMsg = if ($err -is [System.Management.Automation.ErrorRecord]) { $err.Exception.Message } else { [string]$err }
                    $statusText.Text = "Queue wait coverage failed."
                    if ($queueWaitReportStatus) { $queueWaitReportStatus.Text = "Failed: $errMsg" }
                    Add-LogEntry "Queue wait coverage failed: $errMsg"
                    [System.Windows.MessageBox]::Show("Queue wait coverage failed: $errMsg", "Queue Wait Coverage", "OK", "Error") | Out-Null
                    if ($runQueueWaitReportButton) { $runQueueWaitReportButton.IsEnabled = $true }
                }
        })
}

if ($liveSubscriptionEventsList) {
    $script:LiveSubscriptionEventsView = [System.Windows.Data.CollectionViewSource]::GetDefaultView($script:LiveSubscriptionEvents)
    $script:LiveSubscriptionEventsView.Filter = {
        param($item)
        if (-not $item) { return $false }
        if ([string]::IsNullOrWhiteSpace($script:LiveSubscriptionFilterText)) { return $true }
        $term = $script:LiveSubscriptionFilterText.ToLower()
        return (($item.Topic -and $item.Topic.ToLower().Contains($term)) -or
            ($item.EventType -and $item.EventType.ToLower().Contains($term)) -or
            ($item.Summary -and $item.Summary.ToLower().Contains($term)))
    }
    $liveSubscriptionEventsList.ItemsSource = $script:LiveSubscriptionEventsView
}

function Update-LiveSubscriptionFilterStatus {
    if (-not $liveSubscriptionStatusText) { return }
    $total = $script:LiveSubscriptionEvents.Count
    $filtered = $total
    if ($script:LiveSubscriptionEventsView) {
        $filtered = @($script:LiveSubscriptionEventsView | ForEach-Object { $_ }).Count
    }
    $filterText = if ([string]::IsNullOrWhiteSpace($script:LiveSubscriptionFilterText)) { 'none' } else { $script:LiveSubscriptionFilterText }
    $liveSubscriptionStatusText.Text = "Filtered $filtered of $total (filter: $filterText)"
}

if ($liveSubTopicPresetCombo) {
    Reset-LiveSubscriptionPresetCombo
}

if ($liveSubFilterInput) {
    # Placeholder/“watermark” handling to keep the box intuitive
    $liveSubFilterInput.Text = $script:LiveSubFilterPlaceholder
    $liveSubFilterInput.Foreground = 'Gray'

    $liveSubFilterInput.Add_GotFocus({
            if ($liveSubFilterInput.Text -eq $script:LiveSubFilterPlaceholder) {
                $liveSubFilterInput.Text = ''
                $liveSubFilterInput.Foreground = 'Black'
            }
        })

    $liveSubFilterInput.Add_LostFocus({
            if ([string]::IsNullOrWhiteSpace($liveSubFilterInput.Text)) {
                $liveSubFilterInput.Text = $script:LiveSubFilterPlaceholder
                $liveSubFilterInput.Foreground = 'Gray'
                $script:LiveSubscriptionFilterText = ''
                if ($script:LiveSubscriptionEventsView) { $script:LiveSubscriptionEventsView.Refresh() }
                Update-LiveSubscriptionFilterStatus
            }
        })

    $liveSubFilterInput.Add_TextChanged({
            $currentText = if ($liveSubFilterInput.Text) { $liveSubFilterInput.Text } else { '' }
            if ($currentText -eq $script:LiveSubFilterPlaceholder) {
                $script:LiveSubscriptionFilterText = ''
            }
            else {
                $script:LiveSubscriptionFilterText = $currentText.Trim()
            }
            if ($script:LiveSubscriptionEventsView) { $script:LiveSubscriptionEventsView.Refresh() }
            Update-LiveSubscriptionFilterStatus
        })
}

if ($liveSubTopicCatalogList) {
    Load-LiveSubscriptionTopicCatalogCache
    $liveSubTopicCatalogList.ItemsSource = $script:LiveSubscriptionTopicCatalog
    $liveSubTopicCatalogList.Add_MouseDoubleClick({
            if (-not $liveSubTopicInput) { return }
            $selectedItem = $liveSubTopicCatalogList.SelectedItem
            if (-not $selectedItem) { return }
            $topicName = Get-LiveSubscriptionTopicNameFromItem -Item $selectedItem
            if (-not $topicName) { return }

            $current = if ($liveSubTopicInput.Text) { $liveSubTopicInput.Text } else { '' }
            $entries = ($current -split '[,;`n\r]+') | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
            if (-not ($entries -contains $topicName)) {
                $entries += $topicName
            }
            $liveSubTopicInput.Text = ($entries -join ', ')
        })
}

if ($liveSubscriptionTopicTotalsList) {
    $liveSubscriptionTopicTotalsList.ItemsSource = $script:LiveSubscriptionTopicTotals
}

if ($liveSubscriptionEventTypeTotalsList) {
    $liveSubscriptionEventTypeTotalsList.ItemsSource = $script:LiveSubscriptionEventTypeTotals
}

if ($refreshLiveSubTopicsButton) {
    $refreshLiveSubTopicsButton.Add_Click({
            Refresh-LiveSubscriptionTopicCatalog -Force
        })
}

Start-LiveSubscriptionAnalyticsTimer
Refresh-LiveSubscriptionTopicCatalog

if ($operationalEventTopicPresetCombo) {
    foreach ($preset in $script:OperationalEventsTopicPresets) {
        $operationalEventTopicPresetCombo.Items.Add($preset) | Out-Null
    }
    $operationalEventTopicPresetCombo.DisplayMemberPath = 'Label'
    $operationalEventTopicPresetCombo.SelectedValuePath = 'Topic'
    $operationalEventTopicPresetCombo.SelectedIndex = 0
}

if ($stopOperationalEventsLiveButton) {
    $stopOperationalEventsLiveButton.Add_Click({
            Stop-OperationalEventsLiveSubscription
        })
}

if ($operationalEventLiveModeCheckbox) {
    $operationalEventLiveModeCheckbox.Add_Click({
            if ($operationalEventLiveModeCheckbox.IsChecked -eq $false) {
                Stop-OperationalEventsLiveSubscription
            }
        })
}

if ($startLiveSubscriptionButton) {
    $startLiveSubscriptionButton.Add_Click({
            if ($script:LiveSubscriptionCapture) {
                $liveSubscriptionStatusText.Text = "Live subscription already running."
                return
            }

            $topicList = @()
            if ($liveSubTopicPresetCombo -and $liveSubTopicPresetCombo.SelectedItem) {
                $presetValue = if ($liveSubTopicPresetCombo.SelectedValue) { $liveSubTopicPresetCombo.SelectedValue } else { $liveSubTopicPresetCombo.SelectedItem }
                if ($presetValue) { $topicList += [string]$presetValue }
            }
            if ($liveSubTopicCatalogList -and $liveSubTopicCatalogList.SelectedItems.Count -gt 0) {
                foreach ($item in $liveSubTopicCatalogList.SelectedItems) {
                    $name = Get-LiveSubscriptionTopicNameFromItem -Item $item
                    if ($name) { $topicList += $name }
                }
            }
            if ($liveSubTopicInput) {
                $topicList += ($liveSubTopicInput.Text -split '[,;`n\r]') | ForEach-Object { $_.Trim() }
            }

            $topics = $topicList | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique
            $topics = Resolve-LiveSubscriptionTopics -Topics $topics
            if ($topics.Count -eq 0) {
                $liveSubscriptionStatusText.Text = "Enter at least one topic."
                return
            }

            $token = Get-ExplorerAccessToken
            if (-not $token) {
                $liveSubscriptionStatusText.Text = "Set an OAuth token before starting a subscription."
                return
            }

            $startLiveSubscriptionButton.IsEnabled = $false
            if ($stopLiveSubscriptionButton) { $stopLiveSubscriptionButton.IsEnabled = $true }
            $liveSubscriptionStatusText.Text = "Creating channel..."
            Add-LogEntry "Live subscription starting for topics: $($topics -join ', ')"

            try {
                Cleanup-LiveSubscriptionChannel

                if ($script:LiveSubscriptionCapture) {
                    Stop-LiveSubscriptionRefreshTimer
                    try { Stop-GCNotificationCapture -CaptureSession $script:LiveSubscriptionCapture -GenerateSummary } catch { }
                    $script:LiveSubscriptionCapture = $null
                }

                if ($script:LiveSubscriptionConnection) {
                    try { $script:LiveSubscriptionConnection.CancellationTokenSource.Cancel() } catch { }
                    $script:LiveSubscriptionConnection = $null
                }

                $channelName = "APIExplorerLive_$((Get-Date).ToUniversalTime().ToString('yyyyMMddHHmmss'))"
                $chanResp = New-GCNotificationChannel -Name $channelName -ChannelType websocket -Description "Live events from API Explorer" -BaseUri $ApiBaseUrl -AccessToken $token
                $channel = $chanResp.Parsed
                if (-not $channel) {
                    $channel = ($chanResp.Content | ConvertFrom-Json -ErrorAction SilentlyContinue)
                }
                if (-not $channel -or -not $channel.id) {
                    throw "Unable to obtain channel ID from response."
                }

                Add-GCNotificationSubscriptions -ChannelId $channel.id -Topics $topics -BaseUri $ApiBaseUrl -AccessToken $token | Out-Null
                $connection = Connect-GCNotificationWebSocket -ChannelId $channel.id -BaseUri $ApiBaseUrl -AccessToken $token
                $topicGroup = if ($topics.Count -gt 1) { 'multiple' } else { ($topics[0] -replace '[^a-zA-Z0-9]', '_') }
                $captureRoot = if ($workspaceRoot) { Join-Path -Path $workspaceRoot -ChildPath 'captures' } else { Join-Path -Path (Get-Location) -ChildPath 'captures' }
                $captureSession = Start-GCNotificationCapture -Connection $connection -CaptureRoot $captureRoot -TopicGroup $topicGroup -WriteSummary
                $script:LiveSubscriptionConnection = $connection
                $script:LiveSubscriptionCapture = $captureSession
                $script:LiveSubscriptionSession = [pscustomobject]@{
                    Channel     = $channel
                    Topics      = $topics
                    AccessToken = $token
                }
                $script:LiveSubscriptionLastCapturePath = $captureSession.CapturePath
                $liveSubscriptionCapturePathText.Text = "Capture file: $($captureSession.CapturePath)"
                $liveSubscriptionStatusText.Text = "Capturing topics: $($topics -join ', ')"
                Start-LiveSubscriptionRefreshTimer
            }
            catch {
                $err = $_.Exception.Message
                $liveSubscriptionStatusText.Text = "Subscription failed: $err"
                Add-LogEntry "Live subscription failed: $err"
                Cleanup-LiveSubscriptionChannel
                $startLiveSubscriptionButton.IsEnabled = $true
                if ($stopLiveSubscriptionButton) { $stopLiveSubscriptionButton.IsEnabled = $false }
            }
        })
}

if ($stopLiveSubscriptionButton) {
    $stopLiveSubscriptionButton.IsEnabled = $false
    $stopLiveSubscriptionButton.Add_Click({
            if (-not $script:LiveSubscriptionCapture) {
                $liveSubscriptionStatusText.Text = "No active subscription to stop."
                return
            }

            Stop-LiveSubscriptionRefreshTimer
            try {
                $result = Stop-GCNotificationCapture -CaptureSession $script:LiveSubscriptionCapture -GenerateSummary
                $script:LiveSubscriptionLastSummary = $result.Summary
                $script:LiveSubscriptionLastSummaryPath = $result.SummaryPath
                $script:LiveSubscriptionLastCapturePath = $result.CapturePath
                $liveSubscriptionCapturePathText.Text = "Capture file: $($result.CapturePath)"
                $liveSubscriptionStatusText.Text = "Capture saved to $($result.CapturePath)"
                Add-LogEntry "Live subscription capture saved to $($result.CapturePath)"
                Invoke-RefreshLiveSubscriptionAnalyticsSafe
                Cleanup-LiveSubscriptionChannel
            }
            catch {
                $liveSubscriptionStatusText.Text = "Failed to stop subscription: $($_.Exception.Message)"
                Add-LogEntry "Live subscription stop failed: $($_.Exception.Message)"
            }
            finally {
                if ($script:LiveSubscriptionConnection) {
                    try { $script:LiveSubscriptionConnection.CancellationTokenSource.Cancel() } catch { }
                    $script:LiveSubscriptionConnection = $null
                }
                $script:LiveSubscriptionCapture = $null
                $startLiveSubscriptionButton.IsEnabled = $true
                $stopLiveSubscriptionButton.IsEnabled = $false
            }
        })
}

if ($exportLiveSubscriptionRawButton) {
    $exportLiveSubscriptionRawButton.Add_Click({
            $source = $script:LiveSubscriptionLastCapturePath
            if (-not $source -or -not (Test-Path -LiteralPath $source)) {
                $liveSubscriptionStatusText.Text = "No capture file available to export."
                return
            }

            $dialog = New-Object Microsoft.Win32.SaveFileDialog
            $dialog.Filter = "JSONL Files (*.jsonl)|*.jsonl|All Files (*.*)|*.*"
            $dialog.Title = "Export Live Subscription Capture"
            $dialog.FileName = [System.IO.Path]::GetFileName($source)
            if ($dialog.ShowDialog() -eq $true) {
                Copy-Item -Path $source -Destination $dialog.FileName -Force
                $liveSubscriptionStatusText.Text = "Capture exported to $($dialog.FileName)"
                Add-LogEntry "Live capture exported to $($dialog.FileName)"
            }
        })
}

if ($exportLiveSubscriptionSummaryButton) {
    $exportLiveSubscriptionSummaryButton.Add_Click({
            if (-not $script:LiveSubscriptionLastSummary) {
                $liveSubscriptionStatusText.Text = "No summary available; stop the subscription first."
                return
            }

            $dialog = New-Object Microsoft.Win32.SaveFileDialog
            $dialog.Filter = "Excel Workbooks (*.xlsx)|*.xlsx|All Files (*.*)|*.*"
            $dialog.Title = "Export Live Subscription Summary"
            $dialog.FileName = "LiveSubscriptions_Summary.xlsx"
            if ($dialog.ShowDialog() -eq $true) {
                $tables = Build-LiveSubscriptionSummaryTables -Summary $script:LiveSubscriptionLastSummary
                $audioTables = Build-AudioHookRollupTables -Summary $script:LiveSubscriptionLastSummary
                if ($audioTables -and $audioTables.Count -gt 0) {
                    $tables += $audioTables
                }
                Export-SimpleExcelWorkbook -Path $dialog.FileName -Tables $tables
                $liveSubscriptionStatusText.Text = "Summary exported to $($dialog.FileName)"
                Add-LogEntry "Live subscription summary exported to $($dialog.FileName)"
            }
        })
}

if ($operationalEventsList) {
    $operationalEventsList.ItemsSource = $script:OperationalEvents
}

if ($operationalEventsCatalogLink) {
    $operationalEventsCatalogLink.Add_MouseLeftButtonUp({
            Launch-Url -Url "https://help.mypurecloud.com/articles/operational-event-catalog/"
        })
}

if ($runOperationalEventsButton) {
    $runOperationalEventsButton.Add_Click({
            $rawIds = if ($operationalEventDefinitionsInput) { $operationalEventDefinitionsInput.Text } else { '' }
            $ids = ($rawIds -split '[,;`n\r]+') | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
            if (-not $ids -or $ids.Count -eq 0) {
                $operationalEventsStatusText.Text = "Enter at least one operational event definition ID."
                return
            }

            if ($operationalEventLiveModeCheckbox -and $operationalEventLiveModeCheckbox.IsChecked) {
                $presetTopic = $null
                if ($operationalEventTopicPresetCombo -and $operationalEventTopicPresetCombo.SelectedItem) {
                    $presetTopic = $operationalEventTopicPresetCombo.SelectedValue
                }
                if (-not $presetTopic -and $script:OperationalEventsTopicPresets.Count -gt 0) {
                    $presetTopic = $script:OperationalEventsTopicPresets[0].Topic
                }
                if (-not $presetTopic) {
                    $operationalEventsStatusText.Text = "No notification topic selected."
                    return
                }

                try {
                    Start-OperationalEventsLiveSubscription -Topics @($presetTopic) -EventDefinitionIds $ids
                }
                catch {
                    $operationalEventsStatusText.Text = "Live operational events failed: $($_.Exception.Message)"
                    Add-LogEntry "Live operational events failed: $($_.Exception.Message)"
                }

                return
            }

            Stop-OperationalEventsLiveSubscription

            $token = Get-ExplorerAccessToken
            if (-not $token) {
                $operationalEventsStatusText.Text = "Provide an OAuth token to query operational events."
                return
            }

            $interval = "{0}/{1}" -f ((Get-Date).AddMinutes(-30).ToUniversalTime().ToString("o")), ((Get-Date).ToUniversalTime().ToString("o"))
            $filters = @()
            foreach ($id in $ids) {
                $filters += @{ name = 'eventDefinitionId'; value = $id }
            }

            # Capture inputs before background task (DEF-001)
            $capturedInterval       = $interval
            $capturedFilters        = $filters
            $capturedModuleManifest = $script:OpsInsightsManifest
            $capturedBaseUrl        = $ApiBaseUrl
            $capturedToken          = $token

            Invoke-UIBackgroundTask `
                -OnStart {
                    $operationalEventsStatusText.Text = "Querying operational events..."
                    $script:OperationalEvents.Clear()
                    $script:OperationalEventsRaw.Clear()
                    if ($runOperationalEventsButton) { $runOperationalEventsButton.IsEnabled = $false }
                } `
                -WorkParams @{
                    Interval       = $capturedInterval
                    Filters        = $capturedFilters
                    ModuleManifest = $capturedModuleManifest
                    BaseUrl        = $capturedBaseUrl
                    Token          = $capturedToken
                } `
                -WorkScript {
                    Import-Module -Name $ModuleManifest -Force -ErrorAction Stop
                    Set-GCContext -ApiBaseUri $BaseUrl -AccessToken $Token | Out-Null
                    Invoke-GCAuditQuery -Interval $Interval -Filters $Filters -MaxResults 400
                } `
                -OnSuccess {
                    param($output)
                    $result = $output | Select-Object -Last 1
                    foreach ($entry in @($result.Entities)) {
                        $ts = if ($entry.Timestamp) {
                            [DateTime]::Parse($entry.Timestamp).ToString("yyyy-MM-dd HH:mm:ss")
                        }
                        elseif ($entry.timestamp) {
                            [DateTime]::Parse($entry.timestamp).ToString("yyyy-MM-dd HH:mm:ss")
                        }
                        else { (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") }
                        $script:OperationalEvents.Add([pscustomobject]@{
                            Timestamp         = $ts
                            EventDefinitionId = $entry.eventDefinitionId
                            Severity          = $entry.severity
                            EntityId          = $entry.entityId
                            Message           = if ($entry.message) { $entry.message } else { ($entry | ConvertTo-Json -Depth 3) }
                        }) | Out-Null
                    }
                    foreach ($entity in @($result.Entities)) { $script:OperationalEventsRaw.Add($entity) | Out-Null }
                    $operationalEventsStatusText.Text = "Operational events loaded ($($script:OperationalEvents.Count))."
                    if ($runOperationalEventsButton) { $runOperationalEventsButton.IsEnabled = $true }
                } `
                -OnError {
                    param($err)
                    $errMsg = if ($err -is [System.Management.Automation.ErrorRecord]) { $err.Exception.Message } else { [string]$err }
                    $operationalEventsStatusText.Text = "Operational event query failed: $errMsg"
                    Add-LogEntry "Operational event query failed: $errMsg"
                    if ($runOperationalEventsButton) { $runOperationalEventsButton.IsEnabled = $true }
                }
        })
}

if ($importOperationalEventsButton) {
    $importOperationalEventsButton.Add_Click({
            $dialog = New-Object Microsoft.Win32.OpenFileDialog
            $dialog.Filter = "JSON Files (*.json;*.jsonl)|*.json;*.jsonl|All Files (*.*)|*.*"
            $dialog.Title = "Import Operational Events"
            if ($dialog.ShowDialog() -ne $true) { return }

            try {
                $payload = Get-Content -LiteralPath $dialog.FileName -Raw
                $json = $payload | ConvertFrom-Json -Depth 5
                $events = if ($json.PSObject.Properties.Name -contains 'entities') { @($json.entities) } else { @($json) }
                $script:OperationalEvents.Clear()
                $script:OperationalEventsRaw.Clear()
                foreach ($entry in $events) {
                    $timestamp = if ($entry.timestamp) { $entry.timestamp } elseif ($entry.Timestamp) { $entry.Timestamp } else { (Get-Date).ToString("o") }
                    $script:OperationalEvents.Add([pscustomobject]@{
                            Timestamp         = $timestamp
                            EventDefinitionId = $entry.eventDefinitionId
                            Severity          = $entry.severity
                            EntityId          = $entry.entityId
                            Message           = if ($entry.message) { $entry.message } else { ($entry | ConvertTo-Json -Depth 3) }
                        }) | Out-Null
                    $script:OperationalEventsRaw.Add($entry) | Out-Null
                }
                $operationalEventsStatusText.Text = "Imported $($events.Count) operational events."
            }
            catch {
                $operationalEventsStatusText.Text = "Import failed: $($_.Exception.Message)"
            }
        })
}

if ($exportOperationalEventsJsonButton) {
    $exportOperationalEventsJsonButton.Add_Click({
            if (-not $script:OperationalEventsRaw -or $script:OperationalEventsRaw.Count -eq 0) {
                $operationalEventsStatusText.Text = "No operational events available to export."
                return
            }
            $dialog = New-Object Microsoft.Win32.SaveFileDialog
            $dialog.Filter = "JSON Files (*.json)|*.json|All Files (*.*)|*.*"
            $dialog.Title = "Export Operational Events"
            $dialog.FileName = "OperationalEvents.json"
            if ($dialog.ShowDialog() -eq $true) {
                ($script:OperationalEventsRaw | ConvertTo-Json -Depth 5) | Set-Content -LiteralPath $dialog.FileName -Encoding utf8
                $operationalEventsStatusText.Text = "Exported operational events to $($dialog.FileName)"
            }
        })
}

if ($exportOperationalEventsSummaryButton) {
    $exportOperationalEventsSummaryButton.Add_Click({
            if (-not $script:OperationalEventsRaw -or $script:OperationalEventsRaw.Count -eq 0) {
                $operationalEventsStatusText.Text = "No events to summarize."
                return
            }
            $dialog = New-Object Microsoft.Win32.SaveFileDialog
            $dialog.Filter = "Excel Workbooks (*.xlsx)|*.xlsx|All Files (*.*)|*.*"
            $dialog.Title = "Export Operational Events Summary"
            $dialog.FileName = "OperationalEvents_Summary.xlsx"
            if ($dialog.ShowDialog() -eq $true) {
                $tables = Build-OperationalEventsSummaryTables -Events $script:OperationalEventsRaw
                Export-SimpleExcelWorkbook -Path $dialog.FileName -Tables $tables
                $operationalEventsStatusText.Text = "Operational summary exported to $($dialog.FileName)"
                $script:OperationalEventsSummaryPath = $dialog.FileName
            }
        })
}

if ($auditEventsList) {
    $auditEventsList.ItemsSource = $script:AuditInvestigatorEvents
}

if ($runAuditInvestigatorButton) {
    $runAuditInvestigatorButton.Add_Click({
            $start = $null
            if ($auditStartInput -and -not [string]::IsNullOrWhiteSpace($auditStartInput.Text)) {
                try { $start = [DateTime]::Parse($auditStartInput.Text) } catch { $start = $null }
            }
            if (-not $start) { $start = (Get-Date).AddHours(-1) }
            $end = $null
            if ($auditEndInput -and -not [string]::IsNullOrWhiteSpace($auditEndInput.Text)) {
                try { $end = [DateTime]::Parse($auditEndInput.Text) } catch { $end = $null }
            }
            if (-not $end) { $end = Get-Date }
            $interval = "{0}/{1}" -f $start.ToUniversalTime().ToString("o"), $end.ToUniversalTime().ToString("o")

            $filters = @()
            if ($auditEntityInput -and -not [string]::IsNullOrWhiteSpace($auditEntityInput.Text)) {
                $filters += @{ name = 'entityId'; value = $auditEntityInput.Text.Trim() }
            }
            if ($auditUserInput -and -not [string]::IsNullOrWhiteSpace($auditUserInput.Text)) {
                $filters += @{ name = 'userId'; value = $auditUserInput.Text.Trim() }
            }

            $token = Get-ExplorerAccessToken
            if (-not $token) {
                $auditStatusText.Text = "Supply an OAuth token before running audit queries."
                return
            }

            $service = if ($auditServiceInput -and -not [string]::IsNullOrWhiteSpace($auditServiceInput.Text)) { $auditServiceInput.Text.Trim() } else { $null }

            # Capture inputs before background task (DEF-001)
            $capturedInterval       = $interval
            $capturedFilters        = $filters
            $capturedService        = $service
            $capturedModuleManifest = $script:OpsInsightsManifest
            $capturedBaseUrl        = $ApiBaseUrl
            $capturedToken          = $token

            Invoke-UIBackgroundTask `
                -OnStart {
                    $auditStatusText.Text = "Querying audit events..."
                    $script:AuditInvestigatorEvents.Clear()
                    if ($runAuditInvestigatorButton) { $runAuditInvestigatorButton.IsEnabled = $false }
                } `
                -WorkParams @{
                    Interval       = $capturedInterval
                    Filters        = $capturedFilters
                    ServiceName    = $capturedService
                    ModuleManifest = $capturedModuleManifest
                    BaseUrl        = $capturedBaseUrl
                    Token          = $capturedToken
                } `
                -WorkScript {
                    Import-Module -Name $ModuleManifest -Force -ErrorAction Stop
                    Set-GCContext -ApiBaseUri $BaseUrl -AccessToken $Token | Out-Null
                    Invoke-GCAuditQuery -Interval $Interval -ServiceName $ServiceName -Filters $Filters -MaxResults 400
                } `
                -OnSuccess {
                    param($output)
                    $result = $output | Select-Object -Last 1
                    foreach ($entry in @($result.Entities)) {
                        $ts = if ($entry.timestamp) { $entry.timestamp } elseif ($entry.Timestamp) { $entry.Timestamp } else { (Get-Date).ToString("o") }
                        $script:AuditInvestigatorEvents.Add([pscustomobject]@{
                                Timestamp = [DateTime]::Parse($ts).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss")
                                Actor     = if ($entry.userId) { $entry.userId } elseif ($entry.actorId) { $entry.actorId } else { '(unknown)' }
                                Service   = if ($entry.service) { $entry.service } else { '(n/a)' }
                                Action    = if ($entry.action) { $entry.action } else { if ($entry.Name) { $entry.Name } else { '(unknown)' } }
                                EntityId  = if ($entry.entityId) { $entry.entityId } else { '' }
                            }) | Out-Null
                    }
                    $auditTimelineText.Text = Format-AuditTimelineText -Events @($script:AuditInvestigatorEvents)
                    $auditStatusText.Text = "Audit query returned $($script:AuditInvestigatorEvents.Count) events."
                    if ($runAuditInvestigatorButton) { $runAuditInvestigatorButton.IsEnabled = $true }
                } `
                -OnError {
                    param($err)
                    $errMsg = if ($err -is [System.Management.Automation.ErrorRecord]) { $err.Exception.Message } else { [string]$err }
                    $auditStatusText.Text = "Audit query failed: $errMsg"
                    Add-LogEntry "Audit query failed: $errMsg"
                    if ($runAuditInvestigatorButton) { $runAuditInvestigatorButton.IsEnabled = $true }
                }
        })
}

if ($exportAuditJsonButton) {
    $exportAuditJsonButton.Add_Click({
            if ($script:AuditInvestigatorEvents.Count -eq 0) {
                $auditStatusText.Text = "No audit events to export."
                return
            }
            $dialog = New-Object Microsoft.Win32.SaveFileDialog
            $dialog.Filter = "JSON Files (*.json)|*.json|All Files (*.*)|*.*"
            $dialog.Title = "Export Audit Events"
            $dialog.FileName = "AuditEvents.json"
            if ($dialog.ShowDialog() -eq $true) {
                ($script:AuditInvestigatorEvents | ConvertTo-Json -Depth 5) | Set-Content -LiteralPath $dialog.FileName -Encoding utf8
                $auditStatusText.Text = "Audit events exported to $($dialog.FileName)"
            }
        })
}

if ($exportAuditSummaryButton) {
    $exportAuditSummaryButton.Add_Click({
            if ($script:AuditInvestigatorEvents.Count -eq 0) {
                $auditStatusText.Text = "Run an audit query first."
                return
            }
            $dialog = New-Object Microsoft.Win32.SaveFileDialog
            $dialog.Filter = "Excel Workbooks (*.xlsx)|*.xlsx|All Files (*.*)|*.*"
            $dialog.Title = "Export Audit Summary"
            $dialog.FileName = "AuditSummary.xlsx"
            if ($dialog.ShowDialog() -eq $true) {
                $tables = Build-AuditSummaryTables -Events @($script:AuditInvestigatorEvents)
                Export-SimpleExcelWorkbook -Path $dialog.FileName -Tables $tables
                $auditStatusText.Text = "Audit summary exported to $($dialog.FileName)"
                $script:AuditSummaryExportPath = $dialog.FileName
                if ($auditSummaryPathText) {
                    $auditSummaryPathText.Text = "Summary file: $($dialog.FileName)"
                }
            }
        })
}

if ($dryRunSelectedInsightPackButton) {
    $dryRunSelectedInsightPackButton.Add_Click({
            try {
                $statusText.Text = "Running insight pack (dry run)..."
                Run-SelectedInsightPack -Compare:$false -DryRun:$true | Out-Null
                $statusText.Text = "Insight pack dry run completed."
            }
            catch {
                $statusText.Text = "Insight pack dry run failed."
                Add-LogEntry "Insight pack dry run failed: $($_.Exception.Message)"
                [System.Windows.MessageBox]::Show("Insight pack dry run failed: $($_.Exception.Message)", "Insight Pack Error", "OK", "Error")
            }
        })
}

if ($runQueueSmokePackButton) {
    $runQueueSmokePackButton.Add_Click({
            Run-InsightPackWorkflow -Label "Queue Smoke Detector" -FileName "gc.queues.smoke.v1.json"
        })
}

if ($runDataActionsPackButton) {
    $runDataActionsPackButton.Add_Click({
            Run-InsightPackWorkflow -Label "Data Action Failures" -FileName "gc.dataActions.failures.v1.json"
        })
}

if ($runDataActionsEnrichedPackButton) {
    $runDataActionsEnrichedPackButton.Add_Click({
            Run-InsightPackWorkflow -Label "Data Actions (Enriched)" -FileName "gc.dataActions.failures.enriched.v1.json"
        })
}

if ($runPeakConcurrencyPackButton) {
    $runPeakConcurrencyPackButton.Add_Click({
            Run-InsightPackWorkflow -Label "Peak Concurrency (Voice)" -FileName "gc.calls.peakConcurrency.monthly.v1.json"
        })
}

if ($runMosMonthlyPackButton) {
    $runMosMonthlyPackButton.Add_Click({
            # End-of-month reporting is typically "last full month"
            Run-InsightPackWorkflow -Label "Monthly MOS (By Division)" -FileName "gc.mos.monthly.byDivision.v1.json" -TimePresetKey 'lastMonth'
        })
}

if ($exportInsightBriefingButton) {
    $exportInsightBriefingButton.Add_Click({
            if (-not (Test-UserAllowed)) {
                Add-LogEntry "Insight export blocked for user $($script:CurrentUser)"
                return
            }
            $tokenCheck = $null
            try { $tokenCheck = Get-ExplorerAccessToken } catch { $tokenCheck = $null }
            if (-not $tokenCheck) { return }
            Export-InsightBriefingWorkflow
        })
}

# Ops Dashboard controls
if ($opsDashboardMosList) {
    $opsDashboardMosList.ItemsSource = $script:OperationsDashboardMosCollection
}

if ($opsDashboardDataActionList) {
    $opsDashboardDataActionList.ItemsSource = $script:OperationsDashboardDataActionCollection
}

if ($opsDashboardWebRtcList) {
    $opsDashboardWebRtcList.ItemsSource = $script:OperationsDashboardWebRtcCollection
}

if ($exportDivisionQosButton) {
    $exportDivisionQosButton.Add_Click({
            if (-not (Test-UserAllowed)) {
                Add-LogEntry "Export blocked for user $($script:CurrentUser)"
                return
            }
            $tokenCheck = $null
            try { $tokenCheck = Get-ExplorerAccessToken } catch { $tokenCheck = $null }
            if (-not $tokenCheck) { return }
            Export-DivisionQosSummary
        })
}

if ($exportWebRtcButton) {
    $exportWebRtcButton.Add_Click({
            if (-not (Test-UserAllowed)) {
                Add-LogEntry "Export blocked for user $($script:CurrentUser)"
                return
            }
            $tokenCheck = $null
            try { $tokenCheck = Get-ExplorerAccessToken } catch { $tokenCheck = $null }
            if (-not $tokenCheck) { return }
            Export-WebRtcDisconnectReview
        })
}

if ($exportDataActionButton) {
    $exportDataActionButton.Add_Click({
            if (-not (Test-UserAllowed)) {
                Add-LogEntry "Export blocked for user $($script:CurrentUser)"
                return
            }
            $tokenCheck = $null
            try { $tokenCheck = Get-ExplorerAccessToken } catch { $tokenCheck = $null }
            if (-not $tokenCheck) { return }
            Export-DataActionReliability
        })
}

if ($exportIncidentPacketButton) {
    $exportIncidentPacketButton.Add_Click({
            if (-not (Test-UserAllowed)) {
                Add-LogEntry "Export blocked for user $($script:CurrentUser)"
                return
            }
            $tokenCheck = $null
            try { $tokenCheck = Get-ExplorerAccessToken } catch { $tokenCheck = $null }
            if (-not $tokenCheck) { return }
            Export-IncidentPacket
        })
}

if ($exportRedactedKpiButton) {
    $exportRedactedKpiButton.Add_Click({
            if (-not (Test-UserAllowed)) {
                Add-LogEntry "Export blocked for user $($script:CurrentUser)"
                return
            }
            $tokenCheck = $null
            try { $tokenCheck = Get-ExplorerAccessToken } catch { $tokenCheck = $null }
            if (-not $tokenCheck) { return }
            $store = $script:OperationsDashboardStorePath
            if (-not $store -or -not (Test-Path -LiteralPath $store)) {
                [System.Windows.MessageBox]::Show("Dashboard store not found. Run ingest or select a store first.", "Export KPI Rollup", "OK", "Warning") | Out-Null
                return
            }
            try {
                $rollups = Get-GCConversationRollup -StorePath $store
                $tables = @()
                foreach ($rollup in $rollups) {
                    $tables += [pscustomobject]@{
                        Title   = $rollup.Title
                        Headers = @('Bucket', 'Conversations', 'AvgMos', 'MedianMos', 'DegradedPct', 'WebRtcDisconnects')
                        Rows    = $rollup.Rows
                    }
                }
                $dialog = New-Object Microsoft.Win32.SaveFileDialog
                $dialog.Filter = "Excel Workbook (*.xlsx)|*.xlsx|All Files (*.*)|*.*"
                $dialog.Title = "Export KPI Rollup (Redacted)"
                $dialog.FileName = "ConversationKPI_Redacted.xlsx"
                if ($dialog.ShowDialog() -eq $true) {
                    Export-SimpleExcelWorkbook -Path $dialog.FileName -Tables $tables
                    Add-LogEntry "Redacted KPI rollup exported to $($dialog.FileName)"
                }
            }
            catch {
                [System.Windows.MessageBox]::Show("Failed to export KPI rollup: $($_.Exception.Message)", "Export KPI Rollup", "OK", "Error") | Out-Null
                Add-LogEntry "Redacted KPI rollup failed: $($_.Exception.Message)"
            }
        })
}

function Refresh-AuditLogView {
    if (-not $auditLogList -or -not $script:AuditLogEntries) { return }
    $script:AuditLogEntries.Clear()
    $root = Join-Path -Path (Get-RepoRoot -StartPath $ScriptRoot) -ChildPath 'artifacts/ops-dashboard'
    $logPath = Join-Path -Path $root -ChildPath 'ingest-audit.log'
    if (-not (Test-Path -LiteralPath $logPath)) { return }
    foreach ($line in Get-Content -LiteralPath $logPath -Tail 500 -Encoding utf8) {
        $script:AuditLogEntries.Add($line) | Out-Null
    }
    $auditLogList.ItemsSource = $script:AuditLogEntries
}

if ($refreshAuditLogButton) {
    $refreshAuditLogButton.Add_Click({ Refresh-AuditLogView })
    Refresh-AuditLogView
}

if ($refreshOpsDashboardButton) {
    $refreshOpsDashboardButton.Add_Click({
            Refresh-OperationsDashboardData
        })
}

if ($browseOpsDashboardStoreButton) {
    $browseOpsDashboardStoreButton.Add_Click({
            $dialog = New-Object Microsoft.Win32.OpenFileDialog
            $dialog.Title = "Select dashboard store"
            $dialog.Filter = "JSON Lines (*.jsonl)|*.jsonl|JSON files (*.json)|*.json|All Files (*.*)|*.*"
            if ($dialog.ShowDialog() -eq $true) {
                $script:OperationsDashboardStorePath = $dialog.FileName
                Refresh-OperationsDashboardData -StorePath $dialog.FileName
            }
        })
}

if ($opsDashboardTimePresetCombo) {
    $opsDashboardTimePresetCombo.SelectedIndex = 0
    $opsDashboardTimePresetCombo.Add_SelectionChanged({
            $now = (Get-Date).ToUniversalTime()
            switch ([int]$opsDashboardTimePresetCombo.SelectedIndex) {
                0 {
                    $script:OperationsDashboardFilters.StartUtc = $now.AddHours(-1)
                    $script:OperationsDashboardFilters.EndUtc = $now
                }
                1 {
                    $script:OperationsDashboardFilters.StartUtc = $now.AddHours(-24)
                    $script:OperationsDashboardFilters.EndUtc = $now
                }
                2 {
                    # Custom range does not override dates
                }
            }
            Update-OperationsDashboardFilterInputs
            Update-OperationsDashboardFiltersFromUi
            Refresh-OperationsTimelineEntries
        })
}

if ($opsDashboardMosThresholdSlider) {
    $opsDashboardMosThresholdSlider.Add_ValueChanged({
            if ($opsDashboardMosThresholdSlider -and $opsDashboardMosThresholdText) {
                $value = [math]::Round([double]$opsDashboardMosThresholdSlider.Value, 2)
                $opsDashboardMosThresholdText.Text = "{0:N2}" -f $value
                $script:OperationsDashboardFilters.MosThreshold = $value
                Refresh-OperationsTimelineEntries
            }
        })
}

if ($opsDashboardApplyFiltersButton) {
    $opsDashboardApplyFiltersButton.Add_Click({
            Update-OperationsDashboardFiltersFromUi
            Refresh-OperationsTimelineEntries
        })
}

function Get-IngestIntervalPreset {
    param([int]$Index)

    $now = (Get-Date).ToUniversalTime()
    switch ($Index) {
        0 { return "{0}/{1}" -f $now.AddDays(-1).ToString("o"), $now.ToString("o") }       # Yesterday (24h)
        1 { return "{0}/{1}" -f $now.AddDays(-7).ToString("o"), $now.ToString("o") }       # Last 7 days
        2 { return "{0}/{1}" -f $now.AddDays(-30).ToString("o"), $now.ToString("o") }      # Last 30 days
        default { return "{0}/{1}" -f $now.AddDays(-1).ToString("o"), $now.ToString("o") }
    }
}

function Test-UserAllowed {
    if (-not $script:AllowedOpsUsers -or $script:AllowedOpsUsers.Count -eq 0) { return $true }
    return ($script:AllowedOpsUsers -contains $script:CurrentUser)
}

function Get-IngestTokenPath {
    $root = Join-Path -Path (Get-RepoRoot -StartPath $ScriptRoot) -ChildPath 'artifacts/ops-dashboard'
    if (-not (Test-Path -LiteralPath $root)) { New-Item -ItemType Directory -Path $root -Force | Out-Null }
    return Join-Path -Path $root -ChildPath 'ingest-token.dat'
}

function Save-IngestToken {
    param([string]$Token)
    if (-not $Token) { throw "Token is required to save ingest token." }
    $path = Get-IngestTokenPath
    $secure = ConvertTo-SecureString $Token -AsPlainText -Force
    $enc = $secure | ConvertFrom-SecureString
    Set-Content -LiteralPath $path -Value $enc -Encoding utf8
    return $path
}

if ($opsIngestIntervalCombo) {
    $opsIngestIntervalCombo.SelectedIndex = 0
}

if ($runOpsConversationIngestButton) {
    $runOpsConversationIngestButton.Add_Click({
            if (-not (Test-UserAllowed)) {
                $opsIngestStatusText.Text = "Ingest blocked: user not allowed."
                Add-LogEntry "Ingest blocked for user $($script:CurrentUser)"
                return
            }
            $tokenCheck = $null
            try { $tokenCheck = Get-ExplorerAccessToken } catch { $tokenCheck = $null }
            if (-not $tokenCheck) {
                $opsIngestStatusText.Text = "Ingest blocked: OAuth token required."
                Add-LogEntry "Ingest blocked: no OAuth token present."
                return
            }
            $tokenPath = $null
            try { $tokenPath = Save-IngestToken -Token $tokenCheck } catch { $tokenPath = $null }

            # Capture inputs before background task (DEF-001)
            $capturedInterval       = Get-IngestIntervalPreset -Index $opsIngestIntervalCombo.SelectedIndex
            $capturedModuleManifest = $script:OpsInsightsManifest
            $capturedToken          = $tokenCheck

            Invoke-UIBackgroundTask `
                -OnStart {
                    $opsIngestStatusText.Text = "Starting conversation ingest..."
                    if ($runOpsConversationIngestButton) { $runOpsConversationIngestButton.IsEnabled = $false }
                } `
                -WorkParams @{
                    Interval       = $capturedInterval
                    ModuleManifest = $capturedModuleManifest
                    Token          = $capturedToken
                } `
                -WorkScript {
                    Import-Module -Name $ModuleManifest -Force -ErrorAction Stop
                    Invoke-GCConversationIngest -Interval $Interval -AccessToken $Token
                } `
                -OnSuccess {
                    param($output)
                    $result = $output | Select-Object -Last 1
                    $msg = "Ingested $($result.RecordsWritten) conversations to $($result.StorePath)"
                    $opsIngestStatusText.Text = $msg
                    Add-LogEntry $msg
                    Refresh-OperationsDashboardData -StorePath $result.StorePath
                    if ($runOpsConversationIngestButton) { $runOpsConversationIngestButton.IsEnabled = $true }
                } `
                -OnError {
                    param($err)
                    $errMsg = if ($err -is [System.Management.Automation.ErrorRecord]) { $err.Exception.Message } else { [string]$err }
                    $opsIngestStatusText.Text = "Ingest failed: $errMsg"
                    Add-LogEntry "Conversation ingest failed: $errMsg"
                    if ($runOpsConversationIngestButton) { $runOpsConversationIngestButton.IsEnabled = $true }
                }
        })
}

function Register-ConvoIngestScheduledTask {
    param(
        [string]$TaskName = 'GenesysAPIExplorer.ConversationIngestDaily',
        [int]$PresetIndex = 0,
        [string]$TokenPath
    )

    if (-not $TokenPath -or -not (Test-Path -LiteralPath $TokenPath)) {
        throw "Token path not found for scheduled ingest."
    }

    $root = Get-RepoRoot -StartPath $ScriptRoot
    $intervalScript = switch ($PresetIndex) {
        0 { '$now=Get-Date; $interval="{0}/{1}" -f ($now.AddDays(-1).ToUniversalTime().ToString(\"o\")), ($now.ToUniversalTime().ToString(\"o\"))' }
        1 { '$now=Get-Date; $interval="{0}/{1}" -f ($now.AddDays(-7).ToUniversalTime().ToString(\"o\")), ($now.ToUniversalTime().ToString(\"o\"))' }
        default { '$now=Get-Date; $interval="{0}/{1}" -f ($now.AddDays(-30).ToUniversalTime().ToString(\"o\")), ($now.ToUniversalTime().ToString(\"o\"))' }
    }
    $command = @(
        "cd `"$root`"",
        "Import-Module `"$($script:OpsInsightsManifest)`"",
        "Import-Module `"$($script:OpsInsightsCoreManifest)`"",
        "$intervalScript; $enc=Get-Content -LiteralPath `"$TokenPath`" -Raw; $secure=ConvertTo-SecureString $enc; $token=(New-Object System.Net.NetworkCredential('', $secure)).Password; Invoke-GCConversationIngest -Interval $interval -AccessToken $token"
    ) -join '; '

    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -Command `"$command`""
    $trigger = New-ScheduledTaskTrigger -Daily -At 1:00am
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Description "Daily conversation ingest via Genesys API Explorer" -Force | Out-Null
    return $TaskName
}

if ($scheduleOpsConversationIngestButton) {
    # DEF-004: Task Scheduler is Windows-only; disable gracefully on other platforms
    $isWindows = ($IsWindows -eq $true) -or ($env:OS -eq 'Windows_NT')
    if (-not $isWindows) {
        $scheduleOpsConversationIngestButton.IsEnabled = $false
        $scheduleOpsConversationIngestButton.ToolTip   = "Windows Task Scheduler is not available on this platform."
    }

    $scheduleOpsConversationIngestButton.Add_Click({
            try {
                if (-not (Test-UserAllowed)) {
                    $opsIngestStatusText.Text = "Schedule blocked: user not allowed."
                    Add-LogEntry "Schedule blocked for user $($script:CurrentUser)"
                    return
                }
                $tokenCheck = $null
                try { $tokenCheck = Get-ExplorerAccessToken } catch { $tokenCheck = $null }
                if (-not $tokenCheck) {
                    $opsIngestStatusText.Text = "Schedule blocked: OAuth token required."
                    Add-LogEntry "Schedule blocked: no OAuth token present."
                    return
                }
                $tokenPath = Save-IngestToken -Token $tokenCheck
                $task = Register-ConvoIngestScheduledTask -PresetIndex $opsIngestIntervalCombo.SelectedIndex -TokenPath $tokenPath
                $label = @('Yesterday', 'Last 7 days', 'Last 30 days')[$opsIngestIntervalCombo.SelectedIndex]
                $opsIngestStatusText.Text = "Scheduled daily ingest ($label) as task '$task'."
                Add-LogEntry $opsIngestStatusText.Text
            }
            catch {
                $opsIngestStatusText.Text = "Schedule failed: $($_.Exception.Message)"
                Add-LogEntry "Conversation ingest schedule failed: $($_.Exception.Message)"
            }
        })
}

if ($operationsTimelineList) {
    $operationsTimelineList.ItemsSource = $script:OperationsTimelineEntries
}

if ($investigateTimelineEntryButton) {
    $investigateTimelineEntryButton.Add_Click({ Investigate-SelectedTimelineEntry })
}

if ($exportTimelineEntryButton) {
    $exportTimelineEntryButton.Add_Click({ Export-SelectedTimelineEntry })
}

Initialize-OperationsDashboardFilters

Refresh-OperationsDashboardData

# Export PowerShell Script button
if ($exportPowerShellButton) {
    $exportPowerShellButton.Add_Click({
            $selectedPath = $pathCombo.SelectedItem
            $selectedMethod = $methodCombo.SelectedItem
            $token = Get-ExplorerAccessToken

            if (-not $selectedPath -or -not $selectedMethod) {
                $statusText.Text = "Select a path and method first."
                return
            }

            # Collect current parameters
            $requestParams = @{}
            $pathObject = Get-PathObject -ApiPaths $ApiPaths -Path $selectedPath
            $methodObject = Get-MethodObject -PathObject $pathObject -MethodName $selectedMethod
            if ($methodObject -and $methodObject.parameters) {
                foreach ($param in $methodObject.parameters) {
                    $yinput = $paramInputs[$param.name]
                    if ($yinput) {
                        $value = Get-ParameterControlValue -Control $yinput
                        if (-not [string]::IsNullOrWhiteSpace($value)) {
                            $requestParams[$param.name] = $value
                        }
                    }
                }
            }

            $mode = 'Auto'
            try {
                if ($powerShellExportModeCombo -and $powerShellExportModeCombo.SelectedIndex -ge 0) {
                    switch ([int]$powerShellExportModeCombo.SelectedIndex) {
                        1 { $mode = 'Portable' }
                        2 { $mode = 'OpsInsights' }
                        default { $mode = 'Auto' }
                    }
                }
            }
            catch { $mode = 'Auto' }

            # Generate PowerShell script
            $script = Export-PowerShellScript -Method $selectedMethod -Path $selectedPath -Parameters $requestParams -Token $token -Region $script:Region -Mode $mode

            # Show in dialog with copy/save options
            $dialog = New-Object Microsoft.Win32.SaveFileDialog
            $dialog.Filter = "PowerShell Scripts (*.ps1)|*.ps1|All Files (*.*)|*.*"
            $dialog.Title = "Save PowerShell Script"
            $dialog.FileName = "GenesysAPI_$($selectedMethod)_Script.ps1"

            if ($dialog.ShowDialog() -eq $true) {
                $script | Out-File -FilePath $dialog.FileName -Encoding utf8
                $statusText.Text = "PowerShell script exported to $($dialog.FileName)"
                Add-LogEntry "PowerShell script exported to $($dialog.FileName)"

                # Copy to clipboard as well
                [System.Windows.Clipboard]::SetText($script)
                [System.Windows.MessageBox]::Show(
                    "PowerShell script saved to $($dialog.FileName) and copied to clipboard.",
                    "Script Exported",
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Information
                )
            }
        })
}

# Export cURL Command button
if ($exportCurlButton) {
    $exportCurlButton.Add_Click({
            $selectedPath = $pathCombo.SelectedItem
            $selectedMethod = $methodCombo.SelectedItem
            $token = Get-ExplorerAccessToken

            if (-not $selectedPath -or -not $selectedMethod) {
                $statusText.Text = "Select a path and method first."
                return
            }

            # Collect current parameters
            $requestParams = @{}
            $pathObject = Get-PathObject -ApiPaths $ApiPaths -Path $selectedPath
            $methodObject = Get-MethodObject -PathObject $pathObject -MethodName $selectedMethod
            if ($methodObject -and $methodObject.parameters) {
                foreach ($param in $methodObject.parameters) {
                    $xinput = $paramInputs[$param.name]
                    if ($xinput) {
                        $value = Get-ParameterControlValue -Control $xinput
                        if (-not [string]::IsNullOrWhiteSpace($value)) {
                            $requestParams[$param.name] = $value
                        }
                    }
                }
            }

            # Generate cURL command
            $curlCommand = Export-CurlCommand -Method $selectedMethod -Path $selectedPath -Parameters $requestParams -Token $token -Region $script:Region

            # Copy to clipboard and show confirmation
            [System.Windows.Clipboard]::SetText($curlCommand)
            [System.Windows.MessageBox]::Show(
                "cURL command copied to clipboard:`r`n`r`n$curlCommand",
                "cURL Exported",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information
            )
            $statusText.Text = "cURL command copied to clipboard."
            Add-LogEntry "cURL command generated and copied to clipboard"
        })
}

# Templates list selection changed
if ($templatesList) {
    $templatesList.ItemsSource = $script:Templates
    if (-not $script:TemplateSortState) { $script:TemplateSortState = @{} }
    Enable-GridViewColumnSorting -ListView $templatesList -State $script:TemplateSortState

    # Load templates from disk into the collection
    if ($TemplatesData) {
        $defaultLastModified = $null
        try {
            if ($TemplatesFilePath -and (Test-Path -LiteralPath $TemplatesFilePath)) {
                $defaultLastModified = (Get-Item -LiteralPath $TemplatesFilePath).LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
            }
        }
        catch { }

        $normalizedTemplates = Normalize-Templates -Templates $TemplatesData -DefaultLastModified $defaultLastModified
        foreach ($template in $normalizedTemplates) {
            $script:Templates.Add($template)
        }

        # Persist normalized templates back to disk (removes blocked methods + adds LastModified)
        try {
            if ($TemplatesFilePath -and (Test-Path -LiteralPath $TemplatesFilePath)) {
                Save-TemplatesToDisk -Path $TemplatesFilePath -Templates $script:Templates
            }
        }
        catch { }
    }

    $templatesList.Add_SelectionChanged({
            if ($templatesList.SelectedItem) {
                $loadTemplateButton.IsEnabled = $true
                $deleteTemplateButton.IsEnabled = $true
            }
            else {
                $loadTemplateButton.IsEnabled = $false
                $deleteTemplateButton.IsEnabled = $false
            }
        })
}

# Save Template button
if ($saveTemplateButton) {
    $saveTemplateButton.Add_Click({
            $selectedPath = $pathCombo.SelectedItem
            $selectedMethod = $methodCombo.SelectedItem

            if (-not $selectedPath -or -not $selectedMethod) {
                [System.Windows.MessageBox]::Show(
                    "Please select a path and method before saving a template.",
                    "Missing Information",
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Warning
                )
                return
            }

            if (-not (Test-TemplateMethodAllowed -Method $selectedMethod)) {
                [System.Windows.MessageBox]::Show(
                    "Templates for HTTP methods PATCH and DELETE are disabled.",
                    "Template Not Allowed",
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Information
                )
                return
            }

            # Prompt for template name
            Add-Type -AssemblyName Microsoft.VisualBasic
            $templateName = [Microsoft.VisualBasic.Interaction]::InputBox(
                "Enter a name for this template:",
                "Save Template",
                "$selectedMethod $selectedPath"
            )

            if ([string]::IsNullOrWhiteSpace($templateName)) {
                return
            }

            # Collect current parameters
            $requestParams = @{}
            $pathObject = Get-PathObject -ApiPaths $ApiPaths -Path $selectedPath
            $methodObject = Get-MethodObject -PathObject $pathObject -MethodName $selectedMethod
            if ($methodObject -and $methodObject.parameters) {
                foreach ($param in $methodObject.parameters) {
                    $einput = $paramInputs[$param.name]
                    if ($einput) {
                        $value = Get-ParameterControlValue -Control $einput
                        if (-not [string]::IsNullOrWhiteSpace($value)) {
                            $requestParams[$param.name] = $value
                        }
                    }
                }
            }

            # Create template object
            $template = [PSCustomObject]@{
                Name         = $templateName
                Method       = $selectedMethod
                Path         = $selectedPath
                Group        = $groupCombo.SelectedItem
                Parameters   = $requestParams
                Created      = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                LastModified = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            }

            # Add to collection and save
            $script:Templates.Add($template)
            Save-TemplatesToDisk -Path $script:TemplatesFilePath -Templates $script:Templates

            Add-LogEntry "Template saved: $templateName"
            $statusText.Text = "Template '$templateName' saved successfully."
        })
}

# Load Template button
if ($loadTemplateButton) {
    $loadTemplateButton.Add_Click({
            $selectedTemplate = $templatesList.SelectedItem
            if (-not $selectedTemplate) {
                return
            }

            # Set the group, path, and method
            Select-ComboBoxItemByText -ComboBox $groupCombo -Text $selectedTemplate.Group
            Select-ComboBoxItemByText -ComboBox $pathCombo -Text $selectedTemplate.Path
            Select-ComboBoxItemByText -ComboBox $methodCombo -Text $selectedTemplate.Method

            # Restore parameters using Dispatcher
            if ($selectedTemplate.Parameters) {
                $Window.Dispatcher.Invoke([Action] {
                        foreach ($paramName in $selectedTemplate.Parameters.PSObject.Properties.Name) {
                            if ($paramInputs.ContainsKey($paramName)) {
                                Set-ParameterControlValue -Control $paramInputs[$paramName] -Value $selectedTemplate.Parameters.$paramName
                            }
                        }
                    }, [System.Windows.Threading.DispatcherPriority]::Background)
            }

            Add-LogEntry "Template loaded: $($selectedTemplate.Name)"
            $statusText.Text = "Template loaded: $($selectedTemplate.Name)"
        })
}

# Delete Template button
if ($deleteTemplateButton) {
    $deleteTemplateButton.Add_Click({
            $selectedTemplate = $templatesList.SelectedItem
            if (-not $selectedTemplate) {
                return
            }

            $result = [System.Windows.MessageBox]::Show(
                "Are you sure you want to delete the template '$($selectedTemplate.Name)'?",
                "Delete Template",
                [System.Windows.MessageBoxButton]::YesNo,
                [System.Windows.MessageBoxImage]::Question
            )

            if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
                $script:Templates.Remove($selectedTemplate)
                Save-TemplatesToDisk -Path $script:TemplatesFilePath -Templates $script:Templates
                Add-LogEntry "Template deleted: $($selectedTemplate.Name)"
                $statusText.Text = "Template deleted."
            }
        })
}

# Export Templates button
if ($exportTemplatesButton) {
    $exportTemplatesButton.Add_Click({
            if ($script:Templates.Count -eq 0) {
                [System.Windows.MessageBox]::Show(
                    "No templates to export.",
                    "Export Templates",
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Information
                )
                return
            }

            $dialog = New-Object Microsoft.Win32.SaveFileDialog
            $dialog.Filter = "JSON Files (*.json)|*.json|All Files (*.*)|*.*"
            $dialog.Title = "Export Templates"
            $dialog.FileName = "GenesysAPIExplorerTemplates.json"

            if ($dialog.ShowDialog() -eq $true) {
                Save-TemplatesToDisk -Path $dialog.FileName -Templates $script:Templates
                $statusText.Text = "Templates exported to $($dialog.FileName)"
                Add-LogEntry "Templates exported to $($dialog.FileName)"
                [System.Windows.MessageBox]::Show(
                    "Templates exported successfully to $($dialog.FileName)",
                    "Export Complete",
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Information
                )
            }
        })
}

# Import Templates button
if ($importTemplatesButton) {
    $importTemplatesButton.Add_Click({
            $dialog = New-Object Microsoft.Win32.OpenFileDialog
            $dialog.Filter = "JSON Files (*.json)|*.json|All Files (*.*)|*.*"
            $dialog.Title = "Import Templates"

            if ($dialog.ShowDialog() -eq $true) {
                $importedRaw = Load-TemplatesFromDisk -Path $dialog.FileName
                $importedTemplates = if ($importedRaw) { Normalize-Templates -Templates $importedRaw -DefaultLastModified (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') } else { @() }
                if ($importedTemplates -and $importedTemplates.Count -gt 0) {
                    $importCount = 0
                    foreach ($template in $importedTemplates) {
                        # Check if template already exists by name
                        $exists = $false
                        foreach ($existingTemplate in $script:Templates) {
                            if ($existingTemplate.Name -eq $template.Name) {
                                $exists = $true
                                break
                            }
                        }

                        if (-not $exists) {
                            $script:Templates.Add($template)
                            $importCount++
                        }
                    }

                    if ($importCount -gt 0) {
                        Save-TemplatesToDisk -Path $script:TemplatesFilePath -Templates $script:Templates
                        $statusText.Text = "Imported $importCount template(s)."
                        Add-LogEntry "Imported $importCount template(s) from $($dialog.FileName)"
                        [System.Windows.MessageBox]::Show(
                            "Successfully imported $importCount template(s). Duplicates were skipped.",
                            "Import Complete",
                            [System.Windows.MessageBoxButton]::OK,
                            [System.Windows.MessageBoxImage]::Information
                        )
                    }
                    else {
                        [System.Windows.MessageBox]::Show(
                            "No new templates imported. All templates already exist.",
                            "Import Complete",
                            [System.Windows.MessageBoxButton]::OK,
                            [System.Windows.MessageBoxImage]::Information
                        )
                    }
                }
                else {
                    [System.Windows.MessageBox]::Show(
                        "No templates found in the selected file.",
                        "Import Failed",
                        [System.Windows.MessageBoxButton]::OK,
                        [System.Windows.MessageBoxImage]::Warning
                    )
                }
            }
        })
}

$btnSubmit.Add_Click({
        $selectedPath = $pathCombo.SelectedItem
        $selectedMethod = $methodCombo.SelectedItem
        $now = Get-Date
        Write-UxEvent -Name "cta_click" -Properties @{ control = "submit"; path = $selectedPath; method = $selectedMethod }
        if (Test-RageClick -Now $now) {
            Write-UxEvent -Name "rage_click" -Properties @{ control = "submit"; path = $selectedPath; method = $selectedMethod }
        }

        if (-not $selectedPath -or -not $selectedMethod) {
            $statusText.Text = "Select a path and method first."
            Add-LogEntry "Submit blocked: method or path missing."
            Write-UxEvent -Name "dead_click" -Properties @{ control = "submit"; reason = "missing-path-or-method" }
            return
        }

        $pathObject = Get-PathObject -ApiPaths $ApiPaths -Path $selectedPath
        $methodObject = Get-MethodObject -PathObject $pathObject -MethodName $selectedMethod
        if (-not $methodObject) {
            Add-LogEntry "Submit blocked: method metadata missing."
            $statusText.Text = "Method metadata missing."
            return
        }

        $params = $methodObject.parameters

        # Validate required parameters and JSON body parameters
        $validationErrors = @()
        foreach ($param in $params) {
            $ainput = $paramInputs[$param.name]
            if ($ainput) {
                $value = Get-ParameterControlValue -Control $ainput
                if ($value -and $value.GetType().Name -eq "String") {
                    $value = $value.Trim()
                }

                # Check required fields
                if ($param.required -and -not $value) {
                    $validationErrors += "$($param.name) is required"
                }

                # Validate JSON format for body parameters
                if ($param.in -eq "body" -and $value) {
                    if (-not (Test-JsonString -JsonString $value)) {
                        $validationErrors += "$($param.name) contains invalid JSON"
                    }
                }

                # Validate type and constraints for non-body parameters
                if ($param.in -ne "body" -and $value -and $ainput.Tag -is [hashtable]) {
                    $validationResult = Test-ParameterValue -Value $value -ValidationMetadata $ainput.Tag
                    if (-not $validationResult.Valid) {
                        foreach ($validationError in $validationResult.Errors) {
                            $validationErrors += "$($param.name): $validationError"
                        }
                    }
                }

                # Validate array parameters
                if ($param.type -eq "array" -and $value) {
                    $testResult = Test-ArrayValue -Value $value -ItemType $param.items
                    if (-not $testResult.IsValid) {
                        $validationErrors += "$($param.name): " + $testResult.ErrorMessage
                    }
                }

                # Validate numeric parameters
                if ($param.type -in @("integer", "number") -and $value) {
                    $testResult = Test-NumericValue -Value $value -Type $param.type -Minimum $param.minimum -Maximum $param.maximum
                    if (-not $testResult.IsValid) {
                        $validationErrors += "$($param.name): " + $testResult.ErrorMessage
                    }
                }

                # Validate string format/pattern parameters
                if ($param.type -eq "string" -and $value -and ($param.format -or $param.pattern)) {
                    $testResult = Test-StringFormat -Value $value -Format $param.format -Pattern $param.pattern
                    if (-not $testResult.IsValid) {
                        $validationErrors += "$($param.name): " + $testResult.ErrorMessage
                    }
                }
            }
            elseif ($param.required) {
                $validationErrors += "$($param.name) is required but control not found"
            }
        }

        if ($validationErrors.Count -gt 0) {
            $errorMessage = "Validation errors:`n" + ($validationErrors -join "`n")
            $statusText.Text = "Validation failed: " + ($validationErrors -join ", ")
            Add-LogEntry "Submit blocked: $errorMessage"
            Write-UxEvent -Name "validation_error" -Properties @{ errors = $validationErrors; path = $selectedPath; method = $selectedMethod }
            [System.Windows.MessageBox]::Show($errorMessage, "Validation Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
            return
        }

        $queryParams = @{}
        $pathParams = @{}
        $bodyParams = @{}
        $bodyAliasValue = $null
        $headers = @{
            "Content-Type" = "application/json"
        }

        $token = Get-ExplorerAccessToken
        if ($token) {
            $headers["Authorization"] = "Bearer $token"
        }
        else {
            Add-LogEntry "Warning: Authorization token is empty."
        }

        foreach ($param in $params) {
            $rinput = $paramInputs[$param.name]
            if (-not $rinput) { continue }

            $value = Get-ParameterControlValue -Control $rinput
            if ($value -and $value.GetType().Name -eq "String" -and $param.in -ne "body") {
                $value = $value.Trim()
            }
            if (-not $value) { continue }

            switch ($param.in) {
                "query" { $queryParams[$param.name] = $value }
                "path" { $pathParams[$param.name] = $value }
                "body" {
                    $bodyParams[$param.name] = $value
                    if (-not $bodyAliasValue) {
                        $bodyAliasValue = $value
                    }
                }
                "header" { $headers[$param.name] = $value }
            }
        }

        $baseUrl = $ApiBaseUrl
        $pathWithReplacements = $selectedPath
        foreach ($key in $pathParams.Keys) {
            $escaped = [uri]::EscapeDataString($pathParams[$key])
            $pathWithReplacements = $pathWithReplacements -replace "\{$key\}", $escaped
        }

        $queryString = if ($queryParams.Count -gt 0) {
            "?" + ($queryParams.GetEnumerator() | ForEach-Object {
                    [uri]::EscapeDataString($_.Key) + "=" + [uri]::EscapeDataString($_.Value)
                } -join "&")
        }
        else {
            ""
        }

        $fullUrl = $baseUrl + $pathWithReplacements + $queryString
        $body = $null
        if ($bodyAliasValue) {
            $body = if ($bodyAliasValue -is [string]) { $bodyAliasValue } else { $bodyAliasValue | ConvertTo-Json -Depth 10 }
        }
        elseif ($bodyParams.Count -gt 0) {
            $body = $bodyParams | ConvertTo-Json -Depth 10
        }

        # Store parameters for history (captured before background launch)
        $requestParams = @{}
        foreach ($param in $params) {
            $rinput = $paramInputs[$param.name]
            if ($rinput) {
                $value = Get-ParameterControlValue -Control $rinput
                if ($value -and $value.GetType().Name -eq "String") {
                    $value = $value.Trim()
                }
                if ($value) {
                    $requestParams[$param.name] = $value
                }
            }
        }

        Add-LogEntry "Request $($selectedMethod.ToUpper()) $fullUrl"

        # Track request start time
        $requestStartTime = Get-Date
        Write-UxEvent -Name "api_call_start" -Properties @{
            method    = $selectedMethod.ToUpper()
            path      = $selectedPath
            url       = $fullUrl
            timestamp = $requestStartTime.ToString('o')
        }
        $hudRoute = if ($mainTabControl -and $mainTabControl.SelectedItem) { $mainTabControl.SelectedItem.Header } else { "unknown" }
        Update-UxDebugHud -Route $hudRoute -Status "Sending" -LastEvent "api_call_start"

        # Capture all required state before launching background task (DEF-001)
        $capturedMethod         = $selectedMethod.ToUpper()
        $capturedUrl            = $fullUrl
        $capturedHeaders        = $headers
        $capturedBody           = $body
        $capturedSelectedPath   = $selectedPath
        $capturedSelectedMethod = $selectedMethod
        $capturedGroupItem      = $groupCombo.SelectedItem
        $capturedRequestParams  = $requestParams
        $capturedStartTime      = $requestStartTime
        $capturedHudRoute       = $hudRoute
        $capturedModuleManifest = $script:OpsInsightsManifest

        Invoke-UIBackgroundTask `
            -OnStart {
                $statusText.Text = "Sending request..."
                $btnSubmit.IsEnabled = $false
                if ($progressIndicator) { $progressIndicator.Visibility = "Visible" }
            } `
            -WorkParams @{
                Method         = $capturedMethod
                Uri            = $capturedUrl
                Headers        = $capturedHeaders
                Body           = $capturedBody
                ModuleManifest = $capturedModuleManifest
            } `
            -WorkScript {
                Import-Module -Name $ModuleManifest -Force -ErrorAction Stop
                Invoke-GCRequest -Method $Method -Uri $Uri -Headers $Headers -Body $Body -AsResponse
            } `
            -OnSuccess {
                param($output)
                $response = $output | Select-Object -Last 1
                $rawContent      = $response.Content
                $formattedContent = $rawContent
                $json = $null
                try {
                    $json = $rawContent | ConvertFrom-Json -ErrorAction Stop
                    $formattedContent = $json | ConvertTo-Json -Depth 10
                }
                catch { }

                $script:LastResponseText  = $formattedContent
                $script:LastResponseRaw   = $rawContent
                $script:LastResponseFile  = ""
                $script:ResponseViewMode  = "Formatted"
                $responseBox.Text = "Status $($response.StatusCode):`r`n$formattedContent"
                $btnSave.IsEnabled = $true
                $btnSubmit.IsEnabled = $true
                if ($toggleResponseViewButton) { $toggleResponseViewButton.IsEnabled = $true }
                if ($progressIndicator) { $progressIndicator.Visibility = "Collapsed" }

                $requestDuration = ((Get-Date) - $capturedStartTime).TotalMilliseconds

                # Detect pagination in response
                $hasPagination  = $false
                $paginationInfo = ""
                if ($json) {
                    if ($json.cursor) {
                        $hasPagination  = $true
                        $paginationInfo = " (Cursor-based pagination detected)"
                    }
                    elseif ($json.nextUri) {
                        $hasPagination  = $true
                        $paginationInfo = " (Next page available via nextUri)"
                    }
                    elseif ($json.pageCount -and $json.pageNumber) {
                        $hasPagination  = $true
                        $paginationInfo = " (Page $($json.pageNumber) of $($json.pageCount))"
                    }
                }

                $statusText.Text = "Last call succeeded ($($response.StatusCode)) - {0:N0} ms$paginationInfo" -f $requestDuration
                Add-LogEntry ("Response: {0} returned {1} chars in {2:N0} ms.$paginationInfo" -f $response.StatusCode, $formattedContent.Length, $requestDuration)
                Write-UxEvent -Name "api_call" -Properties @{
                    method     = $capturedSelectedMethod.ToUpper()
                    path       = $capturedSelectedPath
                    statusCode = [int]$response.StatusCode
                    durationMs = [math]::Round($requestDuration, 0)
                    pagination = $hasPagination
                    timestamp  = (Get-Date).ToString('o')
                }
                Update-UxDebugHud -Route $capturedHudRoute -Status ("OK " + $response.StatusCode) -LastEvent "api_success"

                if ($hasPagination) {
                    Add-LogEntry "Note: Response contains pagination. To fetch all pages, use Get-PaginatedResults function or the Jobs results fetcher for job endpoints."
                }

                # Add to request history
                $historyEntry = [PSCustomObject]@{
                    Timestamp  = $capturedStartTime.ToString("yyyy-MM-dd HH:mm:ss")
                    Method     = $capturedSelectedMethod.ToUpper()
                    Path       = $capturedSelectedPath
                    Group      = $capturedGroupItem
                    Status     = $response.StatusCode
                    Duration   = "{0:N0} ms" -f $requestDuration
                    Parameters = $capturedRequestParams
                }
                $script:RequestHistory.Insert(0, $historyEntry)
                while ($script:RequestHistory.Count -gt 50) { $script:RequestHistory.RemoveAt(50) }

                if ($capturedSelectedMethod -eq "post" -and $capturedSelectedPath -match "/jobs/?$" -and $json) {
                    $jobId = if ($json.id) { $json.id } elseif ($json.jobId) { $json.jobId } else { $null }
                    if ($jobId) {
                        Start-JobPolling -Path $capturedSelectedPath -JobId $jobId -Headers $capturedHeaders
                    }
                }
            } `
            -OnError {
                param($errRecord)
                $ex = if ($errRecord -is [System.Management.Automation.ErrorRecord]) { $errRecord.Exception } else { $null }
                $errorMessage = if ($ex) { $ex.Message } else { [string]$errRecord }
                $statusCode       = ""
                $errorResponseBody = ""

                if ($ex -and $ex.Response) {
                    $resp = $ex.Response
                    if ($resp -is [System.Net.HttpWebResponse]) {
                        $statusCode = "Status $($resp.StatusCode) ($([int]$resp.StatusCode)) - "
                        try {
                            $responseStream = $resp.GetResponseStream()
                            $reader = New-Object System.IO.StreamReader($responseStream)
                            $errorResponseBody = $reader.ReadToEnd()
                            $reader.Close()
                            $responseStream.Close()
                        }
                        catch { }
                    }
                }

                $displayMessage = "Error:`r`n$statusCode$errorMessage"
                if ($errorResponseBody) {
                    try {
                        $errorJson = $errorResponseBody | ConvertFrom-Json -ErrorAction Stop
                        $displayMessage += "`r`n`r`nResponse Body:`r`n$($errorJson | ConvertTo-Json -Depth 5)"
                    }
                    catch {
                        $displayMessage += "`r`n`r`nResponse Body:`r`n$errorResponseBody"
                    }
                }

                $responseBox.Text       = $displayMessage
                $btnSave.IsEnabled      = $false
                $btnSubmit.IsEnabled    = $true
                if ($toggleResponseViewButton) { $toggleResponseViewButton.IsEnabled = $false }
                if ($progressIndicator) { $progressIndicator.Visibility = "Collapsed" }
                $statusText.Text        = "Request failed - see log."
                $script:LastResponseRaw  = ""
                $script:LastResponseFile = ""

                $requestDuration = ((Get-Date) - $capturedStartTime).TotalMilliseconds
                $statusForHistory = if ($ex -and $ex.Response -and $ex.Response.StatusCode) {
                    [int]$ex.Response.StatusCode
                }
                else { "Error" }
                $historyEntry = [PSCustomObject]@{
                    Timestamp  = $capturedStartTime.ToString("yyyy-MM-dd HH:mm:ss")
                    Method     = $capturedSelectedMethod.ToUpper()
                    Path       = $capturedSelectedPath
                    Group      = $capturedGroupItem
                    Status     = $statusForHistory
                    Duration   = "{0:N0} ms" -f $requestDuration
                    Parameters = $capturedRequestParams
                }
                $script:RequestHistory.Insert(0, $historyEntry)
                while ($script:RequestHistory.Count -gt 50) { $script:RequestHistory.RemoveAt(50) }

                Add-LogEntry "Response error: $statusCode$errorMessage"
                if ($errorResponseBody) {
                    $logBody = if ($errorResponseBody.Length -gt $script:LogMaxMessageLength) {
                        $errorResponseBody.Substring(0, $script:LogMaxMessageLength) + "... (truncated)"
                    }
                    else { $errorResponseBody }
                    Add-LogEntry "Error response body: $logBody"
                }
                Write-UxEvent -Name "api_error" -Properties @{
                    method     = $capturedSelectedMethod.ToUpper()
                    path       = $capturedSelectedPath
                    durationMs = [math]::Round(((Get-Date) - $capturedStartTime).TotalMilliseconds, 0)
                    message    = $errorMessage
                    status     = $statusCode
                }
                Update-UxDebugHud -Route $capturedHudRoute -Status "Error" -LastEvent "api_error"
            }
    })

$btnSave.Add_Click({
        if (-not $script:LastResponseText) {
            return
        }

        $dialog = New-Object Microsoft.Win32.SaveFileDialog
        $dialog.Filter = "JSON Files (*.json)|*.json|All Files (*.*)|*.*"
        $dialog.Title = "Save API Response"
        $dialog.FileName = "GenesysResponse.json"

        if ($dialog.ShowDialog() -eq $true) {
            $script:LastResponseText | Out-File -FilePath $dialog.FileName -Encoding utf8
            $statusText.Text = "Saved response to $($dialog.FileName)"
            Add-LogEntry "Saved response to $($dialog.FileName)"
        }
    })

if ($exportLogButton) {
    $exportLogButton.Add_Click({
            if ([string]::IsNullOrWhiteSpace($logBox.Text)) {
                $statusText.Text = "No log entries to export."
                return
            }

            $timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
            $dialog = New-Object Microsoft.Win32.SaveFileDialog
            $dialog.Filter = "Text Files (*.txt)|*.txt|Log Files (*.log)|*.log|All Files (*.*)|*.*"
            $dialog.Title = "Export Transparency Log"
            $dialog.FileName = "GenesysAPIExplorer_Log_$timestamp.txt"

            if ($dialog.ShowDialog() -eq $true) {
                $logBox.Text | Out-File -FilePath $dialog.FileName -Encoding utf8
                $statusText.Text = "Log exported to $($dialog.FileName)"
                Add-LogEntry "Transparency log exported to $($dialog.FileName)"
            }
        })
}

if ($clearLogButton) {
    $clearLogButton.Add_Click({
            $result = [System.Windows.MessageBox]::Show(
                "Are you sure you want to clear all log entries? This action cannot be undone.",
                "Clear Log",
                [System.Windows.MessageBoxButton]::YesNo,
                [System.Windows.MessageBoxImage]::Question
            )

            if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
                $logBox.Clear()
                $statusText.Text = "Log cleared."
                Add-LogEntry "Log was cleared by user."
            }
        })
}

#endregion Feature tabs (Conversation, Audit, Live Sub, Ops Dash, etc.)

Add-LogEntry "Loaded $($GroupMap.Keys.Count) groups from the API catalog."
$Window.ShowDialog() | Out-Null
