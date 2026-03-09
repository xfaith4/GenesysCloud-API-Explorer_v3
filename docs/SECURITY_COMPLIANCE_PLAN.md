# Security & Compliance Plan (Conversation Ingest & Ops Dashboard)

Status: draft → implement incrementally (no placeholders; each item actionable)

## Data Classification & Scope
- Treat conversation details as High/Restricted (PII/PHI).
- Default ingest scope: conversation metadata (ids, division/queue/agent ids, MOS, error codes). Avoid transcripts unless explicitly enabled.
- Document fields ingested and retained; review any downstream exports for PII/PHI.

## Controls to Implement
1) **Data Minimization / Masking (ingest path)**
   - Strip or mask names, emails, phone numbers (ani/dnis/address fields) in participants/sessions before writing JSONL.
   - Do not store transcripts by default; gate transcript inclusion behind an explicit flag/env.
   - Keep IDs (conversation/division/queue/agent), MOS, errorCode, timestamps for KPIs.

2) **Retention & Purge**
   - Configurable retention window (e.g., 30/90 days).
   - Nightly purge task removes records older than window from `dashboard-store.jsonl` and related captures.
   - Log purge actions (who, when, counts).

3) **Audit Logging**
   - Log ingest runs: user, interval, records written, store path, hash/size.
   - Log exports/views: user, action, target file/path.
   - Store audit log under `artifacts/ops-dashboard/ingest-audit.log` (or similar), rotated by size.

4) **Access Control / Gating**
   - Gate ingest/export buttons behind an allowlist (env/config) or AD group check.
   - Fail closed: show “restricted” status if user not allowed.

5) **Redacted Exports**
   - Provide a redacted KPI export (Division/Queue/Agent aggregates only; no raw records).
   - Label files as redacted; include generation timestamp and thresholds used.

6) **Credential Hygiene**
   - Use minimal-scope client credential for scheduled ingest; store in vault/credential manager.
   - Never persist OAuth tokens; avoid secrets in task definitions.

7) **Transport & Storage**
   - Keep artifacts on encrypted volume; lock down ACLs to least-privileged group.
   - TLS 1.2+ for all API traffic (default).

8) **DLP & Monitoring**
   - Register artifact path with org DLP if applicable.
   - Alert on ingest failures, volume spikes, or disabled masking flag.

## Immediate Implementation Steps
- [ ] Mask PII/PHI in `Invoke-GCConversationIngest` before writing JSONL; add “include transcripts” opt-in flag (off by default).
- [ ] Add `Invoke-GCDashboardStoreRetention` (retention purge helper) with default window + logging.
- [ ] Add audit log writes for ingest/export actions (`artifacts/ops-dashboard/ingest-audit.log`).
- [ ] UI gating for ingest/export via allowlist env/config; show restricted state when blocked.
- [ ] Add “Export KPI Rollup (redacted)” button that uses aggregates only.
- [ ] Scheduled ingest uses dynamic interval + minimal creds hook (plumb to vault/credential manager when available).

## Open Decisions
- Retention window default (30 vs 90 days)?
- Allowlist source: env var (`GENESYS_API_EXPLORER_ALLOWED_USERS`) vs AD group?
- Do we ever store transcripts? If yes, how to redact/tokenize them?
- Vault choice for scheduled ingest credentials (Windows CredMan vs org vault).
