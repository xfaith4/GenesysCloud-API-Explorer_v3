# Test Package

This repository now has a profile-driven Pester package that covers:

- Exhaustive source parsing and function contract checks.
- Public module surface contracts (OpsInsights, OpsConsole, Core, Notifications Toolkit).
- UI contract checks (`UI.Run` control bindings vs `MainWindow.xaml`).
- UI regression checks for Conversation Filter Builder (`dimension`/`metric`/`property` predicates and body serialization).
- Offline unit coverage for Notifications Toolkit and UX telemetry.
- Artifact contracts (JSON and insight pack validation).
- Optional live integration smoke tests.

## Run

From repo root:

```powershell
.\tools\Test.ps1 -Profile Fast
.\tools\Test.ps1 -Profile Full
.\tools\Test.ps1 -Profile Integration
.\tools\Test.ps1 -Profile Full -EnableCoverage -MinimumCoverage 1
```

## Profiles

- `Fast`: excludes `Integration` and `Slow` tags.
- `Full`: runs all non-integration tests.
- `Integration`: runs only tests tagged `Integration`.

## Environment Variables (Integration)

- `GC_API_BASE_URI`
- `GC_ACCESS_TOKEN`

If these are not set, integration tests are skipped.

## Outputs

Test and coverage reports are written under:

`artifacts/test-results/`
