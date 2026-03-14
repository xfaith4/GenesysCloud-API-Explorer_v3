# Genesys Cloud Ops Console — Rescue Roadmap

*Last updated: 2026-03-13. Sprint 1 complete. Sprint 2 complete. Sprint 3 complete. Sprint 4 complete. Sprint 5 complete. Sprint 6 complete. Sprint 7 complete. Sprint 8 complete.*

---

## Current Status Summary

| Area | Status | Notes |
|------|--------|-------|
| UI Filter Builder (8 tests) | FIXED | Duck-typed mocks replace WPF types; passes on Linux/CI |
| OpsConsole UI Contracts (XAML parse) | FIXED | Skipped on non-Windows (WPF-only) |
| NotificationsToolkit Exhaustive (12 tests) | FIXED | Removed Mandatory param prompts that blocked CI |
| Conversation Report | FIXED | Background thread, correlation IDs, telemetry, 16 offline tests (shape, content, guard rails, pagination) |
| Audit Investigator | FIXED | Background thread, correlation IDs, telemetry, 10 offline tests |
| Queue Wait Coverage | FIXED | Background thread, correlation IDs, telemetry, 6 offline tests + 20 Sprint 5 tests |
| Authentication | Improved | DEF-010 401 detection added; DEF-007 token persistence deferred to Sprint 2 |
| Invoke-GCRequest | Improved | DEF-002 429 retry + Retry-After support added |
| Live Subscriptions | Experimental | DEF-008 pagination safety deferred to Sprint 3 |
| Generic API Explorer | Utility | Functional but secondary |

---

## Prioritized Fix Queue

### P1 — Blocking CI / Test Infrastructure

These must be fixed before any developer can run the test suite reliably.

| ID | Issue | Status |
|----|-------|--------|
| T-001 | FilterBuilder tests fail on Linux (WPF assembly) | FIXED |
| T-002 | OpsConsole XAML parse test fails on Linux | FIXED |
| T-003 | NotificationsToolkit exhaustive tests hang (mandatory param prompts) | FIXED |

---

### P2 — High Severity Defects (Core Workflows)

#### DEF-001 — UI Thread Blocking on Long-Running API Workflows

**Impact**: App freezes during Conversation Report, Queue Wait, Audit queries.
**Fix**: Wrap long-running button handlers in background threads with dispatcher callbacks.
**Files**: `apps/OpsConsole/Resources/UI/UI.Run.ps1`
**Affected handlers**: `RunConversationReportButton`, `RunQueueWaitReportButton`, `RunAuditInvestigatorButton`, `RunOperationalEventsButton`, `RunOpsConversationIngestButton`, `RunSelectedInsightPackButton`

#### DEF-002 — No HTTP 429 / Rate-Limit Retry in Invoke-GCRequest

**Impact**: Bulk operations fail silently when API rate-limits the caller.
**Fix**: Add retry loop with exponential backoff (3 retries, 2s base) for 429 responses.
**Files**: `src/GenesysCloud.OpsInsights/Public/Invoke-GCRequest.ps1`

---

### P3 — Medium Severity Defects (UX Quality)

#### DEF-003 — No Input Validation Before Run Handlers

**Impact**: Empty/invalid inputs produce confusing stack traces instead of user-friendly errors.
**Fix**: Add pre-flight guards in handlers with early `return` + status text message.
**Files**: `apps/OpsConsole/Resources/UI/UI.Run.ps1`

#### DEF-004 — Task Scheduler Button Has No OS Guard

**Impact**: `ScheduleOpsConversationIngestButton` errors on Linux/macOS with no explanation.
**Fix**: Disable button on non-Windows at startup with a tooltip explaining why.
**Files**: `apps/OpsConsole/Resources/UI/UI.Run.ps1`

#### DEF-007 — Token Not Persisted Across App Restarts

**Impact**: Users must re-authenticate every launch — high friction for daily use.
**Fix**: Optional DPAPI-encrypted token persistence with "Remember token" checkbox.
**Files**: `apps/OpsConsole/Resources/UI/UI.PreMain.ps1`

#### DEF-010 — Auth State Not Updated on Token Expiry Mid-Session

**Impact**: Users see opaque errors when their token expires during a workflow.
**Fix**: Detect 401 in `Invoke-GCRequest` and call `Update-AuthUiState` with Expired status.
**Files**: `src/GenesysCloud.OpsInsights/Public/Invoke-GCRequest.ps1`

