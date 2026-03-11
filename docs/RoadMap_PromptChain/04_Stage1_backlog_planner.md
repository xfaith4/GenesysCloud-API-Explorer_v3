# Ops Console Lite — Stage 1 Implementation Backlog

Generated: 2026-03-11 | Source of truth: `docs/RoadMap_PromptChain/03_Stage1.md`

---

## 1. Top 10 Backlog Items (Strict Priority Order)

---

### S1-001 — Bridge UI token into module auth context at login

**Priority mapping:** 1 — Fix auth/context reliability

**Why it matters:** `loginButton.Add_Click` (`UI.Run.ps1:1801`) calls `Set-ExplorerAccessToken` at line 1812, which stores the token in `$script:AccessToken` (UI scope only). `$script:GCContext` (module scope, used by `Invoke-GCRequest`) is never populated at login time — it is only populated lazily via `Ensure-OpsInsightsContext` in individual handlers. If any handler calls `Invoke-GCRequest` before `Ensure-OpsInsightsContext` runs, it resolves the token through the `$global:AccessToken` fallback path, which may be stale or empty. Bridging the contexts at login eliminates this race.

**User-visible outcome:** After a successful login, every API call the operator makes — regardless of which tab or handler initiates it — uses the correct, current token. Silent 401 errors caused by context divergence stop occurring.

**Technical scope:**

- `apps/OpsConsole/Resources/UI/UI.Run.ps1:1812` — add `Connect-GCCloud -RegionDomain $script:Region -AccessToken ([string]$newToken)` immediately after the `Set-ExplorerAccessToken` call inside `loginButton.Add_Click`
- `apps/OpsConsole/Resources/UI/UI.Run.ps1:1749` — repeat the same `Connect-GCCloud` call in the settings-dialog save path (where `Set-ExplorerAccessToken` is also called on token update)
- `src/GenesysCloud.OpsInsights/Public/Connect-GCCloud.ps1` — read to confirm parameter names before calling; no changes expected
- New Pester test: `tests/AuthBridge.Offline.Tests.ps1` — mock `Connect-GCCloud` via `Set-GCInvoker`; assert `$script:GCContext.Connected -eq $true` after a simulated login with a valid token

**Dependencies:**

- `src/GenesysCloud.OpsInsights/Public/Connect-GCCloud.ps1` must export `Connect-GCCloud` (confirmed by `GenesysCloud.OpsInsights.Tests.ps1`)
- `$script:Region` must be set before the login handler fires — confirmed by `Set-ExplorerRegion` call at line 1805

**Risk:** Low. Additive change only — one extra function call after the existing `Set-ExplorerAccessToken`. The existing `Ensure-OpsInsightsContext` calls in individual handlers continue to work as a safety net. No data-loss risk. No change to XAML.

**Estimated complexity:** Low

**Acceptance criteria:**

1. After a successful login, run in the PowerShell console: `$script:GCContext.Connected` returns `$true` and `$script:GCContext.AccessToken` is non-empty.
2. New Pester test `tests/AuthBridge.Offline.Tests.ps1` passes: `Invoke-Pester -Path tests/AuthBridge.Offline.Tests.ps1` reports 0 failures.
3. `Invoke-GCRequest` called immediately after login (before any other handler) does not fall back to `$global:AccessToken` — verify by adding a temporary `Write-Host` trace inside `Invoke-GCRequest.ps1:49–72` during dev testing and confirming the explicit-param path is taken.
4. All 21 existing Pester tests remain green: `pwsh -File tools/Test.ps1 -Profile Fast` reports 0 failures.

---

### S1-002 — Add token expiry tracking and guard submit handlers

**Priority mapping:** 1 — Fix auth/context reliability

**Why it matters:** `Set-ExplorerAccessToken` (`UI.PreMain.ps1:885`) sets `$script:TokenValidated = $false` but never records an expiry timestamp. Once validated, the token is assumed valid indefinitely. A Genesys Cloud bearer token expires after 24 hours; an operator leaving the app open overnight will receive a raw 401 error on the next submit with no guidance to re-authenticate.

**User-visible outcome:** If the operator's token has expired (older than 23 hours by default), clicking "Submit" or "Run Report" shows a clear re-authentication prompt — "Session expired. Please log in again." — instead of a raw 401 error or an unhandled exception.

**Technical scope:**

- `apps/OpsConsole/Resources/UI/UI.PreMain.ps1:901` (end of `Set-ExplorerAccessToken`) — add `$script:TokenExpiresAt = (Get-Date).AddHours(23)` after the `$script:OAuthType` assignment
- `apps/OpsConsole/Resources/UI/UI.Run.ps1:4024` (`btnSubmit.Add_Click`) — add expiry guard at the top of the handler:

  ```powershell
  if ($script:TokenExpiresAt -and (Get-Date) -gt $script:TokenExpiresAt) {
      Add-LogEntry "Token expired. Re-authentication required."
      Show-LoginWindow
      return
  }
  ```

- `apps/OpsConsole/Resources/UI/UI.Run.ps1:1913` (`runConversationReportButton.Add_Click`) — add the same expiry guard before the token fetch at line 1924
- `apps/OpsConsole/Resources/UI/UI.Run.ps1:3171` (`runAuditInvestigatorButton.Add_Click`) — add the same expiry guard before the token fetch at line 3192
- New Pester test: `tests/TokenExpiry.Offline.Tests.ps1` — set `$script:TokenExpiresAt` to a past timestamp; assert that the expiry guard triggers (mock `Show-LoginWindow`)

