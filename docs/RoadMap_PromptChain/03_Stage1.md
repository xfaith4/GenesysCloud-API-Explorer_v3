# Ops Console Lite — Stage 1 Salvage Plan

Generated: 2026-03-11 | Source of truth: `docs/RoadMap_PromptChain/02_repo_triage_agent.md`

---

## 1. Stage 1 Target Product Definition

Ops Console Lite targets the **senior cloud operations engineer** who needs to investigate a specific Genesys Cloud conversation or audit a set of platform events without reconstructing raw API calls from scratch. The Stage 1 product promise is: authenticate once, run a Conversation Report from a single conversation ID, optionally run an Audit query over a date range, and export the results — all without touching the PowerShell prompt. The application must not freeze, must show meaningful progress, and must surface a correlation ID in every error message so support can trace failures. Everything outside those two hardened workflows is available but labelled clearly as experimental or a utility.

---

## 2. What to Keep

- **`src/GenesysCloud.OpsInsights/Public/Invoke-GCRequest.ps1`** — canonical REST transport with retry/backoff, 429 handling, mock seam, and auth-header redaction. Do not touch.
- **`src/GenesysCloud.OpsInsights/Public/Connect-GCCloud.ps1`** — auth context setter; clean boundary. Keep as-is; only add a call-site in the UI login handler.
- **`apps/OpsConsole/Resources/UI/UI.PreMain.ps1:3083–4596`** — `Get-ConversationReport`, `Show-ConversationTimelineReport`, and all `Format-*` / `Get-GC*` rendering helpers. Proven working; treat as stable.
- **`apps/OpsConsole/Resources/UI/UI.Run.ps1:1913–2033`** — `runConversationReportButton.Add_Click` handler. Keep wiring; only modify to offload to `Start-ThreadJob`.
- **`src/GenesysCloud.OpsInsights/Private/Invoke-GCAuditQuery.ps1`** — audit backend. Keep as-is; only add test coverage.
- **`apps/OpsConsole/Resources/DefaultTemplates.json`** — 68 templates, all now catalog-valid. Keep. The simulation (`tools/Run-UxSimulations.ps1`) is now the guard.
- **`apps/OpsConsole/Resources/GenesysCloudAPIEndpoints.json`** — vendored Swagger spec. Keep unchanged.
- **`apps/OpsConsole/Resources/UxTelemetry.ps1`** — NDJSON session telemetry. Keep; wire workflow start/complete/fail events into the two hardened workflows.
- **`tests/*.Tests.ps1`** (21 files) — all offline Pester tests. Must keep green. Treat as non-negotiable baseline.
- **`tools/Run-UxSimulations.ps1`** — real simulation that validates template/catalog integrity. Keep and run in CI.

---

## 3. What to Freeze

- **`apps/OpsConsole/Resources/UI/UI.PreMain.ps1`** — the entire file except for additive changes to `Set-ExplorerAccessToken` (token expiry) and the new `UI.Logic.ps1` extractions. No new business logic added inline.
- **`apps/OpsConsole/Resources/UI/UI.Run.ps1`** — freeze all handlers **except** the login handler (token bridge) and the conversation report handler (background thread). All other handlers: read-only.
- **`apps/OpsConsole/Resources/UI/MainWindow.xaml`** — no new XAML elements, no layout changes. Freeze completely.
- **Live Subscriptions tab** (`UI/Tabs/LiveSubscriptions.Tab.ps1`) — WebSocket lifecycle unverified. Freeze; do not modify.
- **Ops Dashboard, Forensic Timeline, Operational Events tabs** — Experimental; freeze during Stage 1.
- **CI must stay green throughout** — `tools/Build.ps1` (Pester + simulation) must pass on every commit to `main`.

---

## 4. What to Demote

- **Generic API Explorer tab** — demote from primary navigation to an "Advanced / Developer Tools" section. Rationale: it is a power-user utility, not an operator workflow. UI treatment: move the tab to the end of the tab strip and add an `[Advanced]` label prefix to the tab header. No code changes required — a one-line XAML `Header` change.
- **Ops Insights / Insight Packs tab** — demote to Experimental. Add a `[Experimental]` badge to the tab header. Do not block access; just label it accurately.
- **Queue Wait Coverage** — demote to Experimental. Same treatment: `[Experimental]` tab label. The backend tests exist; promote to Stable in Stage 2 if a live smoke test passes.
- **Audit Log tab** (raw log browser, separate from Audit Investigator) — demote to a sub-panel inside the Audit Investigator tab rather than a standalone tab. Reduces visible surface area.
- **Filter Builder** — keep accessible inside API Explorer but do not promote it further until `UI.FilterBuilder.Regression.Tests.ps1` passes clean.

