# OpsConsole UI (refactored split)

This directory contains the split UI implementation.

- `UI.PreMain.ps1` — helper functions, models, validation, shared utilities.
- `MainWindow.xaml` — the main window layout.
- `UI.Run.ps1` — UI wiring + event handlers + app runtime (creates the window and calls `ShowDialog()`).

The public entrypoint remains `Resources/GenesysCloudAPIExplorer.UI.ps1` (a thin loader).
