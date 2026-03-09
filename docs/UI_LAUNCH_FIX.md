# UI Launch Functionality Fix

## Overview
This document describes the changes made to fix the UI launch functionality for the refactored OpsConsole UI.

## Problem Statement
The OpsConsole UI was recently refactored into a modular structure with separate files:
- `apps/OpsConsole/Resources/UI/UI.PreMain.ps1` - Helper functions and utilities
- `apps/OpsConsole/Resources/UI/MainWindow.xaml` - XAML layout
- `apps/OpsConsole/Resources/UI/UI.Run.ps1` - UI wiring and runtime
- `apps/OpsConsole/Resources/GenesysCloudAPIExplorer.UI.ps1` - Entry point/loader

The issue was that when `UI.Run.ps1` was dot-sourced by the loader, `$PSScriptRoot` would be empty, causing the XAML file loading to fail.

## Root Cause
When a PowerShell script is dot-sourced (executed in the current scope using `. script.ps1`), the automatic variable `$PSScriptRoot` is not set in the sourced script. This caused line 3 of `UI.Run.ps1` to fail:

```powershell
$Xaml = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot "MainWindow.xaml")
```

## Solution
The fix implements a fallback strategy for path resolution in `UI.Run.ps1`:

```powershell
# When dot-sourced, $PSScriptRoot is empty. Use the UI directory path relative to where we were loaded from.
$uiDir = if ($PSScriptRoot) { 
    $PSScriptRoot 
} elseif ($script:ResourcesRoot) { 
    Join-Path -Path $script:ResourcesRoot -ChildPath "UI" 
} else { 
    Split-Path -Parent $MyInvocation.MyCommand.Definition 
}

$Xaml = Get-Content -Raw -LiteralPath (Join-Path $uiDir "MainWindow.xaml")
```

## How It Works

### Loading Sequence
1. User runs `GenesysCloudAPIExplorer.ps1` (repo root entry point)
2. It loads the OpsConsole module from `apps/OpsConsole/OpsConsole.psd1`
3. Module calls `Start-GCOpsConsole` which dot-sources `Resources/GenesysCloudAPIExplorer.UI.ps1`
4. The loader sets `$script:ResourcesRoot = $PSScriptRoot` (pointing to Resources directory)
5. Loader dot-sources:
   - `UI/UI.PreMain.ps1` - Gets `$ScriptRoot` overridden to `$script:ResourcesRoot`
   - `UI/Tabs/LiveSubscriptions.Tab.ps1` - Tab-specific functionality
   - `UI/UI.Run.ps1` - Uses the new fallback logic to find XAML file

### Path Resolution Strategy
The solution uses a three-tier fallback:
1. **First**: Use `$PSScriptRoot` if available (when script is run directly)
2. **Second**: Use `$script:ResourcesRoot/UI` if set by the loader (when dot-sourced)
3. **Third**: Use `Split-Path -Parent $MyInvocation.MyCommand.Definition` as final fallback

## Files Modified
- `apps/OpsConsole/Resources/UI/UI.Run.ps1` - Fixed XAML path resolution

## Testing
All tests pass successfully:
- ✓ Module loading
- ✓ UI loader script initialization
- ✓ Path resolution for all resource files
- ✓ XAML file can be located correctly
- ✓ All required dependencies present

## Launch Instructions
To launch the OpsConsole UI:

```powershell
# From the repository root
pwsh -File ./GenesysCloudAPIExplorer.ps1
```

Or use the module directly:

```powershell
Import-Module ./apps/OpsConsole/OpsConsole.psd1 -Force
Start-GCOpsConsole
```

## Related Files
- `apps/OpsConsole/Resources/GenesysCloudAPIExplorer.UI.ps1` - Sets `$script:ResourcesRoot`
- `apps/OpsConsole/Resources/UI/UI.PreMain.ps1` - Uses `$ScriptRoot` with override logic
- `apps/OpsConsole/Resources/UI/MainWindow.xaml` - Main UI layout
- `apps/OpsConsole/Resources/GenesysCloudAPIEndpoints.json` - API catalog (28MB)

## Future Considerations
- The current solution maintains backward compatibility with direct script execution
- The path resolution logic is centralized and can be reused if more files are added
- All resource files continue to load from the correct locations