Migration path for demoted items: they remain fully accessible via the tab strip (no feature flags, no hidden menus). The only change is accurate status labelling. Promote them to Stable in Stage 2 after smoke tests pass against a live org.

---

## 5. Minimal Functional Scope

### Story 1 — Stable authentication

**As an operator** I can enter my Genesys Cloud region and access token (or client credentials) and have the application validate and store the token so that all subsequent API calls succeed without re-entering credentials.

Acceptance criteria:

- Login dialog (`Show-LoginWindow`, `UI.PreMain.ps1:1112`) accepts region + token or client ID / secret.
- On successful login, `Connect-GCCloud` is called with the selected region and token, populating `$script:GCContext` (`GenesysCloud.OpsInsights.psm1:6`).
- "Test Token" button calls `GET /api/v2/users/me` and shows green/orange/red indicator within 5 seconds.
- Token expiry is tracked (`$script:TokenExpiresAt`); clicking Submit after expiry shows the login dialog with a clear message rather than a raw 401 error.
- A structured log entry is written at `Info` level: `{ ts, session, event: "auth_success", props: { region, oauthType } }`.
- A `CorrelationId` is generated per login attempt and propagated to the first API call.

Observable success metrics:

- `$script:GCContext.Connected -eq $true` after login — verifiable via Pester mock test.
- Test-token response time < 5 s on a standard broadband connection.
- Zero silent 401 errors after a working token is set.

### Story 2 — Conversation Investigation (primary workflow, hardened)

**As an operator** I can enter a conversation ID, run the Conversation Report, view the full timeline with participant statistics and key insights, and export it to JSON or text — all without the UI freezing.

Acceptance criteria:

- Entering a conversation ID and clicking "Run Report" (`runConversationReportButton`, `UI.Run.ps1:1913`) starts a background job (`Start-ThreadJob`).
- Progress bar increments during the report using the existing `ProgressCallback` parameter (`UI.Run.ps1:1954–1983`).
- UI remains interactive (scrollable, buttons clickable) while the report runs.
- Report completes in under 30 seconds for a typical voice conversation on a standard connection.
- On failure, a user-friendly error is shown in the UI: `"Report failed. Correlation ID: {id}. Check the trace log for details."` — full stack trace goes to the trace log only.
- Structured telemetry events emitted: `conversation_report_start`, `conversation_report_complete` (with duration), `conversation_report_fail` (with error category).
- Export to JSON and export to text both produce non-empty files.
- Correlation ID is logged in every `Invoke-GCRequest` call made during the report.

Required API calls (minimum):

- `GET /api/v2/conversations/{conversationId}` — conversation details
- `GET /api/v2/analytics/conversations/{conversationId}/details` — analytics details
- Merge and format via existing `Merge-GCConversationEvents` / `Get-GCConversationSummary` (`UI.PreMain.ps1:3880–3978`)

Data retention: report output is ephemeral (in-session only); export is user-triggered to local disk.

Observable success metrics:

- 3 operators independently complete a conversation report in under 5 minutes from cold start.
- Zero UI hangs (WPF dispatcher unblocked throughout).
- All Pester offline tests pass; simulation completes at 100%.

### Story 3 — Audit Investigation (secondary workflow, hardened)

**As an operator** I can specify a date range and optional filters (service, entity, user), run the Audit Investigator, view results in the `AuditEventsList`, and export them — without writing any API calls.

Acceptance criteria:

- `RunAuditInvestigatorButton` (XAML-wired) calls `Invoke-GCAuditQuery` (`src/…/Private/Invoke-GCAuditQuery.ps1`) with inputs from `AuditStartInput` and `AuditEndInput`.
- Results populate `AuditEventsList` within 15 seconds for a 24-hour window.
- An error in the query shows a user-friendly message with correlation ID.
- Structured telemetry: `audit_query_start`, `audit_query_complete` (record count), `audit_query_fail`.
- An offline Pester test validates the query function with a mock invoker and fixture data (new test: `tests/AuditInvestigator.Offline.Tests.ps1`).
- A live smoke test (manual, with real org credentials) confirms results appear for a known date range.

Required API calls (minimum):

- `POST /api/v2/audits/query` — start async audit query
- `GET /api/v2/audits/query/{transactionId}` — poll status
- `GET /api/v2/audits/query/{transactionId}/results` — retrieve results

Data retention: results are ephemeral; export is user-triggered to local disk.

Observable success metrics:

