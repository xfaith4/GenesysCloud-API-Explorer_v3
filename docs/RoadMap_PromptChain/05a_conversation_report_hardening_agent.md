# Conversation Report Hardening Spec

Generated: 2026-03-11 | Codebase: PowerShell 7+ / WPF (PowerShell-hosted)

---

## Assumptions and Placeholder Names

The following names are taken directly from the live codebase and used consistently throughout this document.

**WPF Control Names (from `MainWindow.xaml` / `UI.Run.ps1`):**

| Placeholder | Actual control name | Purpose |
| --- | --- | --- |
| `[INPUT_CONVID]` | `conversationReportIdInput` | TextBox: conversation ID entry |
| `[BTN_RUN]` | `runConversationReportButton` | Button: triggers report |
| `[STATUS_TEXT]` | `conversationReportStatus` | TextBlock: status line |
| `[PROGRESS_BAR]` | `conversationReportProgressBar` | ProgressBar: 0–100 |
| `[PROGRESS_TEXT]` | `conversationReportProgressText` | TextBlock: step label |
| `[ENDPOINT_LOG]` | `conversationReportEndpointLog` | TextBox: per-endpoint call log |
| `[REPORT_TEXT]` | `conversationReportText` | TextBox: formatted report output |
| `[BTN_INSPECT]` | `inspectConversationReportButton` | Button: open timeline window |
| `[BTN_EXPORT_JSON]` | `exportConversationReportJsonButton` | Button: export as JSON |
| `[BTN_EXPORT_TEXT]` | `exportConversationReportTextButton` | Button: export as text |
| `[WINDOW]` | `$Window` | Root WPF Window reference |

**PowerShell Functions (from live codebase):**

| Name | Location | Role |
| --- | --- | --- |
| `Get-ConversationReport` | `UI.PreMain.ps1:3394` | Orchestrator: calls 6 endpoints, collects results |
| `Format-ConversationReportText` | `UI.PreMain.ps1:4934` | Renderer: produces formatted text from report object |
| `Show-ConversationTimelineReport` | `UI.PreMain.ps1:3083` | Opens timeline inspection WPF window |
| `Get-GCConversationTimeline` | `src/.../Public/Get-GCConversationTimeline.ps1` | Alternative full-pipeline fetcher (normalizes to TimelineEvents) |
| `Get-GCConversationDetails` | `src/.../Public/Get-GCConversationDetails.ps1` | Analytics details query |
| `Invoke-GCRequest` | `src/.../Public/Invoke-GCRequest.ps1` | Canonical REST transport |
| `Write-UxEvent` | `apps/OpsConsole/Resources/UxTelemetry.ps1:115` | NDJSON telemetry emitter |
| `Connect-GCCloud` | `src/.../Public/Connect-GCCloud.ps1` | Sets `$script:GCContext` |

**Service names used in examples:**

- `ConvoApi` = Genesys Cloud REST API (`https://api.{region}.pure.cloud`)
- `AuthStore` = `$script:GCContext` (module-level auth context)

---

## Section 1 — Current Workflow Decomposition

### Stated Assumptions

- Conversation ID is a GUID-like string from Genesys Cloud (e.g., `a3bd308f-...`).
- Bearer token is stored in `$script:AccessToken` (UI scope); module context `$script:GCContext` may or may not be populated at the time the button is clicked.
- The application runs on the WPF dispatcher thread; `[System.Windows.Forms.Application]::DoEvents()` is called inside the progress callback as a UI-unblocking hack (line 1982) — this is a WinForms call inside a WPF application and is unreliable.
- All 6 API calls are sequential; there is no parallelism.

### Step-by-Step Sequence

```
Operator                    UI.Run.ps1              Get-ConversationReport    ConvoApi
    |                           |                           |                     |
    |-- enter convId ---------->|                           |                     |
    |-- click [BTN_RUN] ------->|                           |                     |
    |                           |-- validate input          |                     |
    |                           |-- validate token          |                     |
    |                           |-- reset progress UI       |                     |
    |                           |-- call (sync) ----------->|                     |
    |                           |                           |-- GET /conversations/{id} -->|
    |  (UI frozen via DoEvents) |<- progress callback ------|<-- 200 OK -----------|
    |                           |                           |-- GET /analytics/.../{id}/details -->|
    |  (UI frozen via DoEvents) |<- progress callback ------|<-- 200 OK -----------|
    |                           |                           |-- GET /speechandtextanalytics/... -->|
    |                           |<- progress callback ------|<-- 200 or 404 ------| (optional)
    |                           |                           |-- GET /.../recordingmetadata -->|
    |                           |<- progress callback ------|<-- 200 or 403 ------| (optional)
    |                           |                           |-- GET /.../sentiments -->|
    |                           |<- progress callback ------|<-- 200 or 404 ------| (optional)
    |                           |                           |-- GET /telephony/sipmessages/... -->|
    |                           |<- progress callback ------|<-- 200 or 404 ------| (optional)
    |                           |                           |                     |
    |                           |<-- PSCustomObject (report)|                     |
    |                           |-- Format-ConversationReportText                 |
    |                           |   (7 inner analysis calls, all sync)            |
    |                           |-- set [REPORT_TEXT].Text                        |
    |                           |-- enable [BTN_INSPECT], [BTN_EXPORT_JSON], ...  |
    |<-- report displayed ------|                           |                     |
```

### Steps and Details

| Step | Responsibility | Inputs | Outputs | Module | Expected payload |
| --- | --- | --- | --- | --- | --- |
| 1 | Input validation | `[INPUT_CONVID].Text` | Blocked or continue | `UI.Run.ps1:1916` | — |
| 2 | Token validation | `$script:AccessToken` | Blocked or continue | `UI.Run.ps1:1924` | — |
| 3 | Progress UI reset | — | `[PROGRESS_BAR]=0`, `[STATUS_TEXT]="Fetching..."` | `UI.Run.ps1:1938` | — |
| 4 | Core conversation fetch | convId, headers, BaseUrl | ConversationDetails object | `GET /conversations/{id}` | 5–50 KB |
| 5 | Analytics details fetch | convId | AnalyticsDetails object | `GET /analytics/.../details` | 10–200 KB |
| 6 | Speech/text analytics | convId | SpeechTextAnalytics or null | `GET /speechandtextanalytics/...` | 5–100 KB |
| 7 | Recording metadata | convId | RecordingMetadata[] or null | `GET /.../recordingmetadata` | 1–20 KB |
| 8 | Sentiments | convId | Sentiments or null | `GET /.../sentiments` | 1–50 KB |
| 9 | SIP messages | convId | SipMessages or null | `GET /telephony/sipmessages/...` | 5–500 KB (raw SIP text) |
| 10 | Timeline merge | Report PSCustomObject | Sorted event list | `UI.PreMain.ps1:4972` | In-memory |
| 11 | Analysis generation | Report + events | DurationAnalysis, ParticipantStats, Summary, FlowPath, KeyInsights | `UI.PreMain.ps1:4979` | In-memory |
| 12 | Render to text | All analyses | Formatted string | `UI.PreMain.ps1:4934` | 10–200 KB string |
| 13 | Display | Formatted string | `[REPORT_TEXT].Text` set | `UI.Run.ps1:1990` | — |
| 14 | Export / Inspect | `$script:LastConversationReport` | File on disk / new WPF window | `UI.Run.ps1:2035` + export handlers | — |

---

## Section 2 — Failure Points