---

### P4 — Low Severity / Polish

#### DEF-005 — ExportInsightBriefingButton Has No Tooltip

**Fix**: Add `ToolTip="Run an insight pack first to enable this export."` in XAML.
**Files**: `apps/OpsConsole/Resources/UI/MainWindow.xaml`

#### DEF-006 — InspectResponseButton Active Before Any API Response

**Fix**: Set `IsEnabled="False"` in XAML; enable on first successful response.
**Files**: `apps/OpsConsole/Resources/UI/MainWindow.xaml`, `UI.Run.ps1`

#### DEF-008 — Notification Topic Refresh Has No Pagination Safety

**Fix**: Add `pageSize` parameter and pagination loop in `Get-GCNotificationTopics`.
**Files**: `Scripts/GenesysCloud.NotificationsToolkit/GenesysCloud.NotificationsToolkit.psm1`

#### DEF-009 — Template Buttons Have No Tooltip When Disabled

**Fix**: Add `ToolTip="Select a template from the list above."` to XAML.
**Files**: `apps/OpsConsole/Resources/UI/MainWindow.xaml`

---

## Feature Maturity Table

| Feature | Status | Intent |
|---------|--------|--------|
| Conversation Report | Stable | Primary workflow — hardened (background threading, correlation IDs, telemetry) |
| Audit Investigator | Stable | Hardened (background threading, correlation IDs, telemetry, offline tests) |
| Queue Health / Smoke | Beta | Hardened (telemetry, expiry guard, correlation IDs, offline tests) |
| Live Subscriptions | Experimental | Internal workflow; labelled |
| Ops Dashboard | Experimental | Needs scope reduction; labelled |
| Generic API Explorer | Utility | Secondary support surface |
| Operational Events | Stable | Hardened (S8: token expiry guard, correlation IDs, telemetry) |
| Templates/Favorites | Utility | Keep minimal |
| AI/Copilot | Deferred | Not core yet |

---

## Architectural Priorities

### What to keep

1. **Conversation investigation/reporting** — proof-of-value feature.
2. **OpsInsights module/backend split** — correct long-term architecture.
3. **Insight packs / evidence packet concept** — unique differentiator.
4. **Notifications/live subscription** — valuable if turned into investigation workflow.
5. **Export/report mindset** — anything that turns findings into evidence is gold.

### What to freeze (do not expand yet)

1. Generic explorer breadth.
2. AI/copilot ambitions.
3. New tabs.
4. Template/catalog sprawl.

### What to cut or demote

1. "API Explorer" as the headline identity (demote to utility pane).
2. Half-finished surfaces that do not support a complete operator job.
3. UI-owned business logic (move to modules/services).

---

## Sprint Execution Plan

### Sprint 0 (Complete) — CI / Test Infrastructure

- [x] Fix FilterBuilder regression tests on Linux.
- [x] Fix OpsConsole UI contract tests on non-Windows.
- [x] Fix NotificationsToolkit exhaustive test hang.

### Sprint 1 (Complete) — Foundation Stability

- [x] DEF-002: Add 429 retry to `Invoke-GCRequest` (exponential backoff + Retry-After support).
- [x] DEF-003: Add input guards to Run handlers (UUID validation, null-token, empty-ID).
- [x] DEF-010: Detect 401 and update auth state mid-session via `OnUnauthorized` callback.
- [x] DEF-004: OS guard for Task Scheduler button (disabled + tooltip on non-Windows).
- [x] Sprint 1 tests hardened: 12 dedicated tests in `Sprint1.Stability.Tests.ps1`
      covering real 429 retry paths (via CLR mock exception), Retry-After header honoring,
      MaxAttempts exhaustion, UUID guard patterns, and token guard pattern.
      Full suite: 73 pass, 1 skipped, 0 failed.

### Sprint 2 (Complete, merged into Sprint 4) — Core Workflow Hardening

- [x] DEF-001: Offload long-running handlers to background threads (`Invoke-UIBackgroundTask` pattern).
- [x] DEF-007: Token expiry tracking (`$script:TokenExpiresAt`) + expiry guards in all key handlers.
- [x] Harden Conversation Report (correlation IDs, `Write-UxEvent` telemetry, background thread).
- [x] Auth bridge: `Connect-GCCloud` called at login to populate module context immediately.
- [x] `Ensure-OpsInsightsContext` updated to use `Connect-GCCloud`; removed `$global:AccessToken` fallback.

