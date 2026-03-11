Genesys Cloud API Explorer v3 — Stage 1 Salvage Triage Report
1. Executive Summary
Recommend Stage 1 salvage. The core transport layer (Invoke-GCRequest.ps1) is well-structured, mockable, and includes retry/backoff logic. The module boundary between GenesysCloud.OpsInsights and the WPF shell is clean enough to be tested in isolation, evidenced by 21 Pester test files that are almost all offline-capable. The primary liability is a UI monolith — UI.PreMain.ps1 (6,763 lines) and UI.Run.ps1 (4,458 lines) — which concentrates all auth, rendering, and workflow logic in two un-scoped flat files. The Conversation Report workflow has a clear function boundary (Get-ConversationReport/Show-ConversationTimelineReport) and a dedicated XAML-wired button (runConversationReportButton → UI.Run.ps1:1913). Seven default templates were confirmed to reference non-existent API paths (just fixed), which is a documentation-drift indicator, not a core transport failure. Stage 2 is not warranted because the transport, module, and data layers are fundamentally sound.

2. Working Nucleus
Component	Path	Evidence	Why Reliable
Root entry point	GenesysCloudAPIExplorer.ps1:6–41	Start-GenesysCloudApiExplorer loads three modules sequentially; Windows Forms MessageBox guards startup failure	Single-responsibility; no business logic here
Module loader	apps/OpsConsole/OpsConsole.psm1:15–23	Exports only Start-GCOpsConsole; dots GenesysCloudAPIExplorer.UI.ps1	Minimal surface; single export
Core transport	src/GenesysCloud.OpsInsights/Public/Invoke-GCRequest.ps1:2–295	$script:GCInvoker mock seam (line 156–172); retry loop with 429/5xx handling (lines 222–286); Set-GCInvoker swap in tests	Tested offline; Retry-After honored; auth header redacted in traces
Auth context	src/GenesysCloud.OpsInsights/GenesysCloud.OpsInsights.psm1:6–26	$script:GCContext object with Connected, AccessToken, TokenProvider, BaseUri; Connect-GCCloud.ps1:22–28 populates it	Self-contained; tests can inject context without WPF
Template store	apps/OpsConsole/Resources/DefaultTemplates.json	68 templates, all 68 now validated against GenesysCloudAPIEndpoints.json (634K-line Swagger spec) by Run-UxSimulations.ps1	Simulation regression catches catalog drift
API catalog	apps/OpsConsole/Resources/GenesysCloudAPIEndpoints.json	Full Swagger spec; Load-PathsFromJson at UI.PreMain.ps1:1495 locates paths section	Statically vendored; no network required at startup
Pester test suite	tests/*.Tests.ps1 (21 files)	tools/Test.ps1:19–23 requires Pester 5.0+; build throws if FailedCount > 0	Offline tests use Set-GCInvoker mock; contract tests cover module exports
UX telemetry	apps/OpsConsole/Resources/UxTelemetry.ps1:1–143	NDJSON buffer (threshold=5, 4s auto-flush); Write-UxEvent writes ts, session, event, props	Has its own UxTelemetry.Tests.ps1 and UxTelemetry.Exhaustive.Tests.ps1
3. Structural Liabilities
1. UI Monolith — UI.PreMain.ps1 (6,763 lines) + UI.Run.ps1 (4,458 lines)
Evidence: Two flat .ps1 files contain all auth helpers, all rendering functions, all event handlers, all workflow orchestration, and all telemetry wiring with no internal module boundaries. A single Set-DesignSystemResources call (line 116), the rage-click queue (line 76), insight pack catalog loading (line 249), conversation timeline rendering (line 3083), and the 75+ click handlers all live in the same scope.

Impact: Large. Any auth or transport change ripples through files you cannot unit-test without loading WPF. Any refactor risks breaking unrelated handlers.

Containment: For Stage 1, treat these files as append-only for new functionality. Extract only functions that have no UI control references into a UI.Logic.ps1 helper before touching them.

2. Three-Scope Token Ambiguity
Evidence: Invoke-GCRequest.ps1:49–72 resolves the access token in priority order: explicit parameter → $global:AccessToken → $script:GCContext.AccessToken → $script:GCContext.TokenProvider. Meanwhile, Set-ExplorerAccessToken (UI.PreMain.ps1:885) stores the token in $script:AccessToken (a fourth variable). A test-token success updates $script:TokenValidated (UI.Run.ps1:1847) but does not push the token into $script:GCContext, meaning the module-level transport may use a stale token if the UI context is not re-synced.

Impact: Medium. Silent auth failures after token rotation. Difficult to reproduce without a live org.

Containment: Add a one-line bridge in loginButton.Add_Click and the test-token success path: Connect-GCCloud -RegionDomain $region -AccessToken (Get-ExplorerAccessToken) to populate $script:GCContext from the UI token.

3. No CI Pipeline
Evidence: No .github/workflows/ directory found. tools/Build.ps1 exists and invokes Pester, but it is only run manually.

Impact: Medium. Any commit can break tests silently. The 7 bad template paths caught by the simulation today would have been invisible without the simulation regression.

Containment: Add a minimal GitHub Actions workflow that runs pwsh -File tools/Build.ps1 on push. 2-hour effort.

4. Synchronous API calls on WPF Dispatcher thread
Evidence: btnSubmit.Add_Click (UI.Run.ps1:4024) calls Invoke-GCRequest inline in the click handler without any Dispatcher.InvokeAsync or Start-Job/Start-ThreadJob. runConversationReportButton.Add_Click (UI.Run.ps1:1913) calls Get-ConversationReport the same way. The conversation report calls multiple downstream endpoints sequentially (Get-GCConversationDetails, Get-GCConversationTimeline, Merge-GCConversationEvents, etc.) from UI.PreMain.ps1:3394–3978.

Impact: Medium. UI freezes during any multi-step report query. Rage-click detection is already wired ($script:SubmitClickTimes, line 76) but can't prevent the freeze.

Containment: Wrap the two critical handlers in Start-ThreadJob with Dispatcher callbacks for progress updates. Target the conversation report first — it has a ProgressCallback parameter already wired in (UI.Run.ps1:1954–1983).

5. No Token Expiry Tracking
Evidence: $script:GCContext (GenesysCloud.OpsInsights.psm1:6–26) has no ExpiresAt or IssuedAt field. Set-ExplorerAccessToken (UI.PreMain.ps1:885) sets $script:TokenValidated = $false on update but there is no scheduled expiry re-prompt. Once validated, the token is assumed valid indefinitely.

Impact: Small in lab use; Medium in production operator shifts. Operators receive 401s mid-investigation with no clear error path.

Containment: Add ExpiresAt = (Get-Date).AddHours(23) to Set-ExplorerAccessToken and check (Get-Date) -gt $script:TokenExpiresAt in btnSubmit.Add_Click before the API call, surfacing a re-auth prompt.

4. Workflow Maturity Table
Workflow	Status	Key scripts / XAML	Evidence	Remediation / Effort
Auth / Login	Working	UI.PreMain.ps1:885–1160; UI.Run.ps1:1800–1867	Login button handler wired; test-token calls GET /api/v2/users/me (line 1844); 7 regions supported	Add token-expiry check: S
API Explorer (submit, history, schema)	Working	UI.Run.ps1:4024+; UI.PreMain.ps1:1495–1586	Submit handler validates parameters, builds request, calls Invoke-GCRequest; catalog loaded from 634K Swagger spec	Move to background thread: M
Templates (save/load/delete)	Working	UI.PreMain.ps1:5416–5515; UI.Run.ps1:3793–3910	Save-TemplatesToDisk / Load-TemplatesFromDisk verified by simulation; 68 templates all catalog-valid after today's fixes	None needed
Favorites	Working	UI.PreMain.ps1:5359–5414; UI.Run.ps1:1611	Round-trip tested by simulation; Save-FavoritesToDisk / Get-FavoritesFromDisk functional	None needed
Conversation Report	Working	UI.PreMain.ps1:3083–4596; UI.Run.ps1:1913–2033	Get-ConversationReport → Show-ConversationTimelineReport; ProgressCallback parameter exists; export wired	Move to background thread: M
Inspect Response (data inspector)	Working	UI.PreMain.ps1:2872–2965; UI.Run.ps1:1719	Show-DataInspector + Populate-InspectorTree; inspectResponseButton.Add_Click wired	None needed
Export (PS script, cURL, CSV, Excel)	Working	UI.PreMain.ps1:1958–2142, 6577–6628; UI.Run.ps1:656	Export-PowerShellScript, Export-CurlCommand, Save-CollectionAsCsv, Export-SimpleExcelWorkbook all present	None needed
Job Watch (async poll)	Working	UI.PreMain.ps1:5202–5345; tab wired in XAML	Start-JobPolling, Get-JobStatus, Fetch-JobResults present; polling timer logic visible	None needed
Filter Builder	Partial	UI.PreMain.ps1:2378–2783	Initialize-FilterBuilderControl, Build-FilterFromInput exist; dedicated regression test UI.FilterBuilder.Regression.Tests.ps1 present	Run regression tests to confirm: S
Ops Insights / Insight Packs	Partial	UI.PreMain.ps1:249–528; UI.Run.ps1:2324–2651	Catalog loads from insightpacks/compositions/*.json; Invoke-GCInsightPack exported; no offline test for the UI path	Write integration smoke test: M
Audit Investigator	Partial	UI.Run.ps1 (handler line ~2800+); MainWindow.xaml (AuditStartInput, AuditEndInput, RunAuditInvestigatorButton)	XAML inputs and button present; handler calls Invoke-GCAuditQuery from src/…/Private/Invoke-GCAuditQuery.ps1; no dedicated Pester test	Write Pester mock test: S
Queue Wait Coverage	Partial	src/GenesysCloud.OpsInsights/Public/Get-GCQueueWaitCoverage.ps1; XAML inputs wired	QueueWaitCoverage.Offline.Tests.ps1 present; UI path not confirmed to be complete	Run offline tests: S
Live Subscriptions	Experimental	UI/Tabs/LiveSubscriptions.Tab.ps1; XAML TopicPresetCombo, EventsList	Helper functions (Add-LiveSubscriptionEvent, Resolve-NotificationRecords) exist; WebSocket connection lifecycle and error handling not confirmed	Manual smoke with real org: L
Operational Events	Experimental	UI.Run.ps1 (OperationalEventsButton handler); MainWindow.xaml	Handler and XAML wired; definition editor and live-mode toggle referenced; no test coverage found	Not Stage 1 priority
Ops Dashboard	Experimental	UI.Run.ps1 (dashboard tab handlers); multiple export functions	Export functions (Export-DivisionQosSummary, etc.) at UI.PreMain.ps1:6620–6628; scheduling logic partially visible	Not Stage 1 priority
Forensic Timeline	Experimental	UI.Run.ps1 (Forensic tab); MainWindow.xaml	Tab present; export button referenced; no functions for forensic-specific data transforms found	Not Stage 1 priority
5. Top 5 Salvage Opportunities
Add CI (GitHub Actions running tools/Build.ps1) — tools/Build.ps1 + tools/Test.ps1 already exist; add .github/workflows/ci.yml calling pwsh -File tools/Build.ps1. S effort, 2 hours. Prevents silent regressions from any future change. One-line fix: create the workflow file and push.

Bridge UI token to module context in login handler — In UI.Run.ps1:1800–1817 (loginButton.Add_Click), add Connect-GCCloud -RegionDomain $region -AccessToken (Get-ExplorerAccessToken) after Set-ExplorerAccessToken. S effort, 30 minutes. Ensures Invoke-GCRequest always uses the current UI token. One-line fix: one Connect-GCCloud call after the existing Set-ExplorerAccessToken line.

Background-thread the Conversation Report — UI.Run.ps1:1913 handler calls Get-ConversationReport synchronously; wrap in Start-ThreadJob using the existing ProgressCallback parameter (line 1954). M effort, 4–6 hours. Eliminates UI freeze on the primary investigation workflow.

Audit Investigator Pester smoke test — Invoke-GCAuditQuery is in src/…/Private/Invoke-GCAuditQuery.ps1; write a mock test with Set-GCInvoker returning fixture data. Resolves Partial status for the second operator workflow. S effort, 2–3 hours. One-line fix: copy QueueWaitCoverage.Offline.Tests.ps1 structure as the test skeleton.

Token expiry re-prompt — Add $script:TokenExpiresAt = (Get-Date).AddHours(23) to Set-ExplorerAccessToken (UI.PreMain.ps1:885); guard btnSubmit.Add_Click with a (Get-Date) -gt $script:TokenExpiresAt check that surfaces the login dialog. S effort, 1 hour. Prevents silent 401s mid-investigation. One-line fix: add the guard at the top of the submit handler.

6. Top 5 Reasons Salvage Might Fail
UI monolith change costs compound fast. Both UI.PreMain.ps1 (6,763 lines) and UI.Run.ps1 (4,458 lines) have no internal scope boundaries. A single auth refactor requires reading ~11K lines of context. If two workflows need simultaneous changes, merge conflicts in these files will be expensive and error-prone.

No CI means test value is theoretical. The 21 Pester test files are only run when a developer manually invokes tools/Build.ps1. The 7 invalid template paths in DefaultTemplates.json existed undetected until the simulation was written today. Any future template or catalog change can regress silently.

Token scope split causes intermittent auth failures. UI.PreMain.ps1:885 stores $script:AccessToken; GenesysCloud.OpsInsights.psm1:6 stores $script:GCContext.AccessToken; Invoke-GCRequest.ps1:49 also checks $global:AccessToken. Under certain startup orderings or module reload scenarios, the three scopes will diverge. Debugging this requires step-through in a live WPF session.

Synchronous UI thread API calls block and degrade trust. The Conversation Report (UI.Run.ps1:1913) and Submit handler (UI.Run.ps1:4024) both run multi-step API sequences on the dispatcher thread. A single 5-second API call makes the app appear frozen. If operators close/reopen the window they may trigger a second request, creating race conditions in $script: state.

No integration tests and no fixture org. tests/Integration.LiveApi.Smoke.Tests.ps1 exists but requires real Genesys Cloud credentials and a live org. All other offline tests use Set-GCInvoker mocks, which means real API changes (endpoint renames, response shape changes) go undetected until a user reports a failure. Seven templates were already stale for this reason.

7. Recommendation: Proceed with Stage 1 Salvage
Proceed with Stage 1 salvage.

Ordered 2-week checklist (developer + tester roles):

[Dev, Day 1–2] Add GitHub Actions CI — create .github/workflows/ci.yml running pwsh -File tools/Build.ps1 on push and PR. Acceptance: green badge on main branch.

[Dev, Day 2] Bridge UI token to $script:GCContext — add Connect-GCCloud call in loginButton.Add_Click and the settings dialog save path. Write a Pester mock test confirming the context is populated after login. Acceptance: $script:GCContext.Connected -eq $true after the test.

[Dev, Day 3–5] Background-thread Conversation Report — wrap Get-ConversationReport call in Start-ThreadJob; use Dispatcher.Invoke for progress callbacks and UI updates. Acceptance: UI remains interactive during a report run; progress bar increments.

[Dev + Tester, Day 6–8] Confirm Audit Investigator end-to-end — write offline Pester mock test for Invoke-GCAuditQuery; manually smoke-test with a real org if available. Acceptance: audit results populate in AuditEventsList for a known date range.

[Dev, Day 9] Token expiry re-prompt — add expiry timestamp and guard check in submit handler. Acceptance: after injecting an expired timestamp, clicking Submit shows the login dialog rather than returning a raw 401 error.

[Tester, Day 10–14] Run tools/Build.ps1 after each of the above changes; confirm 100% Pester pass and Run-UxSimulations.ps1 100% completion rate. Document any new failures as bugs before merging.

8. Confidence Level and Rationale
Confidence: 4 / 5

The module boundary between GenesysCloud.OpsInsights (clean, tested, mockable) and the WPF shell (large, untested in isolation) is clear and the working nucleus is verifiable without running the full app. The 21 Pester tests and the new simulation together provide concrete, evidence-backed signal about what is and isn't working. The score is not 5 because no live-API smoke test was run in this session, the exact state of the Audit Investigator handler wiring was confirmed from file reads rather than execution, and the WebSocket lifecycle of Live Subscriptions is unverified. The three missing areas (live-API validation, Audit handler execution, Live Subscriptions WebSocket) would each need a live org to confirm and push confidence to 5.