| # | Step | Failure mode | Root-cause examples | Detectability | Operator impact | Mitigation |
| --- | --- | --- | --- | --- | --- | --- |
| F1 | Auth | Token missing or empty | Operator skipped login; token not persisted across session | `$script:AccessToken` is null/empty | Report button blocked; message shown | Expiry guard (S1-002); prompt to re-login |
| F2 | Auth | Token expired mid-session | Token is 24+ hours old; operator left app open overnight | 401 from ConvoApi on first required call | Raw "401 Unauthorized" in status bar | Token expiry timestamp (S1-002); re-prompt login dialog |
| F3 | Auth | Token valid but wrong scope | Token lacks `analytics:readonly` or `conversation:readonly` scope | 403 Forbidden with `{ message, code: "forbidden" }` | Raw exception; no report | Detect 403 on required endpoints; show scope guidance message |
| F4 | Input | Conversation ID malformed | Operator pastes full URL instead of UUID; extra whitespace | Client-side: string length / format check | Silent pass-through: API returns 404 | Validate UUID format before calling API |
| F5 | Network | DNS failure at startup | Corporate proxy, split-tunnel VPN off | `WebException` with `NameResolutionFailure` | Raw exception; no report | Startup diagnostics check; retry with backoff |
| F6 | Network | Timeout on required endpoint | Genesys Cloud API latency spike; oversized analytics payload | `TimeoutException` (default 100s in `Invoke-GCRequest`) | UI frozen; then raw exception after 100s | Background thread; timeout visible in progress; retry once |
| F7 | Network | Rate limit (429) | Operator runs multiple reports quickly | `Retry-After` header; 429 status | Delayed or failed report | `Invoke-GCRequest` already handles 429; surface wait message in UI |
| F8 | API | Conversation ID not found | Typo; conversation from wrong org or region | 404 `{ message, code: "not.found" }` | Raw exception or empty report | Detect 404 on required endpoints; show "Conversation not found for ID {id}" |
| F9 | API | Analytics data not yet available | Conversation ended < 2 minutes ago; analytics pipeline lag | 404 or empty `participants[]` on analytics endpoint | Partial report; analytics section blank | Mark analytics section as "Pending — may not be available yet"; add timestamp check |
| F10 | Serialization | Malformed JSON from API | API returns truncated or binary response | `ConvertFrom-Json` throws | Report aborted | Wrap `ConvertFrom-Json` in try/catch; mark endpoint as failed; continue with others |
| F11 | UI thread | Dispatcher thread blocking | All 6 API calls + 7 analysis calls run synchronously | DoEvents() hack; WPF unresponsive; may show "Not Responding" | App appears frozen; operator may force-close | Move to `Start-ThreadJob`; use `Dispatcher.Invoke` for UI updates |
| F12 | State | Race condition on `$script:LastConversationReport` | Operator clicks Run twice quickly; second call overwrites first result mid-render | No guard; second result corrupts display | Garbled report; wrong export data | Disable `[BTN_RUN]` while job is running; re-enable on completion |
| F13 | File I/O | Export path not writable | Network drive disconnected; path contains illegal chars | `IOException` or `UnauthorizedAccessException` | Export silently fails or shows raw error | Wrap in try/catch; show specific error; offer alternate path |
| F14 | Partial data | Optional endpoint returns 404 | Recording not enabled for org; SIP not available | 404 on optional endpoint; caught silently | Report shows N/A sections; operator may not know why | Log which optional endpoints were skipped and why in `[ENDPOINT_LOG]` and export metadata |
| F15 | PII | Export includes ANI/DNIS/user names | Conversation contains customer phone numbers and agent names | Always present in export | Compliance risk if shared without redaction | Add `ContainsPii: true` flag to all exports; include redaction guidance |

### UI Behavior for Failure States

| State | `[STATUS_TEXT]` message | `[ENDPOINT_LOG]` content | What to log | What to export |
| --- | --- | --- | --- | --- |
| Missing token | "Please provide an OAuth token." | — | `WARN auth_missing correlationId={id}` | — |
| Expired token | "Session expired. Please log in again. [Correlation ID: {id}]" | — | `ERROR auth_expired correlationId={id}` | — |
| Conversation not found | "Conversation {id} not found. Verify the ID and region. [Correlation ID: {id}]" | `[HH:mm:ss] ✗ Conversation Details — 404 Not Found` | `ERROR api_404 endpoint=ConversationDetails correlationId={id}` | — |
| Partial data (optional miss) | "Report generated with {n} optional endpoint(s) unavailable. [Correlation ID: {id}]" | `[HH:mm:ss] [WARN] Speech & Text Analytics — Optional, not available` | `WARN partial_data endpoints=[...] correlationId={id}` | Export with `PartialData: true`; list skipped sections |
| Network timeout | "Network timeout on {endpoint}. Retrying… [Correlation ID: {id}]" | `[HH:mm:ss] ↻ Analytics Details — Retrying (attempt 2/3)…` | `WARN network_timeout attempt=2 correlationId={id}` | — if not yet complete |
| Complete with errors | "Report generated with {n} error(s). [Correlation ID: {id}]" | Per-endpoint tick/cross log | `WARN report_partial errors=[...] correlationId={id}` | Export includes `Errors[]` array |
| Success | "Report generated successfully. [Correlation ID: {id}]" | All ticks | `INFO conversation_report_complete durationMs=... correlationId={id}` | Full export |

---

## Section 3 — Data Dependencies / API Dependencies

```yaml
# ConversationReport API Dependencies Manifest
# Generated: 2026-03-11
# Placeholder: ConvoApi = https://api.{region}.pure.cloud

dependencies:

  - name: ConversationCore
    purpose: Primary conversation metadata — participants, segments, start/end time, ANI/DNIS
    required: true
    endpoint: GET /api/v2/conversations/{conversationId}
    auth_method: Bearer token (Authorization header)
    expected_request:
      method: GET
      headers:
        Authorization: "Bearer {token}"
        Content-Type: "application/json"
    expected_response_shape:
      conversationId: string
      startTime: string (ISO 8601)
      endTime: string (ISO 8601)
      participants:
        - participantId: string
          name: string
          purpose: string   # customer | agent | ivr | acd
          userId: string
          queueId: string
          ani: string
          dnis: string
          segments:
            - segmentType: string
              segmentStart: string
              segmentEnd: string
              direction: string
    validation_checks:
      - field: conversationId
        rule: must match input conversationId exactly
      - field: participants
        rule: array length >= 1
      - field: startTime
        rule: parseable as ISO 8601 datetime
    rate_limit: 300 requests/min per OAuth client
    timeout_recommendation: 30s
    retry_guidance: Retry on 429 (honor Retry-After), 500, 503 up to 3 attempts with exponential backoff (base 1s, max 16s)
    required_error_codes:
      - 401: token expired or invalid — re-prompt login
      - 403: insufficient scope — show scope guidance
      - 404: conversation not found — show operator message with ID
      - 429: rate limited — honor Retry-After header
      - 500: transient server error — retry with backoff

  - name: AnalyticsDetails
    purpose: Detailed analytics segments including media type, queue routing, disposition codes, MOS scores
    required: true
    endpoint: GET /api/v2/analytics/conversations/{conversationId}/details
    auth_method: Bearer token
    expected_response_shape:
      conversationId: string
      conversationStart: string
      conversationEnd: string
      originatingDirection: string
      participants:
        - participantId: string
          sessions:
            - sessionId: string
              mediaType: string
              direction: string
              segments:
                - segmentType: string
                  segmentStart: string
                  segmentEnd: string
                  queueId: string
                  userId: string
                  errorCode: string (nullable)
                  mos: number (nullable)
    validation_checks:
      - field: conversationId
        rule: must match input conversationId
      - field: participants
        rule: array may be empty if analytics lag; check conversationStart is non-null
    rate_limit: 300 requests/min
    timeout_recommendation: 30s
    retry_guidance: Same as ConversationCore; 404 may indicate analytics lag (< 2 min after conversation end)
    required_error_codes:
      - 401: token expired — re-prompt
      - 404: analytics not yet available — show "Analytics pending; conversation may have ended recently"
      - 429: rate limited

  - name: SpeechTextAnalytics
    purpose: Topics, sentiments, transcript availability flag
    required: false
    endpoint: GET /api/v2/speechandtextanalytics/conversations/{conversationId}
    auth_method: Bearer token
    expected_response_shape:
      conversation:
        conversationId: string
        startTime: string
        topics:
          - name: string
            type: string
            sentimentScore: number
            dialect: string
        participants:
          - participantId: string
            role: string
    validation_checks:
      - rule: if HTTP 404 or 403 — mark as unavailable; not an error
    timeout_recommendation: 20s
    retry_guidance: Single retry on 503; do not retry 404/403
    required_error_codes:
      - 403: speech analytics not enabled for org — mark section N/A
      - 404: no speech analytics for this conversation — mark section N/A

  - name: RecordingMetadata
    purpose: Recording IDs, durations, archive/delete dates, media URIs
    required: false
    endpoint: GET /api/v2/conversations/{conversationId}/recordingmetadata
    auth_method: Bearer token
    expected_response_shape:
      - id: string
        startTime: string
        endTime: string
        durationMs: number
        participantId: string
        agentId: string
        archiveDate: string (nullable)
        deleteDate: string (nullable)
        mediaUris: object (nullable)
    validation_checks:
      - rule: array may be empty (no recordings); not an error
    timeout_recommendation: 20s
    retry_guidance: Single retry on 503
    required_error_codes:
      - 403: recording access restricted — mark section N/A

  - name: Sentiments
    purpose: Per-participant sentiment timeline (score + label per utterance)
    required: false
    endpoint: GET /api/v2/speechandtextanalytics/conversations/{conversationId}/summaries
    auth_method: Bearer token
    expected_response_shape:
      entities:
        - participantId: string
          sentimentScore: number
          label: string   # positive | neutral | negative
    note: Path was /sentiments in older code; corrected to /summaries per template triage
    timeout_recommendation: 20s
    required_error_codes:
      - 404: no sentiment data — mark section N/A

  - name: SipMessages
    purpose: Raw SIP signaling trace for telephony debugging
    required: false
    endpoint: GET /api/v2/telephony/sipmessages/conversations/{conversationId}
    auth_method: Bearer token
    expected_response_shape:
      message: string | string[]  # raw SIP text blob(s), one per message
    note: Response is raw text blobs, not JSON objects; parser in Get-GCConversationTimeline handles epoch timestamps and SIP start-lines
    timeout_recommendation: 30s
    required_error_codes:
      - 403: telephony SIP access restricted — mark section N/A
      - 404: no SIP data — mark section N/A
```