**Dependencies:**

- S1-001 must be complete so that `Connect-GCCloud` is called at login, making `$script:TokenExpiresAt` the single point of expiry truth
- `Show-LoginWindow` must be accessible from within the handler scope (already used at login — confirmed by `UI.PreMain.ps1:1112`)

**Risk:** Low. The guard is a short-circuit return — if the expiry check logic is wrong, the token is still validated by the test-token call and the API itself. No data is written. The only regression risk is setting the expiry window too short; 23 hours is conservative and safe.

**Estimated complexity:** Low

**Acceptance criteria:**

1. After simulating token expiry (set `$script:TokenExpiresAt = (Get-Date).AddHours(-1)` in the console), clicking "Submit" opens the login dialog without making any API call.
2. After simulating token expiry, clicking "Run Report" opens the login dialog without making any API call.
3. `tests/TokenExpiry.Offline.Tests.ps1` passes: `Invoke-Pester -Path tests/TokenExpiry.Offline.Tests.ps1` reports 0 failures.
4. A fresh login resets `$script:TokenExpiresAt` to approximately `(Get-Date).AddHours(23)` — verify with `$script:TokenExpiresAt` in the console post-login.
5. All existing Pester tests remain green.

---

### S1-003 — Standardize auth context helper; remove global token fallback

**Priority mapping:** 1 — Fix auth/context reliability

**Why it matters:** `Ensure-OpsInsightsContext` (`UI.PreMain.ps1:5845`) uses `Set-GCContext` (a low-level internal setter) and, on failure, falls back to writing `$global:AccessToken` (`UI.PreMain.ps1:5856`). This is a fourth token scope and makes debugging auth failures non-deterministic: `Invoke-GCRequest.ps1:49–72` resolves tokens in priority order (explicit param → global → script context → provider), so a stale `$global:AccessToken` can silently win. After S1-001 is complete, `$script:GCContext` is always populated at login; `Ensure-OpsInsightsContext` should call `Connect-GCCloud` (which populates `$script:GCContext`) and never write to `$global:`.

**User-visible outcome:** Auth failures produce a single, predictable path: the module context is either populated via `Connect-GCCloud` or the handler fails fast with a clear error. No silent fall-through to a global token that may belong to a different session.

**Technical scope:**

- `apps/OpsConsole/Resources/UI/UI.PreMain.ps1:5845` — rewrite `Ensure-OpsInsightsContext` body:
  - Replace `Set-GCContext` call with `Connect-GCCloud -RegionDomain $script:Region -AccessToken ($token.Trim())`
  - Remove the `catch` block that writes to `$global:AccessToken`
  - Keep the null-token guard (line 5847) unchanged
- `apps/OpsConsole/Resources/UI/UI.Run.ps1` — verify all four call-sites of `Ensure-OpsInsightsContext` (lines 2555, 2689, 3055, 3199) still compile and behave correctly; no call-site changes expected
- Update `tests/AuthBridge.Offline.Tests.ps1` (from S1-001) to add a test case: `Ensure-OpsInsightsContext` with a valid token populates `$script:GCContext.Connected -eq $true` and does NOT set `$global:AccessToken`

**Dependencies:**

- S1-001 must be complete (establishes `Connect-GCCloud` as the canonical auth call)
- `Connect-GCCloud` must accept `-RegionDomain` and `-AccessToken` parameters (confirmed from triage)
- `$script:Region` must be in scope inside `Ensure-OpsInsightsContext` (it is a script-level variable in the UI scope — verify this is accessible from `UI.PreMain.ps1`)

**Risk:** Medium. Removing the `$global:AccessToken` fallback is a potentially breaking change for any code paths that currently rely on it. Before merging, search the entire codebase for `$global:AccessToken` reads and confirm none remain after this change. The risk is limited to this one fallback path; the primary path (`Connect-GCCloud`) is already tested.

**Estimated complexity:** Low

**Acceptance criteria:**

1. Grep confirms no remaining writes to `$global:AccessToken` in `UI.PreMain.ps1` or `UI.Run.ps1` after the change: `Select-String -Path apps/**/*.ps1 -Pattern '\$global:AccessToken\s*='` returns zero results.
2. `Ensure-OpsInsightsContext` called with a valid token → `$script:GCContext.Connected` is `$true`; `$global:AccessToken` is not set.
3. `Ensure-OpsInsightsContext` called with an empty token → throws with message containing "OAuth token" (existing guard); `$global:AccessToken` is not set.
4. All existing Pester tests pass; `tests/AuthBridge.Offline.Tests.ps1` new test case passes.

---

### S1-004 — Add startup diagnostics with structured output

**Priority mapping:** 2 — Add startup diagnostics and feature gating

**Why it matters:** The current entry point (`GenesysCloudAPIExplorer.ps1:6–41`) loads three modules sequentially and shows a Windows Forms `MessageBox` on failure, but does not check PowerShell version, does not verify that critical resource files exist, and does not emit a structured startup record. When an operator's environment is misconfigured, the error is a raw exception with no actionable guidance.

