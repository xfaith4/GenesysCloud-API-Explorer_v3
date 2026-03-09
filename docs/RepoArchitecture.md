# Repository Architecture & Startup Flow

This repo is intentionally structured as a layered PowerShell experience rather than a single monolithic project. The following sections describe how pieces map together and clarify the references between `GenesysCloudAPIExplorer.ps1`, the OpsInsights modules, and the OpsConsole UI.

## 1. Launch path

1. `GenesysCloudAPIExplorer.ps1` (root script) is the primary entry point. It:
   * Detects the repo root and ModulePath.
   * Imports the three manifests: `src/GenesysCloud.OpsInsights.Core/GenesysCloud.OpsInsights.Core.psd1`, `src/GenesysCloud.OpsInsights/GenesysCloud.OpsInsights.psd1`, and `apps/OpsConsole/OpsConsole.psd1`.
   * Starts the `Start-GCOpsConsole` command defined in the OpsConsole module.
2. `OpsConsole.psd1` exports `Start-GCOpsConsole`, which in turn imports `GenesysCloud.OpsInsights` (ensuring the analytics helpers are available) and then loads `apps/OpsConsole/Resources/GenesysCloudAPIExplorer.UI.ps1`.
3. The UI script wires together the WPF window, loads module helpers (modules, scripts, new Notifications toolkit, insight packs), and renders the user experience described in `apps/OpsConsole/Resources/GenesysCloudAPIExplorer.UI.ps1`.

## 2. What lives where?

| Location | Role |
| --- | --- |
| `GenesysCloudAPIExplorer.ps1` | Bootstraps module manifests and starts the UI. |
| `src/GenesysCloud.OpsInsights.Core` | Pure helpers referenced by the module and occasionally dot-sourced by the UI (lightweight utilities). |
| `src/GenesysCloud.OpsInsights` | Contains the OpsInsights module manifest plus `Public/` and `Private/` cmdlets (insight packs, export helpers, request helpers). |
| `apps/OpsConsole` | Defines the OpsConsole module, UI resources, telemetry helpers, and any UI-specific commands. Resources include the giant `GenesysCloudAPIExplorer.UI.ps1` which loads UI controls and Ill patterns. |
| `Scripts/GenesysCloud.NotificationsToolkit` | New toolkit for notifications channel creation, websocket capture, and JSONL summaries used by the Live Subscriptions/Operational Events tabs. |
| `insights/` and `insightpacks/` | Schema/data for insight packs/compositions, along with briefings; the UI loads these via awareness of `insights/packs`. |
| `docs/` | Repository-level documentation (new `RepoArchitecture.md`, LiveSubscriptions notes, etc.). |

## 3. Module references & metadata

* `src/GenesysCloud.OpsInsights/GenesysCloud.OpsInsights.psd1` exposes the public commands the UI consumes. Private helpers live in `Private/` but are dot-sourced from the manifest when needed.
* `OpsConsole.psd1` and `GenesysCloud.OpsInsights` each include `PSData` metadata (`CompanyName`, `Description`, `NestedModules`) to help PowerShell tab completion and installation.
* The UI script (`Axes...UI.ps1`) explicitly loads the manifests, insight pack roots, and our new notifications toolkit at startup so the UI can call `Invoke-GCRequest`, start live subscriptions, and run insight packs without additional wiring.

## 4. Developer guidance

- When adding new high-level workflows, keep helpers in `src/GenesysCloud.OpsInsights/Public` if they are purely command-line, and use `apps/OpsConsole/Resources/GenesysCloudAPIExplorer.UI.ps1` only for UI wiring, not business logic.
- Scripts that serve tooling (e.g., `Scripts/GenesysCloud.NotificationsToolkit`) are referenced by the UI as-needed and keep iso dependencies so they can be reused outside the UI.
- Insight pack/composition documents live under `insightpacks/`, and `insights/packs` for evidence/briefing output. Keep these data-only files separate from scripts so the UI can load them via the existing discovery helpers.

## 5. Visualizing the startup chain

```
GenesysCloudAPIExplorer.ps1
├── src/GenesysCloud.OpsInsights.Core (helper module)
├── src/GenesysCloud.OpsInsights (primary module + commands)
└── apps/OpsConsole/OpsConsole.psd1
     └── apps/OpsConsole/Resources/GenesysCloudAPIExplorer.UI.ps1
           ├── insights/ (packs + schema)
           ├── Scripts/GenesysCloud.NotificationsToolkit (live notifications)
           └── UI wiring (tabs, buttons, exports)
```

Keeping this flow in mind ensures new features (Live Subscriptions, operational event tabs, audit investigator) land in the correct layer without creating circular references.
