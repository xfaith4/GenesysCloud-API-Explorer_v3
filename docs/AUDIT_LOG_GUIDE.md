# Audit Log Guide

## Locations
- `artifacts/ops-dashboard/ingest-audit.log` — ingest + retention events
  - Format: `<UTC ISO8601> | <User> | <Message>`
- (Planned) export/audit entries are written via Add-LogEntry + blocking; UI gating uses allowlist + token checks.

## What is logged today
- Ingest runs: interval, jobId, records written, store path (from `Invoke-GCConversationIngest`).
- Retention: kept/dropped counts, threshold (from `Invoke-GCDashboardStoreRetention`).
- UI blocks: Add-LogEntry captures user blocks for ingest/export when not allowed or token missing.

## Viewing
```powershell
Get-Content artifacts/ops-dashboard/ingest-audit.log -Tail 50
```

## Next steps
- Surface a simple viewer in the Ops Dashboard (read-only ListBox + refresh).
- Add explicit export entries (export type, user, target path).
- Add rotation (size-based) if log grows large.