- Query for a 24-hour window returns results and populates the list within 15 seconds.
- Offline Pester test passes with mock invoker returning fixture data.
- At least 2 operators validate the workflow against a real org.

---

## 6. Architecture Guardrails

### Allowed technologies

- PowerShell 7+ (`.psm1`, `.ps1`); no Windows PowerShell–only syntax.
- WPF shell (`MainWindow.xaml`) — **read-only** for Stage 1 except one-line tab header label changes.
- `Start-ThreadJob` (ships with PowerShell 7) for background work; `Dispatcher.Invoke` for UI callbacks from background threads.
- Pester 5.0+ for all tests.
- No new NuGet packages unless already in the repo manifest.
- No new external SaaS or internet-facing services.
- Windows Credential Manager or `Microsoft.PowerShell.SecretManagement` for secrets if a persistent credential store is added (not required for Stage 1; bearer token in-memory is acceptable).

### Observability requirements

Every hardened workflow must emit structured log entries in NDJSON format via `Write-UxEvent` (`UxTelemetry.ps1:115`):

```json
{
  "ts": "2026-03-11T14:23:01.123Z",
  "session": "guid",
  "correlationId": "guid-per-request",
  "event": "conversation_report_start | conversation_report_complete | conversation_report_fail",
  "level": "Info | Warning | Error",
  "module": "ConversationReport | AuditInvestigator | Auth",
  "props": { "durationMs": 4200, "errorCategory": "ApiTimeout" }
}
```

Levels: `Info` (normal flow), `Warning` (retry, fallback), `Error` (failure with stack trace in log only).

Correlation ID: generated once per workflow invocation (`[guid]::NewGuid().ToString()`), passed to all `Invoke-GCRequest` calls via a header or log field, shown in UI error messages.

### Error handling pattern

```powershell
# Transient (5xx, timeout): retry with exponential backoff — already in Invoke-GCRequest.ps1:222
# Auth failure (401): fail fast, show login dialog with correlation ID
# Validation failure: fail fast before the API call, show field-level message in UI
# All errors: write full stack + request context to trace log; show correlation ID in UI only
```

### Performance and scale constraints

- Assume 5–10 concurrent operators on separate machines (no shared server-side state).
- Genesys Cloud API rate limits: respect `Retry-After` header (already handled in `Invoke-GCRequest.ps1:246`).
- Conversation Report: target < 30 s end-to-end for a single voice conversation.
- Audit query: target < 15 s for a 24-hour window.
- API catalog load (634K-line Swagger spec): cached after first load; acceptable at startup.

### Security constraints

- Bearer token stored in `$script:AccessToken` (in-memory, session-scoped). Not written to disk.
- Token value never logged; auth header redacted in trace logs (already done in `Invoke-GCRequest.ps1`).
- Least privilege: only scopes required by Conversation Report and Audit Investigator workflows.
- No new external services. No secrets in source control.

---

## 7. Feature Status Labelling Rules

| Label | Criteria | UI Treatment |
| --- | --- | --- |
| **Stable** | Offline Pester tests pass; live smoke test completed with real org; no known blocking bugs | No badge; default tab/button appearance |
| **Experimental** | Code present and wired; no live smoke test; or known partial wiring | Tab header prefix: `[Experimental]` in muted text |
| **Advanced** | Working but intended for power users / developers, not first-line operators | Tab header prefix: `[Advanced]` |
| **Deprecated** | Superseded by another workflow or no longer maintained | Tab header prefix: `[Deprecated]`; greyed tab text |
| **Hidden** | Broken or unsafe; must not be exposed to operators | Tab `Visibility="Collapsed"` in XAML |

Current mappings:

| Workflow | Current label | Rationale |
| --- | --- | --- |
| Auth / Login | Stable | Working; smoke-tested |
| Conversation Report | Stable | Hardened in Stage 1 |
| Audit Investigator | Stable | Hardened in Stage 1 |
| API Explorer | Advanced | Utility; not an operator workflow |
| Templates / Favorites | Stable | Verified by simulation |
| Ops Insights / Insight Packs | Experimental | No live smoke test |
| Queue Wait Coverage | Experimental | Backend tests pass; UI wiring unconfirmed |
| Filter Builder | Experimental | Regression tests present; UI smoke pending |
| Live Subscriptions | Experimental | WebSocket lifecycle unconfirmed |
| Operational Events | Experimental | No test coverage |
| Ops Dashboard | Experimental | Scheduling logic partial |
| Forensic Timeline | Experimental | No transform functions confirmed |