---

## Section 4 — Recommended Modular Boundaries

```yaml
# Module boundary definitions
# All modules are PowerShell dot-sourced .ps1 files

modules:

  - name: ConversationReportService
    location: apps/OpsConsole/Resources/Services/ConversationReportService.ps1
    responsibilities:
      - Orchestrate all 6 API calls for a given conversationId
      - Accept a CorrelationId parameter and propagate it to all Invoke-GCRequest calls
      - Return a structured PSCustomObject with full data, error list, and endpoint log
      - Emit Write-UxEvent telemetry at start/complete/fail
      - No WPF or UI references; pure data logic
    public_functions:
      - Invoke-ConversationReport
    return_schema:
      ConversationReportResult:
        ConversationId: string
        CorrelationId: string
        ConversationDetails: object | null
        AnalyticsDetails: object | null
        SpeechTextAnalytics: object | null
        RecordingMetadata: object[] | null
        Sentiments: object | null
        SipMessages: object | null
        RetrievedAt: string (ISO 8601)
        DurationMs: number
        Errors: string[]
        Warnings: string[]
        EndpointLog: EndpointLogEntry[]
        IsPartial: bool
        ContainsPii: bool   # always true

  - name: ConversationAnalysisService
    location: apps/OpsConsole/Resources/Services/ConversationAnalysisService.ps1
    responsibilities:
      - Accept a ConversationReportResult and produce analysis objects
      - No API calls; pure in-memory computation
      - Extracted from Format-ConversationReportText (lines 4972-4991)
    public_functions:
      - Invoke-ConversationAnalysis
    return_schema:
      ConversationAnalysisResult:
        CorrelationId: string
        TimelineEvents: object[]
        DurationAnalysis: object
        ParticipantStats: object
        Summary: object
        FlowPath: object
        KeyInsights: object
        AnalysisError: string | null

  - name: ConversationExportService
    location: apps/OpsConsole/Resources/Services/ConversationExportService.ps1
    responsibilities:
      - Write JSON, CSV, or text report to a specified path
      - Produce a manifest file with checksum, PII flag, partial-export metadata
      - No WPF references
    public_functions:
      - Export-ConversationReport
      - New-ExportManifest
    return_schema:
      ExportResult:
        OutputPath: string
        ManifestPath: string
        Format: string
        RecordCount: number
        IsPartial: bool
        ContainsPii: bool
        Checksum: string
        ExportedAt: string

  - name: ConversationReportViewModel
    location: apps/OpsConsole/Resources/UI/ConversationReport.ViewModel.ps1
    responsibilities:
      - Translate ConversationReportResult into UI-safe display objects
      - Manage UI state machine: Idle | Loading | Partial | Complete | Error
      - No API calls; no file I/O
    public_functions:
      - Set-ConvReportUiState
    return_schema:
      ConversationReportViewModel:
        State: string     # Idle | Loading | Partial | Complete | Error
        StatusText: string
        ProgressPercent: int
        ProgressLabel: string
        EndpointLogLines: string[]
        ReportText: string
        CorrelationId: string
        IsRunEnabled: bool
        IsExportEnabled: bool
        IsInspectEnabled: bool
        ErrorBannerText: string | null
        WarningBannerText: string | null
```

**PowerShell function signatures:**

```powershell
# ConversationReportService.ps1
function Invoke-ConversationReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$ConversationId,
        [Parameter(Mandatory)] [string]$BaseUrl,
        [Parameter(Mandatory)] [string]$AccessToken,
        [string]$CorrelationId = [guid]::NewGuid().ToString(),
        [scriptblock]$OnProgress = $null
    )
    # Returns: [ConversationReportResult] PSCustomObject
}

# ConversationAnalysisService.ps1
function Invoke-ConversationAnalysis {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [PSCustomObject]$Report,
        [string]$CorrelationId = ''
    )
    # Returns: [ConversationAnalysisResult] PSCustomObject
}

# ConversationExportService.ps1
function Export-ConversationReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [PSCustomObject]$Report,
        [Parameter(Mandatory)] [string]$OutputPath,
        [ValidateSet('JSON','CSV','Text')] [string]$Format = 'JSON',
        [string]$CorrelationId = [guid]::NewGuid().ToString(),
        [switch]$RedactPii
    )
    # Returns: [ExportResult] PSCustomObject
}

# ConversationReport.ViewModel.ps1
function Set-ConvReportUiState {
    param(
        [ValidateSet('Idle','Loading','Complete','Partial','Error')] [string]$State,
        [string]$StatusText     = '',
        [int]$ProgressPercent   = 0,
        [string]$ProgressLabel  = '',
        [string]$ErrorText      = '',
        [string]$WarningText    = '',
        [bool]$ExportEnabled    = $false
    )
    # Applies state to WPF controls; must be called on the dispatcher thread
}
```

---

## Section 5 — UI Improvements That Reduce Operator Confusion

### UI State Machine

```
              ┌─────────┐
   startup    │  Idle   │  no report loaded; [BTN_RUN] enabled
              └────┬────┘
                   │ click [BTN_RUN]
              ┌────▼────┐
              │ Loading │  [BTN_RUN] disabled; progress bar animating;
              └────┬────┘  cancel button visible
        ┌──────────┤
  errors│          │success (all required endpoints OK)
        │    ┌─────▼──────┐
        │    │  Complete  │  report text shown; export enabled
        │    └─────┬──────┘
        │          │optional misses
        │    ┌─────▼──────┐
        │    │  Partial   │  warning banner; export enabled with PartialData flag
        │    └────────────┘
 ┌──────▼──────┐
 │    Error    │  error banner with CorrelationId; retry button
 └─────────────┘
```

### XAML Snippets

**Error and warning banners — add to conversation report tab above report text area:**

```xml
<Border Name="ConvReportErrorBanner"
        Background="#FFEBEE" BorderBrush="#C62828" BorderThickness="1"
        Padding="8,6" Margin="0,0,0,4" Visibility="Collapsed">
  <DockPanel>
    <TextBlock DockPanel.Dock="Right" Text="&#x274C;" FontSize="14" Margin="8,0,0,0"
               Cursor="Hand" Name="ConvReportDismissError" VerticalAlignment="Center"/>
    <TextBlock Name="ConvReportErrorText" TextWrapping="Wrap"
               Foreground="#C62828" FontSize="12"/>
  </DockPanel>
</Border>

<Border Name="ConvReportWarningBanner"
        Background="#FFF8E1" BorderBrush="#F9A825" BorderThickness="1"
        Padding="8,6" Margin="0,0,0,4" Visibility="Collapsed">
  <TextBlock Name="ConvReportWarningText" TextWrapping="Wrap"
             Foreground="#6D4C00" FontSize="12"/>
</Border>
```

**Busy indicator with cancel button — replace the static progress row:**

```xml
<StackPanel Orientation="Horizontal" Margin="0,4,0,0">
  <ProgressBar Name="conversationReportProgressBar"
               Width="300" Height="14" Minimum="0" Maximum="100"
               IsIndeterminate="False"/>
  <TextBlock Name="conversationReportProgressText"
             Margin="8,0,0,0" VerticalAlignment="Center"
             FontSize="11" Foreground="Gray"/>
  <Button Name="cancelConversationReportButton"
          Content="Cancel" Width="60" Height="22" Margin="8,0,0,0"
          Visibility="Collapsed" Background="#EF9A9A"/>
</StackPanel>
```

**Stale data badge — overlay on report text box:**

