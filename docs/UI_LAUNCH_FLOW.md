# UI Launch Flow Diagram

## Before the Fix ❌

```
GenesysCloudAPIExplorer.ps1
    ↓
OpsConsole.psm1 → Start-GCOpsConsole
    ↓
GenesysCloudAPIExplorer.UI.ps1
    ↓ sets $script:ResourcesRoot = $PSScriptRoot (Resources dir)
    ↓
    ├─→ dot-source UI/UI.PreMain.ps1
    │       ↓ $PSScriptRoot = (empty when dot-sourced)
    │       ↓ BUT: Uses $script:ResourcesRoot fallback ✓
    │       
    └─→ dot-source UI/UI.Run.ps1
            ↓ Line 3: Join-Path $PSScriptRoot "MainWindow.xaml"
            ↓ $PSScriptRoot = (empty when dot-sourced)
            ✗ FAIL: Cannot find MainWindow.xaml
```

## After the Fix ✅

```
GenesysCloudAPIExplorer.ps1
    ↓
OpsConsole.psm1 → Start-GCOpsConsole
    ↓
GenesysCloudAPIExplorer.UI.ps1
    ↓ sets $script:ResourcesRoot = $PSScriptRoot (Resources dir)
    ↓
    ├─→ dot-source UI/UI.PreMain.ps1
    │       ↓ $PSScriptRoot = (empty when dot-sourced)
    │       ↓ Uses $script:ResourcesRoot fallback ✓
    │       ✓ Finds GenesysCloudAPIEndpoints.json
    │       
    └─→ dot-source UI/UI.Run.ps1
            ↓ NEW: $uiDir = fallback logic
            ↓   1. Try $PSScriptRoot (empty)
            ↓   2. Try $script:ResourcesRoot + "UI" ✓
            ↓   3. Fallback to $MyInvocation...
            ↓ 
            ✓ SUCCESS: Finds MainWindow.xaml
            ✓ UI launches successfully!
```

## Path Resolution Logic (UI.Run.ps1)

```powershell
# Three-tier fallback strategy
$uiDir = if ($PSScriptRoot) { 
    # Direct execution (script run with .\UI.Run.ps1)
    $PSScriptRoot 
} elseif ($script:ResourcesRoot) { 
    # Dot-sourced by loader (CURRENT SCENARIO)
    Join-Path -Path $script:ResourcesRoot -ChildPath "UI" 
} else { 
    # Final fallback
    Split-Path -Parent $MyInvocation.MyCommand.Definition 
}

# Now load XAML successfully
$Xaml = Get-Content -Raw -LiteralPath (Join-Path $uiDir "MainWindow.xaml")
```

## Key Insight

**The Problem:**
- `$PSScriptRoot` is ONLY set when a script is executed directly (e.g., `.\script.ps1`)
- When dot-sourced (`. .\script.ps1`), `$PSScriptRoot` is EMPTY in the sourced script

**The Solution:**
- The loader (`GenesysCloudAPIExplorer.UI.ps1`) sets `$script:ResourcesRoot` BEFORE dot-sourcing
- UI.Run.ps1 now checks `$script:ResourcesRoot` as a fallback
- This allows proper path resolution regardless of execution method

## File Locations

```
Genesys-API-Explorer-2/
├── GenesysCloudAPIExplorer.ps1                    ← Entry point
├── apps/OpsConsole/
│   ├── OpsConsole.psd1                            ← Module manifest
│   ├── OpsConsole.psm1                            ← Exports Start-GCOpsConsole
│   └── Resources/
│       ├── GenesysCloudAPIExplorer.UI.ps1         ← Loader (sets ResourcesRoot)
│       ├── GenesysCloudAPIEndpoints.json          ← 28MB API catalog
│       ├── DefaultTemplates.json
│       ├── ExamplePostBodies.json
│       ├── design-tokens.psd1
│       ├── UxTelemetry.ps1
│       └── UI/
│           ├── README.md
│           ├── MainWindow.xaml                    ← XAML layout (FIXED)
│           ├── UI.PreMain.ps1                     ← Helper functions
│           ├── UI.Run.ps1                         ← Runtime (FIXED)
│           └── Tabs/
│               └── LiveSubscriptions.Tab.ps1
└── docs/
    └── UI_LAUNCH_FIX.md                          ← Documentation
```