Label change rule: a feature moves from Experimental to Stable when: (a) an offline Pester test passes with mock data, AND (b) a live smoke test completes successfully against a real org, AND (c) the change is reviewed and merged to `main`.

---

## 8. Exit Criteria for Stage 1 Success

### Functional

- [ ] Operator can authenticate (web OAuth or client credentials) for all 7 supported regions.
- [ ] Operator can run a Conversation Report for any conversation ID and view all sections (summary, timeline, participant stats, key insights).
- [ ] Conversation Report export to JSON and text both produce non-empty files.
- [ ] Operator can run an Audit query for a date range and view results.
- [ ] Audit results can be exported.
- [ ] UI never freezes during report or audit query (dispatcher thread stays unblocked).
- [ ] Token expiry re-prompts the user instead of returning a raw 401.

### Reliability

- [ ] All 21 existing Pester tests pass on every `main` commit (CI green).
- [ ] `tools/Run-UxSimulations.ps1` completes at 100% (no template/catalog drift).
- [ ] `tests/AuditInvestigator.Offline.Tests.ps1` (new) passes with mock invoker.
- [ ] Zero regressions in template or favorites round-trip (simulation regression guard).

### Observability

- [ ] Structured NDJSON telemetry emitted for auth, conversation report, and audit query start/complete/fail events.
- [ ] Correlation ID present in every UI error message.
- [ ] Trace log (`$env:TEMP\GenesysApiExplorer.trace.*.log`) contains full stack traces for any Error-level event.

### UX

- [ ] At least 3 operators independently complete a Conversation Report in under 5 minutes from cold start.
- [ ] At least 2 operators independently complete an Audit query in under 5 minutes.
- [ ] All tabs are accurately labelled (Stable / Advanced / Experimental / Deprecated) — no unlabelled experimental features visible.

### Documentation

- [ ] `docs/ux/01-local-runbook.md` updated with Stage 1 launch steps and credential setup.
- [ ] `docs/RoadMap_PromptChain/02_repo_triage_agent.md` finalized (complete).
- [ ] This file (`03_Stage1.md`) finalized as the implementation contract.
- [ ] Release notes entry listing the 7 template corrections and the 5 hardening changes.

---

## 9. Failure Criteria That Trigger Stage 2

### Trigger 1 — UI monolith becomes unmodifiable

If two or more Stage 1 tasks require simultaneous edits to `UI.PreMain.ps1` or `UI.Run.ps1` and produce merge conflicts that take more than 4 hours to resolve each, the monolith has exceeded its Stage 1 modification budget. **Stage 2 scope:** extract auth, Conversation Report, and Audit Investigator into dedicated `.ps1` modules with clear input/output contracts; keep WPF shell as a thin dispatcher.

### Trigger 2 — Background threading causes state corruption

If `Start-ThreadJob` + `Dispatcher.Invoke` produces race conditions in `$script:` state (e.g., token overwritten mid-report, response displayed for wrong conversation) that cannot be fixed by adding a simple mutex or copying state into the job, the WPF/PowerShell threading model has hit its ceiling. **Stage 2 scope:** move all business logic into a separate runspace with a proper message queue; the WPF shell becomes purely presentational.

### Trigger 3 — Auth token divergence causes > 2 production incidents per week

If the three-scope token split (`$script:AccessToken` vs `$script:GCContext.AccessToken` vs `$global:AccessToken`) produces more than 2 silent auth failures per operator shift after the Stage 1 bridge fix, the in-memory multi-scope design is unsafe. **Stage 2 scope:** consolidate to a single auth context object exposed via `Get-GCAuthContext` / `Set-GCAuthContext`; remove `$global:AccessToken` fallback.

### Trigger 4 — Performance targets missed without architectural change

If the Conversation Report cannot complete within 30 seconds for a standard voice conversation, or the Audit query cannot complete within 15 seconds for a 24-hour window, AND profiling shows the bottleneck is sequential single-threaded API calls that cannot be parallelised within `Start-ThreadJob`, a pipeline/parallel-job architecture is required. **Stage 2 scope:** introduce parallel job fan-out for multi-endpoint report queries using `Start-ThreadJob` pools or a dedicated runspace manager.

### Trigger 5 — > 5 critical defects open simultaneously after launch

If at any point after Stage 1 launch there are more than 5 open defects rated as blocking (operator cannot complete a hardened workflow), Stage 1 stability is not achieved. **Stage 2 scope:** pause new feature work; assess whether the defect root causes require architectural changes or are fixable incrementally.

---

## Developer Implementation Checklist (ordered)

1. **[S — 2 h]** Create `.github/workflows/ci.yml`: run `pwsh -File tools/Build.ps1` on push and PR to `main`. Verify badge goes green.