```xml
<Grid>
  <TextBox Name="conversationReportText"
           TextWrapping="Wrap" AcceptsReturn="True" IsReadOnly="True"
           VerticalScrollBarVisibility="Auto"
           FontFamily="Consolas" FontSize="11"/>
  <Border Name="ConvReportStaleBadge"
          HorizontalAlignment="Right" VerticalAlignment="Top"
          Background="#FFF9C4" BorderBrush="#F9A825" BorderThickness="1"
          Padding="4,2" Margin="4" CornerRadius="3"
          Visibility="Collapsed">
    <TextBlock Text="Previous report — click Run to refresh"
               FontSize="10" Foreground="#6D4C00"/>
  </Border>
</Grid>
```

### PowerShell ViewModel Binding Example

```powershell
# Set-ConvReportUiState — apply ViewModel state to WPF controls
# Must be called on the dispatcher thread (use Dispatcher.Invoke from background jobs)

function Set-ConvReportUiState {
    param(
        [ValidateSet('Idle','Loading','Complete','Partial','Error')] [string]$State,
        [string]$StatusText    = '',
        [int]$ProgressPercent  = 0,
        [string]$ProgressLabel = '',
        [string]$ErrorText     = '',
        [string]$WarningText   = '',
        [bool]$ExportEnabled   = $false
    )

    if ($conversationReportStatus)      { $conversationReportStatus.Text      = $StatusText }
    if ($conversationReportProgressBar) { $conversationReportProgressBar.Value = $ProgressPercent }
    if ($conversationReportProgressText){ $conversationReportProgressText.Text = $ProgressLabel }

    if ($ConvReportErrorBanner) {
        $ConvReportErrorBanner.Visibility = if ($ErrorText) { 'Visible' } else { 'Collapsed' }
        if ($ConvReportErrorText -and $ErrorText) { $ConvReportErrorText.Text = $ErrorText }
    }
    if ($ConvReportWarningBanner) {
        $ConvReportWarningBanner.Visibility = if ($WarningText) { 'Visible' } else { 'Collapsed' }
        if ($ConvReportWarningText -and $WarningText) { $ConvReportWarningText.Text = $WarningText }
    }

    if ($runConversationReportButton) {
        $runConversationReportButton.IsEnabled = ($State -ne 'Loading')
    }
    if ($cancelConversationReportButton) {
        $cancelConversationReportButton.Visibility = if ($State -eq 'Loading') { 'Visible' } else { 'Collapsed' }
    }
    foreach ($btn in @($exportConversationReportJsonButton, $exportConversationReportTextButton, $inspectConversationReportButton)) {
        if ($btn) { $btn.IsEnabled = $ExportEnabled }
    }
    if ($ConvReportStaleBadge) {
        $ConvReportStaleBadge.Visibility = if ($State -eq 'Loading') { 'Visible' } else { 'Collapsed' }
    }
}
```

### Accessibility Improvements

- Add `AutomationProperties.Name="Run Conversation Report"` to `runConversationReportButton` for screen reader announcement.
- Add `KeyboardNavigation.TabIndex` ordering: input field → run button → progress area → report text → export buttons.
- Add `ToolTip="Export full report as JSON (may contain PII)"` to JSON export button.
- Add `AutomationProperties.LiveSetting="Polite"` to `conversationReportStatus` so status changes are announced without interrupting the operator.

---

## Section 6 — Error Handling Improvements

### Structured Error Object

```powershell
# Standard error object — returned by all service functions on failure
function New-ServiceError {
    param(
        [Parameter(Mandatory)] [string]$Code,      # AUTH_EXPIRED | API_404 | NETWORK_TIMEOUT | etc.
        [Parameter(Mandatory)] [string]$Message,   # operator-safe message (no stack traces)
        [ValidateSet('Info','Warning','Error','Fatal')] [string]$Level = 'Error',
        [Parameter(Mandatory)] [string]$Operation, # e.g. ConversationReport.FetchCore
        [string]$CorrelationId  = '',
        [string]$Details        = '',              # dev detail; trace log only, never shown in UI
        [bool]$Recoverable      = $false,
        [object]$InnerException = $null
    )
    return [PSCustomObject]@{
        Code           = $Code
        Message        = $Message
        Level          = $Level
        Operation      = $Operation
        CorrelationId  = $CorrelationId
        Details        = $Details
        Recoverable    = $Recoverable
        Timestamp      = (Get-Date -Format 'o')
        InnerException = $InnerException
    }
}
```

### Retry with Exponential Backoff

```powershell
# Invoke-WithRetry — wrap any scriptblock with exponential backoff retry
# Rationale: transient 429/503/timeout errors should not fail the report;
# retry up to 3 times before marking the endpoint as failed.

function Invoke-WithRetry {
    param(
        [Parameter(Mandatory)] [scriptblock]$Action,
        [string]$OperationName     = 'Unknown',
        [string]$CorrelationId     = '',
        [int]$MaxAttempts          = 3,
        [int]$BaseDelayMs          = 1000,
        [int[]]$RetryOnHttpStatus  = @(429, 500, 502, 503, 504)
    )

    $attempt = 0
    while ($attempt -lt $MaxAttempts) {
        $attempt++
        try {
            return & $Action
        }
        catch {
            $ex         = $_
            $httpStatus = $null

            if ($ex.Exception.Response) {
                $httpStatus = [int]$ex.Exception.Response.StatusCode
            }

            $isRetryable = ($httpStatus -in $RetryOnHttpStatus) -or
                           ($ex.Exception -is [System.Net.WebException]) -or
                           ($ex.Exception -is [System.TimeoutException])

            if (-not $isRetryable -or $attempt -ge $MaxAttempts) {
                $code = switch ($httpStatus) {
                    401 { 'AUTH_EXPIRED' }
                    403 { 'AUTH_FORBIDDEN' }
                    404 { 'API_NOT_FOUND' }
                    429 { 'RATE_LIMITED' }
                    default { 'NETWORK_ERROR' }
                }
                throw (New-ServiceError `
                    -Code          $code `
                    -Message       "Operation '$OperationName' failed after $attempt attempt(s)." `
                    -Operation     $OperationName `
                    -CorrelationId $CorrelationId `
                    -Details       $ex.ScriptStackTrace `
                    -Recoverable   $false)
            }

            # Exponential backoff: 1s, 2s, 4s ...
            $delayMs = $BaseDelayMs * [math]::Pow(2, $attempt - 1)

            # Honor Retry-After for 429
            if ($httpStatus -eq 429 -and $ex.Exception.Response) {
                $retryAfter = $ex.Exception.Response.Headers['Retry-After']
                if ($retryAfter -match '^\d+$') { $delayMs = [int]$retryAfter * 1000 }
            }

            Write-Verbose "[$OperationName] Attempt $attempt failed (HTTP $httpStatus). Retrying in $($delayMs)ms. CorrelationId=$CorrelationId"
            Start-Sleep -Milliseconds $delayMs
        }
    }
}
```

### Hardened UI Handler (Delegation Pattern)