### Sprint 3 (Complete) — Audit Investigator + Queue Health

- [x] Harden Audit Investigator (filtered timeline with live filter input, export buttons enabled only after results load).
- [x] Harden Queue Health (ConfidenceLevel property added to `Get-GCQueueWaitCoverage` results; Confidence column in list;
      drilldown panel shows confidence marker and explanation when a conversation is selected).
- [x] Polish: DEF-005, DEF-006, DEF-008, DEF-009.
- [x] Sprint 3 tests: 11 new tests in `Sprint3.Tests.ps1`
      (DEF-008 pagination, ConfidenceLevel values, confidence logic unit tests).
      Full suite: 86 pass, 1 skipped, 0 failed.

### Sprint 4 (Complete) — Auth Hardening + Observability + Startup Safety

- [x] S1-001: Bridge `Connect-GCCloud` at login — module context populated immediately after `Set-ExplorerAccessToken`.
- [x] S1-002: Token expiry tracking (`$script:TokenExpiresAt = AddHours(23)`) + expiry guards in `btnSubmit`,
      `runConversationReportButton`, and `runAuditInvestigatorButton` handlers.
- [x] S1-003: `Ensure-OpsInsightsContext` now calls `Connect-GCCloud`; removed `$global:AccessToken` fallback.
- [x] S1-004: `StartupDiagnostics.ps1` — `Invoke-StartupChecks` pure-PS pre-flight (PS version, ThreadJob,
      resource files, UI scripts). `StartupDiagnostics.Tests.ps1`: 11 new tests.
- [x] S1-005/S1-010: XAML tab labels — `[Experimental]` prefix applied to Ops Insights, Ops Dashboard,
      Forensic Timeline, Queue Wait Coverage, Live Subscriptions, Operational Events.
      Tab label tests added to `OpsConsole.UiContracts.Tests.ps1` (XML-parsed, no WPF needed).
- [x] S1-007: `Write-UxEvent` telemetry added to Conversation Report handler:
      `conversation_report_start`, `conversation_report_complete`, `conversation_report_fail`.
- [x] S1-008: `AuditInvestigator.Offline.Tests.ps1` — 10 new offline Pester tests covering
      result shape, entity content, guard rails, and multi-page pagination.
- [x] S1-009: Correlation ID + `Write-UxEvent` telemetry added to Audit Investigator handler:
      `audit_query_start`, `audit_query_complete`, `audit_query_fail`.
- [x] `Invoke-GCAuditQuery` promoted to public API (added to `Export-ModuleMember` list).
- [x] Sprint 4 tests: 29 new tests (11 StartupDiagnostics + 10 AuditInvestigator + 8 XAML label).
      Full suite: 115 pass, 1 skipped, 0 failed.

### Sprint 5 (Complete) — Queue Health Hardening + Telemetry

- [x] S5-001: Token expiry guard added to `RunQueueWaitReportButton` handler (matches pattern in
      `runConversationReportButton` and `runAuditInvestigatorButton`; uses `$script:TokenExpiresAt`).
- [x] S5-002: Correlation ID (`[guid]::NewGuid()`) + `Write-UxEvent` telemetry added to Queue Wait handler:
      `queue_wait_start` (with queueId), `queue_wait_complete` (with conversationCount),
      `queue_wait_fail` (with errorCategory). Log entries include `[Correlation ID: ...]` suffix.
- [x] S5-003: `QueueWaitCoverage.Offline.Tests.ps1` expanded with 5 new shape/contract tests:
      all-properties presence, WaitingSinceUtc UTC parse, EligibleAgentsSummary non-empty,
      array return type, default-interval smoke test.
- [x] S5-004: `Sprint5.Tests.ps1` — 20 new tests covering:
      telemetry event name contract (queue_wait_start/complete/fail written + parsed from file),
      token expiry guard pattern unit tests, correlation ID GUID format,
      and Queue Health result shape stability.
- [x] Queue Health / Smoke elevated from `Experimental` to `Beta` in Feature Maturity Table.
- [x] Sprint 5 tests: 20 new tests (6 telemetry + 3 expiry guard + 2 GUID + 4 shape + 5 offline).
      Full suite: 135 pass, 1 skipped, 0 failed.