2. **[S — 30 min]** In `UI.Run.ps1` `loginButton.Add_Click` (line 1817): add `Connect-GCCloud -RegionDomain $selectedRegion -AccessToken (Get-ExplorerAccessToken)` immediately after `Set-ExplorerAccessToken`. Repeat for the settings dialog save path.

3. **[S — 1 h]** In `UI.PreMain.ps1` `Set-ExplorerAccessToken` (line 885): add `$script:TokenExpiresAt = (Get-Date).AddHours(23)`. In `UI.Run.ps1` `btnSubmit.Add_Click` (line 4024): guard with `if ((Get-Date) -gt $script:TokenExpiresAt) { Show-LoginWindow; return }`.

4. **[M — 4–6 h]** Wrap `Get-ConversationReport` call in `UI.Run.ps1:1913` in `Start-ThreadJob`. Wire `ProgressCallback` to `Dispatcher.Invoke` progress-bar updates. On completion, `Dispatcher.Invoke` the report display. On error, show user-friendly message with correlation ID.

5. **[S — 2 h]** Add correlation ID generation and propagation: generate `$correlationId = [guid]::NewGuid().ToString()` at the start of each hardened workflow; pass as a custom header `X-Correlation-Id` to `Invoke-GCRequest`; include in all `Write-UxEvent` calls for the workflow.

6. **[S — 2–3 h]** Write `tests/AuditInvestigator.Offline.Tests.ps1`: use `Set-GCInvoker` to return fixture audit data; assert that `Invoke-GCAuditQuery` returns the expected record count and structure.

7. **[S — 1 h]** Confirm `RunAuditInvestigatorButton` handler in `UI.Run.ps1` is fully wired: inputs → `Invoke-GCAuditQuery` → `AuditEventsList` population. Fix any gap; no new UI elements.

8. **[S — 1 h]** Update XAML tab headers: add `[Advanced]` to API Explorer tab; add `[Experimental]` to Ops Insights, Queue Wait Coverage, Filter Builder, Live Subscriptions, Operational Events, Ops Dashboard, Forensic Timeline tabs.

9. **[S — 2 h]** Add `conversation_report_start/complete/fail` and `audit_query_start/complete/fail` telemetry calls via `Write-UxEvent` in the respective handlers.

10. **[S — 2 h]** Update `docs/ux/01-local-runbook.md` with Stage 1 launch steps, credential setup, and known experimental features. Write release notes.

---

## Rationale: Why This Is the Smallest Credible Salvage Path

This plan makes exactly five code changes to the existing WPF shell (token bridge, expiry guard, background thread, correlation ID, tab labels) and adds one new test file. It does not touch the 634K-line Swagger catalog, the XAML layout, the module exports, or any workflow outside the two targeted ones. The working nucleus — `Invoke-GCRequest`, `Connect-GCCloud`, the conversation report rendering pipeline, and the 21 offline tests — is preserved entirely. Demoting the API Explorer and labelling experimental tabs costs zero engineering time and immediately reduces operator confusion. Adding CI converts the existing `tools/Build.ps1` script into a persistent guard at a one-time cost of 2 hours. The total Stage 1 effort is estimated at 18–22 developer-hours, achievable in two focused weeks without any architectural migration.

---

## Missing Info / Preconditions

The following gaps remain from the triage; resolve before finalising Stage 1 implementation:

| Item | Impact | Resolution |
| --- | --- | --- |
| Live org access for smoke tests | Audit Investigator and Queue Wait Coverage cannot be promoted to Stable without it | Provide a Genesys Cloud sandbox org with at least read-only audit and analytics scopes |
| Exact `RunAuditInvestigatorButton` handler line number in `UI.Run.ps1` | Step 7 in checklist assumes it exists; confirmed by XAML element ID but handler line not pinned | Read `UI.Run.ps1` and search for `RunAuditInvestigatorButton.Add_Click` to confirm line |
| WebSocket connection lifecycle for Live Subscriptions | Cannot confirm Experimental status is safe vs Hidden | Read `LiveSubscriptions.Tab.ps1` beyond line 100; check for error handling around `ClientWebSocket` or notification channel calls |
| PowerShell version constraint | Triage assumed PS 7+; if `Start-ThreadJob` is unavailable, background threading approach changes | Run `$PSVersionTable` on the target operator machine; confirm PS 7.0+ |
| Token scopes required for Audit Investigator | Least-privilege constraint needs exact scope list | Check Genesys Cloud API docs for `/api/v2/audits/query` required OAuth scopes |