```powershell
# Hardened runConversationReportButton.Add_Click
# Replaces UI.Run.ps1:1913 — delegates all work to service functions
# Rationale: handler contains only input validation, state transitions, and job plumbing;
# all API and analysis logic lives in service modules that can be tested independently.

if ($runConversationReportButton) {
    $runConversationReportButton.Add_Click({

        # Step 1 — correlation ID for this invocation
        $correlationId = [guid]::NewGuid().ToString()

        # Step 2 — capture all inputs before starting the job ($script: not accessible in job)
        $convId  = if ($conversationReportIdInput) { $conversationReportIdInput.Text.Trim() } else { '' }
        $token   = Get-ExplorerAccessToken
        $baseUrl = $ApiBaseUrl
        $window  = $Window

        # Step 3 — validate on dispatcher thread
        if (-not $convId) {
            Set-ConvReportUiState -State 'Error' -ErrorText "Please enter a conversation ID." -StatusText "No conversation ID."
            return
        }

        if ($convId -notmatch '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') {
            Set-ConvReportUiState -State 'Error' `
                -ErrorText "Conversation ID does not look like a valid UUID. Check the value and try again." `
                -StatusText "Invalid ID format."
            return
        }

        if (-not $token) {
            Set-ConvReportUiState -State 'Error' -ErrorText "Please provide an OAuth token before running a report." -StatusText "No token."
            return
        }

        if ($script:TokenExpiresAt -and (Get-Date) -gt $script:TokenExpiresAt) {
            Set-ConvReportUiState -State 'Error' `
                -ErrorText "Session expired. Please log in again. [Correlation ID: $correlationId]" `
                -StatusText "Session expired."
            Show-LoginWindow
            return
        }

        # Step 4 — enter Loading state
        Set-ConvReportUiState -State 'Loading' -StatusText "Fetching report..." -ProgressPercent 0 -ProgressLabel "Initializing..."
        if ($conversationReportEndpointLog) { $conversationReportEndpointLog.Text = '' }

        # Step 5 — telemetry start
        try {
            Write-UxEvent -Event 'conversation_report_start' -Level Info -Module 'ConversationReport' `
                -Props @{ conversationId = $convId; correlationId = $correlationId }
        } catch { Write-Verbose "Telemetry start failed: $_" }

        $startTime = Get-Date

        # Step 6 — background job
        $job = Start-ThreadJob -ScriptBlock {
            param($convId, $token, $baseUrl, $correlationId, $windowRef)

            # Import required modules in this runspace
            $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
            . (Join-Path $repoRoot 'apps/OpsConsole/Resources/UI/UI.PreMain.ps1')
            Import-Module (Join-Path $repoRoot 'src/GenesysCloud.OpsInsights/GenesysCloud.OpsInsights.psd1') -Force
            Connect-GCCloud -RegionDomain ($baseUrl -replace '^https?://api\.', '' -replace '\.pure\.cloud.*', '') `
                            -AccessToken $token

            $headers = @{ 'Authorization' = "Bearer $token"; 'Content-Type' = 'application/json' }

            # Progress callback — safe UI update via Dispatcher.Invoke
            $progressCallback = {
                param($PercentComplete, $Status, $EndpointName, $IsStarting, $IsSuccess, $IsOptional)
                $windowRef.Dispatcher.Invoke([Action]{
                    Set-ConvReportUiState -State 'Loading' -ProgressPercent $PercentComplete -ProgressLabel $Status
                    if ($conversationReportEndpointLog) {
                        $ts   = (Get-Date).ToString('HH:mm:ss')
                        $line = if ($IsStarting)  { "[$ts] Querying: $EndpointName..." }
                                elseif ($IsSuccess){ "[$ts] $([char]0x2713) $EndpointName" }
                                elseif ($IsOptional){ "[$ts] [WARN] $EndpointName — Optional, not available" }
                                else               { "[$ts] $([char]0x2717) $EndpointName — Failed" }
                        $conversationReportEndpointLog.AppendText("$line`r`n")
                        $conversationReportEndpointLog.ScrollToEnd()
                    }
                })
            }

            return Get-ConversationReport -ConversationId $convId -Headers $headers `
                                          -BaseUrl $baseUrl -ProgressCallback $progressCallback

        } -ArgumentList $convId, $token, $baseUrl, $correlationId, $window

        # Step 7 — monitor job on event
        $null = Register-ObjectEvent -InputObject $job -EventName StateChanged -Action {
            $completedJob = $Event.Sender
            if ($completedJob.State -notin 'Running', 'NotStarted') {
                $window.Dispatcher.Invoke([Action]{
                    $elapsed = (Get-Date) - $startTime
                    try {
                        $report = Receive-Job -Job $completedJob -ErrorAction Stop
                        $script:LastConversationReport     = $report
                        $script:LastConversationReportJson = $report | ConvertTo-Json -Depth 20

                        $reportText = Format-ConversationReportText -Report $report
                        if ($conversationReportText) { $conversationReportText.Text = $reportText }

                        $hasWarnings = $report.Warnings -and $report.Warnings.Count -gt 0
                        $warnText    = if ($hasWarnings) {
                            "$($report.Warnings.Count) optional endpoint(s) unavailable — partial data. [Correlation ID: $correlationId]"
                        } else { $null }

                        $state = if ($report.Errors -and $report.Errors.Count -gt 0) { 'Partial' } else { 'Complete' }
                        Set-ConvReportUiState -State $state -ExportEnabled $true `
                            -StatusText "Report complete. [Correlation ID: $correlationId]" `
                            -ProgressPercent 100 -ProgressLabel 'Complete' -WarningText $warnText

                        try {
                            Write-UxEvent -Event 'conversation_report_complete' -Level Info -Module 'ConversationReport' `
                                -Props @{ conversationId = $convId; correlationId = $correlationId
                                          durationMs = $elapsed.TotalMilliseconds; errorCount = $report.Errors.Count }
                        } catch { }

                    } catch {
                        Set-ConvReportUiState -State 'Error' `
                            -ErrorText "Report failed. Correlation ID: $correlationId. See trace log for details." `
                            -StatusText "Report failed. [Correlation ID: $correlationId]"
                        Add-LogEntry "Conversation report failed: $($_.Exception.Message) [CorrelationId=$correlationId]"
                        try {
                            Write-UxEvent -Event 'conversation_report_fail' -Level Error -Module 'ConversationReport' `
                                -Props @{ conversationId = $convId; correlationId = $correlationId
                                          errorCategory = $_.Exception.GetType().Name
                                          durationMs    = $elapsed.TotalMilliseconds }
                        } catch { }
                    } finally {
                        Remove-Job  -Job $completedJob -Force
                        Unregister-Event -SourceIdentifier $Event.SourceIdentifier
                    }
                })
            }
        }
    })
}
```

---

## Section 7 — Export / Reporting Improvements

### Recommended Export Formats

| Format | Use case | Notes |
| --- | --- | --- |
| JSON | Machine-readable; full fidelity; re-importable | Default; include all raw API responses + ExportMeta |
| CSV | Spreadsheet analysis of timeline events | One row per timeline event; flatten nested objects |
| Text | Human-readable; paste into incident tickets | Current format from `Format-ConversationReportText` |

### Export-ConversationReport Function

```powershell
# ConversationExportService.ps1
# Rationale: export logic extracted from UI handlers into a testable, reusable function.
# Acceptance criteria: exported file is non-empty, checksum matches manifest,
#   manifest lists PII flag and any skipped endpoints.

function Export-ConversationReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [PSCustomObject]$Report,
        [Parameter(Mandatory)] [string]$OutputPath,
        [ValidateSet('JSON','CSV','Text')] [string]$Format = 'JSON',
        [string]$CorrelationId = [guid]::NewGuid().ToString(),
        [switch]$RedactPii
    )

    $exportedAt = (Get-Date -Format 'o')
    $tempPath   = "$OutputPath.tmp"

    try {
        switch ($Format) {

            'JSON' {
                $payload = [ordered]@{
                    ExportMeta = [ordered]@{
                        ExportedAt       = $exportedAt
                        CorrelationId    = $CorrelationId
                        Format           = 'JSON'
                        ContainsPii      = $true      # always true for conversation data
                        IsPartial        = ($Report.Errors.Count -gt 0)
                        SkippedEndpoints = @($Report.Warnings)
                        Errors           = @($Report.Errors)
                        RedactionApplied = $RedactPii.IsPresent
                    }
                    Report = if ($RedactPii) { Remove-PiiFromReport -Report $Report } else { $Report }
                }
                $payload | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $tempPath -Encoding utf8
            }

            'CSV' {
                $rows = @($Report.TimelineEvents) | ForEach-Object {
                    [ordered]@{
                        ConversationId = $Report.ConversationId
                        StartTime      = $_.StartTime
                        EndTime        = $_.EndTime
                        Source         = $_.Source
                        EventType      = $_.EventType
                        Participant    = if ($RedactPii) { '[REDACTED]' } else { $_.Participant }
                        Queue          = $_.Queue
                        User           = if ($RedactPii) { '[REDACTED]' } else { $_.User }
                        Direction      = $_.Direction
                        DisconnectType = $_.DisconnectType
                    }
                }
                $rows | Export-Csv -LiteralPath $tempPath -NoTypeInformation -Encoding utf8
            }

            'Text' {
                (Format-ConversationReportText -Report $Report) | Out-File -LiteralPath $tempPath -Encoding utf8
            }
        }

        # Checksum
        $hash = (Get-FileHash -LiteralPath $tempPath -Algorithm SHA256).Hash

        # Move temp to final path
        Move-Item -LiteralPath $tempPath -Destination $OutputPath -Force

        # Write manifest
        $manifestPath = "$OutputPath.manifest.json"
        [ordered]@{
            ExportedAt       = $exportedAt
            CorrelationId    = $CorrelationId
            Format           = $Format
            OutputPath       = $OutputPath
            FileSizeBytes    = (Get-Item -LiteralPath $OutputPath).Length
            Sha256           = $hash
            ContainsPii      = $true
            IsPartial        = ($Report.Errors.Count -gt 0)
            SkippedEndpoints = @($Report.Warnings)
            RedactionApplied = $RedactPii.IsPresent
        } | ConvertTo-Json | Set-Content -LiteralPath $manifestPath -Encoding utf8

        return [PSCustomObject]@{
            OutputPath   = $OutputPath
            ManifestPath = $manifestPath
            Format       = $Format
            IsPartial    = ($Report.Errors.Count -gt 0)
            ContainsPii  = $true
            Checksum     = $hash
            ExportedAt   = $exportedAt
        }

    } catch {
        if (Test-Path -LiteralPath $tempPath) { Remove-Item -LiteralPath $tempPath -Force }
        throw $_
    }
}

