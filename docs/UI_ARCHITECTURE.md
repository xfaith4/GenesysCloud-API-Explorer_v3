# UI Architecture

## Lifecycle
1. **Load catalog** – `UI.PreMain.ps1` initializes design tokens, loads the API catalog, and imports the OpsInsights modules.
2. **Bind controls** – `UI.Run.ps1` parses `MainWindow.xaml`, resolves named controls, and seeds script-scoped collections and defaults.
3. **Handle events** – `UI.Run.ps1` wires tab navigation, request submission, filtering, and feature-specific click handlers.
4. **Export** – responses, logs, templates, and feature outputs are exported through button handlers after requests complete.

## State
- Script-level state for authentication, design tokens, filter builder data, live subscription collections, and operations dashboard data is defined in `UI.PreMain.ps1`.
- Runtime UI state such as request history, templates, layout defaults, and per-feature observable collections is created in `UI.Run.ps1` after the XAML is loaded.

## API calls
- Transport helpers and module loading live in `UI.PreMain.ps1` (e.g., `Ensure-OpsInsightsModuleLoaded`, `Ensure-OpsInsightsContext`, token/region helpers).
- UI event handlers in `UI.Run.ps1` call module functions and request helpers (`Invoke-GCRequest`, OpsInsights workflows, notification subscriptions), keeping `UI.Run` as the composition root while the modules perform the work.
