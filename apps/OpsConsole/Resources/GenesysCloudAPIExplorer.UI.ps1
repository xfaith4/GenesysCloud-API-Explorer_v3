<# 
.SYNOPSIS
  Genesys Cloud OpsConsole UI (WPF) loader.

.DESCRIPTION
  This loader keeps the public entrypoint stable while the UI implementation is split into smaller files:
    - UI/UI.PreMain.ps1 : helper functions and shared utilities
    - UI/MainWindow.xaml: the main window XAML
    - UI/UI.Run.ps1     : UI wiring + runtime execution

  NOTE: This file is intended to be dot-sourced by Start-GCOpsConsole in OpsConsole.psm1.
#>

$script:ResourcesRoot = $PSScriptRoot
$uiRoot = Join-Path -Path $PSScriptRoot -ChildPath "UI"

. (Join-Path -Path $uiRoot -ChildPath "UI.PreMain.ps1")
. (Join-Path -Path $uiRoot -ChildPath "Tabs/LiveSubscriptions.Tab.ps1")
. (Join-Path -Path $uiRoot -ChildPath "UI.Run.ps1")