### Sprint 6 (Complete) — Conversation Report Completion

- [x] S6-001: Token expiry guard pattern unit tests for Conversation Report handler (matches Sprint 4/5 pattern;
      tests in `Sprint6.Tests.ps1`): expiry fires when in past, does not fire when in future or null.
- [x] S6-002: Conversation report telemetry event contract tests: `conversation_report_start` (with conversationId),
      `conversation_report_complete` (with errorCount), `conversation_report_fail` (with errorCategory).
      Events verified written to telemetry file via `Flush-UxTelemetryBuffer`.
- [x] S6-003: `ConversationDetails.Offline.Tests.ps1` expanded from 1 → 16 tests:
      result shape (conversations count, cursor value), ByInterval parameter set,
      conversation content (conversationId, start/end, participants with participantId/purpose,
      customer participant, MOS stats), guard rails (empty interval throws, cursor/PageSize accepted),
      and cursor pagination contract (passes cursor to request body; omits cursor when not supplied).
- [x] S6-004: `Sprint6.Tests.ps1` — 24 new tests covering:
      telemetry event names (6), token expiry guard (3), correlation ID GUID contract (2),
      `Get-GCConversationRollup` shape/logic (13: empty store, missing path, 3 sections,
      section titles, rows accessibility, row properties, bucket count, conversation count,
      WebRtcDisconnects, DegradedPct threshold, custom MosThreshold).
- [x] S6-005: `ConversationRollup.store.jsonl` fixture added (3 records: 2 in div-A with MOS 4.2/2.8,
      1 in div-B; div-A has 1 WebRTC disconnect; conv-002 MOS 2.8 is below default 3.5 threshold).
- [x] Conversation Report elevated from `Partial` to `FIXED` in Current Status Summary.
      Feature Maturity Table remains `Stable`.
- [x] Sprint 6 tests: 24 new tests (6 telemetry + 3 expiry + 2 GUID + 13 rollup) + 15 expanded offline.
      Full suite: 174 pass, 1 skipped, 0 failed.

### Sprint 7 (Complete) — Ingest Hardening + Sprint 6 Cliffhanger Fix

- [x] S7-CLIFFHANGER: Added `ExportRedactedKpiButton` to `MainWindow.xaml` (line after `ExportIncidentPacketButton`).
      Handler in `UI.Run.ps1` was fully implemented since Sprint 6 but XAML element was absent.
      `Get-GCConversationRollup` is now reachable via the Ops Dashboard UI.
      `ExportRedactedKpiButton` removed from `$optionalTargets` in `OpsConsole.UiContracts.Tests.ps1`.
- [x] S7-001: Token expiry guard (`$script:TokenExpiresAt`) added to the 4 existing Ops Dashboard export
      button handlers (`ExportDivisionQosButton`, `ExportWebRtcButton`, `ExportDataActionButton`,
      `ExportIncidentPacketButton`) — consistent with pattern used in Conversation Report, Queue Wait,
      Audit, and `ExportRedactedKpiButton` handlers.
- [x] S7-002: Correlation ID (`[guid]::NewGuid()`) + `Write-UxEvent` telemetry added to
      `runOpsConversationIngestButton` handler:
      `ops_ingest_start` (with interval, correlationId),
      `ops_ingest_complete` (with recordsWritten),
      `ops_ingest_fail` (with errorCategory). Log entries include `[Correlation ID: ...]` suffix.
      Token expiry guard also added to the ingest handler (matches pattern from Sprints 4–6).
- [x] S7-003: `Sprint7.Tests.ps1` — 13 new tests covering:
      XAML button presence (2), token expiry guard pattern (3), telemetry event names (3),
      telemetry file writes with properties (3), correlation ID GUID format (2).
      Full suite: 187 pass, 1 skipped, 0 failed.

### Sprint 8 (Complete) — Operational Events Handler Hardening

- [x] S8-001: Token expiry guard (`$script:TokenExpiresAt`) added to `runOperationalEventsButton` handler —
      consistent with pattern in Conversation Report, Queue Wait, Audit, Ingest, and Ops Dashboard export handlers.
- [x] S8-002: Correlation ID (`[guid]::NewGuid()`) added to `runOperationalEventsButton` handler:
      variable `$opEvtCorrId` captured before `Invoke-UIBackgroundTask`; surfaced in status text and log.
