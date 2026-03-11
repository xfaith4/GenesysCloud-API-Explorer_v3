# Defect List — GenesysCloud API Explorer v3

**Analysis date**: 2026-03-11  
**Analysis method**: Static code inspection (XAML + PowerShell source)

---

## Severity Legend

| Level | Meaning |
|-------|---------|
| **Critical** | Causes data loss, crash, or complete loss of a core workflow |
| **High** | Degrades core workflow or traps user with no recovery path |
| **Medium** | Degrades UX or correctness but has a workaround |
| **Low** | Polish / cosmetic; does not affect workflow completion |

---

## DEF-001 — UI Thread Blocking on Long-Running API Workflows

**Severity**: High  
**Area**: Conversation Report, Queue Wait Coverage, Audit Investigator, Operational Events, Ops Conversation Ingest, Insight Pack Execution  
**Evidence**: Static analysis of `UI.Run.ps1`. Event handlers for `RunConversationReportButton`, `RunQueueWaitReportButton`, `RunAuditInvestigatorButton`, `RunOperationalEventsButton`, `RunOpsConversationIngestButton`, and `RunSelectedInsightPackButton` call multi-step backend functions directly without confirmed `Start-ThreadJob` or `RunspaceFactory` offloading. A cancel button exists for Conversation Report only.  
**Impact**: During a 6-call Conversation Report or paginated Audit query, the application window may become unresponsive (frozen). Users may force-close the app and lose results.  
**Recommendation**: Wrap long-running handlers in `[System.Windows.Threading.Dispatcher]::InvokeAsync` background tasks or `Start-ThreadJob`. Update status text from the background thread via the dispatcher.

---

## DEF-002 — No HTTP 429 / Rate-Limit Retry in Invoke-GCRequest

**Severity**: High  
**Area**: All workflows using `Invoke-GCRequest`  
**Evidence**: `src/GenesysCloud.OpsInsights/Public/Invoke-GCRequest.ps1`. No retry logic for 429 (Too Many Requests) is present in static analysis.  
**Impact**: Bulk operations (Ops Ingest, multi-pack runs, Queue Wait Coverage) fail silently or return partial data when the Genesys Cloud API rate-limits the caller. No user-visible message explains the partial result.  
**Recommendation**: Add a retry loop with exponential backoff (e.g., 3 retries, doubling delay starting at 2 seconds) for 429 responses in `Invoke-GCRequest`. Surface the retry count to the Transparency Log.

---

## DEF-003 — No Input Validation Before "Run" Button Handlers

**Severity**: Medium  
**Area**: RunConversationReportButton, RunQueueWaitReportButton, RunAuditInvestigatorButton  
**Evidence**: `UI.Run.ps1` handlers at lines 1947, 2643, 3148. No explicit guard checks for empty/invalid inputs (blank conversation ID, blank queue ID, invalid date range) before calling backend functions.  
**Impact**: Backend functions receive empty or null parameters and may produce confusing errors (exception stack traces rather than user-friendly messages). `ConvReportErrorText` / `AuditStatusText` patterns exist but are only updated after a backend call, not before.  
**Recommendation**: Add pre-flight validation in each handler with an early `return` and a user-visible error in the relevant status text. For example: `if (-not $convId) { $convReportErrorText.Text = 'Please enter a conversation ID.'; return }`.

---

## DEF-004 — ScheduleOpsConversationIngest Uses Windows Task Scheduler Without OS Guard

**Severity**: Medium  
**Area**: `ScheduleOpsConversationIngestButton` (Ops Dashboard tab)  
**Evidence**: `UI.Run.ps1` line 3587. Button is visible and enabled on all platforms. Uses Windows Task Scheduler APIs that are unavailable on Linux/macOS.  
**Impact**: On non-Windows, clicking this button will produce an opaque error with no recovery path.  
**Recommendation**: At startup, detect OS (`$IsWindows`) and set `ScheduleOpsConversationIngestButton.IsEnabled = $false` with `ToolTip = "Scheduled ingest requires Windows."` on non-Windows platforms.

---

## DEF-005 — ExportInsightBriefingButton Has No Explanatory Tooltip

**Severity**: Low  
**Area**: `ExportInsightBriefingButton` (Ops Insights tab)  
**Evidence**: `MainWindow.xaml` line 406. `IsEnabled="False"` at startup, but no tooltip explains why.  
**Impact**: Users attempting to export a briefing before running a pack receive no feedback. May appear broken.  
**Recommendation**: Add `ToolTip="Run an insight pack first to enable this export."` to the XAML attribute.

---

## DEF-006 — InspectResponseButton Has No Guard for Empty Response

**Severity**: Low  
**Area**: `InspectResponseButton` (Response tab)  
**Evidence**: `UI.Run.ps1` line 1753. Button is enabled at startup. Clicking before any API call opens an empty or undefined inspect panel.  
**Impact**: Users may be confused by an empty inspection panel with no message.  
**Recommendation**: Disable button at startup (`IsEnabled="False"`) in XAML, enable it only after a successful API response, matching the pattern already used by `SaveButton` and `ToggleResponseViewButton`.

---

## DEF-007 — Token Not Persisted Across App Restarts

**Severity**: Medium  
**Area**: Authentication (all tabs)  
**Evidence**: `Set-ExplorerAccessToken` stores token in a `$script:` scoped variable. No file-based or OS credential store persistence is present in static analysis.  
**Impact**: Every application restart requires re-authentication. This is a significant friction point for operational users who run the tool frequently.  
**Recommendation**: Optionally persist the token (encrypted via `DPAPI` on Windows) to a local config file, with a user-controlled "Remember token" checkbox. Include an expiry guard so expired tokens are discarded on load.

---

## DEF-008 — Notification Topic Refresh Has No Pagination Safety

**Severity**: Medium  
**Area**: `RefreshLiveSubTopicsButton` (Live Subscriptions tab)  
**Evidence**: `GenesysCloud.NotificationsToolkit.psm1` `Get-GCNotificationTopics`. The `/api/v2/notifications/topics` endpoint returns hundreds of topics in a single response. No explicit page-size limit or pagination is apparent in static analysis.  
**Impact**: Very large responses may cause slow rendering of `LiveSubTopicCatalogList`. On memory-constrained machines, this could cause instability.  
**Recommendation**: Add a `pageSize` query parameter and pagination loop in `Get-GCNotificationTopics`. Alternatively, render the topic list lazily or add a local search/filter before display.

---

## DEF-009 — LoadTemplateButton / DeleteTemplateButton Appear Disabled Without Context

**Severity**: Low  
**Area**: Templates tab  
**Evidence**: `MainWindow.xaml` lines 771–772. Both buttons have `IsEnabled="False"` in XAML.  
**Impact**: New users may not understand they need to click a template in the list first. No tooltip or hint text explains this.  
**Recommendation**: Add `ToolTip="Select a template from the list above."` to both buttons.

---

## DEF-010 — Auth State Not Reflected Consistently After Token Expiry

**Severity**: Medium  
**Area**: All authenticated workflows  
**Evidence**: Static analysis of `Update-AuthUiState` and `Invoke-GCRequest`. Token expiry (401 during a workflow) is handled per-workflow with varying error text updates, but the header `TokenStatusText` may not be updated to reflect the expired state until the user explicitly clicks Test Token.  
**Impact**: A user running a Conversation Report mid-session may see a generic backend error when their token has expired, with no clear prompt to re-authenticate.  
**Recommendation**: In `Invoke-GCRequest`, detect 401 responses and emit a dedicated event or call `Update-AuthUiState` with an "Expired" message. This gives users a clear signal to log in again without needing to diagnose the error themselves.