function Remove-PiiFromReport {
    param([PSCustomObject]$Report)
    $clone = $Report | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    if ($clone.ConversationDetails -and $clone.ConversationDetails.participants) {
        foreach ($p in $clone.ConversationDetails.participants) {
            $p.ani  = '[REDACTED]'
            $p.dnis = '[REDACTED]'
            $p.name = '[REDACTED]'
        }
    }
    return $clone
}
```

### Partial Export Manifest Example

```json
{
  "ExportedAt":       "2026-03-11T14:23:01.123Z",
  "CorrelationId":    "a3bd308f-1234-5678-abcd-ef0123456789",
  "Format":           "JSON",
  "OutputPath":       "C:\\exports\\ConversationReport_a3bd308f.json",
  "FileSizeBytes":    48219,
  "Sha256":           "e3b0c44298fc1c149afbf4c8996fb924...",
  "ContainsPii":      true,
  "IsPartial":        true,
  "SkippedEndpoints": [
    "Speech & Text Analytics — 403 Forbidden (not enabled for org)",
    "SIP Messages — 404 Not Found"
  ],
  "RedactionApplied": false
}
```

---

## Section 8 — Logging / History / Snapshot Improvements

### Structured Log Schema

```json
{
  "Timestamp":      "2026-03-11T14:23:01.123Z",
  "Level":          "Info | Warning | Error | Fatal",
  "Component":      "ConversationReport | Auth | Export | UI",
  "Operation":      "FetchConversationCore | RenderReport | ExportJSON",
  "CorrelationId":  "a3bd308f-...",
  "Actor":          "session-id or operator identifier",
  "RequestId":      "X-Inin-Correlation-Id response header value",
  "DurationMs":     4200,
  "PayloadSummary": "ConversationId=a3bd308f; endpoints=6/6; events=142",
  "Error": {
    "Code":    "API_404",
    "Message": "Conversation not found",
    "Details": "stack trace — not shown in UI"
  }
}
```

### Write-StructuredLog Function

```powershell
# Structured logging helper — writes NDJSON to a rotating trace log file
# Rationale: single log call per operation guarantees every event has a
# CorrelationId and goes to disk, independent of the UI log panel.

function Write-StructuredLog {
    param(
        [ValidateSet('Info','Warning','Error','Fatal')] [string]$Level = 'Info',
        [string]$Component       = 'ConversationReport',
        [string]$Operation       = '',
        [string]$CorrelationId   = '',
        [string]$Actor           = '',
        [string]$RequestId       = '',
        [double]$DurationMs      = -1,
        [string]$PayloadSummary  = '',
        [PSCustomObject]$Error   = $null
    )

    $entry = [ordered]@{
        Timestamp      = (Get-Date -Format 'o')
        Level          = $Level
        Component      = $Component
        Operation      = $Operation
        CorrelationId  = $CorrelationId
        Actor          = $Actor
        RequestId      = $RequestId
        DurationMs     = if ($DurationMs -ge 0) { $DurationMs } else { $null }
        PayloadSummary = $PayloadSummary
        Error          = $Error
    }

    # Write to monthly rotating trace log
    $logPath = Join-Path $env:TEMP "GenesysApiExplorer.trace.$(Get-Date -Format 'yyyy-MM').log"
    try {
        Add-Content -LiteralPath $logPath -Value ($entry | ConvertTo-Json -Compress) -Encoding utf8
    } catch {
        Write-Verbose "Trace log write failed: $_"
    }

    # Also surface to UxTelemetry for session correlation
    try {
        Write-UxEvent -Event "log_$($Level.ToLower())" -Level $Level -Module $Component -Props @{
            operation     = $Operation
            correlationId = $CorrelationId
            durationMs    = $DurationMs
        }
    } catch { }
}
```

### Snapshot-InvestigationState

```powershell
# Capture operator investigation state to disk for post-incident review
# Rationale: enables hand-offs and incident reproduction without requiring
# the operator to re-run the report.

