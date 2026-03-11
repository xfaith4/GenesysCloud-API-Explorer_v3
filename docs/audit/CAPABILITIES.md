# GenesysCloud API Explorer v3 — Current Capabilities

> **Version**: v3 (analysed 2026-03-11)  
> **Platform**: Windows desktop (PowerShell 5.1+ / WPF)  
> **Analysis basis**: Static code inspection of XAML and PowerShell source

---

## What This Application Does

GenesysCloud API Explorer v3 is an operational desktop tool for Genesys Cloud administrators, architects, and support engineers. It provides:

- A generic Genesys Cloud REST API explorer with request history, favorites, and export
- Structured analytics workflows for conversations, queues, and audits
- Real-time notification event monitoring via WebSocket
- Local data store and dashboard for operational conversation data
- Insight pack execution for analytical KPI surfacing

---

## Capability Overview

### ✅ Fully Wired Workflows (No Auth Required to Use Controls)

| Capability | Description |
|---|---|
| **Filter Builder** | Build structured analytics query filters (conversation + segment predicates). Fully tested with Pester regression suite. |
| **Request History** | Replay, inspect, and clear previous API requests. |
| **Templates** | Save, load, delete, export, and import request templates. |
| **Insight Pack Dry Run** | Validate insight pack parameters and structure without executing any API calls. |
| **Ops Dashboard (View)** | Browse and filter previously ingested conversation data from local JSONL store. |
| **Export PowerShell / cURL** | Generate PowerShell or cURL scripts for any request without executing it. |
| **Transparency Log** | View, export, and clear the complete request/response audit log. |

### 🔐 Auth-Gated Workflows (Valid Paths — Require Genesys Cloud Token)

| Capability | Description |
|---|---|
| **API Explorer Submit** | Execute any Genesys Cloud v2 REST API endpoint with full response inspection. |
| **Test Token** | Validate current OAuth access token against `GET /api/v2/users/me`. |
| **Conversation Report** | 6-API forensic report for a single conversation (analytics, metadata, recording, speech, sentiment, SIP). |
| **Queue Wait Coverage** | Multi-step analysis of waiting conversations vs. eligible agents for a queue. |
| **Audit Investigator** | Async audit log query with pagination and summary export. |
| **Operational Events** | Live or one-shot operational event audit log monitoring by topic. |
| **Insight Pack Execution** | Run analytics insight packs (6 built-in packs + custom packs from `insights/packs/`). |
| **Insight Pack Compare** | Compare current insight pack results against a historical baseline (previous window or shifted days). |
| **Live Subscriptions** | Real-time Genesys Cloud notification events via WebSocket with topic catalog, filtering, and capture export. |
| **Ops Conversation Ingest** | Pull conversation analytics data into local JSONL store using async bulk jobs. |
| **Forensic Timeline Investigate** | Drill into operational timeline entries for contextual investigation. |

### ⚠️ Platform-Limited Features

| Capability | Limitation |
|---|---|
| **Schedule Ingest** | Uses Windows Task Scheduler. Only functional on Windows. |

---

## Built-In Insight Packs

| Pack ID | Description |
|---|---|
| `gc.queues.smoke.v1` | Queue Smoke Detector — operational queue health check |
| `gc.dataActions.failures.v1` | Data Action Failures — data action error rate analysis |
| `gc.dataActions.failures.enriched.v1` | Data Actions Enriched — data action failures with per-action breakdown |
| `gc.calls.peakConcurrency.monthly.v1` | Peak Concurrency Monthly — monthly peak concurrent call analysis |
| `gc.mos.monthly.byDivision.v1` | MOS Monthly by Division — mean opinion score tracking by division |
| `gc.webrtc.disconnects.v1` | WebRTC Disconnects — WebRTC disconnect pattern analysis |

---

## API Endpoints Used

| Service | Endpoint |
|---|---|
| Auth validation | `GET /api/v2/users/me` |
| Analytics (aggregates) | `POST /api/v2/analytics/conversations/aggregates/query` |
| Analytics (details query) | `POST /api/v2/analytics/conversations/details/query` |
| Analytics (details jobs) | `POST /api/v2/analytics/conversations/details/jobs` |
| Analytics (details job status) | `GET /api/v2/analytics/conversations/details/jobs/{jobId}` |
| Analytics (details results) | `GET /api/v2/analytics/conversations/details` |
| Analytics (single conversation) | `GET /api/v2/analytics/conversations/{id}/details` |
| Conversations (core) | `GET /api/v2/conversations/{id}` |
| Conversations (recording) | `GET /api/v2/conversations/{id}/recordingmetadata` |
| Speech & Text Analytics | `GET /api/v2/speechandtextanalytics/conversations/{id}` |
| Sentiment Analysis | `GET /api/v2/speechandtextanalytics/conversations/{id}/sentiments` |
| Telephony / SIP | `GET /api/v2/telephony/sipmessages/conversations/{id}` |
| Routing (queues) | `GET /api/v2/routing/queues/{queueId}` |
| Routing (skills) | `GET /api/v2/routing/skills` |
| Audit | `POST /api/v2/audits/query` |
| Audit (poll) | `GET /api/v2/audits/query/{executionId}` |
| Audit (results) | `GET /api/v2/audits/query/{executionId}/results` |
| Notifications (channel create) | `POST /api/v2/notifications/channels` |
| Notifications (subscriptions) | `POST /api/v2/notifications/channels/{id}/subscriptions` |
| Notifications (topics) | `GET /api/v2/notifications/topics` |
| Notifications (WebSocket) | `wss://notifications.{region}.pure.cloud/...` |
| Any user-selected path | `{Method} /api/v2/*` (API Explorer) |

---

## Known Issues Summary

See [`DEFECTS.md`](DEFECTS.md) for full details. High-priority items:

1. **UI thread blocking** — Long-running API workflows may freeze the application window (DEF-001).
2. **No rate-limit retry** — HTTP 429 responses cause silent failures on bulk operations (DEF-002).
3. **No input validation guards** — Empty form fields produce confusing backend errors instead of user-friendly messages (DEF-003).
4. **Windows-only scheduled ingest** — No OS guard on Schedule Ingest button (DEF-004).
5. **Token not persisted** — Must re-authenticate on every app restart (DEF-007).

---

## Full Audit Artifacts

| File | Description |
|---|---|
| [`AUDIT_REPORT.md`](AUDIT_REPORT.md) | Complete end-to-end static analysis report |
| [`controls-and-workflows.json`](controls-and-workflows.json) | Machine-readable control and workflow inventory |
| [`request-ledger.json`](request-ledger.json) | Machine-readable REST request ledger by workflow |
| [`DEFECTS.md`](DEFECTS.md) | Prioritised defect list with recommendations |
| [`CAPABILITIES.md`](CAPABILITIES.md) | This file — current capabilities summary |