- [x] S8-003: `Write-UxEvent` telemetry added to Operational Events handler:
      `ops_events_query_start` (with eventDefinitionIds, correlationId),
      `ops_events_query_complete` (with eventCount),
      `ops_events_query_fail` (with errorCategory). Log entries include `[Correlation ID: ...]` suffix.
- [x] S8-004: `Sprint8.Tests.ps1` — 16 new tests covering:
      token expiry guard pattern (3), telemetry event names accept test (3),
      telemetry file writes with properties (3), correlation ID GUID format (2),
      UI.Run.ps1 source contract checks (5).
      Full suite: 203 pass, 1 skipped, 0 failed.
- [x] Feature Maturity Table updated: Operational Events elevated to `Stable`.
- [x] Remaining roadmap risk updated: Operational Events hardening marked complete.

---



This section defines recurring engineering-hygiene tasks to keep the repository in a consistently shippable state.

### Review cadence

| Cadence | Activity |
|---------|----------|
| Every sprint | Run `.\tools\Test.ps1 -Profile Fast` and confirm zero failures before merging |
| Every sprint | Check ROADMAP for items marked complete — verify against code, not just checklist |
| Every sprint | Search for TODO/FIXME/STUB/HACK/placeholder comments in `src/`, `apps/`, `tests/` |
| Monthly | Run `.\tools\Test.ps1 -Profile Full` to exercise integration paths |
| Monthly | Review `docs/` accuracy against current implementation |
| Monthly | Audit Feature Maturity Table: promote `Beta` → `Stable` or demote if regressions found |
| Quarterly | Review CI workflow for stale or missing job configurations |

### Scheduled test verification checklist

Before any merge to `main`:

- [ ] `.\tools\Test.ps1 -Profile Fast` passes with 0 failures
- [ ] No new test is skipped without a documented reason
- [ ] No test count decreases from the prior sprint baseline
- [ ] `OpsConsole.UiContracts.Tests.ps1` — all FindName targets are present in XAML
- [ ] XAML parses cleanly on Windows (`[System.Windows.Markup.XamlReader]::Parse`)

### Hardening and maintenance checklist

For any new handler that calls an API or modifies state:

- [ ] Token expiry guard: `if ($script:TokenExpiresAt -and (Get-Date) -gt $script:TokenExpiresAt)`
- [ ] User permission guard: `if (-not (Test-UserAllowed))`
- [ ] Token presence guard: `Get-ExplorerAccessToken` check
- [ ] Correlation ID: `$correlationId = [guid]::NewGuid().ToString()`
- [ ] Telemetry start/complete/fail events via `Write-UxEvent`
- [ ] Background thread for long-running work: `Invoke-UIBackgroundTask`
- [ ] Log entries include `[Correlation ID: ...]` suffix

### Documentation accuracy review

- Confirm `ROADMAP.md` sprint entries match actual code changes (not aspirational)
- Confirm `docs/` guides reference functions that still exist and behave as described
- Confirm Feature Maturity Table reflects current test coverage and stability

### Remaining roadmap risks and future work

| Item | Priority | Notes |
|------|----------|-------|
| Ops Dashboard refresh/filter handlers telemetry | Low | Export buttons hardened (S7-001); refresh/filter interactions do not call the API, so telemetry value is low |
| DEF-007: Token persistence across restarts | Low | DPAPI-encrypted "Remember token" deferred since Sprint 1 |
| Forensic Timeline hardening | Medium | Experimental tab; `Investigate-SelectedTimelineEntry` and `Export-SelectedTimelineEntry` are display-only; no API calls — telemetry opportunity is low impact |
| Operational Events hardening | DONE | Completed in Sprint 8: token expiry guard, correlation ID, telemetry (ops_events_query_start/complete/fail) |
| Live Subscriptions hardening | Low | Experimental; DEF-008 pagination safety deferred since Sprint 3 |
| Integration test coverage | Medium | `Integration.LiveApi.Smoke.Tests.ps1` requires live credentials; CI gate only runs Fast profile |

---

The app succeeds when:

> "A Genesys Cloud support engineer can investigate a conversation, audit a config change, or diagnose a queue issue and produce exportable evidence without touching raw APIs manually."

Not: "a PowerShell GUI that exposes lots of Genesys APIs."