function Snapshot-InvestigationState {
    param(
        [string]$SnapshotDir   = (Join-Path $env:TEMP 'GenesysApiExplorer\Snapshots'),
        [string]$CorrelationId = [guid]::NewGuid().ToString(),
        [ValidateSet('manual','error','session_end')] [string]$Reason = 'manual'
    )

    $null = New-Item -ItemType Directory -Force -Path $SnapshotDir

    $snapshot = [ordered]@{
        SnapshotAt     = (Get-Date -Format 'o')
        CorrelationId  = $CorrelationId
        Reason         = $Reason
        Region         = $script:Region
        ConversationId = if ($conversationReportIdInput) { $conversationReportIdInput.Text.Trim() } else { $null }
        ReportLoaded   = ($null -ne $script:LastConversationReport)
        ReportErrors   = if ($script:LastConversationReport) { @($script:LastConversationReport.Errors) } else { @() }
        TokenValidated = $script:TokenValidated
        TokenExpiresAt = if ($script:TokenExpiresAt) { $script:TokenExpiresAt.ToString('o') } else { $null }
        # Token value deliberately excluded
    }

    $filename = "Snapshot_$(Get-Date -Format 'yyyyMMdd_HHmmss')_$($CorrelationId.Substring(0,8)).json"
    $path     = Join-Path $SnapshotDir $filename
    $snapshot | ConvertTo-Json | Set-Content -LiteralPath $path -Encoding utf8

    Write-StructuredLog -Level Info -Component 'Snapshot' -Operation 'Snapshot-InvestigationState' `
        -CorrelationId $CorrelationId -PayloadSummary "Reason=$Reason; Path=$path"

    return $path
}
```

### History Entry Example

```json
{
  "EntryAt":         "2026-03-11T14:23:05.400Z",
  "CorrelationId":   "a3bd308f-...",
  "ConversationId":  "b7c41d9e-...",
  "Action":          "ReportGenerated",
  "Outcome":         "Partial",
  "DurationMs":      4812,
  "EndpointsSummary": {
    "Required": { "Attempted": 2, "Succeeded": 2, "Failed": 0 },
    "Optional": { "Attempted": 4, "Succeeded": 2, "Skipped": 2 }
  },
  "ExportedTo":    null,
  "OperatorNote":  ""
}
```

---

## Section 9 — Prioritized Implementation Plan

### Quick Wins (hours, minimal risk)

| Task | Acceptance criteria | Effort | Artifacts | Blockers |
| --- | --- | --- | --- | --- |
| QW1: UUID format validation | Input `abc` rejected before any API call; message shown | Small | `UI.Run.ps1:1916` — 3-line regex guard | None |
| QW2: Correlation ID in error display | `[STATUS_TEXT]` includes "Correlation ID: {guid}" on every failure | Small | `UI.Run.ps1:1913` — generate `$correlationId` at top | None |
| QW3: Disable `[BTN_RUN]` while running | Second Run click blocked while job is active | Small | `runConversationReportButton.IsEnabled = $false` at start | None |
| QW4: Add error/warning banner XAML | Banners exist, hidden by default | Small | `MainWindow.xaml` — two `Border` elements per Section 5 | None |
| QW5: `ContainsPii: true` in JSON export | JSON `ExportMeta.ContainsPii` equals `true` | Small | Export button handler | None |

QW1 through QW5 are marked **unblock others**: QW3 is required before ST1; QW4 before ST2.

### Short-Term (days, moderate risk)

| Task | Acceptance criteria | Effort | Artifacts | Blockers |
| --- | --- | --- | --- | --- |
| ST1: Background thread for report | UI responsive (no DoEvents); progress bar advances from job thread | Medium | Refactor `UI.Run.ps1:1913` per Section 6 | QW3 |
| ST2: Wire error/warning banners | Error banner visible on failure; warning banner on partial | Small | `Set-ConvReportUiState` per Section 5 | QW4 |
| ST3: `Write-StructuredLog` | Trace log written to `$env:TEMP\GenesysApiExplorer.trace.*.log` | Small | New `StructuredLogging.ps1` | None |
| ST4: Telemetry events | `conversation_report_start/complete/fail` in NDJSON file | Small | `UI.Run.ps1:1913` + `UxTelemetry.ps1` | ST1 |
| ST5: `Export-ConversationReport` function | 4 Pester tests in `tests/ExportService.Tests.ps1` pass offline | Small | `ConversationExportService.ps1` | None |

### Medium-Term (1–2 sprints)

| Task | Acceptance criteria | Effort | Artifacts | Blockers |
| --- | --- | --- | --- | --- |
| MT1: Extract `ConversationReportService.ps1` | Offline Pester tests pass; `UI.PreMain.ps1` calls the service | Medium | New service file; update call sites | ST1 |
| MT2: Cancel button | Cancel stops job within 2s; status shows "Cancelled" | Medium | `cancelConversationReportButton` handler; `$job.StopJob()` | ST1 |
| MT3: `Snapshot-InvestigationState` on Error | Snapshot written on Error state | Small | `StructuredLogging.ps1` | ST3 |
| MT4: Partial export manifest | Manifest includes `SkippedEndpoints` array | Small | `Export-ConversationReport` from Section 7 | ST5 |
| MT5: `Invoke-WithRetry` for transient errors | Report survives single 503 on optional endpoint | Medium | `ConversationReportService.ps1` | MT1 |

### Long-Term (multi-sprint)

| Task | Acceptance criteria | Effort | Artifacts | Blockers |
| --- | --- | --- | --- | --- |
| LT1: Parallel API calls for optional endpoints | Report completes in < 15s vs 30s sequential | Large | Refactor `Get-ConversationReport` to fan-out optional calls | MT1 |
| LT2: HTML export | Export-as-HTML produces browsable report with timeline table | Medium | `ConversationExportService.ps1` — add `HTML` format | MT1 |
| LT3: Investigation history panel | Last 10 conversation IDs + outcomes in sidebar list | Large | New XAML sidebar + `ConversationHistory.ps1` | MT2 |
| LT4: Stale report detection | Banner "Report may be stale — click Run to refresh" if > 5 min old | Small | Check `$report.RetrievedAt` on tab activation | MT2 |

### Minimum Viable Set for Immediate Supportability

Complete **QW1 → QW2 → QW3 → ST1 → ST2 → ST3 → ST4** in order.

After these seven tasks: every error message has a correlation ID; the UI never freezes; a trace log exists with structured entries; operators see clear error/warning banners instead of raw exception text.

---

## Section 10 — Acceptance Tests

### README: Running the Tests

```
Prerequisites:
  - PowerShell 7.0+
  - Pester 5.0+:
      Install-Module Pester -Scope CurrentUser -Force
  - No live Genesys Cloud credentials required;
    all tests use Set-GCInvoker mock

Run all conversation report tests:
  Invoke-Pester -Path tests/ -TagFilter ConversationReport -Output Detailed

Run a single file:
  Invoke-Pester -Path tests/ConversationReportService.Tests.ps1 -Output Detailed
```

### Automated Pester Tests

```powershell
# tests/ConversationReportService.Tests.ps1
# Covers: happy path, partial data, required endpoint failure,
#         export validation, and structured logging.
# All tests run offline using Set-GCInvoker mock.

#Requires -Version 7.0

BeforeAll {
    $repoRoot = Split-Path -Parent $PSScriptRoot
    Import-Module (Join-Path $repoRoot 'src/GenesysCloud.OpsInsights/GenesysCloud.OpsInsights.psd1') -Force
    . (Join-Path $repoRoot 'apps/OpsConsole/Resources/UI/UI.PreMain.ps1')

    # ── Fixtures ────────────────────────────────────────────────────────────────
    $script:ConvId    = 'a3bd308f-0000-0000-0000-000000000001'
    $script:BaseUrl   = 'https://api.usw2.pure.cloud'
    $script:Token     = 'test-token-not-real'
    $script:Headers   = @{ 'Authorization' = "Bearer $($script:Token)"; 'Content-Type' = 'application/json' }

    $script:FixtureCore = [PSCustomObject]@{
        conversationId = $script:ConvId
        startTime      = '2026-03-11T10:00:00.000Z'
        endTime        = '2026-03-11T10:05:00.000Z'
        participants   = @(
            [PSCustomObject]@{
                participantId = 'p1'; name = 'Test Customer'; purpose = 'customer'
                ani = '+15551234567'; dnis = '+18005551234'
                segments = @([PSCustomObject]@{
                    segmentType = 'interact'
                    segmentStart = '2026-03-11T10:00:05Z'
                    segmentEnd   = '2026-03-11T10:04:55Z'
                })
            }
        )
    }

    $script:FixtureAnalytics = [PSCustomObject]@{
        conversationId    = $script:ConvId
        conversationStart = '2026-03-11T10:00:00.000Z'
        participants      = @()
    }
}

AfterAll {
    if (Get-Command Set-GCInvoker -ErrorAction SilentlyContinue) {
        Set-GCInvoker -Reset
    }
}

Describe 'Get-ConversationReport — Happy Path' -Tag ConversationReport {

    BeforeEach {
        # All 6 endpoints return fixture data
        $script:CallLog = [System.Collections.ArrayList]::new()
        Set-GCInvoker -ScriptBlock {
            param($Method, $Uri, $Headers, $Body, $TimeoutSec)
            [void]$script:CallLog.Add([PSCustomObject]@{ Method = $Method; Uri = $Uri })
            if ($Uri -match '/conversations/[^/]+$') {
                return [PSCustomObject]@{ StatusCode = 200; Content = ($script:FixtureCore | ConvertTo-Json -Depth 10) }
            }
            if ($Uri -match '/analytics/conversations/[^/]+/details$') {
                return [PSCustomObject]@{ StatusCode = 200; Content = ($script:FixtureAnalytics | ConvertTo-Json -Depth 10) }
            }
            return [PSCustomObject]@{ StatusCode = 200; Content = '{}' }
        }
    }

    It 'returns a report with ConversationId set correctly' {
        $report = Get-ConversationReport -ConversationId $script:ConvId `
                                         -Headers $script:Headers -BaseUrl $script:BaseUrl
        $report.ConversationId | Should -Be $script:ConvId
    }

    It 'returns non-null ConversationDetails' {
        $report = Get-ConversationReport -ConversationId $script:ConvId `
                                         -Headers $script:Headers -BaseUrl $script:BaseUrl
        $report.ConversationDetails | Should -Not -BeNullOrEmpty
    }

    It 'Errors array is empty on full success' {
        $report = Get-ConversationReport -ConversationId $script:ConvId `
                                         -Headers $script:Headers -BaseUrl $script:BaseUrl
        $report.Errors.Count | Should -Be 0
    }

    It 'calls exactly 6 API endpoints' {
        Get-ConversationReport -ConversationId $script:ConvId `
                               -Headers $script:Headers -BaseUrl $script:BaseUrl | Out-Null
        $script:CallLog.Count | Should -Be 6
    }

    It 'sets RetrievedAt to a parseable ISO 8601 timestamp' {
        $report = Get-ConversationReport -ConversationId $script:ConvId `
                                         -Headers $script:Headers -BaseUrl $script:BaseUrl
        { [datetime]$report.RetrievedAt } | Should -Not -Throw
    }
}

Describe 'Get-ConversationReport — Partial Data (optional 404)' -Tag ConversationReport {

    BeforeEach {
        Set-GCInvoker -ScriptBlock {
            param($Method, $Uri)
            if ($Uri -match '/conversations/[^/]+$') {
                return [PSCustomObject]@{ StatusCode = 200; Content = ($script:FixtureCore | ConvertTo-Json -Depth 10) }
            }
            if ($Uri -match '/analytics/conversations/[^/]+/details$') {
                return [PSCustomObject]@{ StatusCode = 200; Content = ($script:FixtureAnalytics | ConvertTo-Json -Depth 10) }
            }
            # All optional endpoints return 404
            throw [System.Net.WebException]::new('404 Not Found')
        }
    }

    It 'returns a non-null report when optional endpoints fail' {
        $report = Get-ConversationReport -ConversationId $script:ConvId `
                                         -Headers $script:Headers -BaseUrl $script:BaseUrl
        $report | Should -Not -BeNullOrEmpty
    }

    It 'Errors array is empty (optional failures do not propagate to Errors)' {
        $report = Get-ConversationReport -ConversationId $script:ConvId `
                                         -Headers $script:Headers -BaseUrl $script:BaseUrl
        $report.Errors.Count | Should -Be 0
    }

    It 'EndpointLog contains 6 entries' {
        $report = Get-ConversationReport -ConversationId $script:ConvId `
                                         -Headers $script:Headers -BaseUrl $script:BaseUrl
        $report.EndpointLog.Count | Should -Be 6
    }

    It 'optional endpoint log entries contain "Optional"' {
        $report = Get-ConversationReport -ConversationId $script:ConvId `
                                         -Headers $script:Headers -BaseUrl $script:BaseUrl
        ($report.EndpointLog | Where-Object { $_.Status -like '*Optional*' }).Count | Should -BeGreaterOrEqual 1
    }
}