**User-visible outcome:** On launch, the operator sees a startup check summary (in the app's log panel or a brief status bar message): "Environment OK — PS 7.4, modules loaded, resources verified." On failure, the message is specific: "Startup failed: resource file missing — apps/OpsConsole/Resources/GenesysCloudAPIEndpoints.json. Contact support with Correlation ID: {id}." The full exception still goes to the trace log.

**Technical scope:**

- New file: `apps/OpsConsole/Resources/StartupDiagnostics.ps1` — a pure PowerShell script (no WPF dependency) containing `Invoke-StartupChecks` function that returns a result object: `{ Ok: bool, Checks: [{Name, Pass, Detail}], CorrelationId: guid }`
  - Check 1: `$PSVersionTable.PSVersion.Major -ge 7` — PowerShell 7+ required
  - Check 2: `Get-Module -ListAvailable ThreadJob` (or confirm `Start-ThreadJob` is available in PS 7)
  - Check 3: `Test-Path` for `GenesysCloudAPIEndpoints.json`, `DefaultTemplates.json`, `ExamplePostBodies.json`
  - Check 4: `Test-Path` for `UxTelemetry.ps1`, `UI.PreMain.ps1`, `UI.Run.ps1`
  - Check 5: Emit `Write-UxEvent` with event `startup_ok` or `startup_fail` and the check results as `props`
- `GenesysCloudAPIExplorer.ps1` — dot-source `StartupDiagnostics.ps1` and call `Invoke-StartupChecks` before the module load loop; on failure, surface the specific failing check in the `MessageBox` text alongside the correlation ID
- New Pester test: `tests/StartupDiagnostics.Tests.ps1` — mock `Test-Path` to return false for one resource file; assert `Invoke-StartupChecks` returns `Ok = $false` and the failing check is named correctly

**Dependencies:**

- `UxTelemetry.ps1` must be loadable before the full app starts — assumption: `StartupDiagnostics.ps1` loads it independently, not via the module chain. If `UxTelemetry.ps1` has a WPF dependency that prevents loading before the window, fall back to `Write-Host` only in the startup check and emit the `Write-UxEvent` call after WPF initializes.
- No CI pipeline assumed in this item; the test runs via `pwsh -File tools/Test.ps1`.

**Risk:** Low. The startup check is additive and runs before the module load loop; if it throws, the existing `MessageBox` fallback in `GenesysCloudAPIExplorer.ps1` still catches it. Keep `Invoke-StartupChecks` wrapped in a `try/catch` so a bug in the diagnostic code does not prevent the app from starting.

**Estimated complexity:** Low

**Acceptance criteria:**

1. Remove `GenesysCloudAPIEndpoints.json` temporarily; launch the app; the startup dialog shows a message containing the file name and a correlation ID. Restore the file; app launches normally.
2. `Invoke-StartupChecks` called with `$PSVersionTable.PSVersion.Major -lt 7` (simulate by mocking) → `Ok = $false`, `Checks[0].Name -eq 'PowerShell version'`, `Checks[0].Pass -eq $false`.
3. `tests/StartupDiagnostics.Tests.ps1` passes: `Invoke-Pester -Path tests/StartupDiagnostics.Tests.ps1` reports 0 failures.
4. A `startup_ok` NDJSON entry appears in the telemetry buffer after a normal launch.

---

### S1-005 — Enforce UI/XAML contracts in CI; apply tab status labels

**Priority mapping:** 3 — Stabilize UI/code contracts

**Why it matters:** `tests/OpsConsole.UiContracts.Tests.ps1` verifies that every `FindName` call in `UI.Run.ps1` corresponds to an element in `MainWindow.xaml` — a critical contract that prevents silent `$null` control references at runtime. This test is not tagged for inclusion in the CI Fast profile; if XAML changes break a control reference, it is not caught automatically. Separately, the tab strip currently exposes experimental workflows without any status label, misleading operators into relying on untested features.

**User-visible outcome:** A broken XAML/FindName contract fails the CI build before it reaches operators. Operators see accurate status labels on every tab (`[Experimental]`, `[Advanced]`) so they know at a glance which workflows are hardened.

**Technical scope:**

- `tests/pester.config.ps1` — verify `OpsConsole.UiContracts.Tests.ps1` is included in the `Fast` profile tag filter; add `'UI'` and `'Contract'` tags to the Fast profile if not already present
- `apps/OpsConsole/Resources/UI/MainWindow.xaml` — change tab `Header` attributes (one-line changes each, no layout changes):
  - API Explorer tab: `Header="[Advanced] API Explorer"`
  - Ops Insights / Insight Packs tab: `Header="[Experimental] Ops Insights"`
  - Queue Wait Coverage tab: `Header="[Experimental] Queue Wait Coverage"`
  - Filter Builder tab: `Header="[Experimental] Filter Builder"` (if it has a standalone tab header)
  - Live Subscriptions tab: `Header="[Experimental] Live Subscriptions"`
  - Operational Events tab: `Header="[Experimental] Operational Events"`
  - Ops Dashboard tab: `Header="[Experimental] Ops Dashboard"`
  - Forensic Timeline tab: `Header="[Experimental] Forensic Timeline"`
- `tests/OpsConsole.UiContracts.Tests.ps1` — add a test that asserts tab headers for the above tabs contain the expected prefix strings (use `XDocument` or `XmlDocument` to parse XAML without loading WPF assemblies)

**Dependencies:**

- Assumption: `tests/pester.config.ps1` exists and controls which test tags are included per profile. If the Fast profile uses a file path list instead of tags, add the test file path directly.
- CI workflow (`.github/workflows/ci.yml`) must already exist — created in this session.
- No WPF runtime required for the new XAML label test (parse XAML as XML).

**Risk:** Low. XAML header string changes are cosmetic — no bindings, triggers, or event handlers reference the `Header` text value directly. The contract test addition is purely additive. Regression risk: if any existing test asserts the exact header string (e.g., `Header="API Explorer"`), it will fail and must be updated.

**Estimated complexity:** Low

**Acceptance criteria:**

1. `pwsh -File tools/Test.ps1 -Profile Fast` runs `OpsConsole.UiContracts.Tests.ps1` and all existing assertions pass.
2. Launch the app; the tab strip shows `[Advanced] API Explorer` and `[Experimental] Ops Insights` (and all other labelled tabs) with the correct prefix text.
3. New test assertion: `OpsConsole.UiContracts.Tests.ps1` `'API Explorer tab is labelled Advanced'` passes — verifies `MainWindow.xaml` tab `Header` contains `[Advanced]`.
4. Revert one XAML control name change (break a `FindName` contract); confirm `pwsh -File tools/Test.ps1 -Profile Fast` fails with a clear message naming the missing control.

---

### S1-006 — Offload Conversation Report to background thread

**Priority mapping:** 4 — Harden Conversation Report

**Why it matters:** `runConversationReportButton.Add_Click` (`UI.Run.ps1:1913`) calls `Get-ConversationReport` synchronously on the WPF dispatcher thread. A typical voice conversation report makes 4–6 sequential API calls; each can take 2–5 seconds. During this time the UI is frozen — the operator cannot scroll, cancel, or interact with any control. A progress callback is already defined inline (`UI.Run.ps1:1955`) but all updates run on the same thread, providing no responsiveness benefit.

**User-visible outcome:** After clicking "Run Report", the progress bar advances incrementally, the status label updates with each API call's name, and all other UI controls (tab strip, menu, log panel) remain fully interactive. A "Cancel" interaction (if the operator closes or navigates away) does not leave the UI in a frozen state.

**Technical scope:**

- `apps/OpsConsole/Resources/UI/UI.Run.ps1:1913` — restructure `runConversationReportButton.Add_Click`:
  - Capture all required values (`$convId`, `$token`, `$headers`, `$ApiBaseUrl`) into local variables before starting the job (these cannot be accessed from a background runspace via `$script:` references)
  - Start job: `$job = Start-ThreadJob -ScriptBlock { ... } -ArgumentList $convId, $token, $ApiBaseUrl`
  - Inside the job: call `Get-ConversationReport` with the captured values; use `$using:` variables for any captured script-scope references that must cross the runspace boundary
  - Wire progress updates: define a `$progressCallback` that calls `$Window.Dispatcher.Invoke([action]{ ... })` to update `conversationReportProgressBar` and `conversationReportProgressText` safely from the background thread
  - On completion: `$Window.Dispatcher.Invoke` to call `Show-ConversationTimelineReport` with the report result
  - On error: `$Window.Dispatcher.Invoke` to display the user-friendly error message with correlation ID (see S1-007)
- Import `GenesysCloud.OpsInsights` module inside the job script block (background runspace does not inherit the calling session's modules)
- `apps/OpsConsole/Resources/UI/UI.PreMain.ps1` — no changes to `Get-ConversationReport` or rendering functions

**Dependencies:**

- S1-001 must be complete: `$script:GCContext` must be populated so the module can be initialized inside the job with the correct token
- `Start-ThreadJob` — ships with PowerShell 7+ (`ThreadJob` module). Assumption: the operator machine runs PS 7.0+ (listed as a precondition in `03_Stage1.md`). Verify with `$PSVersionTable.PSVersion.Major` during startup check (S1-004).
- `Get-ConversationReport` must be importable from the background runspace — requires the module path to be passed as an argument list value or via `$using:`

**Risk:** Medium. Background threading in PowerShell/WPF introduces runspace isolation: `$script:` variables are not shared, and module imports must be explicit inside the job. The most likely failure mode is a `CommandNotFoundException` for `Get-ConversationReport` if the module import path is wrong. Mitigation: test the job invocation in isolation with a mock `Get-ConversationReport` before integrating with the full report pipeline. Stage 2 trigger: if `$script:` state corruption occurs (token overwritten mid-report), escalate per `03_Stage1.md` Trigger 2.

**Estimated complexity:** Medium

**Acceptance criteria:**

1. Click "Run Report" with a valid conversation ID; the app window remains fully interactive (scrollable, other tabs clickable) throughout the report.
2. The progress bar value increments at least 3 times during a real report run (or during a mock run with a 2-second sleep between steps).
3. `$Window.Dispatcher.CheckAccess()` returns `$true` inside all UI-update closures (verify during development with a temporary assertion).
4. On a simulated API failure (mock `Invoke-GCRequest` to throw), the error message appears in `conversationReportStatus.Text` within 2 seconds and contains a correlation ID.
5. Running a report twice in succession (without restarting the app) completes both correctly with no state bleed between runs.

---

### S1-007 — Add correlation ID and telemetry to Conversation Report

**Priority mapping:** 4 — Harden Conversation Report

**Why it matters:** The current error handler at `UI.Run.ps1:1913` catches exceptions and logs them via `Add-LogEntry` with the raw exception message. Operators and support engineers have no way to correlate a UI error message with a specific trace log entry. Without a correlation ID, reproducing intermittent failures requires reconstructing the request sequence from timestamps alone.

**User-visible outcome:** Every error message in the Conversation Report panel includes a correlation ID (e.g., "Report failed. Correlation ID: a3bd308f-…"). The NDJSON telemetry file contains `conversation_report_start`, `conversation_report_complete` (with `durationMs`), and `conversation_report_fail` (with `errorCategory`) events that can be queried by correlation ID.

**Technical scope:**

- `apps/OpsConsole/Resources/UI/UI.Run.ps1:1913` — in `runConversationReportButton.Add_Click`:
  - Generate: `$correlationId = [guid]::NewGuid().ToString()` at the very start of the handler
  - Emit: `Write-UxEvent -Event 'conversation_report_start' -Level Info -Module 'ConversationReport' -Props @{ conversationId = $convId; correlationId = $correlationId }`
  - Pass `$correlationId` as an argument into the `Start-ThreadJob` block (from S1-006)
  - On success: emit `Write-UxEvent -Event 'conversation_report_complete' -Level Info -Module 'ConversationReport' -Props @{ durationMs = $elapsed.TotalMilliseconds; correlationId = $correlationId }`
  - On failure: emit `Write-UxEvent -Event 'conversation_report_fail' -Level Error -Module 'ConversationReport' -Props @{ errorCategory = $_.Exception.GetType().Name; correlationId = $correlationId }`; show in UI: `"Report failed. Correlation ID: $correlationId. See trace log for details."`
- `apps/OpsConsole/Resources/UxTelemetry.ps1` — verify `Write-UxEvent` accepts a `Props` hashtable and that the existing schema supports a `correlationId` key in `props`; no changes expected if the schema is open
- `tests/UxTelemetry.Tests.ps1` — add a test case: call `Write-UxEvent` with a `conversation_report_start` event and a `correlationId` prop; assert the buffered NDJSON entry contains the correct event name and correlationId value

**Dependencies:**

- S1-006 must be complete: the job structure must exist before wiring telemetry into it
- `Write-UxEvent` (`UxTelemetry.ps1:115`) must be callable from within the `Start-ThreadJob` block — requires `UxTelemetry.ps1` to be dot-sourced inside the job, or telemetry must be emitted on the dispatcher thread via `Dispatcher.Invoke`
- Assumption: `Write-UxEvent` is a pure function with no WPF dependency (confirmed by `UxTelemetry.Tests.ps1` running offline)

**Risk:** Low. Telemetry calls are fire-and-forget with an internal flush buffer (`UxTelemetry.ps1`). A failure in `Write-UxEvent` must not surface to the operator; wrap all telemetry calls in `try/catch` with a fallback to `Write-Verbose`.

**Estimated complexity:** Low

**Acceptance criteria:**

1. Run a Conversation Report; inspect the telemetry NDJSON file (default location: `$env:TEMP\GenesysApiExplorer.ux.*.ndjson`); confirm a `conversation_report_start` entry exists with a non-empty `correlationId` field.
2. Simulate a report failure (mock API to throw); confirm the UI error text contains the phrase "Correlation ID:" followed by a GUID.
3. Confirm the `conversation_report_fail` NDJSON entry has the same `correlationId` as the `conversation_report_start` entry for the same invocation.
4. `tests/UxTelemetry.Tests.ps1` new test case passes.
5. `Write-UxEvent` failure (mock it to throw) does not prevent the report from completing or the error message from displaying.

---

### S1-008 — Write offline Pester test for Audit Investigator

**Priority mapping:** 5 — Harden one additional high-value workflow (Audit Investigator selected)

**Why it matters:** `Invoke-GCAuditQuery` (`src/GenesysCloud.OpsInsights/Private/Invoke-GCAuditQuery.ps1`) has no offline Pester test. The function is wired and functional (confirmed: `UI.Run.ps1:3210`), but any regression in its query construction, response parsing, or pagination logic will go undetected until an operator hits it in production. The module has a `Set-GCInvoker` mock seam specifically for this purpose.

**User-visible outcome:** Engineering impact only. Developers can run `Invoke-Pester -Path tests/AuditInvestigator.Offline.Tests.ps1` in under 5 seconds to verify the audit query function before any commit.

**Technical scope:**

- New file: `tests/AuditInvestigator.Offline.Tests.ps1`
  - `BeforeAll`: import `GenesysCloud.OpsInsights` module; call `Set-GCInvoker` with a mock that returns a canned async-query response sequence: `{ status: 'running' }` on the first poll, `{ status: 'fulfilled' }` on the second, then fixture `entities` array on the results call
  - Test 1: `Invoke-GCAuditQuery -Interval '2026-03-01T00:00:00Z/2026-03-02T00:00:00Z'` returns a result object with `.Entities` containing the expected fixture count
  - Test 2: With a `ServiceName` parameter, the mock invoker receives a request body containing the `serviceName` filter — assert via a captured-call spy
  - Test 3: With a `Filters` array containing `@{ name = 'userId'; value = 'user-123' }`, the request body contains the userId filter
  - Test 4: If the poll returns `{ status: 'failed' }`, `Invoke-GCAuditQuery` throws a terminating error with a descriptive message
  - `AfterAll`: `Set-GCInvoker -Reset`
- `tests/pester.config.ps1` — verify `AuditInvestigator.Offline.Tests.ps1` is included in the Fast profile (add to the file list if the config uses explicit paths)
- Read `src/GenesysCloud.OpsInsights/Private/Invoke-GCAuditQuery.ps1` first to confirm the exact parameter names and response structure before writing the fixture data

**Dependencies:**

- `Set-GCInvoker` mock seam confirmed available (`Invoke-GCRequest.ps1:156–172`)
- `Invoke-GCAuditQuery` confirmed in `src/GenesysCloud.OpsInsights/Private/Invoke-GCAuditQuery.ps1` — read the file to confirm it is dot-sourced by the module and accessible after `Import-Module GenesysCloud.OpsInsights`
- Fixture data must match the actual response schema returned by `GET /api/v2/audits/query/{transactionId}/results` — use the API catalog (`GenesysCloudAPIEndpoints.json`) to verify the response model before writing fixtures

**Risk:** Low. Test-only change; no production code modifications. The only risk is writing a fixture that does not match the real API response schema, which would cause tests to pass but fail against the live API. Mitigate by verifying the fixture structure against the Swagger spec.

**Estimated complexity:** Low

**Acceptance criteria:**

1. `Invoke-Pester -Path tests/AuditInvestigator.Offline.Tests.ps1` reports 4 passing tests and 0 failures.
2. `pwsh -File tools/Test.ps1 -Profile Fast` includes and passes the new test file.
3. Test 4 (failed-status handling): mock returns `{ status: 'failed' }`; `Should -Throw` assertion passes.
4. Tests run offline with no network access (set `Set-GCInvoker` mock; confirm no actual HTTP calls are made by checking that the mock captures all calls).

---

### S1-009 — Background thread, correlation ID, and telemetry for Audit Investigator

**Priority mapping:** 5 — Harden one additional high-value workflow (Audit Investigator)

**Why it matters:** `runAuditInvestigatorButton.Add_Click` (`UI.Run.ps1:3171`) calls `Invoke-GCAuditQuery` synchronously on the dispatcher thread — the same threading defect as the Conversation Report before S1-006. An audit query for a 24-hour window may poll for 10–15 seconds, freezing the UI. The existing error handler at line 3225 shows the raw exception message with no correlation ID, making failures untraceable.

**User-visible outcome:** Clicking "Run Audit Query" starts a background job; `auditStatusText` updates incrementally ("Querying…", "Polling for results…", "Loading entries…"); the UI remains interactive. Failures show: "Audit query failed. Correlation ID: {id}. See trace log." Telemetry records `audit_query_start/complete/fail` events.

**Technical scope:**

- `apps/OpsConsole/Resources/UI/UI.Run.ps1:3171` — restructure `runAuditInvestigatorButton.Add_Click`:
  - Generate `$correlationId = [guid]::NewGuid().ToString()` at the top of the handler
  - Capture `$interval`, `$filters`, `$service`, `$token`, `$correlationId` into local variables
  - Start job: `$job = Start-ThreadJob -ScriptBlock { ... } -ArgumentList $interval, $service, $filters, $token, $correlationId`
  - Inside the job: import `GenesysCloud.OpsInsights`; call `Invoke-GCAuditQuery -Interval $interval -ServiceName $service -Filters $filters -MaxResults 400`
  - On completion: `$Window.Dispatcher.Invoke` to populate `$script:AuditInvestigatorEvents` and update `auditStatusText` and `auditTimelineText`
  - On error: `$Window.Dispatcher.Invoke` to set `auditStatusText.Text = "Audit query failed. Correlation ID: $correlationId. See trace log."`
  - Emit `Write-UxEvent` events: `audit_query_start` (with interval and correlationId), `audit_query_complete` (with record count and durationMs), `audit_query_fail` (with errorCategory and correlationId)
- `apps/OpsConsole/Resources/UI/UI.PreMain.ps1` — no changes to `Invoke-GCAuditQuery` or `Format-AuditTimelineText`

**Dependencies:**

- S1-006 must be complete: use the same `Start-ThreadJob` + `Dispatcher.Invoke` pattern established for the Conversation Report
- S1-007 must be complete: use the same correlation ID and `Write-UxEvent` wiring pattern
- S1-008 must be complete: offline tests must pass before the handler is modified to ensure regression detection
- S1-003 must be complete: `Ensure-OpsInsightsContext` (line 3199) must be called inside the job after `Connect-GCCloud` to initialize the module context

**Risk:** Medium. Same threading risks as S1-006. Additionally, the `$script:AuditInvestigatorEvents` observable collection must be updated only via `Dispatcher.Invoke` to avoid cross-thread WPF binding exceptions. Mitigation: wrap the entire `Add` loop in a single `Dispatcher.Invoke` block rather than calling `Dispatcher.Invoke` per item.

**Estimated complexity:** Medium

**Acceptance criteria:**

1. Click "Run Audit Query" with a valid date range; the UI remains fully interactive (other tabs clickable) while the status label updates from "Querying…" to "Polling…" to the final record count.
2. Simulate a query failure (mock `Invoke-GCAuditQuery` to throw inside the job); the `auditStatusText` shows "Audit query failed. Correlation ID: …" within 2 seconds.
3. Inspect the telemetry NDJSON: confirm `audit_query_start` and `audit_query_complete` (or `audit_query_fail`) entries with matching `correlationId` values.
4. Run the query twice consecutively; confirm both queries complete with no observable state bleed (second query does not display first query's results).
5. `tests/AuditInvestigator.Offline.Tests.ps1` (from S1-008) continues to pass after the handler change.

---

### S1-010 — Demote API Explorer to Advanced; label all Experimental tabs

**Priority mapping:** 6 — Demote Explorer to utility mode

**Why it matters:** The tab strip currently presents every workflow at equal visual prominence, implying they are all production-ready. Operators navigating the API Explorer tab for an ops workflow may encounter an unfamiliar interface; operators clicking Ops Insights or Live Subscriptions may rely on workflows that have no smoke test coverage. Clear status labels set accurate expectations and reduce support noise.

**User-visible outcome:** The API Explorer tab is visually differentiated as `[Advanced]` — clearly a developer/power-user tool. All experimental tabs show `[Experimental]` in their headers. No tab is removed or hidden; access is unchanged. Operators can still use every feature.

**Technical scope:**

- `apps/OpsConsole/Resources/UI/MainWindow.xaml` — update `Header` attributes on 8 tabs (one-line change each; no other XAML modifications):
  - API Explorer → `[Advanced] API Explorer`
  - Ops Insights → `[Experimental] Ops Insights`
  - Queue Wait Coverage → `[Experimental] Queue Wait Coverage`
  - Live Subscriptions → `[Experimental] Live Subscriptions`
  - Operational Events → `[Experimental] Operational Events`
  - Ops Dashboard → `[Experimental] Ops Dashboard`
  - Forensic Timeline → `[Experimental] Forensic Timeline`
  - Filter Builder (if it has a standalone tab header) → `[Experimental] Filter Builder`
- `tests/OpsConsole.UiContracts.Tests.ps1` — update or add assertions that verify each of the 8 tab headers contains the expected prefix (parse XAML as XML; assert string contains `[Advanced]` or `[Experimental]` as appropriate)
- No handler code changes; no XAML element additions or removals

**Dependencies:**

- S1-005 must be complete: the UI contracts test infrastructure must already be in place and running in CI before XAML changes are made, so any accidental breakage is caught immediately
- Assumption: each tab's `Header` attribute is a plain string (not a `DataTemplate` or style binding). Verify by reading the relevant `TabItem` elements in `MainWindow.xaml` before making changes.

**Risk:** Very low. String changes to `Header` attributes have no functional impact. The only regression risk is if any existing test asserts exact header strings (e.g., `Header="API Explorer"` — not `Header="[Advanced] API Explorer"`). Check existing tests before applying the change.

**Estimated complexity:** Low

**Acceptance criteria:**

1. Launch the app; the tab strip shows `[Advanced] API Explorer`, `[Experimental] Ops Insights`, and all other labelled tabs with the correct prefix text.
2. All 8 specified tabs are reachable and functional after the header change — click each; confirm the tab content loads without errors.
3. `tests/OpsConsole.UiContracts.Tests.ps1` new label assertions pass: `Invoke-Pester -Path tests/OpsConsole.UiContracts.Tests.ps1` reports 0 failures.
4. `pwsh -File tools/Test.ps1 -Profile Fast` passes (no regressions from header string changes).

---

### S1-011 — Update local runbook and write Stage 1 release notes (extra, small)

**Priority mapping:** Supports all six — Documentation baseline for operator handoff

**Why it matters:** Without updated documentation, operators launching the Stage 1 build have no reference for credential setup, the meaning of tab labels, or known experimental limitations. Release notes also record the 7 template corrections applied during triage.

**User-visible outcome:** `docs/ux/01-local-runbook.md` contains accurate Stage 1 launch steps. A `docs/release-notes/Stage1.md` entry exists listing the 7 template fixes and the 5 hardening changes.

**Technical scope:**

- `docs/ux/01-local-runbook.md` — add or update sections: prerequisites (PS 7+), credential setup (access token or client credentials), how to run a Conversation Report, how to run an Audit Query, what `[Advanced]` and `[Experimental]` labels mean, how to find the trace log
- `docs/release-notes/Stage1.md` (new file) — list: 7 template path corrections (from `02_repo_triage_agent.md` Appendix), auth context bridge (S1-001/S1-003), token expiry guard (S1-002), background-thread reports (S1-006/S1-009), tab labelling (S1-010)
- No code changes

**Dependencies:**

- All S1-001 through S1-010 must be complete before writing final release notes; this item is last
- Assumption: `docs/ux/01-local-runbook.md` exists. If it does not, create it.

**Risk:** None. Documentation only.

**Estimated complexity:** Low

**Acceptance criteria:**

1. `docs/ux/01-local-runbook.md` contains a "Prerequisites" section listing PS 7+ and the module load sequence.
2. `docs/ux/01-local-runbook.md` contains a "Known Experimental Features" section listing all `[Experimental]` tabs.
3. `docs/release-notes/Stage1.md` lists all 7 template corrections by name and all 5 hardening changes by backlog ID.

---

## 2. Suggested Implementation Sequence

| Step | Item(s) | Rationale |
| --- | --- | --- |
| 1 | S1-001 | Auth bridge is the foundation: every subsequent item that interacts with `$script:GCContext` depends on it being populated correctly at login time. |
| 2 | S1-002 | Token expiry guard is a direct continuation of the auth fix; adds one variable write and three guard checks with no new dependencies. |
| 3 | S1-003 | Standardizing `Ensure-OpsInsightsContext` completes the auth consolidation and removes the `$global:AccessToken` fallback before any new code paths are added. |
| 4 | S1-004 | Startup diagnostics stand alone (no UI dependencies); adding them early gives the CI and dev loop a structured signal before deeper changes begin. |
| 5 | S1-005 | UI contract tests must be in the Fast CI profile before any XAML changes (S1-010) are applied; tab labels are a prerequisite for S1-010. |
| 6 | S1-006 | Conversation Report background thread is the highest-impact UX change; it must be stable before adding telemetry on top of it in S1-007. |
| 7 | S1-007 | Correlation ID and telemetry for Conversation Report are wired into the job structure established by S1-006; they cannot proceed independently. |
| 8 | S1-008 | Audit Investigator offline tests give regression coverage before the handler is modified; writing the test first (test-first) reduces the risk of S1-009. |
| 9 | S1-009 | Audit Investigator background thread + telemetry mirrors the Conversation Report pattern from S1-006/S1-007; do it after those patterns are proven. |
| 10 | S1-010 | Tab labelling is cosmetic and low-risk; doing it last avoids any accidental conflict with the structural changes in S1-005. |
| 11 | S1-011 | Documentation is written last, after all implementation is verified. |

---

## 3. Fastest Path to First Usable Internal Release

### Definition of "Usable"

An internal release is usable when:

- An operator can authenticate for any of the 7 supported regions without silent token failures.
- An operator can enter a conversation ID and receive a full Conversation Report with a non-frozen UI.
- All Pester tests pass and CI is green.
- Every error message includes a correlation ID the operator can quote to support.

This does **not** require the Audit Investigator to be fully hardened (that is Stage 1 complete, not the first internal release). The Audit Investigator tab remains accessible and functional but unlabelled as hardened.

### Minimal Subset: S1-001 + S1-002 + S1-004 + S1-006 + S1-007

| Step | Task | Elapsed time |
| --- | --- | --- |
| 1 | **S1-001 implementation** — add `Connect-GCCloud` call in `loginButton.Add_Click` (line 1812) and the settings save path (line 1749); write `tests/AuthBridge.Offline.Tests.ps1`; run `pwsh -File tools/Test.ps1 -Profile Fast` to verify green | 0.5 days |
| 2 | **S1-002 implementation** — add `$script:TokenExpiresAt` in `Set-ExplorerAccessToken` (line 901); add expiry guards in `btnSubmit.Add_Click` (line 4024), `runConversationReportButton.Add_Click` (line 1924), `runAuditInvestigatorButton.Add_Click` (line 3192); write `tests/TokenExpiry.Offline.Tests.ps1`; verify green | 0.5 days |
| 3 | **S1-004 implementation** — write `apps/OpsConsole/Resources/StartupDiagnostics.ps1`; dot-source it in `GenesysCloudAPIExplorer.ps1`; write `tests/StartupDiagnostics.Tests.ps1`; verify green | 0.5 days |
| 4 | **S1-006 implementation** — restructure `runConversationReportButton.Add_Click` to use `Start-ThreadJob`; capture state variables; wire `Dispatcher.Invoke` for progress and completion; test manually with a real conversation ID on a dev machine; confirm UI stays interactive | 1.5 days |
| 5 | **S1-007 implementation** — add `$correlationId` generation and `Write-UxEvent` calls to the Conversation Report handler; verify telemetry NDJSON output; update `tests/UxTelemetry.Tests.ps1`; run full test suite | 0.5 days |
| 6 | **Smoke test and release packaging** — run `tools/Run-UxSimulations.ps1` (confirm 100%); run `tools/Build.ps1` (confirm green); have one operator run a Conversation Report end-to-end and confirm no UI freeze and a correlation ID appears in any error; tag the release | 0.5 days |

Total estimated elapsed time: 4 person-days

Release is not usable if: any Pester test fails, the UI freezes during a report, or a successful report produces no output in the UI.

---

## 4. Items Explicitly Deferred to Stage 2

| Item | Rationale |
| --- | --- |
| Extract `UI.PreMain.ps1` into scoped modules | 6,763-line monolith; extraction is a major refactor with high merge-conflict risk. Stage 1 treats the file as append-only. |
| Extract `UI.Run.ps1` into scoped handlers | Same rationale as above; 4,458 lines. Stage 2 scope: thin WPF dispatcher + dedicated handler modules. |
| Consolidate token scopes via `Get-GCAuthContext` / `Set-GCAuthContext` | Requires removing `$global:AccessToken` from all call sites across both monoliths simultaneously. Deferred until monolith extraction enables safe, atomic refactoring. |
| Live Subscriptions WebSocket hardening | WebSocket lifecycle (connect, reconnect, graceful close) is unverified. Defer until a live org smoke test can be executed against the notification channel. |
| Ops Insights / Insight Packs end-to-end testing | No offline test for the UI path; live org required. Promote to Stable in Stage 2 after `Invoke-GCInsightPack` UI smoke test passes. |
| Queue Wait Coverage promotion to Stable | Backend tests pass; UI wiring confirmation requires a live org. Defer smoke test to Stage 2. |
| Filter Builder promotion to Stable | `UI.FilterBuilder.Regression.Tests.ps1` exists but must pass clean against a live org before the `[Experimental]` label is removed. |
| Ops Dashboard, Forensic Timeline, Operational Events | Experimental with partial implementation; not Stage 1 priority workflows. |
| Parallel job fan-out for multi-endpoint reports | Stage 2 performance enhancement if Conversation Report cannot meet the 30-second target with the `Start-ThreadJob` single-job approach. |
| Windows Credential Manager / SecretManagement integration | Persistent token storage across sessions is a quality-of-life improvement. In-memory bearer token is sufficient for Stage 1 shift use. |
| Integration / live-API regression test suite | Requires a Genesys Cloud sandbox org with known fixture data. Cannot be automated in CI without dedicated test credentials. |
| CI code coverage reporting | `tools/Test.ps1` supports `EnableCoverage`; wiring it into CI and setting a minimum threshold is a Stage 2 hardening step after baseline coverage is established. |