Describe 'Get-ConversationReport — Required Endpoint Failure' -Tag ConversationReport {

    BeforeEach {
        Set-GCInvoker -ScriptBlock {
            param($Method, $Uri)
            if ($Uri -match '/analytics/conversations/[^/]+/details$') {
                throw [System.Net.WebException]::new('500 Internal Server Error')
            }
            if ($Uri -match '/conversations/[^/]+$') {
                return [PSCustomObject]@{ StatusCode = 200; Content = ($script:FixtureCore | ConvertTo-Json -Depth 10) }
            }
            return [PSCustomObject]@{ StatusCode = 200; Content = '{}' }
        }
    }

    It 'adds an entry to Errors for a required endpoint failure' {
        $report = Get-ConversationReport -ConversationId $script:ConvId `
                                         -Headers $script:Headers -BaseUrl $script:BaseUrl
        $report.Errors.Count | Should -BeGreaterOrEqual 1
    }

    It 'error entry contains the endpoint name' {
        $report = Get-ConversationReport -ConversationId $script:ConvId `
                                         -Headers $script:Headers -BaseUrl $script:BaseUrl
        $report.Errors[0] | Should -Match 'Analytics Details'
    }
}

Describe 'Export-ConversationReport' -Tag ConversationReport, Export {

    BeforeAll {
        $script:MinimalReport = [PSCustomObject]@{
            ConversationId      = $script:ConvId
            ConversationDetails = $script:FixtureCore
            AnalyticsDetails    = $script:FixtureAnalytics
            SpeechTextAnalytics = $null; RecordingMetadata = $null
            Sentiments          = $null; SipMessages = $null
            RetrievedAt         = (Get-Date -Format 'o')
            Errors              = @(); Warnings = @('Speech & Text Analytics — not available')
            EndpointLog         = @(); TimelineEvents = @()
        }
        $script:TempDir = Join-Path $env:TEMP "GCExportTests_$(New-Guid)"
        $null = New-Item -ItemType Directory -Path $script:TempDir
    }

    AfterAll {
        Remove-Item -Recurse -Force -Path $script:TempDir -ErrorAction SilentlyContinue
    }

    It 'JSON export produces a non-empty file' {
        $path = Join-Path $script:TempDir 'export1.json'
        Export-ConversationReport -Report $script:MinimalReport -OutputPath $path -Format JSON -CorrelationId 'test-001'
        (Get-Item -LiteralPath $path).Length | Should -BeGreaterThan 0
    }

    It 'JSON export ExportMeta.ContainsPii is true' {
        $path = Join-Path $script:TempDir 'export2.json'
        Export-ConversationReport -Report $script:MinimalReport -OutputPath $path -Format JSON -CorrelationId 'test-002'
        $content = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        $content.ExportMeta.ContainsPii | Should -Be $true
    }

    It 'produces a companion manifest file' {
        $path   = Join-Path $script:TempDir 'export3.json'
        $result = Export-ConversationReport -Report $script:MinimalReport -OutputPath $path -Format JSON -CorrelationId 'test-003'
        Test-Path -LiteralPath $result.ManifestPath | Should -Be $true
    }

    It 'manifest Sha256 matches actual file hash' {
        $path     = Join-Path $script:TempDir 'export4.json'
        $result   = Export-ConversationReport -Report $script:MinimalReport -OutputPath $path -Format JSON -CorrelationId 'test-004'
        $manifest = Get-Content -LiteralPath $result.ManifestPath -Raw | ConvertFrom-Json
        $actual   = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
        $manifest.Sha256 | Should -Be $actual
    }

    It 'RedactPii replaces ANI with [REDACTED] in output' {
        $path = Join-Path $script:TempDir 'export5.json'
        Export-ConversationReport -Report $script:MinimalReport -OutputPath $path -Format JSON `
                                  -CorrelationId 'test-005' -RedactPii
        $content = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        $content.Report.ConversationDetails.participants[0].ani | Should -Be '[REDACTED]'
    }
}

Describe 'Write-StructuredLog' -Tag ConversationReport, Logging {

    It 'appends a line to the trace log file' {
        $logPath       = Join-Path $env:TEMP "GenesysApiExplorer.trace.$(Get-Date -Format 'yyyy-MM').log"
        $initialLength = if (Test-Path $logPath) { (Get-Item $logPath).Length } else { 0 }
        Write-StructuredLog -Level Info -Component 'Test' -Operation 'UnitTest' `
                            -CorrelationId 'test-log-001' -PayloadSummary 'unit test entry'
        (Get-Item $logPath).Length | Should -BeGreaterThan $initialLength
    }

    It 'written entry is valid JSON with required fields' {
        Write-StructuredLog -Level Warning -Component 'Test' -Operation 'FieldCheck' `
                            -CorrelationId 'test-log-002' -DurationMs 123
        $logPath  = Join-Path $env:TEMP "GenesysApiExplorer.trace.$(Get-Date -Format 'yyyy-MM').log"
        $lastLine = (Get-Content -LiteralPath $logPath -Encoding utf8 | Select-Object -Last 1)
        $entry    = $lastLine | ConvertFrom-Json
        $entry.Level        | Should -Be 'Warning'
        $entry.Component    | Should -Be 'Test'
        $entry.CorrelationId | Should -Be 'test-log-002'
        $entry.DurationMs   | Should -Be 123
        $entry.Timestamp    | Should -Not -BeNullOrEmpty
    }
}
```

### Manual Operator Test Scenarios

#### Scenario 1 — Normal Success Path

**Steps:**

1. Launch the application; confirm startup shows "Environment OK" (after S1-004).
2. Enter a valid region; paste a real access token; click Test Token — indicator turns green.
3. Navigate to the Conversation Report tab.
4. Enter a known valid conversation ID.
5. Click Run Report.
6. Observe progress bar advancing through all 6 steps without the UI freezing.
7. Observe report text appearing in `[REPORT_TEXT]`.
8. Click Export JSON; save to Desktop.
9. Open the `.manifest.json` companion; verify checksum and PII flag.
10. Click Inspect; verify the timeline window opens and shows events.

**Pass criteria:**

- [ ] Progress bar reaches 100%.
- [ ] `[STATUS_TEXT]` shows "Report generated successfully. [Correlation ID: {guid}]".
- [ ] `[REPORT_TEXT]` is non-empty.
- [ ] JSON file and `.manifest.json` exist on Desktop.
- [ ] `manifest.ContainsPii = true`; `manifest.IsPartial = false`.
- [ ] Trace log contains `conversation_report_complete` entry.

---

#### Scenario 2 — Transient Network Failure

**Steps:**

1. Complete login; configure the analytics endpoint (via proxy or mock) to return 503 once then 200.
2. Click Run Report.

**Pass criteria:**

- [ ] `[ENDPOINT_LOG]` shows a retry entry for Analytics Details.
- [ ] Report completes successfully after the retry.
- [ ] `[STATUS_TEXT]` shows success (not an error).
- [ ] Trace log contains a `Warning` entry with attempt count.

---

#### Scenario 3 — Auth Token Expiry Mid-Session

**Steps:**

1. Complete login; in a console attached to the app session run: `$script:TokenExpiresAt = (Get-Date).AddSeconds(5)`.
2. Wait 10 seconds.
3. Click Run Report.

**Pass criteria:**

- [ ] Login dialog appears immediately; no API call is made.
- [ ] `[STATUS_TEXT]` or error banner shows "Session expired. Please log in again."
- [ ] Message includes a Correlation ID.
- [ ] No raw 401 exception text is visible.

---

#### Scenario 4 — Partial / Missing Data

**Steps:**

1. Configure mock so `speechandtextanalytics` and `sipmessages` endpoints return 404.
2. Click Run Report.

**Pass criteria:**

- [ ] Report generates (required endpoints succeeded).
- [ ] `[ENDPOINT_LOG]` shows `[WARN]` entries for both unavailable endpoints.
- [ ] Warning banner is visible naming the unavailable endpoints and the Correlation ID.
- [ ] JSON export includes `SkippedEndpoints` with both endpoint names.
- [ ] Manifest shows `IsPartial = true`.

---

#### Scenario 5 — File System Error During Export

**Steps:**

1. Complete a successful report.
2. Click Export JSON; enter a path to a read-only directory (e.g., `C:\Windows\test.json`).
3. Click Save.

**Pass criteria:**

- [ ] Error message appears in UI: "Export failed: Access to the path '...' is denied."
- [ ] No partial `.tmp` file remains on disk.
- [ ] Trace log contains an `Error` entry for the export failure.
- [ ] Report text and export buttons remain usable; operator can retry with a different path.
