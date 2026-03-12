<#
.SYNOPSIS
    Genesys Cloud API Explorer GUI Tool (WPF)

.DESCRIPTION
    Uses WPF to provide a more structured API explorer experience with
    grouped navigation, dynamic parameter inputs, and a transparency-focused
    log so every request/response step is visible.

.NOTES
    - Valid JSON catalog required from the Genesys Cloud API Explorer.
    - Paste your OAuth token into the supplied field before sending requests.
    - UI implementation script (launch via `.\GenesysCloudAPIExplorer.ps1` from repo root).
#>

if ($IsWindows -or $env:OS -eq 'Windows_NT') {
    Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase, System.Xaml
    Add-Type -AssemblyName System.Windows.Forms
}

#region State + Models
$ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
if (-not $ScriptRoot) {
    $ScriptRoot = Get-Location
}

# Refactor split: preserve original Resources root (loader sets this)
if ($script:ResourcesRoot) {
    $ScriptRoot = $script:ResourcesRoot
}

$script:LiveSubscriptionTopicCatalogCachePath = $null
$cacheOverride = if ($env:GENESYS_API_EXPLORER_NOTIFICATION_TOPICS_PATH) { $env:GENESYS_API_EXPLORER_NOTIFICATION_TOPICS_PATH } else { '' }
$defaultCache = Join-Path -Path $ScriptRoot -ChildPath 'GenesysCloudNotificationTopics.json'
$script:LiveSubscriptionTopicCatalogCachePath = if (-not [string]::IsNullOrWhiteSpace($cacheOverride)) {
    [System.IO.Path]::GetFullPath($cacheOverride)
}
$script:LiveSubscriptionTopicCatalogCachePath = if (-not $script:LiveSubscriptionTopicCatalogCachePath) { $defaultCache } else { $script:LiveSubscriptionTopicCatalogCachePath }

$DeveloperDocsUrl = "https://developer.genesys.cloud"
$SupportDocsUrl = "https://help.mypurecloud.com"

function Get-RepoRoot {
    param([string]$StartPath)

    $current = if ($StartPath) { $StartPath } else { $ScriptRoot }
    for ($i = 0; $i -lt 5; $i++) {
        if (Test-Path -LiteralPath (Join-Path $current "GenesysCloudAPIExplorer.ps1")) {
            return $current
        }
        $parent = Split-Path -Parent $current
        if (-not $parent -or $parent -eq $current) { break }
        $current = $parent
    }

    return $ScriptRoot
}

. "$ScriptRoot/UxTelemetry.ps1"
$script:UxSessionId = [guid]::NewGuid().ToString()
$telemetryRoot = Join-Path (Get-RepoRoot -StartPath $ScriptRoot) 'artifacts/ux-simulations'
$telemetryRoot = [System.IO.Path]::GetFullPath($telemetryRoot)
Initialize-UxTelemetry -TargetPath (Get-UxTelemetryDefaultPath -RootPath $telemetryRoot) -SessionId $script:UxSessionId

$script:DesignTokens = @{}
try {
    $designTokenPath = Join-Path -Path $ScriptRoot -ChildPath "design-tokens.psd1"
    if (Test-Path -LiteralPath $designTokenPath) {
        $script:DesignTokens = Import-PowerShellDataFile -LiteralPath $designTokenPath
    }
}
catch {
    Write-Verbose "Design tokens failed to load: $($_.Exception.Message)"
}
$script:UxDebugBlock = $null
$script:UxDebugWindow = $null
$script:RageClickWindowSeconds = 2
$script:SubmitClickTimes = New-Object System.Collections.Generic.Queue[datetime]
#endregion State + Models

function Get-TraceLogPath {
    try {
        $base = [System.IO.Path]::GetTempPath()
        if (-not $base) { $base = $ScriptRoot }
        $stamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
        return (Join-Path -Path $base -ChildPath "GenesysApiExplorer.trace.$stamp.log")
    }
    catch {
        return $null
    }
}

$script:TraceEnabled = $false
try {
    $traceRaw = [string]$env:GENESYS_API_EXPLORER_TRACE
    $script:TraceEnabled = ($traceRaw -match '^(1|true|yes|on)$')
}
catch { }

$script:TraceLogPath = if ($script:TraceEnabled) { Get-TraceLogPath } else { $null }

#region Logging
function Write-TraceLog {
    param([string]$Message)

    if (-not $script:TraceEnabled) { return }
    if ([string]::IsNullOrWhiteSpace($script:TraceLogPath)) { return }

    try {
        $ts = (Get-Date).ToString('o')
        Add-Content -LiteralPath $script:TraceLogPath -Value "$ts $Message" -Encoding utf8
    }
    catch { }
}
#endregion Logging

#region UI helpers
function Set-DesignSystemResources {
    param([System.Windows.Window]$Window)

    if (-not $Window -or -not $script:DesignTokens) { return }

    try {
        $color = $script:DesignTokens.Color
        $spacing = $script:DesignTokens.Spacing
        $radius = $script:DesignTokens.Radius

        $primaryBrush = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString([string]$color.Primary))
        $accentBrush = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString([string]$color.Accent))
        $surfaceBrush = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString([string]$color.Surface))
        $surfaceMutedBrush = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString([string]$color.SurfaceMuted))
        $borderBrush = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString([string]$color.Border))
        $textPrimary = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString([string]$color.TextPrimary))
        $textSecondary = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString([string]$color.TextSecondary))

        $Window.Resources["PrimaryBrush"] = [System.Windows.Media.Brush]$primaryBrush
        $Window.Resources["AccentBrush"] = [System.Windows.Media.Brush]$accentBrush
        $Window.Resources["SurfaceBrush"] = [System.Windows.Media.Brush]$surfaceBrush
        $Window.Resources["SurfaceMutedBrush"] = [System.Windows.Media.Brush]$surfaceMutedBrush
        $Window.Resources["BorderBrush"] = [System.Windows.Media.Brush]$borderBrush
        $Window.Resources["TextPrimaryBrush"] = [System.Windows.Media.Brush]$textPrimary
        $Window.Resources["TextSecondaryBrush"] = [System.Windows.Media.Brush]$textSecondary
        $Window.Resources["CornerRadiusMD"] = New-Object System.Windows.CornerRadius ($radius.MD)
        $Window.Resources["SpacingSM"] = $spacing.SM
        $Window.Resources["SpacingMD"] = $spacing.MD

        $Window.Background = [System.Windows.Media.Brush]$surfaceBrush
    }
    catch {
        # Keep defaults if token application fails
    }
}

function Update-UxDebugHud {
    param(
        [string]$Route,
        [string]$Status,
        [string]$LastEvent
    )

    if (-not $script:UxDebugBlock) { return }
    $script:UxDebugBlock.Text = "Route: $Route`nStatus: $Status`nLast: $LastEvent`nSession: $script:UxSessionId"
}

function Ensure-UxDebugHud {
    param([System.Windows.Window]$Window)

    if (-not $Window) { return }
    $debugFlag = [string]$env:GENESYS_API_EXPLORER_DEBUG_UI
    if (-not ($debugFlag -match '^(1|true|yes)$')) { return }

    $hud = New-Object System.Windows.Window
    $hud.Width = 320
    $hud.Height = 170
    $hud.Topmost = $true
    $hud.WindowStyle = 'ToolWindow'
    $hud.ResizeMode = 'NoResize'
    $hud.ShowInTaskbar = $false
    $hud.Title = "UX Debug HUD"
    $hud.Owner = $Window

    $panel = New-Object System.Windows.Controls.Border
    $panel.Padding = '10'
    $panel.Background = $Window.Resources["SurfaceMutedBrush"]
    $panel.BorderBrush = $Window.Resources["BorderBrush"]
    $panel.BorderThickness = '1'
    if ($Window.Resources["CornerRadiusMD"]) {
        $panel.CornerRadius = $Window.Resources["CornerRadiusMD"]
    }

    $text = New-Object System.Windows.Controls.TextBlock
    $text.Foreground = $Window.Resources["TextPrimaryBrush"]
    $text.TextWrapping = 'Wrap'
    $text.Text = "UX debug ready..."
    $panel.Child = $text

    $hud.Content = $panel
    $script:UxDebugBlock = $text
    $script:UxDebugWindow = $hud
    $hud.Show()
}

function Open-Url {
    param ([string]$Url)

    if (-not $Url) { return }
    try {
        Start-Process -FilePath $Url
    }
    catch {
        Write-Warning "Unable to open URL '$Url': $($_.Exception.Message)"
    }
}

function Launch-Url {
    param ([string]$Url)
    Open-Url -Url $Url
}

function Get-FirstNonEmptyValue {
    param(
        [Parameter()]
        [AllowNull()]
        [object[]]$Values = @(),
        [Parameter()]
        [object]$Default = $null
    )

    if ($null -eq $Values -or $Values.Count -eq 0) {
        try {
            $caller = $null
            try { $caller = (Get-PSCallStack | Select-Object -Skip 1 -First 1).Command } catch { }
            Write-TraceLog "Get-FirstNonEmptyValue: Values is null/empty; returning default. Caller='$caller'"
        }
        catch { }
        return $Default
    }

    foreach ($v in $Values) {
        if ($null -eq $v) { continue }
        if ($v -is [string]) {
            if (-not [string]::IsNullOrWhiteSpace($v)) { return $v }
        }
        else {
            return $v
        }
    }
    return $Default
}

function Get-InsightPackCatalog {
    param(
        [Parameter()]
        [string]$PackDirectory,

        [Parameter()]
        [string]$LegacyPackDirectory
    )

    if (-not $PackDirectory -and -not $LegacyPackDirectory) {
        throw "Get-InsightPackCatalog: Provide -PackDirectory and/or -LegacyPackDirectory."
    }

    $dirs = New-Object System.Collections.Generic.List[string]
    foreach ($d in @($PackDirectory, $LegacyPackDirectory)) {
        if ($d -and (Test-Path -LiteralPath $d)) { $dirs.Add($d) | Out-Null }
    }

    $items = New-Object System.Collections.Generic.List[object]
    $script:InsightPackCatalogErrors = New-Object System.Collections.Generic.List[string]
    Write-TraceLog "Get-InsightPackCatalog: PackDirectory='$PackDirectory' (exists=$(Test-Path -LiteralPath $PackDirectory))"
    foreach ($dir in $dirs) {
        $files = @()
        try {
            $files = @(Get-ChildItem -LiteralPath $dir -File -ErrorAction Stop | Where-Object { $_.Extension -eq '.json' } | Sort-Object Name)
            Write-TraceLog "Get-InsightPackCatalog: dir='$dir' jsonCount=$($files.Count)"
        }
        catch {
            try { $script:InsightPackCatalogErrors.Add("$dir :: $($_.Exception.Message)") | Out-Null } catch { }
            Write-TraceLog "Get-InsightPackCatalog: dir='$dir' enumerate error: $($_.Exception.Message)"
            continue
        }

        foreach ($file in $files) {
            $packPath = $file.FullName
            try {
                $raw = Get-Content -LiteralPath $packPath -Raw -Encoding utf8
                $pack = $raw | ConvertFrom-Json
                if (-not $pack) {
                    Write-TraceLog "Get-InsightPackCatalog: file='$packPath' parsed pack is null"
                    continue
                }
                if (-not $pack.id) {
                    Write-TraceLog "Get-InsightPackCatalog: file='$packPath' missing/empty id"
                    continue
                }

                $examples = @()
                if ($pack -and ($pack.PSObject.Properties.Name -contains 'examples') -and $pack.examples) {
                    foreach ($ex in @($pack.examples)) {
                        if (-not $ex) { continue }
                        $examples += [pscustomobject]@{
                            Title      = [string](Get-FirstNonEmptyValue -Values @($ex.title, $ex.name) -Default 'Example')
                            Notes      = [string](Get-FirstNonEmptyValue -Values @($ex.notes) -Default '')
                            Parameters = $ex.parameters
                        }
                    }
                }

                $items.Add([pscustomobject]@{
                        Id                 = [string]$pack.id
                        Name               = [string](Get-FirstNonEmptyValue -Values @($pack.name, $pack.id) -Default $pack.id)
                        Version            = [string](Get-FirstNonEmptyValue -Values @($pack.version) -Default '')
                        Description        = [string](Get-FirstNonEmptyValue -Values @($pack.description) -Default '')
                        Scopes             = @(Get-FirstNonEmptyValue -Values @($pack.scopes, $pack.requiredScopes) -Default @())
                        Owner              = [string](Get-FirstNonEmptyValue -Values @($pack.owner) -Default '')
                        Maturity           = [string](Get-FirstNonEmptyValue -Values @($pack.maturity) -Default '')
                        ExpectedRuntimeSec = if ($pack.PSObject.Properties.Name -contains 'expectedRuntimeSec') { $pack.expectedRuntimeSec } else { $null }
                        Tags               = @($pack.tags)
                        Endpoints          = @(
                            foreach ($step in @($pack.pipeline)) {
                                if (-not $step -or -not $step.type) { continue }
                                $t = $step.type.ToString().ToLowerInvariant()
                                if ($t -eq 'gcrequest') {
                                    (Get-FirstNonEmptyValue -Values @($step.uri, $step.path) -Default $null)
                                }
                                elseif ($t -eq 'jobpoll' -and $step.create) {
                                    (Get-FirstNonEmptyValue -Values @($step.create.uri, $step.create.path) -Default $null)
                                }
                                elseif ($t -eq 'join' -and $step.lookup) {
                                    (Get-FirstNonEmptyValue -Values @($step.lookup.uri, $step.lookup.path) -Default $null)
                                }
                            }
                        ) | Where-Object { $_ }
                        Examples           = $examples
                        FileName           = $file.Name
                        FullPath           = $file.FullName
                        Pack               = $pack
                        Display            = if ($pack.name) { "$($pack.name)  [$($pack.id)]" } else { [string]$pack.id }
                    }) | Out-Null
                Write-TraceLog "Get-InsightPackCatalog: loaded id='$($pack.id)' name='$($pack.name)' file='$($file.Name)'"
            }
            catch {
                try { $script:InsightPackCatalogErrors.Add("$packPath :: $($_.Exception.Message)") | Out-Null } catch { }
                Write-TraceLog "Get-InsightPackCatalog: file='$packPath' parse error: $($_.Exception.Message)"
            }
        }
    }

    Write-TraceLog "Get-InsightPackCatalog: totalLoaded=$($items.Count)"
    return @($items | Sort-Object Name, Id)
}

function Get-InsightTimePresets {
    return @(
        [pscustomobject]@{ Key = 'last7'; Name = 'Last 7 days (ending now)' },
        [pscustomobject]@{ Key = 'last30'; Name = 'Last 30 days (ending now)' },
        [pscustomobject]@{ Key = 'thisWeek'; Name = 'This week (Mon 00:00 -> now, UTC)' },
        [pscustomobject]@{ Key = 'lastWeek'; Name = 'Last full week (Mon -> Mon, UTC)' },
        [pscustomobject]@{ Key = 'thisMonth'; Name = 'This month (1st 00:00 -> now, UTC)' },
        [pscustomobject]@{ Key = 'lastMonth'; Name = 'Last full month (1st -> 1st, UTC)' }
    )
}

function Resolve-InsightUtcWindowFromPreset {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$PresetKey
    )

    $now = (Get-Date).ToUniversalTime()

    function Start-OfWeekUtc {
        param([datetime]$UtcNow)

        $dow = [int]$UtcNow.DayOfWeek
        $mondayIndex = 1
        $daysSinceMonday = ($dow - $mondayIndex)
        if ($daysSinceMonday -lt 0) { $daysSinceMonday += 7 }
        $start = $UtcNow.Date.AddDays(-1 * $daysSinceMonday)
        return [datetime]::SpecifyKind($start, [System.DateTimeKind]::Utc)
    }

    function Start-OfMonthUtc {
        param([datetime]$UtcNow)
        $start = New-Object datetime($UtcNow.Year, $UtcNow.Month, 1, 0, 0, 0)
        return [datetime]::SpecifyKind($start, [System.DateTimeKind]::Utc)
    }

    switch ($PresetKey) {
        'last7' {
            return [pscustomobject]@{ StartUtc = $now.AddDays(-7); EndUtc = $now }
        }
        'last30' {
            return [pscustomobject]@{ StartUtc = $now.AddDays(-30); EndUtc = $now }
        }
        'thisWeek' {
            return [pscustomobject]@{ StartUtc = (Start-OfWeekUtc -UtcNow $now); EndUtc = $now }
        }
        'lastWeek' {
            $thisWeekStart = Start-OfWeekUtc -UtcNow $now
            return [pscustomobject]@{ StartUtc = $thisWeekStart.AddDays(-7); EndUtc = $thisWeekStart }
        }
        'thisMonth' {
            return [pscustomobject]@{ StartUtc = (Start-OfMonthUtc -UtcNow $now); EndUtc = $now }
        }
        'lastMonth' {
            $thisMonthStart = Start-OfMonthUtc -UtcNow $now
            return [pscustomobject]@{ StartUtc = $thisMonthStart.AddMonths(-1); EndUtc = $thisMonthStart }
        }
        default {
            throw "Unknown time preset key: $PresetKey"
        }
    }
}

function New-InsightPackParameterRow {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter()]
        [string]$Type,

        [Parameter()]
        [bool]$Required = $false,

        [Parameter()]
        $DefaultValue,

        [Parameter()]
        [string]$Description
    )

    $grid = New-Object System.Windows.Controls.Grid
    $grid.Margin = '0,2,0,2'
    [void]$grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = '220' }))
    [void]$grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = '*' }))

    $label = New-Object System.Windows.Controls.TextBlock
    $label.Text = if ($Required) { "$Name *" } else { $Name }
    $label.FontWeight = 'SemiBold'
    $label.VerticalAlignment = 'Center'
    if ($Description) { $label.ToolTip = $Description }
    [System.Windows.Controls.Grid]::SetColumn($label, 0)
    [void]$grid.Children.Add($label)

    $control = $null
    $normalizedType = if ($Type) { $Type.ToLowerInvariant() } else { '' }
    if ($normalizedType -in @('bool', 'boolean')) {
        $cb = New-Object System.Windows.Controls.CheckBox
        $cb.VerticalAlignment = 'Center'
        $cb.IsChecked = if ($null -ne $DefaultValue) { [bool]$DefaultValue } else { $false }
        if ($Description) { $cb.ToolTip = $Description }
        $control = $cb
    }
    else {
        $tb = New-Object System.Windows.Controls.TextBox
        $tb.MinWidth = 220
        $tb.Height = 26
        $tb.VerticalContentAlignment = 'Center'
        $tb.Text = if ($null -ne $DefaultValue) { [string]$DefaultValue } else { '' }
        if ($Description) { $tb.ToolTip = $Description }
        $control = $tb
    }

    [System.Windows.Controls.Grid]::SetColumn($control, 1)
    [void]$grid.Children.Add($control)

    return [pscustomobject]@{
        Name    = $Name
        Control = $control
        Row     = $grid
    }
}

function Render-InsightPackParameters {
    param(
        [Parameter(Mandatory)]
        $Pack,

        [Parameter(Mandatory)]
        [System.Windows.Controls.Panel]$Panel
    )

    $Panel.Children.Clear()
    $script:InsightParamInputs = @{}

    if (-not $Pack -or -not $Pack.parameters) {
        $hint = New-Object System.Windows.Controls.TextBlock
        $hint.Text = '(No parameters)'
        $hint.Foreground = 'Gray'
        [void]$Panel.Children.Add($hint)
        return
    }

    foreach ($prop in ($Pack.parameters.PSObject.Properties | Sort-Object Name)) {
        $paramName = $prop.Name
        $definition = $prop.Value

        $type = $null
        $required = $false
        $default = $null
        $desc = $null

        if ($definition -is [psobject]) {
            $names = @($definition.PSObject.Properties.Name)
            $isSchema = ($names -contains 'type') -or ($names -contains 'required') -or ($names -contains 'default') -or ($names -contains 'description')
            if ($isSchema) {
                $type = [string]$definition.type
                if ($names -contains 'required') { $required = [bool]$definition.required }
                if ($names -contains 'default') { $default = $definition.default }
                if ($names -contains 'description') { $desc = [string]$definition.description }
            }
            else {
                $default = $definition
            }
        }
        else {
            $default = $definition
        }

        $row = New-InsightPackParameterRow -Name $paramName -Type $type -Required:$required -DefaultValue $default -Description $desc
        $script:InsightParamInputs[$paramName] = $row.Control
        [void]$Panel.Children.Add($row.Row)
    }
}

function Get-InsightPackParameterValues {
    $values = @{}
    foreach ($name in $script:InsightParamInputs.Keys) {
        $control = $script:InsightParamInputs[$name]
        if ($control -is [System.Windows.Controls.CheckBox]) {
            $values[$name] = [bool]$control.IsChecked
            continue
        }
        if ($control -is [System.Windows.Controls.TextBox]) {
            $text = $control.Text
            if (-not [string]::IsNullOrWhiteSpace($text)) {
                $values[$name] = $text.Trim()
            }
        }
    }
    return $values
}

function Show-HelpWindow {
    $helpXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Explorer Help" Height="420" Width="520" ResizeMode="NoResize" WindowStartupLocation="CenterOwner">
  <Border Margin="10" Padding="12" BorderBrush="LightGray" BorderThickness="1" Background="White">
    <StackPanel>
      <TextBlock Text="Genesys Cloud API Explorer Help" FontSize="16" FontWeight="Bold" Margin="0 0 0 8"/>
      <TextBlock TextWrapping="Wrap">
        This explorer mirrors the Genesys Cloud API catalog while keeping transparency front and center. Use the grouped navigator to select any endpoint, provide query/path/body values, and press Submit to send requests.
      </TextBlock>
      <TextBlock TextWrapping="Wrap" Margin="0 6 0 0">
        Feature highlights: dynamic parameter rendering, large payload inspector/export, schema viewer, job watcher for bulk requests, and favorites storage alongside logs that capture every action.
      </TextBlock>
      <StackPanel Margin="0 12 0 0">
        <TextBlock FontWeight="Bold">Usage notes</TextBlock>
        <TextBlock TextWrapping="Wrap" Margin="0 2 0 0">
          - Provide an OAuth token before submitting calls. An invalid token will surface through the log and response panel.
        </TextBlock>
        <TextBlock TextWrapping="Wrap" Margin="0 2 0 0">
          - When a job endpoint returns an identifier, the Job Watch tab polls it automatically and saves results to a temp file you can inspect/export.
        </TextBlock>
        <TextBlock TextWrapping="Wrap" Margin="0 2 0 0">
          - Favorites persist under your Windows profile (~\GenesysApiExplorerFavorites.json) and store both endpoint metadata and body payloads.
        </TextBlock>
      </StackPanel>
      <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0 12 0 0">
        <Button Name="OpenDevDocs" Width="140" Height="30" Content="Developer Portal" Margin="0 0 10 0"/>
        <Button Name="OpenSupportDocs" Width="140" Height="30" Content="Genesys Support"/>
      </StackPanel>
      <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0 8 0 0">
        <Button Name="CloseHelp" Width="90" Height="28" Content="Close"/>
      </StackPanel>
    </StackPanel>
  </Border>
</Window>
"@

    $helpWindow = [System.Windows.Markup.XamlReader]::Parse($helpXaml)
    if (-not $helpWindow) {
        Write-Warning "Unable to instantiate help window."
        return
    }

    $openDevButton = $helpWindow.FindName("OpenDevDocs")
    $openSupportButton = $helpWindow.FindName("OpenSupportDocs")
    $closeButton = $helpWindow.FindName("CloseHelp")

    if ($openDevButton) {
        $openDevButton.Add_Click({ Launch-Url -Url $DeveloperDocsUrl })
    }
    if ($openSupportButton) {
        $openSupportButton.Add_Click({ Launch-Url -Url $SupportDocsUrl })
    }
    if ($closeButton) {
        $closeButton.Add_Click({ $helpWindow.Close() })
    }

    if ($Window) {
        $helpWindow.Owner = $Window
    }
    $helpWindow.ShowDialog() | Out-Null
}

function Show-SettingsDialog {
    param (
        [string]$CurrentJsonPath
    )

    $settingsXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Endpoints Configuration" Height="360" Width="760"
        MinHeight="340" MinWidth="640"
        ResizeMode="CanResizeWithGrip"
        WindowStartupLocation="CenterOwner" ShowInTaskbar="False">
  <StackPanel Margin="20" VerticalAlignment="Top" HorizontalAlignment="Stretch">
    <TextBlock Text="Genesys Cloud API Endpoints Configuration" FontSize="14" FontWeight="Bold" Margin="0 0 0 15"/>

    <StackPanel Margin="0 0 0 15">
      <TextBlock Text="Current Endpoints File:" FontWeight="Bold" Margin="0 0 0 5"/>
      <TextBox Name="CurrentPathText" IsReadOnly="True" Height="30" Padding="8" Background="#F5F5F5"
               HorizontalAlignment="Stretch" MinWidth="520" TextWrapping="Wrap"/>
    </StackPanel>

    <StackPanel Margin="0 0 0 15">
      <TextBlock Text="Upload Custom Endpoints JSON:" FontWeight="Bold" Margin="0 0 0 8"/>
      <Grid>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>
        <TextBox Name="SelectedFileText" Grid.Column="0" Height="30" Padding="8" IsReadOnly="True" Margin="0 0 10 0"/>
        <Button Name="BrowseButton" Grid.Column="1" Content="Browse..." Width="100" Height="30"/>
      </Grid>
      <TextBlock Text="Select a JSON file containing Genesys Cloud API endpoint definitions." Foreground="Gray" Margin="0 8 0 0" TextWrapping="Wrap"/>
    </StackPanel>

    <StackPanel Margin="0 0 0 15">
      <TextBlock Text="Note: The JSON file must contain a 'paths' property with API endpoint definitions." Foreground="#555555" TextWrapping="Wrap" FontSize="11" FontStyle="Italic"/>
    </StackPanel>

    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0 20 0 0">
      <Button Name="ApplyButton" Content="Apply" Width="100" Height="32" Margin="0 0 10 0"/>
      <Button Name="CancelButton" Content="Cancel" Width="100" Height="32"/>
    </StackPanel>
  </StackPanel>
</Window>
"@

    $settingsWindow = [System.Windows.Markup.XamlReader]::Parse($settingsXaml)
    $currentPathText = $settingsWindow.FindName("CurrentPathText")
    $selectedFileText = $settingsWindow.FindName("SelectedFileText")
    $browseButton = $settingsWindow.FindName("BrowseButton")
    $applyButton = $settingsWindow.FindName("ApplyButton")
    $cancelButton = $settingsWindow.FindName("CancelButton")

    if (-not $CurrentJsonPath) {
        $CurrentJsonPath = if ($PSScriptRoot) {
            Join-Path -Path $ScriptRoot -ChildPath "GenesysCloudAPIEndpoints.json"
        }
        else {
            Join-Path -Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) -ChildPath "GenesysCloudAPIEndpoints.json"
        }
    }

    if ($currentPathText) {
        $currentPathText.Text = $CurrentJsonPath
    }

    # Use script scope for the selected file so closures can access/modify it
    $script:SettingsDialogSelectedFile = ""

    $browseButton.Add_Click({
            $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
            $openFileDialog.Filter = "JSON files (*.json)|*.json|All files (*.*)|*.*"
            $initialDir = if ($CurrentJsonPath -and (Test-Path -Path $CurrentJsonPath)) {
                Split-Path -Parent $CurrentJsonPath
            }
            else {
                (Get-Location).ProviderPath
            }
            if (-not $initialDir) {
                $initialDir = (Get-Location).ProviderPath
            }
            $openFileDialog.InitialDirectory = $initialDir

            if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                $script:SettingsDialogSelectedFile = $openFileDialog.FileName
                if ($selectedFileText) {
                    $selectedFileText.Text = $script:SettingsDialogSelectedFile
                }
            }
        })

    $applyButton.Add_Click({
            if (-not $script:SettingsDialogSelectedFile) {
                [System.Windows.MessageBox]::Show("Please select a JSON file.", "No File Selected", "OK", "Information")
                return
            }

            if (-not (Test-Path -Path $script:SettingsDialogSelectedFile)) {
                [System.Windows.MessageBox]::Show("The selected file does not exist.", "File Not Found", "OK", "Error")
                return
            }

            try {
                $testJson = Get-Content -Path $script:SettingsDialogSelectedFile -Raw | ConvertFrom-Json -ErrorAction Stop

                $hasPaths = $false
                if ($testJson.paths) {
                    $hasPaths = $true
                }
                else {
                    foreach ($prop in $testJson.PSObject.Properties) {
                        if ($prop.Value -and $prop.Value.paths) {
                            $hasPaths = $true
                            break
                        }
                    }
                }

                if (-not $hasPaths) {
                    [System.Windows.MessageBox]::Show("The selected file does not contain valid Genesys Cloud API endpoint definitions (missing 'paths' property).", "Invalid Format", "OK", "Error")
                    return
                }

                $settingsWindow.DialogResult = $true
                $settingsWindow.Close()
            }
            catch {
                [System.Windows.MessageBox]::Show("Error reading JSON file: $($_.Exception.Message)", "JSON Error", "OK", "Error")
            }
        })

    $cancelButton.Add_Click({
            $settingsWindow.DialogResult = $false
            $settingsWindow.Close()
        })

    $settingsWindow.ShowDialog() | Out-Null

    if ($settingsWindow.DialogResult) {
        return $script:SettingsDialogSelectedFile
    }
    else {
        return $null
    }
}

#endregion UI helpers

#region Transport/API
function ConvertTo-FormEncodedString {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Values
    )

    $pairs = foreach ($entry in $Values.GetEnumerator()) {
        $key = [System.Uri]::EscapeDataString([string]$entry.Key)
        $value = if ($null -eq $entry.Value) { '' } else { $entry.Value }
        "$key=$([System.Uri]::EscapeDataString([string]$value))"
    }

    return ($pairs -join '&')
}

function Invoke-OAuthTokenRequest {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Uri,

        [Parameter(Mandatory)]
        [hashtable]$Body,

        [Parameter()]
        [hashtable]$Headers = @{}
    )

    $requestHeaders = @{}
    foreach ($k in $Headers.Keys) {
        $requestHeaders[$k] = $Headers[$k]
    }
    if (-not $requestHeaders.ContainsKey('Content-Type')) {
        $requestHeaders['Content-Type'] = 'application/x-www-form-urlencoded'
    }

    $formBody = ConvertTo-FormEncodedString -Values $Body

    try {
        return Invoke-RestMethod -Method Post -Uri $Uri -Headers $requestHeaders -Body $formBody -ErrorAction Stop
    }
    catch {
        $details = $null
        try {
            if ($_.Exception.Response) {
                $stream = $_.Exception.Response.GetResponseStream()
                if ($stream) {
                    $reader = New-Object System.IO.StreamReader($stream)
                    $details = $reader.ReadToEnd()
                    $reader.Close()
                }
            }
        }
        catch { }

        if (-not [string]::IsNullOrWhiteSpace($details)) {
            throw "OAuth token request failed. URI: $Uri`nDetails: $details"
        }

        throw
    }
}

function Get-ExplorerSettingsPath {
    $base = if ($env:USERPROFILE) { $env:USERPROFILE } else { $ScriptRoot }
    return (Join-Path -Path $base -ChildPath 'GenesysApiExplorer.settings.json')
}

function Load-ExplorerSettings {
    $path = Get-ExplorerSettingsPath
    if (-not (Test-Path -LiteralPath $path)) { return @{} }
    try {
        $raw = Get-Content -LiteralPath $path -Raw
        if ([string]::IsNullOrWhiteSpace($raw)) { return @{} }
        $obj = $raw | ConvertFrom-Json -ErrorAction Stop
        $settings = @{}
        foreach ($p in $obj.PSObject.Properties) {
            $settings[$p.Name] = $p.Value
        }
        return $settings
    }
    catch {
        return @{}
    }
}

function Save-ExplorerSettings {
    param([hashtable]$Settings)
    try {
        $path = Get-ExplorerSettingsPath
        ($Settings | ConvertTo-Json) | Set-Content -LiteralPath $path -Encoding utf8
    }
    catch { }
}

$script:Region = 'mypurecloud.com'
$script:AccessToken = ''
$script:OAuthType = '(none)'
$script:TokenValidated = $false

function Set-ExplorerRegion {
    param([Parameter(Mandatory)][string]$Region)

    $regionValue = $Region.Trim()
    if ($regionValue -notin @('mypurecloud.com', 'usw2.pure.cloud')) {
        $regionValue = 'mypurecloud.com'
    }

    $script:Region = $regionValue
    $script:TokenValidated = $false
    Set-Variable -Name ApiBaseUrl -Scope Script -Value ("https://api.$regionValue")
}

try {
    $saved = Load-ExplorerSettings
    if ($saved -and $saved.ContainsKey('Region') -and $saved.Region) {
        Set-ExplorerRegion -Region ([string]$saved.Region)
    }
    else {
        Set-ExplorerRegion -Region $script:Region
    }
}
catch {
    Set-ExplorerRegion -Region $script:Region
}

function Set-ExplorerAccessToken {
    param(
        [string]$Token,
        [string]$OAuthType
    )

    $tokenValue = if ($Token) { $Token.Trim() } else { '' }
    $script:AccessToken = $tokenValue
    $script:TokenValidated = $false

    if ([string]::IsNullOrWhiteSpace($tokenValue)) {
        $script:OAuthType = '(none)'
        $script:TokenExpiresAt = $null
    }
    else {
        $script:OAuthType = if ($OAuthType) { $OAuthType } else { 'Manual' }
        $script:TokenExpiresAt = (Get-Date).AddHours(23)
    }
}

function Get-ExplorerAccessToken {
    if ($script:AccessToken) { return $script:AccessToken.Trim() }
    return ''
}

function Update-AuthUiState {
    if ($regionStatusText) { $regionStatusText.Text = "Region: $($script:Region)" }
    if ($oauthTypeText) { $oauthTypeText.Text = "OAuth: $($script:OAuthType)" }

    $hasToken = -not [string]::IsNullOrWhiteSpace((Get-ExplorerAccessToken))
    if ($tokenReadyIndicator) {
        $tokenReadyIndicator.Text = if ($script:TokenValidated) { [char]0x25CF } else { [char]0x25CF }
        $tokenReadyIndicator.Foreground = if (-not $hasToken) { 'Gray' } elseif ($script:TokenValidated) { 'Green' } else { 'Orange' }
        $tokenReadyIndicator.ToolTip = if (-not $hasToken) { 'No token set' } elseif ($script:TokenValidated) { 'Token validated' } else { 'Token set (not validated)' }
    }

    if ($tokenStatusText) {
        if (-not $hasToken) {
            $tokenStatusText.Text = 'No token'
            $tokenStatusText.Foreground = 'Gray'
        }
        elseif ($script:TokenValidated) {
            $tokenStatusText.Text = "$([char]0x2713) Valid"
            $tokenStatusText.Foreground = 'Green'
        }
        else {
            $tokenStatusText.Text = 'Token set'
            $tokenStatusText.Foreground = 'Orange'
        }
    }
}

function Show-AppSettingsDialog {
    param(
        [string]$CurrentRegion,
        [string]$CurrentOAuthType,
        [string]$CurrentToken
    )

    $settingsXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="App Settings" Height="340" Width="760"
        MinHeight="340" MinWidth="640"
        ResizeMode="CanResizeWithGrip"
        WindowStartupLocation="CenterOwner" ShowInTaskbar="False">
  <Grid Margin="20">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <TextBlock Grid.Row="0" Text="Application Settings" FontSize="14" FontWeight="Bold" Margin="0 0 0 12"/>

    <StackPanel Grid.Row="1" Margin="0 0 0 12">
      <TextBlock Text="Region" FontWeight="Bold" Margin="0 0 0 6"/>
      <ComboBox Name="RegionCombo" Height="28" SelectedIndex="0">
        <ComboBoxItem Content="mypurecloud.com"/>
        <ComboBoxItem Content="usw2.pure.cloud"/>
      </ComboBox>
      <TextBlock Text="This controls the API base URL, exported PowerShell, and exported cURL." Foreground="Gray" FontSize="11" Margin="0 6 0 0"/>
    </StackPanel>

    <StackPanel Grid.Row="2" Margin="0 0 0 12">
      <TextBlock Text="OAuth Token" FontWeight="Bold" Margin="0 0 0 6"/>
      <TextBox Name="TokenText" Height="60" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto"
               ToolTip="Paste a Genesys Cloud OAuth access token (Bearer)."
               ToolTipService.Placement="Top" ToolTipService.InitialShowDelay="450" ToolTipService.ShowDuration="12000"/>
      <TextBlock Text="Token is stored in memory only (not written to disk)." Foreground="Gray" FontSize="11" Margin="0 6 0 0"/>
    </StackPanel>

    <StackPanel Grid.Row="3" Orientation="Horizontal" VerticalAlignment="Top">
      <TextBlock Text="OAuth Type:" FontWeight="Bold" VerticalAlignment="Center" Margin="0 0 8 0"/>
      <TextBlock Name="OAuthTypeValue" VerticalAlignment="Center" Foreground="SlateGray" Margin="0 0 16 0"/>
      <Button Name="ClearTokenButton" Width="120" Height="28" Content="Clear Token"/>
    </StackPanel>

    <StackPanel Grid.Row="5" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0 20 0 0">
      <Button Name="ApplyButton" Content="Apply" Width="100" Height="32" Margin="0 0 10 0"/>
      <Button Name="CancelButton" Content="Cancel" Width="100" Height="32"/>
    </StackPanel>
  </Grid>
</Window>
"@

    $win = [System.Windows.Markup.XamlReader]::Parse($settingsXaml)
    if (-not $win) { return $null }
    if ($Window) { $win.Owner = $Window }

    $regionCombo = $win.FindName('RegionCombo')
    $tokenText = $win.FindName('TokenText')
    $oauthTypeValue = $win.FindName('OAuthTypeValue')
    $clearTokenButton = $win.FindName('ClearTokenButton')
    $applyButton = $win.FindName('ApplyButton')
    $cancelButton = $win.FindName('CancelButton')

    if ($tokenText) { $tokenText.Text = $CurrentToken }
    if ($oauthTypeValue) { $oauthTypeValue.Text = if ($CurrentOAuthType) { $CurrentOAuthType } else { '(none)' } }

    if ($regionCombo -and $CurrentRegion) {
        $idx = -1
        foreach ($item in $regionCombo.Items) {
            $idx++
            if ($item.Content -eq $CurrentRegion) { $regionCombo.SelectedIndex = $idx; break }
        }
    }

    if ($clearTokenButton) {
        $clearTokenButton.Add_Click({
                if ($tokenText) { $tokenText.Text = '' }
                if ($oauthTypeValue) { $oauthTypeValue.Text = '(none)' }
            })
    }

    if ($tokenText) {
        $tokenText.Add_TextChanged({
                $txt = $tokenText.Text
                if ([string]::IsNullOrWhiteSpace($txt)) {
                    if ($oauthTypeValue) { $oauthTypeValue.Text = '(none)' }
                }
                else {
                    if ($oauthTypeValue) { $oauthTypeValue.Text = 'Manual' }
                }
            })
    }

    if ($applyButton) {
        $applyButton.Add_Click({
                $regionValue = 'mypurecloud.com'
                if ($regionCombo -and $regionCombo.SelectedItem) {
                    $regionValue = $regionCombo.SelectedItem.Content.ToString().Trim()
                }
                $tokenValue = if ($tokenText) { $tokenText.Text } else { '' }
                $oauthType = if ($oauthTypeValue) { $oauthTypeValue.Text } else { '(none)' }

                $script:AppSettingsDialogResult = [pscustomobject]@{
                    Region    = $regionValue
                    Token     = $tokenValue
                    OAuthType = $oauthType
                }
                $win.DialogResult = $true
                $win.Close()
            })
    }

    if ($cancelButton) {
        $cancelButton.Add_Click({
                $win.DialogResult = $false
                $win.Close()
            })
    }

    $script:AppSettingsDialogResult = $null
    $win.ShowDialog() | Out-Null
    if ($win.DialogResult) { return $script:AppSettingsDialogResult }
    return $null
}

function Resolve-LoginEnvValue {
    param(
        [Parameter(Mandatory)]
        [string]$EnvName
    )

    $trimmed = if ($EnvName) { $EnvName.Trim() } else { '' }
    if (-not $trimmed) { return $null }

    foreach ($scope in 'Process','User','Machine') {
        try {
            $value = [Environment]::GetEnvironmentVariable($trimmed, $scope)
            if (-not [string]::IsNullOrWhiteSpace($value)) {
                return $value.Trim()
            }
        }
        catch { }
    }

    return $null
}

function Build-LoginCredential {
    param(
        [string]$DirectValue,
        [string]$EnvName,
        [string]$FriendlyName
    )

    $directTrim = if ($DirectValue) { $DirectValue.Trim() } else { '' }
    $envTrim = if ($EnvName) { $EnvName.Trim() } else { '' }
    $envValue = $null
    if ($envTrim) {
        $envValue = Resolve-LoginEnvValue -EnvName $envTrim
    }

    $finalValue = if ($envValue) { $envValue } else { $directTrim }

    return [pscustomobject]@{
        FriendlyName = $FriendlyName
        DirectValue  = $directTrim
        EnvName      = $envTrim
        EnvValue     = $envValue
        Value        = $finalValue
    }
}

function Show-LoginWindow {
    $loginXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Genesys Cloud Login" Height="450" Width="500" ResizeMode="NoResize" WindowStartupLocation="CenterOwner">
  <Grid Margin="20">
    <TabControl Name="LoginTabs">
      <TabItem Header="User Login (Web)">
        <StackPanel Margin="10">
          <TextBlock Text="Region" FontWeight="Bold" Margin="0 0 0 5"/>
          <ComboBox Name="UserRegionCombo" Margin="0 0 0 15" SelectedIndex="0">
            <ComboBoxItem Content="mypurecloud.com (US East)"/>
            <ComboBoxItem Content="usw2.pure.cloud (US West)"/>
            <ComboBoxItem Content="mypurecloud.ie (EU West)"/>
            <ComboBoxItem Content="mypurecloud.de (EU Central)"/>
            <ComboBoxItem Content="mypurecloud.jp (Japan)"/>
            <ComboBoxItem Content="mypurecloud.com.au (Australia)"/>
            <ComboBoxItem Content="use2.us-gov-pure.cloud (FedRAMP)"/>
          </ComboBox>

          <TextBlock Text="Client ID (PKCE Grant)" FontWeight="Bold" Margin="0 0 0 5"/>
          <TextBox Name="UserClientIdInput" Height="28" Margin="0 0 0 5"/>
          <TextBlock Text="Ensure this Client ID is configured for Code Grant (PKCE) with the Redirect URI you plan to use below." FontSize="10" Foreground="Gray" TextWrapping="Wrap" Margin="0 0 0 5"/>
          <TextBlock Text="Redirect URI" FontWeight="Bold" Margin="0 5 0 3"/>
          <TextBox Name="UserRedirectUriInput" Height="28" Margin="0 0 0 5" Text="http://localhost:8080" ToolTip="Enter the redirect URI registered with your OAuth client (default: http://localhost:8080)"/>
          <TextBlock Text="Must match the redirect URI configured for the client. Leave blank to use http://localhost:8080." FontSize="10" Foreground="Gray" TextWrapping="Wrap" Margin="0 0 0 15"/>

          <Button Name="UserLoginButton" Content="Login with Browser" Height="32" Margin="0 10 0 0"/>
        </StackPanel>
      </TabItem>

      <TabItem Header="Client Credentials">
        <StackPanel Margin="10">
          <TextBlock Text="Region" FontWeight="Bold" Margin="0 0 0 5"/>
          <ComboBox Name="ClientRegionCombo" Margin="0 0 0 15" SelectedIndex="0">
            <ComboBoxItem Content="mypurecloud.com (US East)"/>
            <ComboBoxItem Content="usw2.pure.cloud (US West)"/>
            <ComboBoxItem Content="mypurecloud.ie (EU West)"/>
            <ComboBoxItem Content="mypurecloud.de (EU Central)"/>
            <ComboBoxItem Content="mypurecloud.jp (Japan)"/>
            <ComboBoxItem Content="mypurecloud.com.au (Australia)"/>
            <ComboBoxItem Content="use2.us-gov-pure.cloud (FedRAMP)"/>
          </ComboBox>

          <TextBlock Text="Client ID (or env var name)" FontWeight="Bold" Margin="0 0 0 5"/>
          <TextBox Name="ClientClientIdInput" Height="28" Margin="0 0 0 6" ToolTip="Paste the client ID directly"/>
          <TextBlock Text="Optional: Client ID environment variable name" FontSize="10" Foreground="Gray" Margin="0 0 0 3"/>
          <TextBox Name="ClientClientIdEnvInput" Height="24" Margin="0 0 0 10" ToolTip="Optional: environment variable containing the client ID"/>

          <TextBlock Text="Client Secret (or env var name)" FontWeight="Bold" Margin="0 0 0 5"/>
          <PasswordBox Name="ClientSecretInput" Height="28" Margin="0 0 0 6" ToolTip="Paste the client secret directly"/>
          <TextBlock Text="Optional: Client Secret environment variable name" FontSize="10" Foreground="Gray" Margin="0 0 0 3"/>
          <TextBox Name="ClientSecretEnvInput" Height="24" Margin="0 0 0 15" ToolTip="Optional: environment variable containing the client secret"/>

          <Button Name="ClientLoginButton" Content="Get Token" Height="32" Margin="0 10 0 0"/>
        </StackPanel>
      </TabItem>
    </TabControl>
  </Grid>
</Window>
"@

    $loginWindow = [System.Windows.Markup.XamlReader]::Parse($loginXaml)
    if (-not $loginWindow) { return $null }

    if ($Window) { $loginWindow.Owner = $Window }

    # User Login Controls
    $userRegionCombo = $loginWindow.FindName("UserRegionCombo")
    $userClientIdInput = $loginWindow.FindName("UserClientIdInput")
    $userLoginButton = $loginWindow.FindName("UserLoginButton")
    $userRedirectUriInput = $loginWindow.FindName("UserRedirectUriInput")

    # Client Login Controls
    $clientRegionCombo = $loginWindow.FindName("ClientRegionCombo")
    $clientClientIdInput = $loginWindow.FindName("ClientClientIdInput")
    $clientClientIdEnvInput = $loginWindow.FindName("ClientClientIdEnvInput")
    $clientSecretInput = $loginWindow.FindName("ClientSecretInput")
    $clientSecretEnvInput = $loginWindow.FindName("ClientSecretEnvInput")
    $clientLoginButton = $loginWindow.FindName("ClientLoginButton")

    # Stored Settings Key (simple persistence for convenience)
    $settingsPath = Join-Path -Path $env:USERPROFILE -ChildPath "GenesysApiExplorer.settings.json"
    $savedSettings = @{}
    if (Test-Path $settingsPath) {
        try { $savedSettings = Get-Content $settingsPath -Raw | ConvertFrom-Json } catch {}
    }

    # Restore saved values
    if ($savedSettings.UserClientId) { $userClientIdInput.Text = $savedSettings.UserClientId }
    if ($savedSettings.UserRedirectUri -and $userRedirectUriInput) { $userRedirectUriInput.Text = $savedSettings.UserRedirectUri }
    if ($savedSettings.ClientClientId) { $clientClientIdInput.Text = $savedSettings.ClientClientId }
    if ($savedSettings.ClientClientIdEnv) { $clientClientIdEnvInput.Text = $savedSettings.ClientClientIdEnv }
    if ($savedSettings.ClientSecretEnv) { $clientSecretEnvInput.Text = $savedSettings.ClientSecretEnv }
    if ($savedSettings.Region) {
            $idx = -1
            foreach ($item in $userRegionCombo.Items) {
                $idx++
                if ($item.Content -match $savedSettings.Region) {
                    $userRegionCombo.SelectedIndex = $idx
                    $clientRegionCombo.SelectedIndex = $idx
                    break
                }
            }
        }

    $script:LoginResult = $null
    $script:LastLoginOAuthType = $null
    $script:LastLoginRegion = $null

    # --- Client Credentials Flow ---
    $clientLoginButton.Add_Click({
            if (-not $clientRegionCombo -or -not $clientRegionCombo.SelectedItem) {
                [System.Windows.MessageBox]::Show("Please select a region before logging in.", "Missing Region", "OK", "Warning")
                return
            }

            $regionContent = $clientRegionCombo.SelectedItem.Content
            if (-not $regionContent) {
                [System.Windows.MessageBox]::Show("Please select a region before logging in.", "Missing Region", "OK", "Warning")
                return
            }
            $regionText = ([string]$regionContent).Split(' ')[0]

            $clientIdEnvName = if ($clientClientIdEnvInput) { $clientClientIdEnvInput.Text.Trim() } else { '' }
            $clientSecretEnvName = if ($clientSecretEnvInput) { $clientSecretEnvInput.Text.Trim() } else { '' }

            $clientIdDirectValue = ''
            if ($clientClientIdInput) { $clientIdDirectValue = $clientClientIdInput.Text }

            $clientSecretDirectValue = ''
            if ($clientSecretInput) { $clientSecretDirectValue = $clientSecretInput.Password }

            $clientIdInfo = Build-LoginCredential -DirectValue $clientIdDirectValue -EnvName $clientIdEnvName -FriendlyName 'Client ID'
            $clientSecretInfo = Build-LoginCredential -DirectValue $clientSecretDirectValue -EnvName $clientSecretEnvName -FriendlyName 'Client Secret'

            if (-not $clientIdInfo.Value -or -not $clientSecretInfo.Value) {
                $missingFields = @()
                if (-not $clientIdInfo.Value) { $missingFields += $clientIdInfo.FriendlyName }
                if (-not $clientSecretInfo.Value) { $missingFields += $clientSecretInfo.FriendlyName }
                $messageLines = @("Please enter $($missingFields -join ' and ') (or provide valid environment variable names).")
                if ($clientIdInfo.EnvName -and -not $clientIdInfo.EnvValue) {
                    $messageLines += "Environment variable '$($clientIdInfo.EnvName)' did not resolve to a value."
                }
                if ($clientSecretInfo.EnvName -and -not $clientSecretInfo.EnvValue) {
                    $messageLines += "Environment variable '$($clientSecretInfo.EnvName)' did not resolve to a value."
                }
                [System.Windows.MessageBox]::Show(($messageLines -join "`n"), "Missing Credentials", "OK", "Warning")
                return
            }

            $clientId = $clientIdInfo.Value
            $clientSecret = $clientSecretInfo.Value

            try {
                $authHeader = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("${clientId}:${clientSecret}"))
                $body = @{
                    grant_type    = "client_credentials"
                    client_id     = $clientId
                    client_secret = $clientSecret
                }

                $loginWindow.Cursor = [System.Windows.Input.Cursors]::Wait

                $headers = @{
                    Authorization  = "Basic $authHeader"
                    'Content-Type' = 'application/x-www-form-urlencoded'
                }
                $response = Invoke-OAuthTokenRequest -Uri "https://login.$regionText/oauth/token" -Body $body -Headers $headers

                if ($response.access_token) {
                    $script:LoginResult = $response.access_token
                    $script:LastLoginOAuthType = 'Client Credentials'
                    $script:LastLoginRegion = $regionText

                    # Save settings
                    $savedSettings.ClientClientId = $clientIdInfo.DirectValue
                    $savedSettings.ClientClientIdEnv = $clientIdInfo.EnvName
                    $savedSettings.ClientSecretEnv = $clientSecretInfo.EnvName
                    $savedSettings.Region = $regionText
                    $savedSettings | ConvertTo-Json | Set-Content $settingsPath

                    $loginWindow.Close()
                }
            }
            catch {
                [System.Windows.MessageBox]::Show("Authentication failed: $($_.Exception.Message)", "Login Error", "OK", "Error")
            }
            finally {
                $loginWindow.Cursor = [System.Windows.Input.Cursors]::Arrow
            }
        })

    # --- User PKCE Flow ---
    $userLoginButton.Add_Click({
            if (-not $userRegionCombo -or -not $userRegionCombo.SelectedItem) {
                [System.Windows.MessageBox]::Show("Please select a region before logging in.", "Missing Region", "OK", "Warning")
                return
            }

            $regionContent = $userRegionCombo.SelectedItem.Content
            if (-not $regionContent) {
                [System.Windows.MessageBox]::Show("Please select a region before logging in.", "Missing Region", "OK", "Warning")
                return
            }
            $regionText = ([string]$regionContent).Split(' ')[0]

            $clientId = if ($userClientIdInput) { $userClientIdInput.Text.Trim() } else { '' }
            $redirectUriInput = if ($userRedirectUriInput) { $userRedirectUriInput.Text.Trim() } else { '' }
            $redirectUri = if ($redirectUriInput) { $redirectUriInput } else { 'http://localhost:8080' }

            if (-not $clientId) {
                [System.Windows.MessageBox]::Show("Please enter a Client ID.", "Missing info", "OK", "Warning")
                return
            }

            # Save settings immediately
            $savedSettings.UserClientId = $clientId
            $savedSettings.Region = $regionText
            $savedSettings.UserRedirectUri = $redirectUri
            $savedSettings | ConvertTo-Json | Set-Content $settingsPath

            # 1. Generate Code Verifier and Challenge (PKCE)
            # Verifier: Random 32-96 bytes, base64url encoded
            $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
            $bytes = New-Object byte[] 32
            $rng.GetBytes($bytes)
            $verifier = [Convert]::ToBase64String($bytes).Replace('+', '-').Replace('/', '_').Replace('=', '')

            # Challenge: SHA256(verifier) -> base64url
            $sha256 = [System.Security.Cryptography.SHA256]::Create()
            $challengeBytes = $sha256.ComputeHash([Text.Encoding]::ASCII.GetBytes($verifier))
            $challenge = [Convert]::ToBase64String($challengeBytes).Replace('+', '-').Replace('/', '_').Replace('=', '')

            $redirectUriObj = $null
            try {
                $redirectUriObj = [System.Uri]$redirectUri
            }
            catch {
                [System.Windows.MessageBox]::Show("Invalid Redirect URI: $redirectUri", "Login Error", "OK", "Error")
                return
            }

            if (-not $redirectUriObj.IsAbsoluteUri -or $redirectUriObj.Scheme -ne 'http' -or -not $redirectUriObj.IsLoopback) {
                [System.Windows.MessageBox]::Show("Redirect URI must be an absolute loopback HTTP URI (example: http://localhost:8080).", "Login Error", "OK", "Error")
                return
            }

            $callbackPath = if ([string]::IsNullOrWhiteSpace($redirectUriObj.AbsolutePath)) { "/" } else { $redirectUriObj.AbsolutePath }
            if (-not $callbackPath.EndsWith('/')) { $callbackPath = "$callbackPath/" }
            $listenerPrefix = "http://$($redirectUriObj.Host):$($redirectUriObj.Port)$callbackPath"

            $stateBytes = New-Object byte[] 24
            $rng.GetBytes($stateBytes)
            $state = [Convert]::ToBase64String($stateBytes).Replace('+', '-').Replace('/', '_').Replace('=', '')

            $authUrl = "https://login.$regionText/oauth/authorize?client_id=$([System.Uri]::EscapeDataString($clientId))&response_type=code&redirect_uri=$([System.Uri]::EscapeDataString($redirectUri))&code_challenge=$([System.Uri]::EscapeDataString($challenge))&code_challenge_method=S256&state=$([System.Uri]::EscapeDataString($state))"

            $listener = $null
            try {
                $listener = New-Object System.Net.HttpListener
                $listener.Prefixes.Add($listenerPrefix)
                $listener.Start()

                Start-Process -FilePath $authUrl
                $loginWindow.Cursor = [System.Windows.Input.Cursors]::Wait

                $contextTask = $listener.GetContextAsync()
                if (-not $contextTask.Wait(180000)) {
                    throw "Timed out waiting for authorization response. Complete login in browser within 3 minutes."
                }

                $context = $contextTask.Result
                $requestUrl = $context.Request.Url
                $query = @{}
                foreach ($part in ($requestUrl.Query.TrimStart('?') -split '&')) {
                    if (-not $part) { continue }
                    $segments = $part -split '=', 2
                    $key = [System.Net.WebUtility]::UrlDecode($segments[0])
                    $val = if ($segments.Count -gt 1) { [System.Net.WebUtility]::UrlDecode($segments[1]) } else { '' }
                    $query[$key] = $val
                }

                $responseHtml = "<html><body style='font-family:Segoe UI,Arial;padding:20px;'><h3>Authorization complete</h3><p>You can close this tab and return to Genesys Cloud API Explorer.</p></body></html>"
                if ($query.error) {
                    $responseHtml = "<html><body style='font-family:Segoe UI,Arial;padding:20px;'><h3>Authorization failed</h3><p>$([System.Net.WebUtility]::HtmlEncode([string]$query.error_description))</p></body></html>"
                }

                $respBytes = [System.Text.Encoding]::UTF8.GetBytes($responseHtml)
                $context.Response.StatusCode = 200
                $context.Response.ContentType = 'text/html; charset=utf-8'
                $context.Response.ContentLength64 = $respBytes.Length
                $context.Response.OutputStream.Write($respBytes, 0, $respBytes.Length)
                $context.Response.OutputStream.Close()
                $context.Response.Close()

                if ($query.error) {
                    throw "Authorization error: $($query.error). $($query.error_description)"
                }
                if (-not $query.state -or $query.state -ne $state) {
                    throw "Authorization state validation failed."
                }
                if (-not $query.code) {
                    throw "Authorization response did not include a code."
                }

                $authCode = $query.code
                $tokenBody = @{
                    grant_type    = "authorization_code"
                    client_id     = $clientId
                    code          = $authCode
                    redirect_uri  = $redirectUri
                    code_verifier = $verifier
                }
                $headers = @{
                    'Content-Type' = 'application/x-www-form-urlencoded'
                }
                $response = Invoke-OAuthTokenRequest -Uri "https://login.$regionText/oauth/token" -Body $tokenBody -Headers $headers

                if ($response.access_token) {
                    $script:LoginResult = $response.access_token
                    $script:LastLoginOAuthType = 'User PKCE'
                    $script:LastLoginRegion = $regionText
                    $loginWindow.Close()
                }
            }
            catch {
                [System.Windows.MessageBox]::Show("Token exchange failed: $($_.Exception.Message)", "Login Error", "OK", "Error")
            }
            finally {
                try {
                    if ($listener -and $listener.IsListening) { $listener.Stop() }
                    if ($listener) { $listener.Close() }
                }
                catch { }
                $loginWindow.Cursor = [System.Windows.Input.Cursors]::Arrow
            }
        })

    $loginWindow.ShowDialog() | Out-Null
    return $script:LoginResult
}

function Show-SplashScreen {
    $splashXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Genesys Cloud  Explorer" WindowStartupLocation="CenterScreen" ResizeMode="NoResize"
        WindowStyle="None" AllowsTransparency="True" Background="White" Topmost="True"
        SizeToContent="WidthAndHeight" MinWidth="520" MinHeight="320">
  <Border Margin="10" Padding="14" BorderBrush="#FF2C2C2C" BorderThickness="1" CornerRadius="6" Background="#FFF8F9FB">
    <StackPanel>
      <TextBlock Text="Genesys Cloud  Explorer" FontSize="18" FontWeight="Bold"/>
      <TextBlock Text="Instant access to every Genesys Cloud endpoint with schema insight, job tracking, and saved favorites." TextWrapping="Wrap" Margin="0 6"/>
      <TextBlock Text="Features in this release:" FontWeight="Bold" Margin="0 8 0 0"/>
      <TextBlock Text="- Grouped endpoint navigation with parameter assistance." Margin="0 2"/>
      <TextBlock Text="- Transparency log, schema viewer, and large-response inspection/export." Margin="0 2"/>
      <TextBlock Text="- Job Watch tab polls bulk jobs and stages outputs in temp files for export." Margin="0 2"/>
      <TextBlock Text="- Favorites persist locally and include payloads for reuse." Margin="0 2"/>
      <TextBlock TextWrapping="Wrap" Margin="0 10 0 0">
        Visit the Genesys Cloud developer documentation or help center from the Help menu when you're ready for deeper reference.
      </TextBlock>
      <Button Name="ContinueButton" Content="Continue" Width="120" Height="32" HorizontalAlignment="Right" Margin="0 12 0 0"/>
    </StackPanel>
  </Border>
</Window>
"@

    $splashWindow = [System.Windows.Markup.XamlReader]::Parse($splashXaml)
    if (-not $splashWindow) {
        return
    }

    $continueButton = $splashWindow.FindName("ContinueButton")
    if ($continueButton) {
        $continueButton.Add_Click({
                $splashWindow.Close()
            })
    }

    $splashWindow.ShowDialog() | Out-Null
}

function Load-PathsFromJson {
    param ([Parameter(Mandatory = $true)] [string]$JsonPath)

    $json = Get-Content -Path $JsonPath -Raw | ConvertFrom-Json
    if ($json.paths) {
        return [PSCustomObject]@{
            Paths       = $json.paths
            Definitions = if ($json.definitions) { $json.definitions } else { @{} }
        }
    }

    foreach ($prop in $json.PSObject.Properties) {
        if ($prop.Value -and $prop.Value.paths) {
            return [PSCustomObject]@{
                Paths       = $prop.Value.paths
                Definitions = if ($prop.Value.definitions) { $prop.Value.definitions } else { @{} }
            }
        }
    }

    throw "Cannot locate a 'paths' section in '$JsonPath'."
}

function Ensure-ApiCatalogLoaded {
    if ($script:ApiCatalog -and $script:ApiPaths -and $script:GroupMap) { return }

    $defaultJsonPath = Join-Path -Path $ScriptRoot -ChildPath "GenesysCloudAPIEndpoints.json"
    if (-not (Test-Path -Path $defaultJsonPath)) {
        throw "Required endpoint catalog not found at '$defaultJsonPath'."
    }

    $catalog = Load-PathsFromJson -JsonPath $defaultJsonPath
    $script:ApiCatalog = $catalog
    $script:ApiPaths = $catalog.Paths
    $script:Definitions = if ($catalog.Definitions) { $catalog.Definitions } else { @{} }
    $script:GroupMap = Build-GroupMap -Paths $script:ApiPaths
    $script:CurrentJsonPath = $defaultJsonPath

    Initialize-FilterBuilderEnum
}
function Build-GroupMap {
    param ([Parameter(Mandatory = $true)] $Paths)

    $map = @{}
    foreach ($prop in $Paths.PSObject.Properties) {
        $path = $prop.Name
        if ($path -match "^/api/v2/([^/]+)") {
            $group = $Matches[1]
        }
        else {
            $group = "Other"
        }

        if (-not $map.ContainsKey($group)) {
            $map[$group] = @()
        }

        $map[$group] += $path
    }

    return $map
}

function Get-PathObject {
    param (
        $ApiPaths,
        [string]$Path
    )

    $prop = $ApiPaths.PSObject.Properties | Where-Object { $_.Name -eq $Path }
    return $prop.Value
}

function Get-MethodObject {
    param (
        $PathObject,
        [string]$MethodName
    )

    $methodProp = $PathObject.PSObject.Properties | Where-Object { $_.Name -eq $MethodName }
    return $methodProp.Value
}

function Get-GroupForPath {
    param ([string]$Path)

    if ($Path -match "^/api/v2/([^/]+)") {
        return $Matches[1]
    }

    return "Other"
}

function Get-ParameterControlValue {
    param ($Control)

    if (-not $Control) { return $null }

    # Handle CheckBox (wrapped in StackPanel)
    if ($Control.ValueControl -and $Control.ValueControl -is [System.Windows.Controls.CheckBox]) {
        $checkBox = $Control.ValueControl
        if ($checkBox.IsChecked -eq $true) {
            return "true"
        }
        elseif ($checkBox.IsChecked -eq $false) {
            return "false"
        }
    }

    # Handle ComboBox
    if ($Control -is [System.Windows.Controls.ComboBox]) {
        $controlValue = $Control.SelectedItem
        if ($controlValue) {
            return $controlValue.ToString()
        }
        return $null
    }

    # Handle TextBox
    if ($Control -is [System.Windows.Controls.TextBox]) {
        return $Control.Text
    }

    return $null
}

function Select-ComboBoxItemByText {
    param (
        [System.Windows.Controls.ComboBox]$ComboBox,
        [string]$Text
    )

    if (-not $ComboBox -or -not $Text) { return $false }

    foreach ($item in $ComboBox.Items) {
        if ($item -and $item.ToString().Equals($Text, [System.StringComparison]::InvariantCultureIgnoreCase)) {
            $ComboBox.SelectedItem = $item
            return $true
        }
    }

    return $false
}

function Set-ParameterControlValue {
    param (
        $Control,
        $Value
    )

    if (-not $Control) { return }

    # Handle CheckBox (wrapped in StackPanel)
    if ($Control.ValueControl -and $Control.ValueControl -is [System.Windows.Controls.CheckBox]) {
        $checkBox = $Control.ValueControl
        if ($Value -eq "true" -or $Value -eq $true) {
            $checkBox.IsChecked = $true
        }
        elseif ($Value -eq "false" -or $Value -eq $false) {
            $checkBox.IsChecked = $false
        }
        else {
            $checkBox.IsChecked = $null
        }
    }

    # Handle ComboBox
    if ($Control -is [System.Windows.Controls.ComboBox]) {
        $Control.SelectedItem = $Value
        return
    }

    # Handle TextBox
    if ($Control -is [System.Windows.Controls.TextBox]) {
        $Control.Text = $Value
        return
    }
}

function Test-JsonString {
    param ([string]$JsonString)

    if ([string]::IsNullOrWhiteSpace($JsonString)) {
        return $true  # Empty is valid (will be handled by required check)
    }

    try {
        $null = $JsonString | ConvertFrom-Json -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

function Test-ParameterValue {
    param (
        [string]$Value,
        [object]$ValidationMetadata
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return @{ Valid = $true }  # Empty values handled by required field check
    }

    if (-not $ValidationMetadata) {
        return @{ Valid = $true }
    }

    $errors = @()

    # Validate integer type
    if ($ValidationMetadata.Type -eq "integer") {
        $intValue = $null
        if (-not [int]::TryParse($Value, [ref]$intValue)) {
            $errors += "Must be an integer value"
        }
        else {
            if ($null -ne $ValidationMetadata.Minimum -and $intValue -lt $ValidationMetadata.Minimum) {
                $errors += "Must be at least $($ValidationMetadata.Minimum)"
            }
            if ($null -ne $ValidationMetadata.Maximum -and $intValue -gt $ValidationMetadata.Maximum) {
                $errors += "Must be at most $($ValidationMetadata.Maximum)"
            }
        }
    }

    # Validate number type (float/double)
    if ($ValidationMetadata.Type -eq "number") {
        $numValue = $null
        if (-not [double]::TryParse($Value, [ref]$numValue)) {
            $errors += "Must be a numeric value"
        }
        else {
            if ($null -ne $ValidationMetadata.Minimum -and $numValue -lt $ValidationMetadata.Minimum) {
                $errors += "Must be at least $($ValidationMetadata.Minimum)"
            }
            if ($null -ne $ValidationMetadata.Maximum -and $numValue -gt $ValidationMetadata.Maximum) {
                $errors += "Must be at most $($ValidationMetadata.Maximum)"
            }
        }
    }

    # Validate array type (comma-separated values)
    if ($ValidationMetadata.Type -eq "array") {
        # Arrays are entered as comma-separated values
        # Just validate that it's not completely malformed
        # Individual item validation could be added for specific item types
        if ($ValidationMetadata.ItemType -eq "integer") {
            $items = $Value -split ',' | ForEach-Object { $_.Trim() }
            foreach ($item in $items) {
                if (-not [string]::IsNullOrWhiteSpace($item)) {
                    $intValue = $null
                    if (-not [int]::TryParse($item, [ref]$intValue)) {
                        $errors += "Array item '$item' must be an integer"
                        break
                    }
                }
            }
        }
    }

    if ($errors.Count -gt 0) {
        return @{ Valid = $false; Errors = $errors }
    }

    return @{ Valid = $true }
}

function Test-NumericValue {
    param (
        [string]$Value,
        [string]$Type,
        [object]$Minimum,
        [object]$Maximum
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return @{ IsValid = $true; ErrorMessage = $null }
    }

    # Try to parse the number
    $number = $null
    $parseSuccess = $false

    if ($Type -eq "integer") {
        $parseSuccess = [int]::TryParse($Value, [ref]$number)
        if (-not $parseSuccess) {
            return @{ IsValid = $false; ErrorMessage = "Must be a valid integer" }
        }
    }
    elseif ($Type -eq "number") {
        $parseSuccess = [double]::TryParse($Value, [ref]$number)
        if (-not $parseSuccess) {
            return @{ IsValid = $false; ErrorMessage = "Must be a valid number" }
        }
    }

    # Check minimum constraint
    if ($null -ne $Minimum -and $number -lt $Minimum) {
        return @{ IsValid = $false; ErrorMessage = "Must be >= $Minimum" }
    }

    # Check maximum constraint
    if ($null -ne $Maximum -and $number -gt $Maximum) {
        return @{ IsValid = $false; ErrorMessage = "Must be <= $Maximum" }
    }

    return @{ IsValid = $true; ErrorMessage = $null }
}

function Test-StringFormat {
    param (
        [string]$Value,
        [string]$Format = $null,
        [string]$Pattern = $null
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return @{ IsValid = $true; ErrorMessage = $null }
    }

    # Check pattern first if provided
    if ($Pattern) {
        try {
            if ($Value -notmatch $Pattern) {
                return @{ IsValid = $false; ErrorMessage = "Does not match required pattern" }
            }
        }
        catch {
            # Regex error - skip pattern validation
        }
    }

    # Check format
    switch ($Format) {
        "email" {
            # Simple email validation
            if ($Value -notmatch '^[^@]+@[^@]+\.[^@]+$') {
                return @{ IsValid = $false; ErrorMessage = "Must be a valid email address" }
            }
        }
        { $_ -in @("uri", "url") } {
            # Simple URL validation
            if ($Value -notmatch '^https?://') {
                return @{ IsValid = $false; ErrorMessage = "Must be a valid URL (http:// or https://)" }
            }
        }
        { $_ -in @("date", "date-time") } {
            # Try to parse as date
            $date = $null
            if (-not [DateTime]::TryParse($Value, [ref]$date)) {
                return @{ IsValid = $false; ErrorMessage = "Must be a valid date/time" }
            }
        }
    }

    return @{ IsValid = $true; ErrorMessage = $null }
}

function Test-ArrayValue {
    param (
        [string]$Value,
        [object]$ItemType
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return @{ IsValid = $true; ErrorMessage = $null }
    }

    # Array values are comma-separated
    $items = $Value -split ',' | ForEach-Object { $_.Trim() }

    # If itemType is string, anything is valid
    if ($ItemType.type -eq "string") {
        return @{ IsValid = $true; ErrorMessage = $null }
    }

    # If itemType is integer or number, validate each item
    if ($ItemType.type -in @("integer", "number")) {
        foreach ($item in $items) {
            if ([string]::IsNullOrWhiteSpace($item)) { continue }

            $testResult = Test-NumericValue -Value $item -Type $ItemType.type -Minimum $null -Maximum $null
            if (-not $testResult.IsValid) {
                return @{ IsValid = $false; ErrorMessage = "Array items must be valid $($ItemType.type) values" }
            }
        }
    }

    return @{ IsValid = $true; ErrorMessage = $null }
}

function Test-ParameterVisibility {
    param (
        [object]$Parameter,
        [array]$AllParameters,
        [hashtable]$ParameterInputs
    )

    # Default: all parameters are visible
    # This function provides infrastructure for future conditional parameter logic

    # Check for custom visibility metadata (for future use)
    if ($Parameter.'x-conditional-on') {
        $conditionParam = $Parameter.'x-conditional-on'
        $conditionValue = $Parameter.'x-conditional-value'

        # Check if the condition parameter exists and has the required value
        if ($ParameterInputs.ContainsKey($conditionParam)) {
            $actualValue = Get-ParameterControlValue -Control $ParameterInputs[$conditionParam]

            if ($actualValue -ne $conditionValue) {
                return $false  # Hide parameter
            }
        }
    }

    # Check for mutually exclusive parameters (for future use)
    if ($Parameter.'x-mutually-exclusive-with') {
        $exclusiveParams = $Parameter.'x-mutually-exclusive-with'

        foreach ($exclusiveParam in $exclusiveParams) {
            if ($ParameterInputs.ContainsKey($exclusiveParam)) {
                $exclusiveValue = Get-ParameterControlValue -Control $ParameterInputs[$exclusiveParam]

                if (-not [string]::IsNullOrWhiteSpace($exclusiveValue)) {
                    return $false  # Hide parameter if mutually exclusive parameter has a value
                }
            }
        }
    }

    return $true  # Show parameter
}

function Update-ParameterVisibility {
    param (
        [array]$Parameters,
        [hashtable]$ParameterInputs,
        [System.Windows.Controls.Panel]$ParameterPanel
    )

    # Update visibility for all parameters based on current values
    foreach ($param in $Parameters) {
        if ($ParameterInputs.ContainsKey($param.name)) {
            $control = $ParameterInputs[$param.name]
            $isVisible = Test-ParameterVisibility -Parameter $param -AllParameters $Parameters -ParameterInputs $ParameterInputs

            # Find the Grid row that contains this control
            $parent = $control.Parent
            if ($parent -and $parent -is [System.Windows.Controls.Grid]) {
                if ($isVisible) {
                    $parent.Visibility = "Visible"
                }
                else {
                    $parent.Visibility = "Collapsed"
                }
            }
        }
    }
}

function Export-PowerShellScript {
    param (
        [string]$Method,
        [string]$Path,
        [hashtable]$Parameters,
        [string]$Token,
        [string]$Region = "mypurecloud.com",

        # Auto = prefer Invoke-GCRequest when available (fallback to Invoke-WebRequest)
        # Portable = always use Invoke-WebRequest
        # OpsInsights = require Invoke-GCRequest (module transport)
        [Parameter()]
        [ValidateSet('Auto', 'Portable', 'OpsInsights')]
        [string]$Mode = 'Auto'
    )

    $script = @"
# Generated PowerShell script for Genesys Cloud API
# Endpoint: $Method $Path
# Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

`$token = "$Token"
`$region = "$Region"
`$baseUrl = "https://api.`$region"
`$path = "$Path"

"@

    # Build headers
    $script += @"
`$headers = @{
    "Authorization" = "Bearer `$token"
    "Content-Type" = "application/json"
}

"@

    # Build query parameters
    $queryParams = @()
    $pathParams = @{}
    $bodyContent = ""

    if ($Parameters) {
        foreach ($paramName in $Parameters.Keys) {
            $paramValue = $Parameters[$paramName]
            if ([string]::IsNullOrWhiteSpace($paramValue)) { continue }

            # Determine parameter type based on name and path
            $pattern = "{$paramName}"
            if ($Path -match [regex]::Escape($pattern)) {
                # Path parameter
                $pathParams[$paramName] = $paramValue
            }
            elseif ($paramName -eq "body") {
                # Body parameter
                $bodyContent = $paramValue
            }
            else {
                # Query parameter
                $queryParams += "$paramName=$([System.Uri]::EscapeDataString($paramValue))"
            }
        }
    }

    # Replace path parameters
    foreach ($paramName in $pathParams.Keys) {
        $escapedParam = [regex]::Escape("{$paramName}")
        $script += "`$path = `$path -replace '$escapedParam', '$($pathParams[$paramName])'`r`n"
    }

    # Build full URL with query parameters
    if ($queryParams.Count -gt 0) {
        $script += "`$url = `"`$baseUrl`$path?$($queryParams -join '&')`"`r`n"
    }
    else {
        $script += "`$url = `"`$baseUrl`$path`"`r`n"
    }

    $script += "`r`n"

    # Build request command (export mode)
    if ($bodyContent) {
        $script += "`$body = @'`r`n"
        $script += $bodyContent
        $script += "`r`n'@`r`n`r`n"
        if ($Mode -eq 'Portable') {
            $script += @"
	try {
	    `$iwr = @{ Uri = `$url; Method = "$Method"; Headers = `$headers; Body = `$body; ContentType = "application/json"; ErrorAction = "Stop" }
	    if (`$PSVersionTable.PSVersion.Major -lt 6) { `$iwr.UseBasicParsing = `$true }
	    `$response = Invoke-WebRequest @iwr
	    Write-Host "Success: `$(`$response.StatusCode)"
	    `$response.Content | ConvertFrom-Json | ConvertTo-Json -Depth 10
	} catch {
	    Write-Error "Request failed: `$(`$_.Exception.Message)"
	}
"@
        }
        elseif ($Mode -eq 'OpsInsights') {
            $script += @"
	try {
	    Import-Module GenesysCloud.OpsInsights -ErrorAction Stop | Out-Null
	    `$response = Invoke-GCRequest -Method $Method -Uri `$url -Headers `$headers -Body `$body -AsResponse
	    Write-Host "Success: `$(`$response.StatusCode)"
	    `$response.Content | ConvertFrom-Json | ConvertTo-Json -Depth 10
	} catch {
	    Write-Error "Request failed: `$(`$_.Exception.Message)"
	}
"@
        }
        else {
            $script += @"
	try {
	    try { Import-Module GenesysCloud.OpsInsights -ErrorAction SilentlyContinue | Out-Null } catch { }

	    if (Get-Command Invoke-GCRequest -ErrorAction SilentlyContinue) {
	        `$response = Invoke-GCRequest -Method $Method -Uri `$url -Headers `$headers -Body `$body -AsResponse
	    }
	    else {
	        `$iwr = @{ Uri = `$url; Method = "$Method"; Headers = `$headers; Body = `$body; ContentType = "application/json"; ErrorAction = "Stop" }
	        if (`$PSVersionTable.PSVersion.Major -lt 6) { `$iwr.UseBasicParsing = `$true }
	        `$response = Invoke-WebRequest @iwr
	    }

	    Write-Host "Success: `$(`$response.StatusCode)"
	    `$response.Content | ConvertFrom-Json | ConvertTo-Json -Depth 10
	} catch {
	    Write-Error "Request failed: `$(`$_.Exception.Message)"
	}
"@
        }
    }
    else {
        if ($Mode -eq 'Portable') {
            $script += @"
	try {
	    `$iwr = @{ Uri = `$url; Method = "$Method"; Headers = `$headers; ErrorAction = "Stop" }
	    if (`$PSVersionTable.PSVersion.Major -lt 6) { `$iwr.UseBasicParsing = `$true }
	    `$response = Invoke-WebRequest @iwr
	    Write-Host "Success: `$(`$response.StatusCode)"
	    `$response.Content | ConvertFrom-Json | ConvertTo-Json -Depth 10
	} catch {
	    Write-Error "Request failed: `$(`$_.Exception.Message)"
	}
"@
        }
        elseif ($Mode -eq 'OpsInsights') {
            $script += @"
	try {
	    Import-Module GenesysCloud.OpsInsights -ErrorAction Stop | Out-Null
	    `$response = Invoke-GCRequest -Method $Method -Uri `$url -Headers `$headers -AsResponse
	    Write-Host "Success: `$(`$response.StatusCode)"
	    `$response.Content | ConvertFrom-Json | ConvertTo-Json -Depth 10
	} catch {
	    Write-Error "Request failed: `$(`$_.Exception.Message)"
	}
"@
        }
        else {
            $script += @"
	try {
	    try { Import-Module GenesysCloud.OpsInsights -ErrorAction SilentlyContinue | Out-Null } catch { }

	    if (Get-Command Invoke-GCRequest -ErrorAction SilentlyContinue) {
	        `$response = Invoke-GCRequest -Method $Method -Uri `$url -Headers `$headers -AsResponse
	    }
	    else {
	        `$iwr = @{ Uri = `$url; Method = "$Method"; Headers = `$headers; ErrorAction = "Stop" }
	        if (`$PSVersionTable.PSVersion.Major -lt 6) { `$iwr.UseBasicParsing = `$true }
	        `$response = Invoke-WebRequest @iwr
	    }

	    Write-Host "Success: `$(`$response.StatusCode)"
	    `$response.Content | ConvertFrom-Json | ConvertTo-Json -Depth 10
	} catch {
	    Write-Error "Request failed: `$(`$_.Exception.Message)"
	}
"@
        }
    }

    return $script
}

function Export-CurlCommand {
    param (
        [string]$Method,
        [string]$Path,
        [hashtable]$Parameters,
        [string]$Token,
        [string]$Region = "mypurecloud.com"
    )

    $baseUrl = "https://api.$Region"
    $fullPath = $Path

    # Build query parameters and handle path parameters
    $queryParams = @()
    $bodyContent = ""

    if ($Parameters) {
        foreach ($paramName in $Parameters.Keys) {
            $paramValue = $Parameters[$paramName]
            if ([string]::IsNullOrWhiteSpace($paramValue)) { continue }

            $pattern = "{$paramName}"
            if ($fullPath -match [regex]::Escape($pattern)) {
                # Path parameter
                $fullPath = $fullPath -replace [regex]::Escape($pattern), $paramValue
            }
            elseif ($paramName -eq "body") {
                # Body parameter
                $bodyContent = $paramValue
            }
            else {
                # Query parameter - escape for URL
                $encodedValue = [System.Uri]::EscapeDataString($paramValue)
                $queryParams += "$paramName=$encodedValue"
            }
        }
    }

    # Build full URL
    $url = "$baseUrl$fullPath"
    if ($queryParams.Count -gt 0) {
        $url += "?" + ($queryParams -join "&")
    }

    # Build cURL command
    $curl = "curl -X $($Method.ToUpper()) `"$url`" ``"
    $curl += "`r`n  -H `"Authorization: Bearer $Token`" ``"
    $curl += "`r`n  -H `"Content-Type: application/json`""

    if ($bodyContent) {
        # Escape body for shell - single quotes are safest for JSON
        $escapedBody = $bodyContent -replace "'", "'\\''"
        $curl += " ``"
        $curl += "`r`n  -d '$escapedBody'"
    }

    return $curl
}

function Populate-ParameterValues {
    param ([Parameter(ValueFromPipeline)] $ParameterSet)

    if (-not $ParameterSet) { return }
    foreach ($entry in $ParameterSet) {
        $name = $entry.name
        if (-not $name) { continue }

        $paramControl = $paramInputs[$name]
        if ($paramControl -and $null -ne $entry.value) {
            Set-ParameterControlValue -Control $paramControl -Value $entry.value
        }
    }
}

function Resolve-SchemaReference {
    param (
        $Schema,
        $Definitions
    )

    if (-not $Schema) {
        return $null
    }

    $current = $Schema
    $depth = 0
    while ($current.'$ref' -and $depth -lt 10) {
        if ($current.'$ref' -match "#/definitions/(.+)") {
            $refName = $Matches[1]
            if ($Definitions -and $Definitions.$refName) {
                $current = $Definitions.$refName
            }
            else {
                return $current
            }
        }
        else {
            break
        }
        $depth++
    }

    return $current
}

function Format-SchemaType {
    param (
        $Schema,
        $Definitions
    )

    $resolved = Resolve-SchemaReference -Schema $Schema -Definitions $Definitions
    if (-not $resolved) {
        return "unknown"
    }

    $type = $resolved.type
    if (-not $type -and $resolved.'$ref') {
        $type = "ref"
    }

    if ($type -eq "array" -and $resolved.items) {
        $itemType = Format-SchemaType -Schema $resolved.items -Definitions $Definitions
        return "array of $itemType"
    }

    if ($type) {
        return $type
    }

    return "object"
}

function Flatten-Schema {
    param (
        $Schema,
        $Definitions,
        [string]$Prefix = "",
        [int]$Depth = 0
    )

    if ($Depth -ge 10) {
        return @()
    }

    $resolved = Resolve-SchemaReference -Schema $Schema -Definitions $Definitions
    if (-not $resolved) {
        return @()
    }

    $entries = @()
    $type = $resolved.type

    if ($type -eq "object" -or $resolved.properties) {
        $requiredSet = @{}
        $requiredList = if ($resolved.required) { $resolved.required } else { @() }
        foreach ($req in $requiredList) {
            $requiredSet[$req] = $true
        }

        $props = $resolved.properties
        if ($props) {
            foreach ($prop in $props.PSObject.Properties) {
                $fieldName = if ($Prefix) { "$Prefix.$($prop.Name)" } else { $prop.Name }
                $propResolved = Resolve-SchemaReference -Schema $prop.Value -Definitions $Definitions
                $entries += [PSCustomObject]@{
                    Field       = $fieldName
                    Type        = Format-SchemaType -Schema $prop.Value -Definitions $Definitions
                    Description = $propResolved.description
                    Required    = if ($requiredSet.ContainsKey($prop.Name)) { "Yes" } else { "No" }
                }

                if ($propResolved.type -eq "object" -or $propResolved.type -eq "array" -or $propResolved.'$ref') {
                    $entries += Flatten-Schema -Schema $prop.Value -Definitions $Definitions -Prefix $fieldName -Depth ($Depth + 1)
                }
            }
        }
    }
    elseif ($type -eq "array" -and $resolved.items) {
        $itemField = if ($Prefix) { "$Prefix[]" } else { "[]" }
        $entries += [PSCustomObject]@{
            Field       = $itemField
            Type        = Format-SchemaType -Schema $resolved.items -Definitions $Definitions
            Description = $resolved.items.description
            Required    = "No"
        }

        $entries += Flatten-Schema -Schema $resolved.items -Definitions $Definitions -Prefix $itemField -Depth ($Depth + 1)
    }

    return $entries
}

function Get-ResponseSchema {
    param ($MethodObject)

    if (-not $MethodObject) { return $null }

    $preferredCodes = @("200", "201", "202", "203", "default")
    foreach ($code in $preferredCodes) {
        $resp = $MethodObject.responses.$code
        if ($resp -and $resp.schema) {
            return $resp.schema
        }
    }

    foreach ($resp in $MethodObject.responses.PSObject.Properties) {
        if ($resp.Value -and $resp.Value.schema) {
            return $resp.Value.schema
        }
    }

    return $null
}

function Update-SchemaList {
    param ($Schema)

    if (-not $schemaList) { return }
    $schemaList.Items.Clear()

    $entries = Flatten-Schema -Schema $Schema -Definitions $Definitions
    if (-not $entries -or $entries.Count -eq 0) {
        $entries = @([PSCustomObject]@{
                Field       = "(no schema available)"
                Type        = ""
                Description = ""
                Required    = ""
            })
    }

    foreach ($entry in $entries) {
        $schemaList.Items.Add($entry) | Out-Null
    }
}

function Get-EnumValues {
    param (
        $Schema,
        [string]$PropertyName
    )

    if (-not $Schema) {
        return @()
    }

    # First check if the schema has properties
    $properties = $Schema.properties
    if (-not $properties) {
        return @()
    }

    # Look for the property by name
    $property = $properties.PSObject.Properties[$PropertyName]
    if (-not $property) {
        return @()
    }

    # Check if the property has enum values
    $propValue = $property.Value
    if ($propValue -and $propValue.enum) {
        # Comma operator forces PowerShell to treat the array as a single object
        # preventing automatic unwrapping when the array is returned
        return , $propValue.enum
    }

    return @()
}

function Initialize-FilterBuilderEnum {
    $convPredicate = Resolve-SchemaReference -Schema $script:Definitions.ConversationDetailQueryPredicate -Definitions $script:Definitions
    $segmentPredicate = Resolve-SchemaReference -Schema $script:Definitions.SegmentDetailQueryPredicate -Definitions $script:Definitions

    $script:FilterBuilderEnums.Conversation.Dimensions = Get-EnumValues -Schema $convPredicate -PropertyName "dimension"
    $script:FilterBuilderEnums.Conversation.Metrics = Get-EnumValues -Schema $convPredicate -PropertyName "metric"
    $script:FilterBuilderEnums.Conversation.Types = Get-EnumValues -Schema $convPredicate -PropertyName "type"

    $script:FilterBuilderEnums.Segment.Dimensions = Get-EnumValues -Schema $segmentPredicate -PropertyName "dimension"
    $script:FilterBuilderEnums.Segment.Metrics = Get-EnumValues -Schema $segmentPredicate -PropertyName "metric"
    $script:FilterBuilderEnums.Segment.Types = Get-EnumValues -Schema $segmentPredicate -PropertyName "type"
    $script:FilterBuilderEnums.Segment.PropertyTypes = Get-EnumValues -Schema $segmentPredicate -PropertyName "propertyType"

    $operatorValues = Get-EnumValues -Schema $convPredicate -PropertyName "operator"
    if ($operatorValues.Count -gt 0) {
        $script:FilterBuilderEnums.Operators = $operatorValues
    }
}
function Update-FilterFieldOptions {
    param (
        [string]$Scope,
        [string]$PredicateType,
        $ComboBox
    )

    if (-not $ComboBox) { return }

    $ComboBox.Items.Clear()
    $ComboBox.IsEnabled = $true

    switch ("$Scope|$PredicateType") {
        "Conversation|metric" {
            $items = $script:FilterBuilderEnums.Conversation.Metrics
        }
        "Conversation|dimension" {
            $items = $script:FilterBuilderEnums.Conversation.Dimensions
        }
        "Segment|metric" {
            $items = $script:FilterBuilderEnums.Segment.Metrics
        }
        "Segment|dimension" {
            $items = $script:FilterBuilderEnums.Segment.Dimensions
        }
        default {
            # For property type or unknown types, no field selection is needed
            $items = @()
        }
    }
    if (-not $items -or $items.Count -eq 0) {
        $ComboBox.Items.Add("(no fields available)") | Out-Null
        $ComboBox.IsEnabled = $false
        $ComboBox.SelectedIndex = 0
        return
    }

    foreach ($item in $items) {
        $ComboBox.Items.Add($item) | Out-Null
    }

    $ComboBox.SelectedIndex = 0
}

function Format-FilterSummary {
    param ($Filter)

    if (-not $Filter) { return "" }

    $predicate = if ($Filter.predicates -and $Filter.predicates.Count -gt 0) { $Filter.predicates[0] } else { $null }
    if (-not $predicate) { return "$($Filter.type) filter" }

    $fieldName = if ($predicate.dimension) {
        $predicate.dimension
    }
    elseif ($predicate.metric) {
        $predicate.metric
    }
    elseif ($predicate.property) {
        "$($predicate.property) ($($predicate.propertyType))"
    }
    else {
        "<field>"
    }

    $valueText = "<no value>"
    if ($predicate.range) {
        $valueText = "(range)"
    }
    elseif ($null -ne $predicate.value) {
        $valueText = $predicate.value
    }

    return "$($Filter.type): $($predicate.type) $fieldName $($predicate.operator) $valueText"
}
function Reset-FilterBuilderData {
    $script:FilterBuilderData.ConversationFilters = New-Object System.Collections.ArrayList
    $script:FilterBuilderData.SegmentFilters = New-Object System.Collections.ArrayList
    if ($conversationFiltersList) { $conversationFiltersList.Items.Clear() }
    if ($segmentFiltersList) { $segmentFiltersList.Items.Clear() }
    if ($filterIntervalInput) {
        $filterIntervalInput.Text = $script:FilterBuilderData.Interval
    }
    if ($removeConversationPredicateButton) {
        $removeConversationPredicateButton.IsEnabled = $false
    }
    if ($removeSegmentPredicateButton) {
        $removeSegmentPredicateButton.IsEnabled = $false
    }
}

function Update-FilterList {
    param ([string]$Scope)

    if ($Scope -eq "Conversation") {
        if (-not $conversationFiltersList) { return }
        $conversationFiltersList.Items.Clear()
        foreach ($filter in $script:FilterBuilderData.ConversationFilters) {
            $summary = Format-FilterSummary -Filter $filter
            $conversationFiltersList.Items.Add($summary) | Out-Null
        }
    }
    else {
        if (-not $segmentFiltersList) { return }
        $segmentFiltersList.Items.Clear()
        foreach ($filter in $script:FilterBuilderData.SegmentFilters) {
            $summary = Format-FilterSummary -Filter $filter
            $segmentFiltersList.Items.Add($summary) | Out-Null
        }
    }
}

function Refresh-FilterList {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Conversation', 'Segment')]
        [string]$Scope
    )

    try {
        Update-FilterList -Scope $Scope
        Update-FilterBuilderHint
        Invoke-FilterBuilderBody
    }
    catch {
        Add-LogEntry "Failed to refresh filter list ($Scope): $($_.Exception.Message)"
    }
}

function Get-BodyTextBox {
    if ($script:CurrentBodyControl) {
        $vc = $script:CurrentBodyControl.ValueControl
        if ($vc -and (Get-Member -InputObject $vc -Name 'Text' -ErrorAction SilentlyContinue)) {
            return $vc
        }
        if (Get-Member -InputObject $script:CurrentBodyControl -Name 'Text' -ErrorAction SilentlyContinue) {
            return $script:CurrentBodyControl
        }
    }
    return $null
}
function Invoke-FilterBuilderBody {
    $bodyTextBox = Get-BodyTextBox
    if (-not $bodyTextBox) { return }

    $intervalValue = if ($filterIntervalInput -and ($filterIntervalInput.Text.Trim())) {
        $filterIntervalInput.Text.Trim()
    }
    else {
        $script:FilterBuilderData.Interval
    }

    $payload = [ordered]@{}
    if ($intervalValue) {
        $payload.interval = $intervalValue
        $script:FilterBuilderData.Interval = $intervalValue
    }

    if ($script:FilterBuilderData.ConversationFilters.Count -gt 0) {
        $payload.conversationFilters = $script:FilterBuilderData.ConversationFilters
    }
    if ($script:FilterBuilderData.SegmentFilters.Count -gt 0) {
        $payload.segmentFilters = $script:FilterBuilderData.SegmentFilters
    }

    $json = $payload | ConvertTo-Json -Depth 10
    $bodyTextBox.Text = $json
}
function Set-FilterBuilderVisibility {
    param ([bool]$Visible)

    if ($filterBuilderExpander) {
        $filterBuilderExpander.Visibility = if ($Visible) { "Visible" } else { "Collapsed" }
        $filterBuilderExpander.IsExpanded = $Visible
    }

    if (-not $filterBuilderBorder) { return }
    $filterBuilderBorder.Visibility = if ($Visible) { "Visible" } else { "Collapsed" }

    if (-not $Visible) {
        Release-FilterBuilderResources
        if ($filterBuilderHintText) {
            $filterBuilderHintText.Text = ""
        }
    }
    else {
        Initialize-FilterBuilderControl
    }
}
function Update-FilterBuilderHint {
    if (-not $filterBuilderHintText) { return }
    $convDims = $script:FilterBuilderEnums.Conversation.Dimensions.Count
    $convMetrics = $script:FilterBuilderEnums.Conversation.Metrics.Count
    $convTypes = $script:FilterBuilderEnums.Conversation.Types.Count
    $segDims = $script:FilterBuilderEnums.Segment.Dimensions.Count
    $segMetrics = $script:FilterBuilderEnums.Segment.Metrics.Count
    $segTypes = $script:FilterBuilderEnums.Segment.Types.Count
    $segPropTypes = $script:FilterBuilderEnums.Segment.PropertyTypes.Count
    $hint = "Conversation types ($convTypes) | dims ($convDims) | metrics ($convMetrics); Segment types ($segTypes) | dims ($segDims) | metrics ($segMetrics) | prop types ($segPropTypes)."
    $filterBuilderHintText.Text = $hint
}

function Release-FilterBuilderResources {
    if ($conversationFiltersList) {
        $conversationFiltersList.Items.Clear()
        $conversationFiltersList.ItemsSource = $null
    }
    if ($segmentFiltersList) {
        $segmentFiltersList.Items.Clear()
        $segmentFiltersList.ItemsSource = $null
    }
    if ($conversationFieldCombo) {
        $conversationFieldCombo.Items.Clear()
        $conversationFieldCombo.ItemsSource = $null
    }
    if ($segmentFieldCombo) {
        $segmentFieldCombo.Items.Clear()
        $segmentFieldCombo.ItemsSource = $null
    }
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
}

function Parse-FilterValueInput {
    param ([string]$Text)

    $value = if ($Text) { $Text.Trim() } else { "" }
    if (-not $value) { return $null }

    if ($value.StartsWith("{") -and $value.EndsWith("}")) {
        try {
            $parsed = $value | ConvertFrom-Json -ErrorAction Stop
            return $parsed
        }
        catch {
            Write-Verbose "Filter value is not valid JSON; falling back to literal string."
        }
    }

    return $value
}

function Add-FilterEntry {
    param (
        [string]$Scope,
        $FilterObject
    )

    if ($Scope -eq "Conversation") {
        $script:FilterBuilderData.ConversationFilters.Add($FilterObject) | Out-Null
    }
    else {
        $script:FilterBuilderData.SegmentFilters.Add($FilterObject) | Out-Null
    }
    Refresh-FilterList -Scope $Scope
}

function Show-FilterBuilderMessage {
    param (
        [string]$Message,
        [string]$Title = "Filter Builder"
    )

    [System.Windows.MessageBox]::Show($Message, $Title, [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
}

function Build-FilterFromInput {
    param (
        [string]$Scope,
        $FilterTypeCombo,
        $PredicateTypeCombo,
        $FieldCombo,
        $OperatorCombo,
        $ValueInput,
        $PropertyTypeCombo,
        $PropertyNameInput
    )

    $filterType = if ($FilterTypeCombo -and $FilterTypeCombo.SelectedItem) { $FilterTypeCombo.SelectedItem } else { "and" }
    $predicateType = if ($PredicateTypeCombo -and $PredicateTypeCombo.SelectedItem) { $PredicateTypeCombo.SelectedItem } else { "dimension" }
    $operator = if ($OperatorCombo -and $OperatorCombo.SelectedItem) { $OperatorCombo.SelectedItem } else { "" }

    # Field selection differs by predicate type:
    # - dimension/metric: choose from FieldCombo (enum-derived)
    # - property: user supplies the property name via PropertyNameInput
    $fieldName = ""
    if ($predicateType -eq "property") {
        if ($PropertyNameInput -and (Get-Member -InputObject $PropertyNameInput -Name 'Text' -ErrorAction SilentlyContinue)) {
            $fieldName = $PropertyNameInput.Text
        }
    }
    else {
        if ($FieldCombo -and $FieldCombo.SelectedItem) {
            $fieldName = $FieldCombo.SelectedItem
        }
    }
    if ($fieldName) { $fieldName = [string]$fieldName }
    $fieldName = $fieldName.Trim()

    if ($predicateType -eq "property") {
        if ([string]::IsNullOrWhiteSpace($fieldName)) {
            Show-FilterBuilderMessage -Message "Enter a property name before adding a property predicate."
            return $null
        }
    }
    else {
        if (-not $fieldName -or $fieldName -eq "(no fields available)") {
            Show-FilterBuilderMessage -Message "Please select a valid field before adding a predicate."
            return $null
        }
    }
    if (-not $operator) {
        Show-FilterBuilderMessage -Message "Please select an operator."
        return $null
    }

    $valueInput = Parse-FilterValueInput -Text $ValueInput.Text
    if ($operator -ne "exists" -and $null -eq $valueInput) {
        Show-FilterBuilderMessage -Message "Provide a value or range for the predicate."
        return $null
    }

    $predicateData = [ordered]@{
        type     = $predicateType
        operator = $operator
    }

    if ($predicateType -eq "metric") {
        $predicateData.metric = $fieldName
    }
    elseif ($predicateType -eq "property") {
        $predicateData.property = $fieldName
        if ($PropertyTypeCombo -and $PropertyTypeCombo.SelectedItem) {
            $predicateData.propertyType = $PropertyTypeCombo.SelectedItem
        }
    }
    else {
        $predicateData.dimension = $fieldName
    }

    if ($valueInput -and ($valueInput -is [System.Management.Automation.PSCustomObject] -or $valueInput -is [System.Collections.IDictionary])) {
        $predicateData.range = $valueInput
    }
    elseif ($null -ne $valueInput) {
        $predicateData.value = $valueInput
    }

    $predicate = [PSCustomObject]$predicateData

    return [PSCustomObject]@{
        type       = $filterType
        predicates = @($predicate)
    }
}

function Initialize-FilterBuilderControl {
    if (-not $conversationFilterTypeCombo) { return }

    $conversationFilterTypeCombo.Items.Clear()
    $conversationFilterTypeCombo.Items.Add("and") | Out-Null
    $conversationFilterTypeCombo.Items.Add("or") | Out-Null
    $conversationFilterTypeCombo.SelectedIndex = 0

    $segmentFilterTypeCombo.Items.Clear()
    $segmentFilterTypeCombo.Items.Add("and") | Out-Null
    $segmentFilterTypeCombo.Items.Add("or") | Out-Null
    $segmentFilterTypeCombo.SelectedIndex = 0

    $conversationPredicateTypeCombo.Items.Clear()
    if ($script:FilterBuilderEnums.Conversation.Types.Count -gt 0) {
        foreach ($type in $script:FilterBuilderEnums.Conversation.Types) {
            $conversationPredicateTypeCombo.Items.Add($type) | Out-Null
        }
    }
    else {
        # Fallback to default values if enum extraction fails
        $conversationPredicateTypeCombo.Items.Add("dimension") | Out-Null
        $conversationPredicateTypeCombo.Items.Add("property") | Out-Null
        $conversationPredicateTypeCombo.Items.Add("metric") | Out-Null
    }
    $conversationPredicateTypeCombo.SelectedIndex = 0

    $segmentPredicateTypeCombo.Items.Clear()
    if ($script:FilterBuilderEnums.Segment.Types.Count -gt 0) {
        foreach ($type in $script:FilterBuilderEnums.Segment.Types) {
            $segmentPredicateTypeCombo.Items.Add($type) | Out-Null
        }
    }
    else {
        # Fallback to default values if enum extraction fails
        $segmentPredicateTypeCombo.Items.Add("dimension") | Out-Null
        $segmentPredicateTypeCombo.Items.Add("property") | Out-Null
        $segmentPredicateTypeCombo.Items.Add("metric") | Out-Null
    }
    $segmentPredicateTypeCombo.SelectedIndex = 0

    if ($conversationOperatorCombo) {
        $conversationOperatorCombo.Items.Clear()
        foreach ($op in $script:FilterBuilderEnums.Operators) {
            $conversationOperatorCombo.Items.Add($op) | Out-Null
        }
        $conversationOperatorCombo.SelectedIndex = 0
    }
    if ($segmentOperatorCombo) {
        $segmentOperatorCombo.Items.Clear()
        foreach ($op in $script:FilterBuilderEnums.Operators) {
            $segmentOperatorCombo.Items.Add($op) | Out-Null
        }
        $segmentOperatorCombo.SelectedIndex = 0
    }

    if ($segmentPropertyTypeCombo) {
        $segmentPropertyTypeCombo.Items.Clear()
        if ($script:FilterBuilderEnums.Segment.PropertyTypes.Count -gt 0) {
            foreach ($propType in $script:FilterBuilderEnums.Segment.PropertyTypes) {
                $segmentPropertyTypeCombo.Items.Add($propType) | Out-Null
            }
        }
        else {
            # Fallback to default values if enum extraction fails
            $segmentPropertyTypeCombo.Items.Add("bool") | Out-Null
            $segmentPropertyTypeCombo.Items.Add("integer") | Out-Null
            $segmentPropertyTypeCombo.Items.Add("real") | Out-Null
            $segmentPropertyTypeCombo.Items.Add("date") | Out-Null
            $segmentPropertyTypeCombo.Items.Add("string") | Out-Null
            $segmentPropertyTypeCombo.Items.Add("uuid") | Out-Null
        }
        if ($segmentPropertyTypeCombo.Items.Count -gt 0) {
            $segmentPropertyTypeCombo.SelectedIndex = 0
        }
    }

    Update-FilterFieldOptions -Scope "Conversation" -PredicateType "dimension" -ComboBox $conversationFieldCombo
    Update-FilterFieldOptions -Scope "Segment" -PredicateType "dimension" -ComboBox $segmentFieldCombo
}

# Script-level variables to track tree population progress
$script:InspectorNodeCount = 0
$script:InspectorMaxNodes = 2000
$script:InspectorMaxDepth = 15

# Maximum length for log message truncation
$script:LogMaxMessageLength = 500

function Add-InspectorTreeNode {
    param (
        $Tree,
        $Data,
        [string]$Label = "root",
        [int]$Depth = 0
    )

    if (-not $Tree) { return }

    # Check if we've exceeded the maximum node count to prevent freezing
    if ($script:InspectorNodeCount -ge $script:InspectorMaxNodes) {
        if ($Depth -eq 0) {
            $limitNode = New-Object System.Windows.Controls.TreeViewItem
            $limitNode.Header = "[Maximum node limit reached ($($script:InspectorMaxNodes) nodes). Use Raw tab for full data.]"
            $limitNode.Foreground = [System.Windows.Media.Brushes]::OrangeRed
            $Tree.Items.Add($limitNode) | Out-Null
        }
        return
    }

    # Check if we've exceeded the maximum depth to prevent deep recursion
    if ($Depth -ge $script:InspectorMaxDepth) {
        $depthNode = New-Object System.Windows.Controls.TreeViewItem
        $depthNode.Header = "[Max depth reached - use Raw tab for full data]"
        $depthNode.Foreground = [System.Windows.Media.Brushes]::Gray
        $Tree.Items.Add($depthNode) | Out-Null
        return
    }

    $script:InspectorNodeCount++
    $node = New-Object System.Windows.Controls.TreeViewItem
    $isEnumerable = ($Data -is [System.Collections.IEnumerable]) -and -not ($Data -is [string])
    if ($Data -and $Data.PSObject.Properties.Count -gt 0) {
        $node.Header = "$($Label) (object)"
        foreach ($prop in $Data.PSObject.Properties) {
            if ($script:InspectorNodeCount -ge $script:InspectorMaxNodes) {
                $ellipsis = New-Object System.Windows.Controls.TreeViewItem
                $ellipsis.Header = "[... node limit reached]"
                $ellipsis.Foreground = [System.Windows.Media.Brushes]::Gray
                $node.Items.Add($ellipsis) | Out-Null
                break
            }
            Add-InspectorTreeNode -Tree $node -Data $prop.Value -Label "$($prop.Name)" -Depth ($Depth + 1)
        }
    }
    elseif ($isEnumerable) {
        $node.Header = "$($Label) (array)"
        $count = 0
        foreach ($item in $Data) {
            if ($count -ge 150) {
                $ellipsis = New-Object System.Windows.Controls.TreeViewItem
                $ellipsis.Header = "[... $($Data.Count - 150) more items]"
                $ellipsis.Foreground = [System.Windows.Media.Brushes]::Gray
                $node.Items.Add($ellipsis) | Out-Null
                break
            }
            if ($script:InspectorNodeCount -ge $script:InspectorMaxNodes) {
                $ellipsis = New-Object System.Windows.Controls.TreeViewItem
                $ellipsis.Header = "[... node limit reached]"
                $ellipsis.Foreground = [System.Windows.Media.Brushes]::Gray
                $node.Items.Add($ellipsis) | Out-Null
                break
            }

            Add-InspectorTreeNode -Tree $node -Data $item -Label "[$count]" -Depth ($Depth + 1)
            $count++
        }
    }
    else {
        $valueText = if ($null -ne $Data) { $Data.ToString() } else { "<null>" }
        $node.Header = "$($Label): $valueText"
    }

    $node.IsExpanded = $Depth -lt 2
    $Tree.Items.Add($node) | Out-Null
}

function Populate-InspectorTree {
    param(
        [Parameter(Mandatory)]
        $Tree,

        [Parameter(Mandatory)]
        $Data,

        [Parameter()]
        [string]$Label = 'root'
    )

    Add-InspectorTreeNode -Tree $Tree -Data $Data -Label $Label -Depth 0
}

function Show-DataInspector {
    param ([string]$JsonText)

    $sourceText = $JsonText
    if (-not $sourceText -and $script:LastResponseFile -and (Test-Path -Path $script:LastResponseFile)) {
        $fileInfo = Get-Item -Path $script:LastResponseFile
        if ($fileInfo.Length -gt 5MB) {
            $result = [System.Windows.MessageBox]::Show("The stored result is large ($([math]::Round($fileInfo.Length / 1MB, 1)) MB). Parsing it may take some time. Continue?", "Large Result Warning", "YesNo")
            if ($result -ne "Yes") {
                Add-LogEntry "Inspector aborted by user for large stored result."
                return
            }
        }
        $sourceText = Get-Content -Path $script:LastResponseFile -Raw
    }

    if (-not $sourceText) {
        Add-LogEntry "Inspector: no data to show."
        return
    }

    try {
        $parsed = $sourceText | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        [System.Windows.MessageBox]::Show("Unable to parse current response for inspection.`n$($_.Exception.Message)", "Data Inspector")
        return
    }

    $inspectorXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Data Inspector" Height="600" Width="700" WindowStartupLocation="CenterOwner">
  <DockPanel Margin="10">
    <StackPanel DockPanel.Dock="Top" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0 0 0 8">
      <Button Name="CopyJsonButton" Width="110" Height="28" Content="Copy JSON" Margin="0 0 10 0"/>
      <Button Name="ExportJsonButton" Width="130" Height="28" Content="Export JSON"/>
    </StackPanel>
    <TabControl>
      <TabItem Header="Structured">
        <ScrollViewer VerticalScrollBarVisibility="Auto">
          <TreeView Name="InspectorTree"/>
        </ScrollViewer>
      </TabItem>
      <TabItem Header="Raw">
        <TextBox Name="InspectorRaw" TextWrapping="Wrap" AcceptsReturn="True"
                 VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto" IsReadOnly="True"/>
      </TabItem>
    </TabControl>
  </DockPanel>
</Window>
"@

    $inspectorWindow = [System.Windows.Markup.XamlReader]::Parse($inspectorXaml)
    if (-not $inspectorWindow) {
        Add-LogEntry "Data Inspector UI failed to load."
        return
    }

    $treeView = $inspectorWindow.FindName("InspectorTree")
    $rawBox = $inspectorWindow.FindName("InspectorRaw")
    $copyButton = $inspectorWindow.FindName("CopyJsonButton")
    $exportButton = $inspectorWindow.FindName("ExportJsonButton")

    if ($rawBox) {
        $rawBox.Text = $sourceText
    }

    if ($treeView) {
        $treeView.Items.Clear()
        # Reset the node counter before populating
        $script:InspectorNodeCount = 0
        Add-LogEntry "Inspector: Building tree view for data (max $($script:InspectorMaxNodes) nodes, max depth $($script:InspectorMaxDepth))..."
        Populate-InspectorTree -Tree $treeView -Data $parsed -Label "root"
        Add-LogEntry "Inspector: Tree view populated with $($script:InspectorNodeCount) nodes."
    }

    if ($copyButton) {
        $copyButton.Add_Click({
                if (Get-Command Set-Clipboard -ErrorAction SilentlyContinue) {
                    Set-Clipboard -Value $sourceText
                    Add-LogEntry "Raw JSON copied to clipboard via inspector."
                }
                else {
                    [System.Windows.MessageBox]::Show("Clipboard access is not available in this host.", "Clipboard")
                    Add-LogEntry "Clipboard copy skipped (command missing)."
                }
            })
    }

    if ($exportButton) {
        $exportButton.Add_Click({
                $dialog = New-Object Microsoft.Win32.SaveFileDialog
                $dialog.Filter = "JSON Files (*.json)|*.json|All Files (*.*)|*.*"
                $dialog.FileName = "GenesysData.json"
                $dialog.Title = "Export Inspector JSON"
                if ($dialog.ShowDialog() -eq $true) {
                    $JsonText | Out-File -FilePath $dialog.FileName -Encoding utf8
                    Add-LogEntry "Inspector JSON exported to $($dialog.FileName)"
                }
            })
    }

    if ($Window) {
        $inspectorWindow.Owner = $Window
    }
    $inspectorWindow.ShowDialog() | Out-Null
}

<#
.SYNOPSIS
    Displays a formatted conversation timeline report in a popup window.
.DESCRIPTION
    Shows the chronological timeline report with all events from the conversation,
    including timing, errors, MOS scores, hold times, queue wait times, and flow path.
.PARAMETER Report
    The conversation report object containing all data from 6 API endpoints
#>
function Show-ConversationTimelineReport {
    param (
        [Parameter(Mandatory = $true)]
        $Report
    )

    if (-not $Report) {
        Add-LogEntry "No conversation report data to display."
        return
    }

    # Generate the formatted timeline report text
    $reportText = Format-ConversationReportText -Report $Report

    # Sanitize ConversationId for safe use in XAML Title (prevent XML injection)
    $safeConvId = if ($Report.ConversationId) {
        [System.Security.SecurityElement]::Escape($Report.ConversationId)
    }
    else {
        "Unknown"
    }

    $timelineXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Conversation Timeline Report - $safeConvId" Height="700" Width="1000" WindowStartupLocation="CenterOwner">
  <DockPanel Margin="10">
    <StackPanel DockPanel.Dock="Top" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0 0 0 8">
      <Button Name="CopyReportButton" Width="110" Height="28" Content="Copy Report" Margin="0 0 10 0"/>
      <Button Name="ExportReportButton" Width="130" Height="28" Content="Export Report"/>
    </StackPanel>
    <TextBox Name="TimelineReportText" TextWrapping="Wrap" AcceptsReturn="True"
             VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto" IsReadOnly="True"
             FontFamily="Consolas" FontSize="11"/>
  </DockPanel>
</Window>
"@

    try {
        $timelineWindow = [System.Windows.Markup.XamlReader]::Parse($timelineXaml)
    }
    catch {
        Add-LogEntry "Failed to create timeline window: $($_.Exception.Message)"
        [System.Windows.MessageBox]::Show("Failed to create timeline window: $($_.Exception.Message)", "Error")
        return
    }

    if (-not $timelineWindow) {
        Add-LogEntry "Timeline report window failed to load."
        return
    }

    $timelineTextBox = $timelineWindow.FindName("TimelineReportText")
    $copyButton = $timelineWindow.FindName("CopyReportButton")
    $exportButton = $timelineWindow.FindName("ExportReportButton")

    if ($timelineTextBox) {
        $timelineTextBox.Text = $reportText
    }

    if ($copyButton) {
        $copyButton.Add_Click({
                try {
                    if (Get-Command Set-Clipboard -ErrorAction SilentlyContinue) {
                        Set-Clipboard -Value $reportText
                        Add-LogEntry "Timeline report copied to clipboard."
                    }
                    else {
                        [System.Windows.Clipboard]::SetText($reportText)
                        Add-LogEntry "Timeline report copied to clipboard."
                    }
                }
                catch {
                    Add-LogEntry "Failed to copy timeline report: $($_.Exception.Message)"
                }
            })
    }

    if ($exportButton) {
        $exportButton.Add_Click({
                # Sanitize ConversationId for safe use in filename (remove invalid filename characters)
                $safeFilenameConvId = if ($Report.ConversationId) {
                    $Report.ConversationId -replace '[\\/:*?"<>|]', '_'
                }
                else {
                    "Unknown"
                }

                $dialog = New-Object Microsoft.Win32.SaveFileDialog
                $dialog.Filter = "Text Files (*.txt)|*.txt|All Files (*.*)|*.*"
                $dialog.Title = "Export Conversation Timeline Report"
                $dialog.FileName = "ConversationTimeline_$safeFilenameConvId.txt"
                if ($dialog.ShowDialog() -eq $true) {
                    try {
                        $reportText | Out-File -FilePath $dialog.FileName -Encoding utf8
                        Add-LogEntry "Timeline report exported to $($dialog.FileName)"
                    }
                    catch {
                        Add-LogEntry "Failed to export timeline report: $($_.Exception.Message)"
                        [System.Windows.MessageBox]::Show("Failed to export timeline report: $($_.Exception.Message)", "Export Error")
                    }
                }
            })
    }

    if ($Window) {
        $timelineWindow.Owner = $Window
    }
    $timelineWindow.ShowDialog() | Out-Null
}

function Job-StatusIsPending {
    param ([string]$Status)

    if (-not $Status) { return $false }
    return $Status -match '^(pending|running|in[-]?progress|processing|created)$'
}

<#
.SYNOPSIS
    Updates or adds a query parameter in a URL.
.DESCRIPTION
    Safely updates an existing query parameter or adds a new one to a URL path.
    Handles URLs with or without existing query strings.
.PARAMETER Path
    The URL path (may include existing query string)
.PARAMETER ParameterName
    The query parameter name to update or add
.PARAMETER ParameterValue
    The value to set for the parameter
.OUTPUTS
    Updated URL path with query parameter
#>
function Update-UrlParameter {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$ParameterName,
        [Parameter(Mandatory = $true)]
        [string]$ParameterValue
    )

    # Parse URL into path and query parts
    if ($Path -match '^([^\?]+)(\?.*)$') {
        $pathPart = $matches[1]
        $queryPart = $matches[2]
        # Check if parameter already exists in query (match any value, not just digits)
        $paramPattern = "[&\?]$ParameterName=[^&]*"
        if ($queryPart -match $paramPattern) {
            $queryPart = $queryPart -replace "([&\?])$ParameterName=[^&]*", "`${1}$ParameterName=$ParameterValue"
            return $pathPart + $queryPart
        }
        else {
            return "$Path&$ParameterName=$ParameterValue"
        }
    }
    else {
        # No query string yet
        return "$Path?$ParameterName=$ParameterValue"
    }
}

<#
.SYNOPSIS
    Fetches all pages from a paginated API endpoint.
.DESCRIPTION
    Handles three types of pagination:
    1. Cursor-based: Response contains 'cursor' field
    2. URI-based: Response contains 'nextUri' field
    3. Page number based: Response contains 'pageCount' and 'pageNumber' fields
    Continues fetching pages until no more pagination info is found.
.PARAMETER BaseUrl
    Base URL for the API
.PARAMETER InitialPath
    Initial endpoint path
.PARAMETER Headers
    HTTP headers including authorization
.PARAMETER Method
    HTTP method (GET or POST)
.PARAMETER Body
    Request body for POST requests
.PARAMETER ProgressCallback
    Optional callback for progress reporting
#>
function Get-PaginatedResults {
    param (
        [Parameter(Mandatory = $true)]
        [string]$BaseUrl,
        [Parameter(Mandatory = $true)]
        [string]$InitialPath,
        [Parameter(Mandatory = $true)]
        [hashtable]$Headers,
        [Parameter(Mandatory = $false)]
        [string]$Method = "GET",
        [Parameter(Mandatory = $false)]
        [string]$Body = $null,
        [scriptblock]$ProgressCallback = $null
    )

    $allResults = [System.Collections.ArrayList]::new()
    $currentPath = $InitialPath
    $pageNumber = 1
    $continueLoop = $true

    while ($continueLoop) {
        if ($ProgressCallback) {
            & $ProgressCallback -PageNumber $pageNumber -Status "Fetching page $pageNumber..."
        }

        try {
            $url = if ($currentPath -match '^https?://') { $currentPath } else { "$BaseUrl$currentPath" }
            $response = Invoke-GCRequest -Method $Method -Uri $url -Headers $Headers -Body $Body -AsResponse
            $data = $response.Content | ConvertFrom-Json

            # Add results from this page
            if ($data.entities) {
                foreach ($entity in $data.entities) {
                    [void]$allResults.Add($entity)
                }
            }
            elseif ($data.conversations) {
                foreach ($conv in $data.conversations) {
                    [void]$allResults.Add($conv)
                }
            }
            elseif ($data -is [array]) {
                foreach ($item in $data) {
                    [void]$allResults.Add($item)
                }
            }
            else {
                # Single result or unknown structure
                [void]$allResults.Add($data)
            }

            # Check for cursor-based pagination
            if ($data.cursor) {
                # URL-encode the cursor value to handle special characters
                $encodedCursor = [uri]::EscapeDataString($data.cursor)
                $currentPath = $InitialPath
                if ($currentPath -match '\?') {
                    $currentPath += "&cursor=$encodedCursor"
                }
                else {
                    $currentPath += "?cursor=$encodedCursor"
                }
                $pageNumber++
            }
            elseif ($data.nextUri) {
                $currentPath = $data.nextUri
                $pageNumber++
            }
            # Check for page number based pagination
            elseif ($data.pageCount -and $data.pageNumber) {
                if ($data.pageNumber -lt $data.pageCount) {
                    $nextPage = $data.pageNumber + 1
                    # Use helper function to safely update pageNumber parameter
                    $currentPath = Update-UrlParameter -Path $InitialPath -ParameterName "pageNumber" -ParameterValue $nextPage
                    $pageNumber++
                }
                else {
                    $continueLoop = $false
                }
            }
            else {
                # No pagination info found, this is the last page
                $continueLoop = $false
            }
        }
        catch {
            if ($ProgressCallback) {
                & $ProgressCallback -PageNumber $pageNumber -Status "Error on page $pageNumber : $($_.Exception.Message)" -IsError $true
            }
            throw
        }
    }

    if ($ProgressCallback) {
        & $ProgressCallback -PageNumber $pageNumber -Status "Completed - Retrieved $($allResults.Count) total results" -IsComplete $true
    }

    return $allResults
}

<#
.SYNOPSIS
    Generates a comprehensive conversation report by querying multiple API endpoints.
.DESCRIPTION
    Queries 6 different Genesys Cloud API endpoints to gather comprehensive conversation data:
    - Conversation Details (required)
    - Analytics Details (required)
    - Speech & Text Analytics (optional)
    - Recording Metadata (optional)
    - Sentiments (optional)
    - SIP Messages (optional)

    Reports progress via optional callback for real-time UI updates.
.PARAMETER ConversationId
    The conversation ID to retrieve data for
.PARAMETER Headers
    HTTP headers including authorization (Authorization: Bearer token)
.PARAMETER BaseUrl
    Base API URL for the region (e.g., https://api.usw2.pure.cloud)
.PARAMETER ProgressCallback
    Optional scriptblock called for each endpoint with parameters:
    -PercentComplete (int), -Status (string), -EndpointName (string),
    -IsStarting (bool), -IsSuccess (bool), -IsOptional (bool)
.OUTPUTS
    PSCustomObject with ConversationId, endpoint data properties, RetrievedAt, Errors array, and EndpointLog
#>
function Get-ConversationReport {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ConversationId,
        [Parameter(Mandatory = $true)]
        [hashtable]$Headers,
        [string]$BaseUrl = "https://api.mypurecloud.com",
        [scriptblock]$ProgressCallback = $null
    )

    # Define all endpoints to query
    $endpoints = @(
        @{ Name = "Conversation Details"; Path = "/api/v2/conversations/$ConversationId"; PropertyName = "ConversationDetails" }
        @{ Name = "Analytics Details"; Path = "/api/v2/analytics/conversations/$ConversationId/details"; PropertyName = "AnalyticsDetails" }
        @{ Name = "Speech & Text Analytics"; Path = "/api/v2/speechandtextanalytics/conversations/$ConversationId"; PropertyName = "SpeechTextAnalytics"; Optional = $true }
        @{ Name = "Recording Metadata"; Path = "/api/v2/conversations/$ConversationId/recordingmetadata"; PropertyName = "RecordingMetadata"; Optional = $true }
        @{ Name = "Sentiments"; Path = "/api/v2/speechandtextanalytics/conversations/$ConversationId/sentiments"; PropertyName = "Sentiments"; Optional = $true }
        @{ Name = "SIP Messages"; Path = "/api/v2/telephony/sipmessages/conversations/$ConversationId"; PropertyName = "SipMessages"; Optional = $true }
    )

    $result = [PSCustomObject]@{
        ConversationId      = $ConversationId
        ConversationDetails = $null
        AnalyticsDetails    = $null
        SpeechTextAnalytics = $null
        RecordingMetadata   = $null
        Sentiments          = $null
        SipMessages         = $null
        RetrievedAt         = (Get-Date).ToString("o")
        Errors              = @()
        EndpointLog         = [System.Collections.ArrayList]::new()
    }

    $totalEndpoints = $endpoints.Count
    $currentEndpoint = 0

    foreach ($endpoint in $endpoints) {
        $currentEndpoint++
        $percentComplete = [int](($currentEndpoint / $totalEndpoints) * 100)

        # Report progress if callback provided
        if ($ProgressCallback) {
            & $ProgressCallback -PercentComplete $percentComplete -Status "Querying: $($endpoint.Name)" -EndpointName $endpoint.Name -IsStarting $true
        }

        $url = "$BaseUrl$($endpoint.Path)"
        $logEntry = [PSCustomObject]@{
            Timestamp = (Get-Date).ToString("HH:mm:ss.fff")
            Endpoint  = $endpoint.Name
            Path      = $endpoint.Path
            Status    = "Pending"
            Message   = ""
        }

        try {
            $response = Invoke-GCRequest -Method GET -Uri $url -Headers $Headers -AsResponse
            $data = $response.Content | ConvertFrom-Json -ErrorAction SilentlyContinue
            $result.($endpoint.PropertyName) = $data

            $logEntry.Status = "Success"
            $logEntry.Message = "Retrieved successfully"

            if ($ProgressCallback) {
                & $ProgressCallback -PercentComplete $percentComplete -Status "$([char]0x2713) $($endpoint.Name)" -EndpointName $endpoint.Name -IsSuccess $true
            }
        }
        catch {
            $errorMessage = $_.Exception.Message
            if ($endpoint.Optional) {
                $logEntry.Status = "Optional - Not Available"
                $logEntry.Message = $errorMessage
            }
            else {
                $result.Errors += "$($endpoint.Name): $errorMessage"
                $logEntry.Status = "Failed"
                $logEntry.Message = $errorMessage
            }

            if ($ProgressCallback) {
                & $ProgressCallback -PercentComplete $percentComplete -Status "$([char]0x2717) $($endpoint.Name)" -EndpointName $endpoint.Name -IsSuccess $false -IsOptional $endpoint.Optional
            }
        }

        [void]$result.EndpointLog.Add($logEntry)
    }

    return $result
}

<#
.SYNOPSIS
    Extracts timeline events from analytics and conversation details.
.DESCRIPTION
    Parses both API responses and creates a unified list of events with timestamps,
    participant info, segment IDs, MOS scores, error codes, and event types.
#>
function Get-GCConversationDetailsTimeline {
    param (
        [Parameter(Mandatory = $true)]
        $Report
    )

    # Use ArrayList for efficient appending instead of array += which creates new arrays
    $events = [System.Collections.ArrayList]::new()
    $segmentCounter = 0

    # Extract events from analytics details (segments with MOS, errorCodes, etc.)
    if ($Report.AnalyticsDetails -and $Report.AnalyticsDetails.participants) {
        foreach ($participant in $Report.AnalyticsDetails.participants) {
            $participantName = if ($participant.participantName) { $participant.participantName } else { $participant.purpose }
            $participantId = $participant.participantId

            if ($participant.sessions) {
                foreach ($session in $participant.sessions) {
                    $mediaType = $session.mediaType
                    $direction = $session.direction
                    $ani = $session.ani
                    $dnis = $session.dnis
                    $sessionId = $session.sessionId

                    # Extract MOS from session-level mediaEndpointStats
                    # MOS is at the session level, not segment level
                    $sessionMos = $null
                    if ($session.mediaEndpointStats) {
                        foreach ($stat in $session.mediaEndpointStats) {
                            if ($stat.minMos) {
                                $sessionMos = $stat.minMos
                                break  # Use first available MOS value
                            }
                        }
                    }

                    if ($session.segments) {
                        foreach ($segment in $session.segments) {
                            $segmentCounter++
                            $segmentId = $segmentCounter
                            $segmentType = $segment.segmentType
                            $queueId = $segment.queueId
                            $flowId = $segment.flowId
                            $flowName = $segment.flowName
                            $queueName = $segment.queueName
                            $wrapUpCode = $segment.wrapUpCode
                            $wrapUpNote = $segment.wrapUpNote

                            # Extract error codes from segment
                            $errorCode = $null
                            if ($segment.errorCode) {
                                $errorCode = $segment.errorCode
                            }
                            # Also check for sipResponseCode as an error indicator
                            if ($segment.sipResponseCode -and -not $errorCode) {
                                $errorCode = "sip:$($segment.sipResponseCode)"
                            }

                            # Segment start event - parse with InvariantCulture for reliable ISO 8601 parsing
                            if ($segment.segmentStart) {
                                [void]$events.Add([PSCustomObject]@{
                                        Timestamp      = [DateTime]::Parse($segment.segmentStart, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
                                        Source         = "AnalyticsDetails"
                                        Participant    = $participantName
                                        ParticipantId  = $participantId
                                        SegmentId      = $segmentId
                                        EventType      = "SegmentStart"
                                        SegmentType    = $segmentType
                                        MediaType      = $mediaType
                                        Direction      = $direction
                                        QueueName      = $queueName
                                        FlowName       = $flowName
                                        Mos            = $sessionMos
                                        ErrorCode      = $errorCode
                                        Context        = "ANI: $ani, DNIS: $dnis"
                                        DisconnectType = $null
                                    })
                            }

                            # Segment end event - parse with InvariantCulture
                            if ($segment.segmentEnd) {
                                $disconnectType = $segment.disconnectType
                                [void]$events.Add([PSCustomObject]@{
                                        Timestamp      = [DateTime]::Parse($segment.segmentEnd, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
                                        Source         = "AnalyticsDetails"
                                        Participant    = $participantName
                                        ParticipantId  = $participantId
                                        SegmentId      = $segmentId
                                        EventType      = if ($disconnectType) { "Disconnect" } else { "SegmentEnd" }
                                        SegmentType    = $segmentType
                                        MediaType      = $mediaType
                                        Direction      = $direction
                                        QueueName      = $queueName
                                        FlowName       = $flowName
                                        Mos            = $sessionMos
                                        ErrorCode      = $errorCode
                                        Context        = if ($disconnectType) { "DisconnectType: $disconnectType" } else { $null }
                                        DisconnectType = $disconnectType
                                    })
                            }
                        }
                    }
                }
            }
        }
    }

    # Extract events from conversation details (state transitions, etc.)
    if ($Report.ConversationDetails -and $Report.ConversationDetails.participants) {
        foreach ($participant in $Report.ConversationDetails.participants) {
            $participantName = if ($participant.name) { $participant.name } else { $participant.purpose }
            $participantId = $participant.id

            # Start time event - parse with InvariantCulture
            if ($participant.startTime) {
                [void]$events.Add([PSCustomObject]@{
                        Timestamp      = [DateTime]::Parse($participant.startTime, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
                        Source         = "Conversations"
                        Participant    = $participantName
                        ParticipantId  = $participantId
                        SegmentId      = $null
                        EventType      = "ParticipantJoined"
                        SegmentType    = $null
                        MediaType      = $null
                        Direction      = $null
                        QueueName      = $null
                        FlowName       = $null
                        Mos            = $null
                        ErrorCode      = $null
                        Context        = "Purpose: $($participant.purpose)"
                        DisconnectType = $null
                    })
            }

            # End time / disconnect event - parse with InvariantCulture
            if ($participant.endTime) {
                $disconnectType = $participant.disconnectType
                [void]$events.Add([PSCustomObject]@{
                        Timestamp      = [DateTime]::Parse($participant.endTime, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
                        Source         = "Conversations"
                        Participant    = $participantName
                        ParticipantId  = $participantId
                        SegmentId      = $null
                        EventType      = if ($disconnectType) { "Disconnect" } else { "ParticipantLeft" }
                        SegmentType    = $null
                        MediaType      = $null
                        Direction      = $null
                        QueueName      = $null
                        FlowName       = $null
                        Mos            = $null
                        ErrorCode      = $null
                        Context        = if ($disconnectType) { "DisconnectType: $disconnectType" } else { $null }
                        DisconnectType = $disconnectType
                    })
            }

            # Process calls/chats for state changes
            if ($participant.calls) {
                foreach ($call in $participant.calls) {
                    if ($call.state -and $call.connectedTime) {
                        [void]$events.Add([PSCustomObject]@{
                                Timestamp      = [DateTime]::Parse($call.connectedTime, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
                                Source         = "Conversations"
                                Participant    = $participantName
                                ParticipantId  = $participantId
                                SegmentId      = $null
                                EventType      = "StateChange"
                                SegmentType    = $null
                                MediaType      = "voice"
                                Direction      = $call.direction
                                QueueName      = $null
                                FlowName       = $null
                                Mos            = $null
                                ErrorCode      = $null
                                Context        = "State: connected"
                                DisconnectType = $null
                            })
                    }
                    if ($call.disconnectedTime) {
                        [void]$events.Add([PSCustomObject]@{
                                Timestamp      = [DateTime]::Parse($call.disconnectedTime, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
                                Source         = "Conversations"
                                Participant    = $participantName
                                ParticipantId  = $participantId
                                SegmentId      = $null
                                EventType      = "Disconnect"
                                SegmentType    = $null
                                MediaType      = "voice"
                                Direction      = $call.direction
                                QueueName      = $null
                                FlowName       = $null
                                Mos            = $null
                                ErrorCode      = $null
                                Context        = "State: disconnected"
                                DisconnectType = $call.disconnectType
                            })
                    }
                }
            }

            # Process chats
            if ($participant.chats) {
                foreach ($chat in $participant.chats) {
                    if ($chat.state -and $chat.connectedTime) {
                        [void]$events.Add([PSCustomObject]@{
                                Timestamp      = [DateTime]::Parse($chat.connectedTime, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
                                Source         = "Conversations"
                                Participant    = $participantName
                                ParticipantId  = $participantId
                                SegmentId      = $null
                                EventType      = "StateChange"
                                SegmentType    = $null
                                MediaType      = "chat"
                                Direction      = $chat.direction
                                QueueName      = $null
                                FlowName       = $null
                                Mos            = $null
                                ErrorCode      = $null
                                Context        = "State: connected"
                                DisconnectType = $null
                            })
                    }
                    if ($chat.disconnectedTime) {
                        [void]$events.Add([PSCustomObject]@{
                                Timestamp      = [DateTime]::Parse($chat.disconnectedTime, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
                                Source         = "Conversations"
                                Participant    = $participantName
                                ParticipantId  = $participantId
                                SegmentId      = $null
                                EventType      = "Disconnect"
                                SegmentType    = $null
                                MediaType      = "chat"
                                Direction      = $chat.direction
                                QueueName      = $null
                                FlowName       = $null
                                Mos            = $null
                                ErrorCode      = $null
                                Context        = "State: disconnected"
                                DisconnectType = $chat.disconnectType
                            })
                    }
                }
            }
        }
    }

    # Extract events from SIP messages if available
    if ($Report.SipMessages) {
        foreach ($msg in $Report.SipMessages) {
            if ($msg.timestamp) {
                # Build error information from SIP status codes and reason phrases
                # Only include status codes that indicate errors (4xx, 5xx, 6xx)
                $sipErrorInfo = $null
                if ($msg.statusCode -and $msg.statusCode -ge 400) {
                    $sipErrorInfo = "SIP $($msg.statusCode)"
                    if ($msg.reasonPhrase -and -not [string]::IsNullOrWhiteSpace($msg.reasonPhrase)) {
                        $sipErrorInfo += ": $($msg.reasonPhrase)"
                    }
                }

                [void]$events.Add([PSCustomObject]@{
                        Timestamp      = [DateTime]::Parse($msg.timestamp, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
                        Source         = "SIP"
                        Participant    = $msg.participantId
                        ParticipantId  = $msg.participantId
                        SegmentId      = $null
                        EventType      = "SIP_$($msg.method)"
                        SegmentType    = $null
                        MediaType      = "voice"
                        Direction      = $msg.direction
                        QueueName      = $null
                        FlowName       = $null
                        Mos            = $null
                        ErrorCode      = $sipErrorInfo
                        Context        = $msg.method
                        DisconnectType = $null
                    })
            }
        }
    }

    # Extract events from speech & text analytics if available
    if ($Report.SpeechTextAnalytics -and $Report.SpeechTextAnalytics.conversation) {
        $convStart = $null
        if ($Report.SpeechTextAnalytics.conversation.startTime) {
            $convStart = [DateTime]::Parse($Report.SpeechTextAnalytics.conversation.startTime, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
        }

        if ($Report.SpeechTextAnalytics.conversation.topics) {
            foreach ($topic in $Report.SpeechTextAnalytics.conversation.topics) {
                [void]$events.Add([PSCustomObject]@{
                        Timestamp      = $convStart
                        Source         = "SpeechText"
                        Participant    = $null
                        ParticipantId  = $null
                        SegmentId      = $null
                        EventType      = "Topic"
                        SegmentType    = $null
                        MediaType      = $null
                        Direction      = $null
                        QueueName      = $null
                        FlowName       = $null
                        Mos            = $null
                        ErrorCode      = $null
                        Context        = "Topic: $($topic.name)"
                        DisconnectType = $null
                    })
            }
        }
    }

    # Extract events from sentiment analysis if available
    if ($Report.Sentiments -and $Report.Sentiments.sentiment) {
        foreach ($sentiment in $Report.Sentiments.sentiment) {
            if ($sentiment.time) {
                [void]$events.Add([PSCustomObject]@{
                        Timestamp      = [DateTime]::Parse($sentiment.time, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
                        Source         = "Sentiment"
                        Participant    = $sentiment.participantId
                        ParticipantId  = $sentiment.participantId
                        SegmentId      = $null
                        EventType      = "SentimentSample"
                        SegmentType    = $null
                        MediaType      = $null
                        Direction      = $null
                        QueueName      = $null
                        FlowName       = $null
                        Mos            = $null
                        ErrorCode      = $null
                        Context        = "Sentiment: $($sentiment.label) ($($sentiment.score))"
                        DisconnectType = $null
                    })
            }
        }
    }

    # Extract events from recording metadata if available
    if ($Report.RecordingMetadata) {
        foreach ($rec in $Report.RecordingMetadata) {
            if ($rec.startTime) {
                [void]$events.Add([PSCustomObject]@{
                        Timestamp      = [DateTime]::Parse($rec.startTime, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
                        Source         = "Recording"
                        Participant    = $rec.participantId
                        ParticipantId  = $rec.participantId
                        SegmentId      = $null
                        EventType      = "RecordingStart"
                        SegmentType    = $null
                        MediaType      = $null
                        Direction      = $null
                        QueueName      = $null
                        FlowName       = $null
                        Mos            = $null
                        ErrorCode      = $null
                        Context        = "Recording ID: $($rec.id)"
                        DisconnectType = $null
                    })
            }
            if ($rec.endTime) {
                [void]$events.Add([PSCustomObject]@{
                        Timestamp      = [DateTime]::Parse($rec.endTime, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
                        Source         = "Recording"
                        Participant    = $rec.participantId
                        ParticipantId  = $rec.participantId
                        SegmentId      = $null
                        EventType      = "RecordingEnd"
                        SegmentType    = $null
                        MediaType      = $null
                        Direction      = $null
                        QueueName      = $null
                        FlowName       = $null
                        Mos            = $null
                        ErrorCode      = $null
                        Context        = "Recording ID: $($rec.id)"
                        DisconnectType = $null
                    })
            }
        }
    }

    return $events
}

<#
.SYNOPSIS
    Merges and sorts conversation events chronologically.
.DESCRIPTION
    Takes events from Get-GCConversationDetailsTimeline and sorts them by timestamp
    to create a unified, chronological view of the conversation.
#>
function Merge-GCConversationEvents {
    param (
        [Parameter(Mandatory = $true)]
        [array]$Events
    )

    # Sort events by timestamp ascending
    $sortedEvents = $Events | Sort-Object -Property Timestamp

    return $sortedEvents
}

<#
.SYNOPSIS
    Formats the chronological timeline as text output.
.DESCRIPTION
    Creates a text-based timeline with each event on a line showing timestamp,
    event type, participant, segment ID, MOS score, and error code.
#>

function Format-GCConversationTimelineText {
    param (
        [Parameter(Mandatory = $true)]
        [array]$Events
    )

    $sb = [System.Text.StringBuilder]::new()

    foreach ($timelineEvent in $Events) {
        $timestamp = $timelineEvent.Timestamp.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssK')
        $eventType = $timelineEvent.EventType.PadRight(18)

        $participantStr = ''
        if ($timelineEvent.FlowName) {
            $participantStr = 'Flow: ' + $timelineEvent.FlowName
        }
        elseif ($timelineEvent.QueueName) {
            $participantStr = 'Queue: ' + $timelineEvent.QueueName
        }
        elseif ($timelineEvent.Participant) {
            $participantStr = $timelineEvent.Participant
        }
        else {
            $participantStr = '(unknown)'
        }

        $segmentStr = if ($timelineEvent.SegmentId) { 'seg=' + $timelineEvent.SegmentId } else { '' }

        $mediaStr = ''
        if ($timelineEvent.MediaType -or $timelineEvent.Direction) {
            $parts = @()
            if ($timelineEvent.MediaType) { $parts += 'media=' + $timelineEvent.MediaType }
            if ($timelineEvent.Direction) { $parts += 'dir=' + $timelineEvent.Direction }
            $mediaStr = $parts -join ' | '
        }

        $mosStr = ''
        if ($null -ne $timelineEvent.Mos) {
            $mosValue = 0.0
            if ([double]::TryParse($timelineEvent.Mos.ToString(), [ref]$mosValue)) {
                if ($mosValue -lt 3.5) {
                    $mosStr = 'MOS=' + $mosValue.ToString('0.00') + ' (DEGRADED)'
                }
                else {
                    $mosStr = 'MOS=' + $mosValue.ToString('0.00')
                }
            }
        }

        $errorStr = if ($timelineEvent.ErrorCode) { 'errorCode=' + $timelineEvent.ErrorCode } else { '' }

        $disconnectStr = ''
        if ($timelineEvent.EventType -eq 'Disconnect' -and $timelineEvent.DisconnectType) {
            $disconnectStr = $timelineEvent.Participant + ' disconnected (' + $timelineEvent.DisconnectType + ')'
        }

        $lineParts = @($timestamp, '|', $eventType, '|', $participantStr)
        if ($segmentStr) { $lineParts += '| ' + $segmentStr }
        if ($mediaStr) { $lineParts += '| ' + $mediaStr }
        if ($mosStr) { $lineParts += '| ' + $mosStr }
        if ($errorStr) { $lineParts += '| ' + $errorStr }
        if ($disconnectStr) { $lineParts += '| ' + $disconnectStr }

        $line = $lineParts -join ' '
        [void]$sb.AppendLine($line.Trim())
    }

    return $sb.ToString()
}

<#
.SYNOPSIS
    Generates a summary of degraded segments and disconnects.
.DESCRIPTION
    Analyzes the timeline events to produce summary statistics including
    total segments, segments with MOS values, degraded segments (MOS < 3.5),
    and all disconnect events.
#>
function Get-GCConversationSummary {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ConversationId,
        [Parameter(Mandatory = $true)]
        [array]$Events
    )

    # Count segments (SegmentEnd events contain the final MOS)
    $segmentEndEvents = $Events | Where-Object { $_.EventType -eq "SegmentEnd" -or ($_.EventType -eq "Disconnect" -and $_.SegmentId) }
    $segmentStartEvents = $Events | Where-Object { $_.EventType -eq "SegmentStart" }

    $totalSegments = ($segmentStartEvents | Measure-Object).Count

    # Get segments with MOS values
    $segmentsWithMos = $segmentEndEvents | Where-Object { $null -ne $_.Mos }
    $segmentsWithMosCount = ($segmentsWithMos | Measure-Object).Count

    # Get degraded segments (MOS < 3.5) - use TryParse for safe conversion
    $degradedSegments = $segmentsWithMos | Where-Object {
        $mosValue = 0.0
        if ([double]::TryParse($_.Mos.ToString(), [ref]$mosValue)) {
            return $mosValue -lt 3.5
        }
        return $false
    }
    $degradedCount = ($degradedSegments | Measure-Object).Count

    # Get all disconnect events
    $disconnectEvents = $Events | Where-Object { $_.EventType -eq "Disconnect" }

    # Build segment details lookup (start times)
    $segmentDetails = @{}
    foreach ($startEvent in $segmentStartEvents) {
        if ($startEvent.SegmentId) {
            $segmentDetails[$startEvent.SegmentId] = $startEvent
        }
    }

    return [PSCustomObject]@{
        ConversationId       = $ConversationId
        TotalSegments        = $totalSegments
        SegmentsWithMos      = $segmentsWithMosCount
        DegradedSegmentCount = $degradedCount
        DegradedSegments     = $degradedSegments
        DisconnectEvents     = $disconnectEvents
        SegmentDetails       = $segmentDetails
    }
}

<#
.SYNOPSIS
    Formats the conversation summary as text output.
.DESCRIPTION
    Creates a text block with summary statistics and lists of degraded
    segments and disconnect events.
#>
function Format-GCConversationSummaryText {
    param (
        [Parameter(Mandatory = $true)]
        $Summary
    )

    $sb = [System.Text.StringBuilder]::new()

    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("=" * 50 + " Summary " + "=" * 50)
    [void]$sb.AppendLine("ConversationId: $($Summary.ConversationId)")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("Segments:          $($Summary.TotalSegments)")
    [void]$sb.AppendLine("Segments with MOS: $($Summary.SegmentsWithMos)")
    [void]$sb.AppendLine("Degraded segments (MOS less than 3.5): $($Summary.DegradedSegmentCount)")
    [void]$sb.AppendLine("")

    # List degraded segments
    if ($Summary.DegradedSegments -and ($Summary.DegradedSegments | Measure-Object).Count -gt 0) {
        [void]$sb.AppendLine("Degraded segments:")
        foreach ($seg in $Summary.DegradedSegments) {
            $startInfo = $Summary.SegmentDetails[$seg.SegmentId]
            $startTime = if ($startInfo) { $startInfo.Timestamp.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssK") } else { "(unknown)" }
            $endTime = $seg.Timestamp.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssK")

            $participantStr = if ($seg.QueueName) { "Queue: $($seg.QueueName)" } `
                elseif ($seg.FlowName) { "Flow: $($seg.FlowName)" } `
                elseif ($seg.Participant) { $seg.Participant } `
                else { "(unknown)" }

            # Use TryParse for safe MOS value conversion
            $mosValue = 0.0
            [void][double]::TryParse($seg.Mos.ToString(), [ref]$mosValue)
            $errorStr = if ($seg.ErrorCode) { "errorCode=$($seg.ErrorCode)" } else { "errorCode=" }

            [void]$sb.AppendLine("  - seg=$($seg.SegmentId) | $participantStr | MOS=$($mosValue.ToString('0.00')) | $startTime-$endTime | $errorStr")
        }
        [void]$sb.AppendLine("")
    }

    # List disconnect events
    if ($Summary.DisconnectEvents -and ($Summary.DisconnectEvents | Measure-Object).Count -gt 0) {
        [void]$sb.AppendLine("Disconnects:")
        foreach ($disc in $Summary.DisconnectEvents) {
            $timestamp = $disc.Timestamp.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssK")
            $segStr = if ($disc.SegmentId) { "seg=$($disc.SegmentId)" } else { "(no segment)" }
            $disconnector = if ($disc.DisconnectType) { "$($disc.Participant) disconnected ($($disc.DisconnectType))" } else { "$($disc.Participant) disconnected" }
            $errorStr = if ($disc.ErrorCode) { "errorCode=$($disc.ErrorCode)" } else { "errorCode=" }

            [void]$sb.AppendLine("  - $timestamp | $segStr | $disconnector | $errorStr")
        }
        [void]$sb.AppendLine("")
    }

    [void]$sb.AppendLine("=" * 109)

    return $sb.ToString()
}

<#
.SYNOPSIS
    Calculates duration statistics from conversation events and analytics data.
.DESCRIPTION
    Computes total duration, IVR time, queue wait time, agent talk time, hold time,
    wrap-up time, and other timing metrics from the conversation data.
#>
function Get-GCConversationDurationAnalysis {
    param (
        [Parameter(Mandatory = $true)]
        $Report,
        [Parameter(Mandatory = $true)]
        [array]$Events
    )

    $analysis = [PSCustomObject]@{
        TotalDurationSeconds = 0
        IvrTimeSeconds       = 0
        QueueWaitSeconds     = 0
        AgentTalkSeconds     = 0
        HoldTimeSeconds      = 0
        WrapUpSeconds        = 0
        ConferenceSeconds    = 0
        SystemTimeSeconds    = 0
        InteractTimeSeconds  = 0
        AlertTimeSeconds     = 0
        ConversationStart    = $null
        ConversationEnd      = $null
        SegmentBreakdown     = @{}
    }

    # Get conversation start/end times from analytics or conversation details
    if ($Report.AnalyticsDetails) {
        if ($Report.AnalyticsDetails.conversationStart) {
            $analysis.ConversationStart = [DateTime]::Parse($Report.AnalyticsDetails.conversationStart, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
        }
        if ($Report.AnalyticsDetails.conversationEnd) {
            $analysis.ConversationEnd = [DateTime]::Parse($Report.AnalyticsDetails.conversationEnd, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
        }
    }

    # Calculate total duration
    if ($analysis.ConversationStart -and $analysis.ConversationEnd) {
        $analysis.TotalDurationSeconds = ($analysis.ConversationEnd - $analysis.ConversationStart).TotalSeconds
    }

    # Process segments from analytics to extract timing metrics
    if ($Report.AnalyticsDetails -and $Report.AnalyticsDetails.participants) {
        foreach ($participant in $Report.AnalyticsDetails.participants) {
            if ($participant.sessions) {
                foreach ($session in $participant.sessions) {
                    # Extract metrics from session if available
                    if ($session.metrics) {
                        foreach ($metric in $session.metrics) {
                            # Metrics are typically in milliseconds
                            $valueSeconds = if ($metric.value) { $metric.value / 1000.0 } else { 0 }
                            # Note: "Complete" metrics are cumulative totals; regular metrics may be emitted multiple times
                            # For talk/held, we use the "Complete" values when available as they represent totals
                            switch ($metric.name) {
                                "tIvr" { $analysis.IvrTimeSeconds += $valueSeconds }
                                "tAcd" { $analysis.QueueWaitSeconds += $valueSeconds }
                                "tTalk" {
                                    # Regular tTalk may be emitted multiple times; track the max as a fallback
                                    $analysis.AgentTalkSeconds = [Math]::Max($analysis.AgentTalkSeconds, $valueSeconds)
                                }
                                "tTalkComplete" {
                                    # Complete value is the authoritative total
                                    $analysis.AgentTalkSeconds = [Math]::Max($analysis.AgentTalkSeconds, $valueSeconds)
                                }
                                "tHeld" {
                                    # Regular tHeld may be emitted multiple times; track the max as a fallback
                                    $analysis.HoldTimeSeconds = [Math]::Max($analysis.HoldTimeSeconds, $valueSeconds)
                                }
                                "tHeldComplete" {
                                    # Complete value is the authoritative total
                                    $analysis.HoldTimeSeconds = [Math]::Max($analysis.HoldTimeSeconds, $valueSeconds)
                                }
                                "tAcw" { $analysis.WrapUpSeconds += $valueSeconds }
                                "tAlert" { $analysis.AlertTimeSeconds += $valueSeconds }
                            }
                        }
                    }

                    # Calculate segment-based timing
                    if ($session.segments) {
                        foreach ($segment in $session.segments) {
                            if ($segment.segmentStart -and $segment.segmentEnd) {
                                $start = [DateTime]::Parse($segment.segmentStart, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
                                $end = [DateTime]::Parse($segment.segmentEnd, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
                                $durationSec = ($end - $start).TotalSeconds

                                $segType = if ($segment.segmentType) { $segment.segmentType } else { "unknown" }
                                if (-not $analysis.SegmentBreakdown.ContainsKey($segType)) {
                                    $analysis.SegmentBreakdown[$segType] = 0
                                }
                                $analysis.SegmentBreakdown[$segType] += $durationSec

                                switch ($segType) {
                                    "interact" { $analysis.InteractTimeSeconds += $durationSec }
                                    "hold" { $analysis.HoldTimeSeconds += $durationSec }
                                    "system" { $analysis.SystemTimeSeconds += $durationSec }
                                    "ivr" { $analysis.IvrTimeSeconds += $durationSec }
                                    "wrapup" { $analysis.WrapUpSeconds += $durationSec }
                                    "alert" { $analysis.AlertTimeSeconds += $durationSec }
                                }

                                if ($segment.conference -eq $true) {
                                    $analysis.ConferenceSeconds += $durationSec
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    return $analysis
}

<#
.SYNOPSIS
    Generates participant statistics from conversation data.
.DESCRIPTION
    Calculates per-participant metrics including time in conversation,
    segment counts, and role-specific information.
#>
function Get-GCParticipantStatistics {
    param (
        [Parameter(Mandatory = $true)]
        $Report
    )

    $stats = [System.Collections.ArrayList]::new()

    if ($Report.AnalyticsDetails -and $Report.AnalyticsDetails.participants) {
        foreach ($participant in $Report.AnalyticsDetails.participants) {
            $participantName = if ($participant.participantName) { $participant.participantName } else { $participant.purpose }
            $purpose = $participant.purpose

            $participantStat = [PSCustomObject]@{
                Name                 = $participantName
                ParticipantId        = $participant.participantId
                Purpose              = $purpose
                SessionCount         = 0
                SegmentCount         = 0
                TotalDurationSeconds = 0
                MediaTypes           = [System.Collections.ArrayList]::new()
                DisconnectType       = $null
                HasErrors            = $false
                ErrorCodes           = [System.Collections.ArrayList]::new()
                MosScores            = [System.Collections.ArrayList]::new()
                FlowNames            = [System.Collections.ArrayList]::new()
                QueueNames           = [System.Collections.ArrayList]::new()
                HasRecording         = $false
                Providers            = [System.Collections.ArrayList]::new()
                RemoteName           = $null
                ANI                  = $null
                DNIS                 = $null
            }

            if ($participant.sessions) {
                $participantStat.SessionCount = $participant.sessions.Count

                foreach ($session in $participant.sessions) {
                    if ($session.mediaType -and $participantStat.MediaTypes -notcontains $session.mediaType) {
                        [void]$participantStat.MediaTypes.Add($session.mediaType)
                    }

                    # Extract recording info
                    if ($session.recording -eq $true) {
                        $participantStat.HasRecording = $true
                    }

                    # Extract provider info
                    if ($session.provider -and $participantStat.Providers -notcontains $session.provider) {
                        [void]$participantStat.Providers.Add($session.provider)
                    }

                    # Extract remote party name
                    if ($session.remoteNameDisplayable -and -not $participantStat.RemoteName) {
                        $participantStat.RemoteName = $session.remoteNameDisplayable
                    }

                    # Extract ANI/DNIS
                    if ($session.ani -and -not $participantStat.ANI) {
                        $participantStat.ANI = $session.ani
                    }
                    if ($session.dnis -and -not $participantStat.DNIS) {
                        $participantStat.DNIS = $session.dnis
                    }

                    # Extract flow info
                    if ($session.flow -and $session.flow.flowName) {
                        if ($participantStat.FlowNames -notcontains $session.flow.flowName) {
                            [void]$participantStat.FlowNames.Add($session.flow.flowName)
                        }
                    }

                    if ($session.segments) {
                        $participantStat.SegmentCount += $session.segments.Count

                        foreach ($segment in $session.segments) {
                            # Calculate segment duration
                            if ($segment.segmentStart -and $segment.segmentEnd) {
                                $start = [DateTime]::Parse($segment.segmentStart, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
                                $end = [DateTime]::Parse($segment.segmentEnd, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
                                $participantStat.TotalDurationSeconds += ($end - $start).TotalSeconds
                            }

                            # Track disconnect type
                            if ($segment.disconnectType -and -not $participantStat.DisconnectType) {
                                $participantStat.DisconnectType = $segment.disconnectType
                            }

                            # Track errors
                            if ($segment.errorCode) {
                                $participantStat.HasErrors = $true
                                if ($participantStat.ErrorCodes -notcontains $segment.errorCode) {
                                    [void]$participantStat.ErrorCodes.Add($segment.errorCode)
                                }
                            }

                            # Track queue names
                            if ($segment.queueId) {
                                # Note: queueId would need lookup for actual name
                                if ($participantStat.QueueNames -notcontains $segment.queueId) {
                                    [void]$participantStat.QueueNames.Add($segment.queueId)
                                }
                            }
                        }
                    }

                    # Track MOS from media endpoint stats
                    if ($session.mediaEndpointStats) {
                        foreach ($stat in $session.mediaEndpointStats) {
                            if ($stat.minMos) {
                                [void]$participantStat.MosScores.Add($stat.minMos)
                            }
                        }
                    }
                }
            }

            [void]$stats.Add($participantStat)
        }
    }

    return $stats
}

<#
.SYNOPSIS
    Analyzes the conversation flow and path.
.DESCRIPTION
    Creates a visual representation of the conversation path showing
    how the call moved between IVR, queues, agents, and external parties.
#>
function Get-GCConversationFlowPath {
    param (
        [Parameter(Mandatory = $true)]
        $Report
    )

    $flowPath = [System.Collections.ArrayList]::new()

    if ($Report.AnalyticsDetails -and $Report.AnalyticsDetails.participants) {
        # Sort participants by their first segment start time
        $participantOrder = @()
        foreach ($participant in $Report.AnalyticsDetails.participants) {
            $earliestTime = $null
            if ($participant.sessions) {
                foreach ($session in $participant.sessions) {
                    if ($session.segments) {
                        foreach ($segment in $session.segments) {
                            if ($segment.segmentStart) {
                                $segTime = [DateTime]::Parse($segment.segmentStart, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
                                if (-not $earliestTime -or $segTime -lt $earliestTime) {
                                    $earliestTime = $segTime
                                }
                            }
                        }
                    }
                }
            }
            $participantOrder += [PSCustomObject]@{
                Participant = $participant
                StartTime   = $earliestTime
            }
        }

        $sortedParticipants = $participantOrder | Sort-Object -Property StartTime

        foreach ($entry in $sortedParticipants) {
            $participant = $entry.Participant
            $participantName = if ($participant.participantName) { $participant.participantName } else { $participant.purpose }
            $purpose = $participant.purpose

            $flowStep = [PSCustomObject]@{
                Order        = $flowPath.Count + 1
                Name         = $participantName
                Purpose      = $purpose
                StartTime    = $entry.StartTime
                FlowName     = $null
                TransferType = $null
                TransferTo   = $null
            }

            # Get flow info and transfer details
            if ($participant.sessions) {
                foreach ($session in $participant.sessions) {
                    if ($session.flow) {
                        $flowStep.FlowName = $session.flow.flowName
                        $flowStep.TransferType = $session.flow.transferType
                        $flowStep.TransferTo = $session.flow.transferTargetName
                    }
                }
            }

            [void]$flowPath.Add($flowStep)
        }
    }

    return $flowPath
}

<#
.SYNOPSIS
    Generates key insights from the conversation analysis.
.DESCRIPTION
    Analyzes all conversation data to produce actionable insights and
    highlights about quality issues, timing anomalies, and patterns.
#>
function Get-GCConversationKeyInsights {
    param (
        [Parameter(Mandatory = $true)]
        $Report,
        [Parameter(Mandatory = $true)]
        $DurationAnalysis,
        [Parameter(Mandatory = $true)]
        $ParticipantStats,
        [Parameter(Mandatory = $true)]
        $Summary
    )

    $insights = [System.Collections.ArrayList]::new()

    # Insight: Overall quality assessment
    $minMos = $null
    if ($Report.AnalyticsDetails -and $Report.AnalyticsDetails.mediaStatsMinConversationMos) {
        $minMos = $Report.AnalyticsDetails.mediaStatsMinConversationMos
        if ($minMos -lt 3.0) {
            [void]$insights.Add([PSCustomObject]@{
                    Category = "CRITICAL"
                    Type     = "Quality"
                    Message  = "Very poor voice quality detected (MOS: $([Math]::Round($minMos, 2))). Call likely had significant audio issues."
                })
        }
        elseif ($minMos -lt 3.5) {
            [void]$insights.Add([PSCustomObject]@{
                    Category = "WARNING"
                    Type     = "Quality"
                    Message  = "Below-average voice quality detected (MOS: $([Math]::Round($minMos, 2))). Some audio degradation may have occurred."
                })
        }
        elseif ($minMos -ge 4.0) {
            [void]$insights.Add([PSCustomObject]@{
                    Category = "OK"
                    Type     = "Quality"
                    Message  = "Good voice quality maintained throughout (MOS: $([Math]::Round($minMos, 2)))."
                })
        }
    }

    # Insight: Long hold times
    if ($DurationAnalysis.HoldTimeSeconds -gt 300) {
        [void]$insights.Add([PSCustomObject]@{
                Category = "WARNING"
                Type     = "Experience"
                Message  = "Extended hold time detected ($([Math]::Round($DurationAnalysis.HoldTimeSeconds / 60, 1)) minutes). Customer may have experienced frustration."
            })
    }

    # Insight: Long IVR time
    if ($DurationAnalysis.IvrTimeSeconds -gt 180) {
        [void]$insights.Add([PSCustomObject]@{
                Category = "INFO"
                Type     = "Flow"
                Message  = "Extended IVR navigation ($([Math]::Round($DurationAnalysis.IvrTimeSeconds / 60, 1)) minutes). Consider reviewing IVR flow complexity."
            })
    }

    # Insight: Multiple transfers
    $transferCount = 0
    foreach ($stat in $ParticipantStats) {
        if ($stat.Purpose -eq "agent" -or $stat.Purpose -eq "acd") {
            $transferCount++
        }
    }
    if ($transferCount -gt 2) {
        [void]$insights.Add([PSCustomObject]@{
                Category = "WARNING"
                Type     = "Flow"
                Message  = "Multiple transfers occurred ($transferCount agent/queue handoffs). Customer experience may be affected."
            })
    }

    # Insight: Error conditions
    $hasErrors = $false
    $errorTypes = [System.Collections.ArrayList]::new()
    foreach ($stat in $ParticipantStats) {
        if ($stat.HasErrors) {
            $hasErrors = $true
            foreach ($err in $stat.ErrorCodes) {
                if ($errorTypes -notcontains $err) {
                    [void]$errorTypes.Add($err)
                }
            }
        }
    }
    if ($hasErrors) {
        [void]$insights.Add([PSCustomObject]@{
                Category = "WARNING"
                Type     = "Error"
                Message  = "Technical errors occurred during the conversation: $($errorTypes -join ', ')"
            })
    }

    # Insight: Abnormal disconnect
    $abnormalDisconnects = @("error", "system", "timeout")
    foreach ($stat in $ParticipantStats) {
        if ($null -ne $stat.DisconnectType -and $stat.DisconnectType -ne "" -and $abnormalDisconnects -contains $stat.DisconnectType.ToLower()) {
            [void]$insights.Add([PSCustomObject]@{
                    Category = "WARNING"
                    Type     = "Disconnect"
                    Message  = "$($stat.Name) disconnected abnormally ($($stat.DisconnectType)). May indicate technical issue."
                })
        }
    }

    # Insight: Conference call
    if ($DurationAnalysis.ConferenceSeconds -gt 0) {
        [void]$insights.Add([PSCustomObject]@{
                Category = "INFO"
                Type     = "Flow"
                Message  = "Conference call included ($([Math]::Round($DurationAnalysis.ConferenceSeconds / 60, 1)) minutes with multiple parties)."
            })
    }

    # Insight: Long total duration
    if ($DurationAnalysis.TotalDurationSeconds -gt 3600) {
        [void]$insights.Add([PSCustomObject]@{
                Category = "INFO"
                Type     = "Duration"
                Message  = "Extended conversation duration ($([Math]::Round($DurationAnalysis.TotalDurationSeconds / 60, 0)) minutes). May require follow-up review."
            })
    }

    # Insight: Short conversation (might be abandoned)
    if ($DurationAnalysis.TotalDurationSeconds -gt 0 -and $DurationAnalysis.TotalDurationSeconds -lt 30) {
        [void]$insights.Add([PSCustomObject]@{
                Category = "INFO"
                Type     = "Duration"
                Message  = "Very short conversation ($([Math]::Round($DurationAnalysis.TotalDurationSeconds, 0)) seconds). May indicate abandoned call or quick resolution."
            })
    }

    # Add a general quality rating
    $qualityRating = "Unknown"
    $ratingScore = 0

    # Score calculation based on various factors
    if ($minMos) {
        if ($minMos -ge 4.0) { $ratingScore += 3 }
        elseif ($minMos -ge 3.5) { $ratingScore += 2 }
        elseif ($minMos -ge 3.0) { $ratingScore += 1 }
    }
    if ($DurationAnalysis.HoldTimeSeconds -lt 60) { $ratingScore += 1 }
    if ($transferCount -le 1) { $ratingScore += 1 }
    if (-not $hasErrors) { $ratingScore += 2 }

    if ($ratingScore -ge 6) { $qualityRating = "Excellent" }
    elseif ($ratingScore -ge 4) { $qualityRating = "Good" }
    elseif ($ratingScore -ge 2) { $qualityRating = "Fair" }
    else { $qualityRating = "Needs Review" }

    [void]$insights.Insert(0, [PSCustomObject]@{
            Category = "OVERALL"
            Type     = "Rating"
            Message  = "Overall Quality: $qualityRating (Score: $ratingScore/8)"
        })

    return $insights
}

<#
.SYNOPSIS
    Provides human-readable explanations for common error codes.
.DESCRIPTION
    Maps Genesys Cloud error codes to user-friendly descriptions
    and potential resolution steps.
#>
function Get-GCErrorExplanation {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ErrorCode
    )

    $explanations = @{
        "error.ininedgecontrol.session.inactive"               = "Session became inactive, possibly due to network issues or timeout."
        "error.ininedgecontrol.connection.media.endpoint.idle" = "Media endpoint went idle, often due to prolonged silence or network dropout."
        "sip:400"                                              = "Bad Request - The SIP request was malformed or invalid."
        "sip:403"                                              = "Forbidden - The request was understood but refused."
        "sip:404"                                              = "Not Found - The requested resource could not be found."
        "sip:408"                                              = "Request Timeout - The server timed out waiting for the request."
        "sip:410"                                              = "Gone - The resource is no longer available (often indicates transfer completion)."
        "sip:480"                                              = "Temporarily Unavailable - The callee is currently unavailable."
        "sip:486"                                              = "Busy Here - The callee is busy."
        "sip:487"                                              = "Request Terminated - The request was terminated by a BYE or CANCEL."
        "sip:500"                                              = "Server Internal Error - An internal server error occurred."
        "sip:502"                                              = "Bad Gateway - The gateway received an invalid response."
        "sip:503"                                              = "Service Unavailable - The service is temporarily unavailable."
        "sip:504"                                              = "Gateway Timeout - The gateway timed out."
        "network.packetloss"                                   = "Network packet loss detected, causing audio quality degradation."
        "network.jitter"                                       = "Network jitter detected, causing inconsistent audio delivery."
    }

    if ($explanations.ContainsKey($ErrorCode)) {
        return $explanations[$ErrorCode]
    }

    # Try partial match for error codes
    foreach ($key in $explanations.Keys) {
        if ($ErrorCode -like "*$key*") {
            return $explanations[$key]
        }
    }

    return "Unknown error condition. Review system logs for details."
}

<#
.SYNOPSIS
    Formats the key insights section for the report.
.DESCRIPTION
    Creates a formatted text block with categorized insights
    that appears at the top of the report for quick review.
#>
function Format-GCKeyInsightsText {
    param (
        [Parameter(Mandatory = $true)]
        [array]$Insights
    )

    $sb = [System.Text.StringBuilder]::new()

    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("*" * 60)
    [void]$sb.AppendLine("KEY INSIGHTS")
    [void]$sb.AppendLine("*" * 60)
    [void]$sb.AppendLine("")

    foreach ($insight in $Insights) {
        $icon = switch ($insight.Category) {
            "CRITICAL" { "[!!!]" }
            "WARNING" { "[!]  " }
            "INFO" { "[i]  " }
            "OK" { "[OK] " }
            "OVERALL" { "[*]  " }
            default { "     " }
        }
        [void]$sb.AppendLine("$icon $($insight.Message)")
    }

    [void]$sb.AppendLine("")

    return $sb.ToString()
}

<#
.SYNOPSIS
    Formats the duration analysis section for the report.
.DESCRIPTION
    Creates a formatted text block showing timing breakdown
    with easy-to-read duration values.
#>
function Format-GCDurationAnalysisText {
    param (
        [Parameter(Mandatory = $true)]
        $Analysis
    )

    $sb = [System.Text.StringBuilder]::new()

    # Helper function to format seconds as human-readable duration
    function Format-Duration {
        param ([double]$Seconds)
        if ($Seconds -lt 60) {
            return "$([Math]::Round($Seconds, 0))s"
        }
        elseif ($Seconds -lt 3600) {
            $mins = [Math]::Floor($Seconds / 60)
            $secs = [Math]::Round($Seconds % 60, 0)
            return "${mins}m ${secs}s"
        }
        else {
            $hours = [Math]::Floor($Seconds / 3600)
            $mins = [Math]::Floor(($Seconds % 3600) / 60)
            return "${hours}h ${mins}m"
        }
    }

    [void]$sb.AppendLine("-" * 40)
    [void]$sb.AppendLine("DURATION ANALYSIS")
    [void]$sb.AppendLine("-" * 40)
    [void]$sb.AppendLine("")

    if ($Analysis.ConversationStart -and $Analysis.ConversationEnd) {
        [void]$sb.AppendLine("Start: $($Analysis.ConversationStart.ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')) UTC")
        [void]$sb.AppendLine("End:   $($Analysis.ConversationEnd.ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')) UTC")
        [void]$sb.AppendLine("")
    }

    [void]$sb.AppendLine("Timing Breakdown:")
    [void]$sb.AppendLine("  Total Duration:   $(Format-Duration $Analysis.TotalDurationSeconds)")

    if ($Analysis.IvrTimeSeconds -gt 0) {
        [void]$sb.AppendLine("  IVR Time:         $(Format-Duration $Analysis.IvrTimeSeconds)")
    }
    if ($Analysis.QueueWaitSeconds -gt 0) {
        [void]$sb.AppendLine("  Queue Wait:       $(Format-Duration $Analysis.QueueWaitSeconds)")
    }
    if ($Analysis.AlertTimeSeconds -gt 0) {
        [void]$sb.AppendLine("  Alert/Ring Time:  $(Format-Duration $Analysis.AlertTimeSeconds)")
    }
    if ($Analysis.InteractTimeSeconds -gt 0) {
        [void]$sb.AppendLine("  Interaction Time: $(Format-Duration $Analysis.InteractTimeSeconds)")
    }
    if ($Analysis.AgentTalkSeconds -gt 0) {
        [void]$sb.AppendLine("  Agent Talk Time:  $(Format-Duration $Analysis.AgentTalkSeconds)")
    }
    if ($Analysis.HoldTimeSeconds -gt 0) {
        [void]$sb.AppendLine("  Hold Time:        $(Format-Duration $Analysis.HoldTimeSeconds)")
    }
    if ($Analysis.ConferenceSeconds -gt 0) {
        [void]$sb.AppendLine("  Conference Time:  $(Format-Duration $Analysis.ConferenceSeconds)")
    }
    if ($Analysis.WrapUpSeconds -gt 0) {
        [void]$sb.AppendLine("  Wrap-up Time:     $(Format-Duration $Analysis.WrapUpSeconds)")
    }
    if ($Analysis.SystemTimeSeconds -gt 0) {
        [void]$sb.AppendLine("  System Time:      $(Format-Duration $Analysis.SystemTimeSeconds)")
    }

    # Segment type breakdown if available
    if ($Analysis.SegmentBreakdown.Count -gt 0) {
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("Segment Type Distribution:")
        foreach ($segType in $Analysis.SegmentBreakdown.Keys | Sort-Object) {
            $duration = $Analysis.SegmentBreakdown[$segType]
            $pct = if ($Analysis.TotalDurationSeconds -gt 0) { [Math]::Round(($duration / $Analysis.TotalDurationSeconds) * 100, 1) } else { 0 }
            [void]$sb.AppendLine("  $($segType.PadRight(15)): $(Format-Duration $duration) ($pct%)")
        }
    }

    [void]$sb.AppendLine("")

    return $sb.ToString()
}

<#
.SYNOPSIS
    Formats the participant statistics section for the report.
.DESCRIPTION
    Creates a formatted text block with per-participant details
    including timing, quality metrics, and flow information.
#>
function Format-GCParticipantStatisticsText {
    param (
        [Parameter(Mandatory = $true)]
        [array]$Stats
    )

    $sb = [System.Text.StringBuilder]::new()

    # Helper function to format seconds as human-readable duration
    function Format-Duration {
        param ([double]$Seconds)
        if ($Seconds -lt 60) {
            return "$([Math]::Round($Seconds, 0))s"
        }
        elseif ($Seconds -lt 3600) {
            $mins = [Math]::Floor($Seconds / 60)
            $secs = [Math]::Round($Seconds % 60, 0)
            return "${mins}m ${secs}s"
        }
        else {
            $hours = [Math]::Floor($Seconds / 3600)
            $mins = [Math]::Floor(($Seconds % 3600) / 60)
            return "${hours}h ${mins}m"
        }
    }

    [void]$sb.AppendLine("-" * 40)
    [void]$sb.AppendLine("PARTICIPANT STATISTICS")
    [void]$sb.AppendLine("-" * 40)
    [void]$sb.AppendLine("")

    foreach ($stat in $Stats) {
        $roleIcon = switch ($stat.Purpose) {
            "customer" { "[C]" }
            "external" { "[E]" }
            "agent" { "[A]" }
            "acd" { "[Q]" }
            "ivr" { "[I]" }
            "voicemail" { "[V]" }
            default { "[?]" }
        }

        [void]$sb.AppendLine("$roleIcon $($stat.Name)")
        [void]$sb.AppendLine("    Role: $($stat.Purpose)")
        [void]$sb.AppendLine("    Duration: $(Format-Duration $stat.TotalDurationSeconds)")
        [void]$sb.AppendLine("    Sessions: $($stat.SessionCount) | Segments: $($stat.SegmentCount)")

        if ($stat.MediaTypes.Count -gt 0) {
            [void]$sb.AppendLine("    Media: $($stat.MediaTypes -join ', ')")
        }

        # Display ANI/DNIS for customer/external participants
        if ($stat.ANI -or $stat.DNIS) {
            $contactInfo = @()
            if ($stat.ANI) { $contactInfo += "ANI: $($stat.ANI)" }
            if ($stat.DNIS) { $contactInfo += "DNIS: $($stat.DNIS)" }
            [void]$sb.AppendLine("    Contact: $($contactInfo -join ' | ')")
        }

        # Display remote party name if available
        if ($stat.RemoteName) {
            [void]$sb.AppendLine("    Remote: $($stat.RemoteName)")
        }

        if ($stat.FlowNames.Count -gt 0) {
            [void]$sb.AppendLine("    Flows: $($stat.FlowNames -join ', ')")
        }

        # Display provider info
        if ($stat.Providers.Count -gt 0) {
            [void]$sb.AppendLine("    Provider: $($stat.Providers -join ', ')")
        }

        if ($stat.MosScores.Count -gt 0) {
            $avgMos = ($stat.MosScores | Measure-Object -Average).Average
            $minMos = ($stat.MosScores | Measure-Object -Minimum).Minimum
            [void]$sb.AppendLine("    MOS: avg=$([Math]::Round($avgMos, 2)) min=$([Math]::Round($minMos, 2))")
        }

        # Display recording indicator
        if ($stat.HasRecording) {
            [void]$sb.AppendLine("    Recording: Yes")
        }

        if ($stat.DisconnectType) {
            [void]$sb.AppendLine("    Disconnect: $($stat.DisconnectType)")
        }

        if ($stat.HasErrors) {
            [void]$sb.AppendLine("    Errors: $($stat.ErrorCodes -join ', ')")
        }

        [void]$sb.AppendLine("")
    }

    [void]$sb.AppendLine("Legend: [C]=Customer [E]=External [A]=Agent [Q]=Queue/ACD [I]=IVR [V]=Voicemail")
    [void]$sb.AppendLine("")

    return $sb.ToString()
}

<#
.SYNOPSIS
    Formats the conversation flow path for the report.
.DESCRIPTION
    Creates a visual ASCII representation of the call flow
    showing the path through IVR, queues, and agents.
#>
function Format-GCConversationFlowText {
    param (
        [Parameter(Mandatory = $true)]
        [array]$FlowPath
    )

    $sb = [System.Text.StringBuilder]::new()

    [void]$sb.AppendLine("-" * 40)
    [void]$sb.AppendLine("CONVERSATION FLOW PATH")
    [void]$sb.AppendLine("-" * 40)
    [void]$sb.AppendLine("")

    if ($FlowPath.Count -eq 0) {
        [void]$sb.AppendLine("No flow path data available.")
        [void]$sb.AppendLine("")
        return $sb.ToString()
    }

    $lastPurpose = ""
    foreach ($step in $FlowPath) {
        $roleIcon = switch ($step.Purpose) {
            "customer" { "[CUSTOMER]" }
            "external" { "[EXTERNAL]" }
            "agent" { "[AGENT]   " }
            "acd" { "[QUEUE]   " }
            "ivr" { "[IVR]     " }
            "voicemail" { "[VM]      " }
            default { "[OTHER]   " }
        }

        $connector = if ($lastPurpose) { "     |" } else { "" }
        if ($connector) {
            [void]$sb.AppendLine($connector)
            [void]$sb.AppendLine("     v")
        }

        [void]$sb.AppendLine("$($step.Order). $roleIcon $($step.Name)")

        if ($step.FlowName) {
            [void]$sb.AppendLine("              Flow: $($step.FlowName)")
        }

        if ($step.TransferTo) {
            [void]$sb.AppendLine("              -> Transfer to: $($step.TransferTo) ($($step.TransferType))")
        }

        $lastPurpose = $step.Purpose
    }

    [void]$sb.AppendLine("")

    return $sb.ToString()
}

function Format-ConversationReportText {
    param (
        [Parameter(Mandatory = $true)]
        $Report
    )

    $sb = [System.Text.StringBuilder]::new()

    [void]$sb.AppendLine("=" * 60)
    [void]$sb.AppendLine("CONVERSATION REPORT")
    [void]$sb.AppendLine("=" * 60)
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("Conversation ID: $($Report.ConversationId)")
    [void]$sb.AppendLine("Retrieved At: $($Report.RetrievedAt)")
    [void]$sb.AppendLine("")

    if ($Report.Errors -and $Report.Errors.Count -gt 0) {
        [void]$sb.AppendLine("-" * 40)
        [void]$sb.AppendLine("ERRORS")
        [void]$sb.AppendLine("-" * 40)
        foreach ($err in $Report.Errors) {
            [void]$sb.AppendLine("  - $err")
        }
        [void]$sb.AppendLine("")
    }

    # Generate insight data early so we can display key insights at the top
    $events = $null
    $sortedEvents = $null
    $durationAnalysis = $null
    $participantStats = $null
    $summary = $null
    $keyInsights = $null
    $flowPath = $null
    $analysisError = $null

    try {
        # Extract events from both API responses
        $events = Get-GCConversationDetailsTimeline -Report $Report

        if ($events -and $events.Count -gt 0) {
            # Merge and sort events chronologically
            $sortedEvents = Merge-GCConversationEvents -Events $events

            # Generate analysis data
            $durationAnalysis = Get-GCConversationDurationAnalysis -Report $Report -Events $sortedEvents
            $participantStats = Get-GCParticipantStatistics -Report $Report
            $summary = Get-GCConversationSummary -ConversationId $Report.ConversationId -Events $sortedEvents
            $flowPath = Get-GCConversationFlowPath -Report $Report

            # Generate key insights (requires all other analyses)
            $keyInsights = Get-GCConversationKeyInsights -Report $Report -DurationAnalysis $durationAnalysis -ParticipantStats $participantStats -Summary $summary
        }
    }
    catch {
        # Store error but continue with report using available data
        $analysisError = $_.Exception.Message
    }

    # Display analysis error if one occurred
    if ($analysisError) {
        [void]$sb.AppendLine("-" * 40)
        [void]$sb.AppendLine("ANALYSIS NOTE")
        [void]$sb.AppendLine("-" * 40)
        [void]$sb.AppendLine("Some analysis sections may be incomplete due to: $analysisError")
        [void]$sb.AppendLine("")
    }

    # Display Key Insights at the top (most valuable information first)
    if ($keyInsights -and $keyInsights.Count -gt 0) {
        $insightsText = Format-GCKeyInsightsText -Insights $keyInsights
        [void]$sb.Append($insightsText)
    }

    # Display Duration Analysis
    if ($durationAnalysis) {
        $durationText = Format-GCDurationAnalysisText -Analysis $durationAnalysis
        [void]$sb.Append($durationText)
    }

    # Display Conversation Flow Path
    if ($flowPath -and $flowPath.Count -gt 0) {
        $flowText = Format-GCConversationFlowText -FlowPath $flowPath
        [void]$sb.Append($flowText)
    }

    # Display Participant Statistics
    if ($participantStats -and $participantStats.Count -gt 0) {
        $participantText = Format-GCParticipantStatisticsText -Stats $participantStats
        [void]$sb.Append($participantText)
    }

    # Conversation Details Section
    if ($Report.ConversationDetails) {
        $conv = $Report.ConversationDetails
        [void]$sb.AppendLine("-" * 40)
        [void]$sb.AppendLine("CONVERSATION DETAILS")
        [void]$sb.AppendLine("-" * 40)

        if ($conv.startTime) {
            [void]$sb.AppendLine("Start Time: $($conv.startTime)")
        }
        if ($conv.endTime) {
            [void]$sb.AppendLine("End Time: $($conv.endTime)")
        }
        if ($conv.conversationStart) {
            [void]$sb.AppendLine("Conversation Start: $($conv.conversationStart)")
        }
        if ($conv.conversationEnd) {
            [void]$sb.AppendLine("Conversation End: $($conv.conversationEnd)")
        }
        if ($conv.state) {
            [void]$sb.AppendLine("State: $($conv.state)")
        }
        if ($conv.externalTag) {
            [void]$sb.AppendLine("External Tag: $($conv.externalTag)")
        }
        if ($conv.utilizationLabelId) {
            [void]$sb.AppendLine("Utilization Label ID: $($conv.utilizationLabelId)")
        }

        # Participants
        if ($conv.participants -and $conv.participants.Count -gt 0) {
            [void]$sb.AppendLine("")
            [void]$sb.AppendLine("Participants ($($conv.participants.Count)):")
            foreach ($participant in $conv.participants) {
                [void]$sb.AppendLine("  - Purpose: $($participant.purpose)")
                if ($participant.userId) {
                    [void]$sb.AppendLine("    User ID: $($participant.userId)")
                }
                if ($participant.name) {
                    [void]$sb.AppendLine("    Name: $($participant.name)")
                }
                if ($participant.queueId) {
                    [void]$sb.AppendLine("    Queue ID: $($participant.queueId)")
                }
                if ($participant.address) {
                    [void]$sb.AppendLine("    Address: $($participant.address)")
                }
                if ($participant.startTime) {
                    [void]$sb.AppendLine("    Start Time: $($participant.startTime)")
                }
                if ($participant.endTime) {
                    [void]$sb.AppendLine("    End Time: $($participant.endTime)")
                }
                if ($null -ne $participant.wrapupRequired) {
                    [void]$sb.AppendLine("    Wrapup Required: $($participant.wrapupRequired)")
                }
            }
        }
        [void]$sb.AppendLine("")
    }
    else {
        [void]$sb.AppendLine("-" * 40)
        [void]$sb.AppendLine("CONVERSATION DETAILS: Not available")
        [void]$sb.AppendLine("-" * 40)
        [void]$sb.AppendLine("")
    }

    # Analytics Details Section
    if ($Report.AnalyticsDetails) {
        $analytics = $Report.AnalyticsDetails
        [void]$sb.AppendLine("-" * 40)
        [void]$sb.AppendLine("ANALYTICS DETAILS")
        [void]$sb.AppendLine("-" * 40)

        if ($analytics.conversationStart) {
            [void]$sb.AppendLine("Conversation Start: $($analytics.conversationStart)")
        }
        if ($analytics.conversationEnd) {
            [void]$sb.AppendLine("Conversation End: $($analytics.conversationEnd)")
        }
        if ($analytics.originatingDirection) {
            [void]$sb.AppendLine("Originating Direction: $($analytics.originatingDirection)")
        }
        if ($analytics.divisionIds -and $analytics.divisionIds.Count -gt 0) {
            [void]$sb.AppendLine("Division IDs: $($analytics.divisionIds -join ', ')")
        }
        if ($analytics.mediaStatsMinConversationMos) {
            [void]$sb.AppendLine("Min MOS: $($analytics.mediaStatsMinConversationMos)")
        }
        if ($analytics.mediaStatsMinConversationRFactor) {
            [void]$sb.AppendLine("Min R-Factor: $($analytics.mediaStatsMinConversationRFactor)")
        }

        # Participant Sessions
        if ($analytics.participants -and $analytics.participants.Count -gt 0) {
            [void]$sb.AppendLine("")
            [void]$sb.AppendLine("Analytics Participants ($($analytics.participants.Count)):")
            foreach ($participant in $analytics.participants) {
                [void]$sb.AppendLine("  - Participant ID: $($participant.participantId)")
                if ($participant.participantName) {
                    [void]$sb.AppendLine("    Name: $($participant.participantName)")
                }
                if ($participant.purpose) {
                    [void]$sb.AppendLine("    Purpose: $($participant.purpose)")
                }
                if ($participant.sessions -and $participant.sessions.Count -gt 0) {
                    [void]$sb.AppendLine("    Sessions: $($participant.sessions.Count)")
                    foreach ($session in $participant.sessions) {
                        if ($session.mediaType) {
                            [void]$sb.AppendLine("      Media Type: $($session.mediaType)")
                        }
                        if ($session.direction) {
                            [void]$sb.AppendLine("      Direction: $($session.direction)")
                        }
                        if ($session.ani) {
                            [void]$sb.AppendLine("      ANI: $($session.ani)")
                        }
                        if ($session.dnis) {
                            [void]$sb.AppendLine("      DNIS: $($session.dnis)")
                        }
                    }
                }
            }
        }
        [void]$sb.AppendLine("")
    }
    else {
        [void]$sb.AppendLine("-" * 40)
        [void]$sb.AppendLine("ANALYTICS DETAILS: Not available")
        [void]$sb.AppendLine("-" * 40)
        [void]$sb.AppendLine("")
    }

    # Generate chronological timeline by extracting events from both endpoints
    # and interlacing them in time order
    [void]$sb.AppendLine("-" * 40)
    [void]$sb.AppendLine("CHRONOLOGICAL TIMELINE")
    [void]$sb.AppendLine("-" * 40)
    [void]$sb.AppendLine("")

    # Use previously computed events if available
    if ($sortedEvents -and $sortedEvents.Count -gt 0) {
        # Format timeline text
        $timelineText = Format-GCConversationTimelineText -Events $sortedEvents
        [void]$sb.AppendLine($timelineText)

        # Generate and append summary (use pre-computed if available)
        if ($summary) {
            $summaryText = Format-GCConversationSummaryText -Summary $summary
            [void]$sb.AppendLine($summaryText)
        }
    }
    else {
        [void]$sb.AppendLine("No timeline events could be extracted from the available data.")
        [void]$sb.AppendLine("")
    }

    [void]$sb.AppendLine("=" * 60)
    [void]$sb.AppendLine("END OF REPORT")
    [void]$sb.AppendLine("=" * 60)

    return $sb.ToString()
}

$ApiBaseUrl = "https://api.$($script:Region)"
$JobTracker = [PSCustomObject]@{
    Timer      = $null
    JobId      = $null
    Path       = $null
    Headers    = @{}
    Status     = ""
    ResultFile = ""
    LastUpdate = ""
}
$script:LastResponseFile = ""

function Stop-JobPolling {
    if ($JobTracker.Timer) {
        $JobTracker.Timer.Stop()
        $JobTracker.Timer = $null
    }
}

function Update-JobPanel {
    param (
        [string]$JobId,
        [string]$Status,
        [string]$Updated
    )

    if ($jobIdText) {
        $jobIdText.Text = if ($JobTracker.JobId) { $JobTracker.JobId } else { "No active job" }
    }

    if ($jobStatusText) {
        $jobStatusText.Text = if ($Status) { "Status: $Status" } else { "Status: (none)" }
    }

    if ($jobUpdatedText) {
        $jobUpdatedText.Text = if ($Updated) { "Last checked: $Updated" } else { "Last checked: --" }
    }

    if ($jobResultsPath) {
        $jobResultsPath.Text = if ($JobTracker.ResultFile) { "Results file: $($JobTracker.ResultFile)" } else { "Results file: (not available yet)" }
    }

    if ($fetchJobResultsButton) {
        $fetchJobResultsButton.IsEnabled = [bool]$JobTracker.JobId
    }

    if ($exportJobResultsButton) {
        $exportJobResultsButton.IsEnabled = (($JobTracker.ResultFile) -and (Test-Path $JobTracker.ResultFile))
    }
}

function Start-JobPolling {
    param (
        [string]$Path,
        [string]$JobId,
        [hashtable]$Headers
    )

    if (-not $Path -or -not $JobId) {
        return
    }

    Stop-JobPolling
    $JobTracker.Path = $Path.TrimEnd('/')
    $JobTracker.JobId = $JobId
    $JobTracker.Headers = $Headers
    $JobTracker.Status = "Pending"
    $JobTracker.ResultFile = ""
    Update-JobPanel -Status $JobTracker.Status -Updated (Get-Date).ToString("HH:mm:ss")

    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [System.TimeSpan]::FromSeconds(6)
    $timer.Add_Tick({
            Get-JobStatus
        })
    $JobTracker.Timer = $timer
    $timer.Start()
    Get-JobStatus
}

function Get-JobStatus {
    if (-not $JobTracker.JobId -or -not $JobTracker.Path) {
        return
    }

    $statusUrl = "$ApiBaseUrl$($JobTracker.Path)/$($JobTracker.JobId)"
    try {
        $statusResponse = Invoke-GCRequest -Method GET -Uri $statusUrl -Headers $JobTracker.Headers -AsResponse
        $statusJson = $statusResponse.Content | ConvertFrom-Json -ErrorAction SilentlyContinue
        $statusValue = if ($statusJson.status) { $statusJson.status } elseif ($statusJson.state) { $statusJson.state } else { $null }
        $JobTracker.Status = $statusValue
        $JobTracker.LastUpdate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Update-JobPanel -Status $statusValue -Updated $JobTracker.LastUpdate
        Add-LogEntry "Job $($JobTracker.JobId) status checked: $statusValue"

        if (-not (Job-StatusIsPending -Status $statusValue)) {
            Stop-JobPolling
            Fetch-JobResults
        }
    }
    catch {
        Add-LogEntry "Job status poll failed: $($_.Exception.Message)"
    }
}

function Fetch-JobResults {
    param ([switch]$Force)

    if (-not $JobTracker.JobId -or -not $JobTracker.Path) {
        return
    }

    $resultsPath = "$($JobTracker.Path)/$($JobTracker.JobId)/results"
    $tempFile = Join-Path -Path $env:TEMP -ChildPath "GenesysJobResults_$([guid]::NewGuid()).json"
    $errorMessage = $null

    try {
        # Update status to show we're fetching
        $statusText.Text = "Fetching job results (may be paginated)..."
        Add-LogEntry "Fetching job results from $resultsPath"

        # Define progress callback for pagination
        $paginationCallback = {
            param($PageNumber, $Status, $IsError, $IsComplete)

            if ($IsError) {
                $statusText.Text = "Error: $Status"
            }
            elseif ($IsComplete) {
                $statusText.Text = $Status
            }
            else {
                $statusText.Text = "Fetching results - $Status"
            }
            Add-LogEntry $Status
            [System.Windows.Forms.Application]::DoEvents()
        }

        # Use pagination helper to fetch all results
        $allResults = Get-PaginatedResults `
            -BaseUrl $ApiBaseUrl `
            -InitialPath $resultsPath `
            -Headers $JobTracker.Headers `
            -Method "GET" `
            -ProgressCallback $paginationCallback

        # Save all results to temp file
        $allResults | ConvertTo-Json -Depth 20 | Set-Content -Path $tempFile -Encoding UTF8

        $JobTracker.ResultFile = $tempFile
        if ($jobResultsPath) {
            $jobResultsPath.Text = "Results file: $tempFile"
        }
        $snippet = Get-Content -Path $tempFile -TotalCount 200 | Out-String
        $script:LastResponseText = "Job results saved to temp file (Total: $($allResults.Count) items).`r`n$tempFile`r`n`r`n${snippet}"
        $script:LastResponseRaw = $snippet.Trim()
        $script:LastResponseFile = $tempFile
        $responseBox.Text = "Job $($JobTracker.JobId) completed; $($allResults.Count) results saved to temp file."
        Add-LogEntry "Job results downloaded: $($allResults.Count) total items saved to $tempFile"
        Update-JobPanel -Status $JobTracker.Status -Updated (Get-Date).ToString("HH:mm:ss")
    }
    catch {
        $errorMessage = $_.Exception.Message
        Add-LogEntry "Fetching job results failed: $errorMessage"
        $responseBox.Text = "Failed to download job results: $errorMessage"
        $statusText.Text = "Job results fetch failed"
    }
}

function Get-FavoritesFromDisk {
    param ([string]$Path)

    if (-not (Test-Path -Path $Path)) {
        return @()
    }

    try {
        $content = Get-Content -Path $Path -Raw
        if (-not $content) {
            return @()
        }

        return $content | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        Write-Warning "Unable to load favorites: $($_.Exception.Message)"
        return @()
    }
}

function Save-FavoritesToDisk {
    param (
        [string]$Path,
        [Parameter(Mandatory)][System.Collections.IEnumerable]$Favorites
    )

    try {
        $Favorites | ConvertTo-Json -Depth 5 | Set-Content -Path $Path -Encoding utf8
    }
    catch {
        Write-Verbose "Unable to save favorites: $($_.Exception.Message)"
        Write-TraceLog "Unable to save favorites: $($_.Exception.Message)"
    }
}

function Build-FavoritesCollection {
    param ($Source)

    $list = [System.Collections.ArrayList]::new()
    if (-not $Source) {
        return $list
    }

    $isEnumerable = ($Source -is [System.Collections.IEnumerable]) -and -not ($Source -is [string])
    if ($isEnumerable) {
        foreach ($item in $Source) {
            $list.Add($item) | Out-Null
        }
    }
    else {
        $list.Add($Source) | Out-Null
    }

    return $list
}

function Load-TemplatesFromDisk {
    param ([string]$Path)

    if (-not (Test-Path -Path $Path)) {
        return @()
    }

    try {
        $content = Get-Content -Path $Path -Raw
        if (-not $content) {
            return @()
        }

        return $content | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        Write-Verbose "Unable to load templates: $($_.Exception.Message)"
        Write-TraceLog "Unable to load templates: $($_.Exception.Message)"
        return @()
    }
}

function Save-TemplatesToDisk {
    param (
        [string]$Path,
        [Parameter(Mandatory)][System.Collections.IEnumerable]$Templates
    )

    try {
        $normalized = @($Templates | Where-Object { $_ } | ForEach-Object { $_ })
        $normalized | ConvertTo-Json -Depth 5 | Set-Content -Path $Path -Encoding utf8
    }
    catch {
        Write-Verbose "Unable to save templates: $($_.Exception.Message)"
        Write-TraceLog "Unable to save templates: $($_.Exception.Message)"
    }
}

$script:BlockedTemplateMethods = @('DELETE', 'PATCH', 'PUT')

function Test-TemplateMethodAllowed {
    param([string]$Method)

    if ([string]::IsNullOrWhiteSpace($Method)) { return $true }
    return (-not ($script:BlockedTemplateMethods -contains $Method.Trim().ToUpperInvariant()))
}

function Normalize-TemplateObject {
    param(
        [Parameter(Mandatory)]
        $Template,
        [string]$DefaultLastModified
    )

    if (-not $Template) { return $null }

    $method = ''
    try { $method = [string]$Template.Method } catch { $method = '' }
    if (-not (Test-TemplateMethodAllowed -Method $method)) { return $null }

    $created = ''
    $lastModified = ''
    try { $created = [string]$Template.Created } catch { $created = '' }
    try { $lastModified = [string]$Template.LastModified } catch { $lastModified = '' }

    if ([string]::IsNullOrWhiteSpace($created)) {
        $created = if ($DefaultLastModified) { $DefaultLastModified } else { (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') }
    }
    if ([string]::IsNullOrWhiteSpace($lastModified)) {
        $lastModified = $created
    }

    $templateOut = [pscustomobject]@{
        Name         = [string]$Template.Name
        Method       = [string]$Template.Method
        Path         = [string]$Template.Path
        Group        = [string]$Template.Group
        Parameters   = $Template.Parameters
        Created      = $created
        LastModified = $lastModified
    }

    return $templateOut
}

function Normalize-Templates {
    param(
        [Parameter(Mandatory)]
        [System.Collections.IEnumerable]$Templates,
        [string]$DefaultLastModified
    )

    $out = New-Object System.Collections.Generic.List[object]
    foreach ($t in @($Templates)) {
        $norm = Normalize-TemplateObject -Template $t -DefaultLastModified $DefaultLastModified
        if ($norm) { $out.Add($norm) | Out-Null }
    }
    # Avoid PowerShell host differences when expanding generic lists.
    return $out.ToArray()
}

function Enable-GridViewColumnSorting {
    param(
        [Parameter(Mandatory)]
        [System.Windows.Controls.ListView]$ListView,
        [hashtable]$State
    )

    if (-not $State) { $State = @{} }
    if (-not $State.ContainsKey('Property')) { $State['Property'] = $null }
    if (-not $State.ContainsKey('Direction')) { $State['Direction'] = [System.ComponentModel.ListSortDirection]::Ascending }

    $ListView.Resources['ColumnSortState'] = $State

    $ListView.AddHandler(
        [System.Windows.Controls.GridViewColumnHeader]::ClickEvent,
        [System.Windows.RoutedEventHandler] {
            param($src, $e)

            $header = $e.OriginalSource
            if (-not ($header -is [System.Windows.Controls.GridViewColumnHeader])) { return }
            if (-not $header.Tag) { return }

            $sortBy = [string]$header.Tag
            if ([string]::IsNullOrWhiteSpace($sortBy)) { return }

            $State = $null
            try { $State = $src.Resources['ColumnSortState'] } catch { }
            if (-not ($State -is [hashtable])) {
                $State = @{}
                $State['Property'] = $null
                $State['Direction'] = [System.ComponentModel.ListSortDirection]::Ascending
                try { $src.Resources['ColumnSortState'] = $State } catch { }
            }

            $direction = [System.ComponentModel.ListSortDirection]::Ascending
            if ($State['Property'] -eq $sortBy) {
                $direction = if ($State['Direction'] -eq [System.ComponentModel.ListSortDirection]::Ascending) {
                    [System.ComponentModel.ListSortDirection]::Descending
                }
                else {
                    [System.ComponentModel.ListSortDirection]::Ascending
                }
            }

            $State['Property'] = $sortBy
            $State['Direction'] = $direction

            $view = [System.Windows.Data.CollectionViewSource]::GetDefaultView($src.ItemsSource)
            if (-not $view) { return }

            $view.SortDescriptions.Clear()
            $view.SortDescriptions.Add((New-Object System.ComponentModel.SortDescription($sortBy, $direction)))
            $view.Refresh()
        }
    )
}

#endregion Transport/API

#region Feature tabs (Conversation, Audit, Live Sub, Ops Dash, etc.)
$script:LastResponseText = ""
$script:LastResponseRaw = ""
$paramInputs = @{}
$pendingFavoriteParameters = $null
$script:FilterBuilderData = @{
    ConversationFilters = New-Object System.Collections.ArrayList
    SegmentFilters      = New-Object System.Collections.ArrayList
    Interval            = "2025-12-01T00:00:00.000Z/2025-12-07T23:59:59.999Z"
}
$script:FilterBuilderEnums = @{
    Conversation = @{
        Dimensions = @()
        Metrics    = @()
    }
    Segment      = @{
        Dimensions = @()
        Metrics    = @()
    }
    Operators    = @("matches", "exists", "notExists")
}
$script:LiveSubscriptionEvents = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
$script:LiveSubscriptionFilterText = ''
$script:LiveSubscriptionConnection = $null
$script:LiveSubscriptionCapture = $null
$script:LiveSubscriptionRefreshTimer = $null
$script:LiveSubscriptionLastCapturePath = ''
$script:LiveSubscriptionLastSummaryPath = ''
$script:LiveSubscriptionLastSummary = $null
$script:LiveSubscriptionEventsView = $null
$script:LiveSubscriptionTopicCatalog = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
$script:LiveSubscriptionTopicTotals = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
$script:LiveSubscriptionEventTypeTotals = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
$script:LiveSubscriptionAnalyticsTimer = $null
$script:LiveSubscriptionTopicCatalogLastUpdated = $null
$script:LiveSubscriptionSummaryFileStamp = $null
$script:LiveSubscriptionTopicCatalogStatusText = $null
$script:LiveSubscriptionAnalyticsStatusText = $null
$script:LiveSubscriptionTopicCatalogCachePath = $null
$script:LiveSubscriptionSession = $null
$script:AudioHookTopics = @()
$script:LiveSubFilterPlaceholder = "Filter by conversationId, topic, event type, or message text"
$script:LiveSubscriptionPresets = @(
    [pscustomobject]@{ Label = 'AudioHook streams (all)'; Topic = 'v2.audiohook' },
    [pscustomobject]@{ Label = 'AudioHook errors only'; Topic = 'v2.audiohook.errors' },
    [pscustomobject]@{ Label = 'All conversation notifications'; Topic = 'v2.conversations' },
    [pscustomobject]@{ Label = 'Operational events'; Topic = 'notifications.operational.events' },
    [pscustomobject]@{ Label = 'Routing events (wildcard)'; Topic = 'notifications.routing.*' },
    [pscustomobject]@{ Label = 'User events (wildcard)'; Topic = 'notifications.user.*' },
    [pscustomobject]@{ Label = 'Administration events'; Topic = 'notifications.administration.*' },
    [pscustomobject]@{ Label = 'Data Actions events'; Topic = 'notifications.data.actions' }
)
$script:AllowedOpsUsers = if ($env:GENESYS_API_EXPLORER_ALLOWED_USERS) { @($env:GENESYS_API_EXPLORER_ALLOWED_USERS -split '[,; ]+' | Where-Object { $_ }) } else { @() }
$script:CurrentUser = [Environment]::UserName
$script:AllowedOpsUsers = if ($env:GENESYS_API_EXPLORER_ALLOWED_USERS) { @($env:GENESYS_API_EXPLORER_ALLOWED_USERS -split '[,; ]+' | Where-Object { $_ }) } else { @() }
$script:CurrentUser = [Environment]::UserName
$script:OperationalEvents = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
$script:OperationalEventsRaw = New-Object System.Collections.ArrayList
$script:OperationalEventsSummaryPath = ''
$script:AuditInvestigatorEvents = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
$script:AuditFilterText = ''
$script:AuditFilterTextLower = ''
$script:AuditSummaryExportPath = ''
$script:AuditLogEntries = New-Object System.Collections.ObjectModel.ObservableCollection[object]
$script:OperationalEventsLiveSubscription = $null
$script:OperationalEventsLiveTimer = $null
$script:OperationalEventsLiveDefinitions = @()
$script:OperationalEventsTopicPresets = @(
    [pscustomobject]@{ Label = 'All operational events'; Topic = 'notifications.operational.events' },
    [pscustomobject]@{ Label = 'Routing/Queue updates'; Topic = 'notifications.routing.events' },
    [pscustomobject]@{ Label = 'Administration events'; Topic = 'notifications.administration.events' },
    [pscustomobject]@{ Label = 'Operational service alerts'; Topic = 'notifications.operational.service' }
)
$script:OperationsDashboardMosCollection = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
$script:OperationsDashboardDataActionCollection = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
$script:OperationsDashboardWebRtcCollection = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
$script:OperationsTimelineEntries = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
$script:OperationsDashboardFilters = $null
$script:OperationsDashboardRecords = @()
$script:OperationsDashboardLastRefresh = $null

function Get-OperationsDashboardStorePath {
    $root = Join-Path -Path (Get-RepoRoot -StartPath $ScriptRoot) -ChildPath 'artifacts/ops-dashboard'
    if (-not (Test-Path -LiteralPath $root)) {
        try {
            New-Item -ItemType Directory -Path $root -Force | Out-Null
        }
        catch {
            Write-TraceLog "Get-OperationsDashboardStorePath: unable to create '$root': $($_.Exception.Message)"
        }
    }

    return Join-Path -Path $root -ChildPath 'dashboard-store.jsonl'
}

$script:OperationsDashboardStorePath = Get-OperationsDashboardStorePath
$script:OperationsDashboardMosCollection = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
$script:OperationsDashboardDataActionCollection = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
$script:OperationsDashboardWebRtcCollection = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
$script:OperationsDashboardLastRefresh = $null

if (-not (Get-Command Refresh-LiveSubscriptionAnalytics -ErrorAction SilentlyContinue)) {
    function Refresh-LiveSubscriptionAnalytics { }
}

function Invoke-RefreshLiveSubscriptionAnalyticsSafe {
    if (Get-Command Refresh-LiveSubscriptionAnalytics -ErrorAction SilentlyContinue) {
        Refresh-LiveSubscriptionAnalytics
    }
    else {
        Write-TraceLog "Refresh-LiveSubscriptionAnalytics not available; skipping analytics refresh."
    }
}

function Join-FromScriptRoot {
    param (
        [int]$Levels,
        [string]$Child
    )

    $base = $ScriptRoot
    for ($i = 1; $i -le $Levels; $i++) {
        $base = Split-Path -Parent $base
    }

    return Join-Path -Path $base -ChildPath $Child
}

function Resolve-WorkspaceRoot {
    param(
        [string[]]$StartDirectories
    )

    Write-TraceLog "Resolve-WorkspaceRoot: startDirs=$(@($StartDirectories) -join ' | ')"
    foreach ($start in @($StartDirectories)) {
        if ([string]::IsNullOrWhiteSpace($start)) { continue }
        try {
            $item = Get-Item -LiteralPath $start -ErrorAction SilentlyContinue
            if (-not $item) { continue }
            $current = if ($item.PSIsContainer) { $item.FullName } else { Split-Path -Parent $item.FullName }
            for ($i = 0; $i -lt 10; $i++) {
                $packs = Join-Path -Path (Join-Path -Path $current -ChildPath 'insights') -ChildPath 'packs'
                if (Test-Path -LiteralPath $packs) { return $current }

                $parent = Split-Path -Parent $current
                if (-not $parent -or ($parent -eq $current)) { break }
                $current = $parent
            }
        }
        catch { }
    }

    return $null
}

$candidateRoots = @(
    $env:GENESYS_API_EXPLORER_ROOT,
    $ScriptRoot,
    (Get-Location).Path,
    $PSCommandPath,
    $MyInvocation.MyCommand.Path,
    [AppDomain]::CurrentDomain.BaseDirectory
)

$workspaceRoot = Resolve-WorkspaceRoot -StartDirectories $candidateRoots
if (-not $workspaceRoot) {
    # Fallback to the original assumption (script lives under apps/OpsConsole/Resources)
    $workspaceRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $ScriptRoot))
}

# Allow overriding pack discovery when running from an installed module/EXE.
# - `GENESYS_API_EXPLORER_PACKS_DIR` may point directly to the packs folder, or to the repo root.
$insightPackRoot = Join-Path -Path (Join-Path -Path $workspaceRoot -ChildPath 'insights') -ChildPath 'packs'
$packOverride = [string]$env:GENESYS_API_EXPLORER_PACKS_DIR
if (-not [string]::IsNullOrWhiteSpace($packOverride)) {
    try {
        if (Test-Path -LiteralPath $packOverride) {
            $overrideItem = Get-Item -LiteralPath $packOverride -ErrorAction SilentlyContinue
            if ($overrideItem -and $overrideItem.PSIsContainer) {
                $overrideDirect = Join-Path -Path (Join-Path -Path $overrideItem.FullName -ChildPath 'insights') -ChildPath 'packs'
                if (Test-Path -LiteralPath $overrideDirect) {
                    $insightPackRoot = $overrideDirect
                }
                else {
                    $insightPackRoot = $overrideItem.FullName
                }
            }
        }
    }
    catch { }
}
$insightBriefingRoot = Join-Path -Path (Join-Path -Path $workspaceRoot -ChildPath 'insights') -ChildPath 'briefings'
$script:OpsInsightsManifest = Join-Path -Path $workspaceRoot -ChildPath 'src/GenesysCloud.OpsInsights/GenesysCloud.OpsInsights.psd1'
$script:OpsInsightsModuleRoot = Split-Path -Parent $script:OpsInsightsManifest
$script:OpsInsightsCoreManifest = Join-Path -Path $script:OpsInsightsModuleRoot -ChildPath '..\GenesysCloud.OpsInsights.Core\GenesysCloud.OpsInsights.Core.psd1'
$script:NotificationsToolkitManifest = Join-Path -Path $workspaceRoot -ChildPath 'Scripts/GenesysCloud.NotificationsToolkit/GenesysCloud.NotificationsToolkit.psd1'
if (Test-Path -LiteralPath $script:NotificationsToolkitManifest) {
    try {
        Import-Module -Name $script:NotificationsToolkitManifest -Force -ErrorAction Stop
    }
    catch {
        Write-TraceLog "Notifications toolkit import failed: $($_.Exception.Message)"
    }
}

Write-TraceLog "Workspace/Pack roots: workspaceRoot='$workspaceRoot' scriptRoot='$ScriptRoot' insightPackRoot='$insightPackRoot' override='$packOverride'"

function Load-OpsInsightsScripts {
    if ($script:OpsInsightsScriptsLoaded) { return }

    $directories = @(
        Join-Path -Path $script:OpsInsightsModuleRoot -ChildPath 'Private',
        Join-Path -Path $script:OpsInsightsModuleRoot -ChildPath 'Public'
    )

    foreach ($dir in $directories) {
        if (-not (Test-Path -LiteralPath $dir)) { continue }
        Get-ChildItem -Path $dir -Filter '*.ps1' -File | Sort-Object Name | ForEach-Object {
            try {
                . $_.FullName
            }
            catch {
                Write-Warning "Failed to load OpsInsights script '$($_.FullName)': $($_.Exception.Message)"
            }
        }
    }

    $script:OpsInsightsScriptsLoaded = $true
}

#region Background task helper (DEF-001)
<#
.SYNOPSIS
    Runs a heavy scriptblock off the WPF UI thread using a dedicated runspace.
.DESCRIPTION
    Accepts a work scriptblock, an optional hashtable of variables to pass to it, and
    success/error callbacks that are invoked back on the WPF dispatcher thread so UI
    controls can be updated safely.  A DispatcherTimer polls for completion every 200 ms;
    the UI thread remains fully responsive throughout.
.PARAMETER WorkScript
    Scriptblock executed on the background thread.  Receives no positional arguments.
    Variables listed in WorkParams are injected into the runspace before execution.
.PARAMETER WorkParams
    Hashtable whose keys are set as runspace variables before WorkScript runs.
.PARAMETER OnSuccess
    Scriptblock called on the UI thread when WorkScript finishes without errors.
    Receives the pipeline output of WorkScript as its first argument.
.PARAMETER OnError
    Scriptblock called on the UI thread when WorkScript throws or has stream errors.
    Receives the error record as its first argument.
.PARAMETER OnStart
    Optional scriptblock called synchronously on the UI thread immediately before the
    background runspace is started (e.g., to disable buttons and show a status message).
.PARAMETER OnTick
    Optional scriptblock called on each timer tick (on the UI thread) while the
    background task is running.  Use to drain a progress queue, update a spinner, etc.
#>
function Invoke-UIBackgroundTask {
    param(
        [Parameter(Mandatory)]
        [scriptblock]$WorkScript,

        [Parameter()]
        [hashtable]$WorkParams = @{},

        [Parameter()]
        [scriptblock]$OnSuccess,

        [Parameter()]
        [scriptblock]$OnError,

        [Parameter()]
        [scriptblock]$OnStart,

        [Parameter()]
        [scriptblock]$OnTick
    )

    # Run the optional pre-start callback on the UI thread (synchronous)
    if ($OnStart) {
        try { & $OnStart } catch { Write-Verbose "Invoke-UIBackgroundTask OnStart error: $($_.Exception.Message)" }
    }

    $rs = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
    $rs.ApartmentState = 'STA'
    $rs.ThreadOptions  = 'ReuseThread'
    $rs.Open()
    # Future enhancement: use a RunspacePool with a configurable MaxRunspaces limit
    # to bound resource use when many operations are triggered in quick succession.

    foreach ($key in $WorkParams.Keys) {
        $rs.SessionStateProxy.SetVariable($key, $WorkParams[$key])
    }

    $ps = [System.Management.Automation.PowerShell]::Create()
    $ps.Runspace = $rs
    [void]$ps.AddScript($WorkScript)

    $handle = $ps.BeginInvoke()

    # Use a shared state container so the timer closure can reference the timer itself
    # (needed because GetNewClosure captures values at closure-creation time)
    $taskState = @{
        Ps      = $ps
        Rs      = $rs
        Handle  = $handle
        Success = $OnSuccess
        Error   = $OnError
        Tick    = $OnTick
        Timer   = $null    # set below, after closure created
    }

    $timerTick = {
        # Run optional per-tick callback (e.g., drain progress queue)
        if ($taskState.Tick) {
            try { & $taskState.Tick } catch { }
        }

        if (-not $taskState.Handle.IsCompleted) { return }

        $taskState.Timer.Stop()

        try {
            if ($taskState.Ps.HadErrors -and $taskState.Ps.Streams.Error.Count -gt 0) {
                $err = $taskState.Ps.Streams.Error[0]
                if ($taskState.Error) {
                    try { & $taskState.Error $err } catch { }
                }
            }
            else {
                $output = $taskState.Ps.EndInvoke($taskState.Handle)
                if ($taskState.Success) {
                    try { & $taskState.Success $output } catch { }
                }
            }
        }
        catch {
            if ($taskState.Error) {
                try { & $taskState.Error $_ } catch { }
            }
        }
        finally {
            try { $taskState.Ps.Dispose() } catch { }
            try { $taskState.Rs.Dispose() } catch { }
        }
    }.GetNewClosure()

    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [System.TimeSpan]::FromMilliseconds(200)
    $timer.Add_Tick($timerTick)

    # Assign timer into shared state AFTER closure creation (GetNewClosure captured
    # the $taskState hashtable reference, not a copy, so this assignment is visible)
    $taskState.Timer = $timer
    $timer.Start()
}
#endregion Background task helper

function Ensure-OpsInsightsModuleLoaded {
    param(
        [switch]$Force
    )

    if (-not $script:OpsInsightsManifest) {
        throw "OpsInsights module manifest path is unavailable."
    }
    if (-not (Test-Path -LiteralPath $script:OpsInsightsManifest)) {
        throw "OpsInsights module manifest not found at '$script:OpsInsightsManifest'."
    }

    if ($Force -or (-not (Get-Module -Name 'GenesysCloud.OpsInsights'))) {
        Import-Module -Name $script:OpsInsightsManifest -Force -ErrorAction Stop
    }

    if ($Force -or (-not (Get-Module -Name 'GenesysCloud.OpsInsights.Core'))) {
        if ($script:OpsInsightsCoreManifest -and (Test-Path -LiteralPath $script:OpsInsightsCoreManifest)) {
            Import-Module -Name $script:OpsInsightsCoreManifest -Force -ErrorAction Stop
        }
        else {
            Write-Verbose "OpsInsights core manifest missing or unavailable at '$script:OpsInsightsCoreManifest'."
        }
    }

    if (-not (Get-Command -Name 'Invoke-GCInsightPack' -ErrorAction SilentlyContinue)) {
        Load-OpsInsightsScripts
    }
}

# Fail fast with a clear message when the UI is launched without the bundled modules available.
try {
    Ensure-OpsInsightsModuleLoaded
}
catch {
    $msg = "Failed to load required OpsInsights modules: $($_.Exception.Message)`n`nLaunch this app using the repo entrypoint script:`n  .\\GenesysCloudAPIExplorer.ps1"
    try { Write-TraceLog $msg } catch { }
    try { [System.Windows.MessageBox]::Show($msg, "Startup Error", "OK", "Error") | Out-Null } catch { }
    throw
}

function Ensure-OpsInsightsContext {
    $token = Get-ExplorerAccessToken
    if ([string]::IsNullOrWhiteSpace($token)) {
        throw "Please provide an OAuth token before running Insight Packs."
    }

    # Callback invoked by Invoke-GCRequest when a 401 is received (DEF-010).
    # Marshals the auth-expiry notification back to the WPF dispatcher thread.
    $authExpiredCallback = {
        try {
            $script:TokenValidated = $false
            if ($Window -and $Window.Dispatcher) {
                $Window.Dispatcher.Invoke([Action]{
                    Update-AuthUiState
                    if ($tokenStatusText) {
                        $tokenStatusText.Text = 'Token Expired'
                        $tokenStatusText.Foreground = 'Red'
                    }
                }, [System.Windows.Threading.DispatcherPriority]::Background)
            }
        }
        catch { }
    }

    try {
        Connect-GCCloud -RegionDomain $script:Region -AccessToken ($token.Trim()) | Out-Null
        Set-GCContext -ApiBaseUri $ApiBaseUrl -AccessToken ($token.Trim()) -OnUnauthorized $authExpiredCallback | Out-Null
    }
    catch {
        # Last-resort: still configure the context directly so requests can proceed
        try { Set-GCContext -ApiBaseUri $ApiBaseUrl -AccessToken ($token.Trim()) -OnUnauthorized $authExpiredCallback | Out-Null } catch { }
    }
}

function Get-PropertyValueIgnoreCase {
    param(
        [Parameter(Mandatory)]
        $Object,
        [Parameter(Mandatory)]
        [string]$PropertyName
    )

    if (-not $Object) { return $null }
    foreach ($prop in $Object.PSObject.Properties) {
        try {
            if ($prop.Name.Equals($PropertyName, [System.StringComparison]::InvariantCultureIgnoreCase)) {
                return $prop.Value
            }
        }
        catch { }
    }

    return $null
}

function Get-FirstPropertyValue {
    param(
        [Parameter(Mandatory)]
        $Object,
        [Parameter(Mandatory)]
        [string[]]$PropertyNames
    )

    foreach ($name in $PropertyNames) {
        $value = Get-PropertyValueIgnoreCase -Object $Object -PropertyName $name
        if ($null -ne $value) { return $value }
    }

    return $null
}

function Resolve-DashboardRecordTimestamp {
    param([object]$Record)

    if (-not $Record) { return [datetime]::MinValue }

    $timestamps = New-Object System.Collections.ArrayList
    foreach ($name in @('GeneratedAt','Timestamp','UpdatedAt','StartUtc','EndUtc','CreatedAt')) {
        $value = Get-PropertyValueIgnoreCase -Object $Record -PropertyName $name
        if ($value) {
            $timestamps.Add($value) | Out-Null
        }
    }

    $interval = Get-PropertyValueIgnoreCase -Object $Record -PropertyName 'Interval'
    if ($interval) {
        foreach ($name in @('StartUtc','Start','Begin','StartedAt')) {
            $value = Get-PropertyValueIgnoreCase -Object $interval -PropertyName $name
            if ($value) {
                $timestamps.Add($value) | Out-Null
            }
        }
    }

    foreach ($candidate in $timestamps) {
        if (-not $candidate) { continue }
        $text = [string]$candidate
        if ([string]::IsNullOrWhiteSpace($text)) { continue }
        try {
            return [datetime]::Parse($text)
        }
        catch { }
    }

    return [datetime]::MinValue
}

function Try-ConvertToDouble {
    param($Value)

    $output = 0.0
    if ($null -eq $Value) { return $output }
    [double]::TryParse([string]$Value, [ref]$output) | Out-Null
    return $output
}

function Get-LatestDashboardRecord {
    param(
        [System.Collections.IEnumerable]$Records,
        [string]$Type,
        [scriptblock]$Fallback
    )

    if (-not $Records) { return $null }

    $matches = New-Object System.Collections.ArrayList
    foreach ($rec in @($Records)) {
        if (-not $rec) { continue }
        $recType = Get-PropertyValueIgnoreCase -Object $rec -PropertyName 'Type'
        $matched = $false
        if ($recType) {
            try {
                if ([string]::IsNullOrWhiteSpace($Type)) {
                    $matched = $true
                }
                elseif ($recType.Equals($Type, [System.StringComparison]::InvariantCultureIgnoreCase)) {
                    $matched = $true
                }
                elseif ($recType.IndexOf($Type, [System.StringComparison]::InvariantCultureIgnoreCase) -ge 0) {
                    $matched = $true
                }
            }
            catch { }
        }
        if ($matched) {
            $matches.Add($rec) | Out-Null
            continue
        }

        if ($Fallback) {
            try {
                if ($Fallback.Invoke($rec)) {
                    $matches.Add($rec) | Out-Null
                }
            }
            catch { }
        }
    }

    if ($matches.Count -eq 0) { return $null }

    return $matches |
        Sort-Object -Property @{ Expression = { Resolve-DashboardRecordTimestamp -Record $_ }; Descending = $true } |
        Select-Object -First 1
}

function Read-OperationsDashboardStoreRecords {
    param([string]$Path)

    if (-not $Path) { return @() }
    if (-not (Test-Path -LiteralPath $Path)) { return @() }

    try {
        $content = Get-Content -LiteralPath $Path -Raw -Encoding utf8
    }
    catch {
        Write-TraceLog "Read-OperationsDashboardStoreRecords: unable to read '$Path': $($_.Exception.Message)"
        throw
    }

    if ([string]::IsNullOrWhiteSpace($content)) { return @() }

    $records = New-Object System.Collections.Generic.List[object]
    try {
        $parsed = $content | ConvertFrom-Json -Depth 5
        if ($parsed) {
            if ($parsed -is [System.Collections.IEnumerable]) {
                foreach ($entry in @($parsed)) {
                    if ($entry) { $records.Add($entry) | Out-Null }
                }
            }
            else {
                $records.Add($parsed) | Out-Null
            }
        }
        if ($records.Count -gt 0) { return $records }
    }
    catch { }

    foreach ($line in ($content -split '[\r\n]+')) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try {
            $entry = $line | ConvertFrom-Json -Depth 5
            if ($entry) { $records.Add($entry) | Out-Null }
        }
        catch {
            Write-TraceLog "Read-OperationsDashboardStoreRecords: skipped invalid record in '$Path': $($_.Exception.Message)"
        }
    }

    return $records
}

function Format-MosValue {
    param($Value)

    if ($null -eq $Value) { return '-' }
    try {
        $numeric = [double]$Value
        return "{0:N2}" -f $numeric
    }
    catch {
        return [string]$Value
    }
}

function Refresh-OperationsDashboardData {
    param([string]$StorePath)

    $path = if ($StorePath) { $StorePath } elseif ($script:OperationsDashboardStorePath) { $script:OperationsDashboardStorePath } else { Get-OperationsDashboardStorePath }
    $script:OperationsDashboardStorePath = $path
    if ($script:OpsDashboardStorePathText) { $script:OpsDashboardStorePathText.Text = $path }
    if ($script:OpsDashboardStatusText) { $script:OpsDashboardStatusText.Text = "Reading dashboard store..." }

    try {
        $records = Read-OperationsDashboardStoreRecords -Path $path
    }
    catch {
        $message = "Unable to read dashboard store: $($_.Exception.Message)"
        if ($script:OpsDashboardStatusText) { $script:OpsDashboardStatusText.Text = $message }
        Add-LogEntry $message
        return
    }

    $script:OperationsDashboardLastRefresh = Get-Date

    $mosRecord = Get-LatestDashboardRecord -Records $records -Type 'mos-by-division' -Fallback {
        param($rec)
        if ($rec -and $rec.PSObject.Properties.Name -contains 'Divisions' -and @($rec.Divisions).Count -gt 0) { return $true }
        return $false
    }
    $daRecord = Get-LatestDashboardRecord -Records $records -Type 'dataActions.failures' -Fallback {
        param($rec)
        if ($rec -and ($rec.PSObject.Properties.Name -contains 'ByAction' -or $rec.PSObject.Properties.Name -contains 'Actions' -or $rec.PSObject.Properties.Name -contains 'DataActions')) { return $true }
        return $false
    }
    $webRtcRecord = Get-LatestDashboardRecord -Records $records -Type 'webrtc-disconnects' -Fallback {
        param($rec)
        if ($rec -and ($rec.PSObject.Properties.Name -contains 'QueueSummary' -or $rec.PSObject.Properties.Name -contains 'Disconnects')) { return $true }
        return $false
    }

    $script:OperationsDashboardMosCollection.Clear()
    $divisions = New-Object System.Collections.ArrayList
    if ($mosRecord) {
        foreach ($propName in @('Divisions','DivisionMetrics','Division')) {
            if ($mosRecord.PSObject.Properties.Name -contains $propName) {
                foreach ($item in @($mosRecord.$propName)) {
                    $divisions.Add($item) | Out-Null
                }
            }
        }
    }
    foreach ($division in $divisions) {
        $divisionName = Get-FirstPropertyValue -Object $division -PropertyNames @('DivisionName','Name','DivisionId','Id')
        if (-not $divisionName) { $divisionName = '(unknown)' }
        $mos = Format-MosValue -Value (Get-FirstPropertyValue -Object $division -PropertyNames @('MosAverage','MOS','Mos','Mean'))
        $callVolume = Get-FirstPropertyValue -Object $division -PropertyNames @('CallVolume','CallCount','Volume','TotalCalls')
        $callVolume = if ($callVolume) { [string]$callVolume } else { '-' }
        $notes = Get-FirstPropertyValue -Object $division -PropertyNames @('Notes','Summary','Remarks')

        $script:OperationsDashboardMosCollection.Add([pscustomobject]@{
            Division   = $divisionName
            Mos        = $mos
            CallVolume = $callVolume
            Notes      = if ($notes) { [string]$notes } else { '' }
        }) | Out-Null
    }
    if ($script:OperationsDashboardMosCollection.Count -eq 0) {
        $script:OperationsDashboardMosCollection.Add([pscustomobject]@{
            Division   = '(no MOS data)'
            Mos        = '-'
            CallVolume = '-'
            Notes      = 'Run the ingestion pipeline to populate MOS metrics.'
        }) | Out-Null
    }

    $script:OperationsDashboardDataActionCollection.Clear()
    $actionRows = New-Object System.Collections.ArrayList
    if ($daRecord) {
        foreach ($propName in @('ByAction','Actions','DataActions')) {
            if ($daRecord.PSObject.Properties.Name -contains $propName) {
                foreach ($item in @($daRecord.$propName)) {
                    $actionRows.Add($item) | Out-Null
                }
            }
        }
    }
    foreach ($entry in $actionRows) {
        $actionName = Get-FirstPropertyValue -Object $entry -PropertyNames @('DataAction','Action','Name','DataActionName')
        if (-not $actionName) { $actionName = '(unknown)' }
        $successValue = Try-ConvertToDouble (Get-FirstPropertyValue -Object $entry -PropertyNames @('SuccessCount','Success','Successes','SuccessfulCount'))
        $failureValue = Try-ConvertToDouble (Get-FirstPropertyValue -Object $entry -PropertyNames @('FailureCount','Failures','FailedCount','ErrorCount'))
        $totalValue = Try-ConvertToDouble (Get-FirstPropertyValue -Object $entry -PropertyNames @('Total','TotalCount','ConversationCount'))
        $successRate = '-'
        if ($totalValue -gt 0) {
            $successRate = "{0:P1}" -f ($successValue / $totalValue)
        }
        $lastError = Get-FirstPropertyValue -Object $entry -PropertyNames @('LastError','LastErrorMessage','ErrorSummary','ErrorCode')

        $script:OperationsDashboardDataActionCollection.Add([pscustomobject]@{
            DataAction  = [string]$actionName
            SuccessRate = $successRate
            Failures    = if ($failureValue -gt 0) { [string]$failureValue } else { '-' }
            LastError   = if ($lastError) { [string]$lastError } else { '-' }
        }) | Out-Null
    }
    if ($script:OperationsDashboardDataActionCollection.Count -eq 0) {
        $script:OperationsDashboardDataActionCollection.Add([pscustomobject]@{
            DataAction  = '(no DataAction data)'
            SuccessRate = '-'
            Failures    = '-'
            LastError   = 'Run the DataAction insight pack to capture performance metrics.'
        }) | Out-Null
    }

    $summaryPieces = New-Object System.Collections.Generic.List[string]
    if ($daRecord) {
        $totalSummary = Get-FirstPropertyValue -Object $daRecord -PropertyNames @('Total','TotalCount','ConversationCount')
        $successSummary = Get-FirstPropertyValue -Object $daRecord -PropertyNames @('Success','SuccessCount','SuccessfulCount')
        $failureSummary = Get-FirstPropertyValue -Object $daRecord -PropertyNames @('Failure','FailureCount','FailedCount')
        if ($successSummary) { $summaryPieces.Add("Successes: $successSummary") | Out-Null }
        if ($failureSummary) { $summaryPieces.Add("Failures: $failureSummary") | Out-Null }
        if ($totalSummary) { $summaryPieces.Add("Total: $totalSummary") | Out-Null }
    }
    if ($summaryPieces.Count -eq 0) {
        if ($script:OperationsDashboardDataActionSummaryText) {
            $script:OperationsDashboardDataActionSummaryText.Text = 'DataAction summary unavailable.'
        }
    }
    else {
        if ($script:OperationsDashboardDataActionSummaryText) {
            $script:OperationsDashboardDataActionSummaryText.Text = ($summaryPieces -join '; ')
        }
    }

    $script:OperationsDashboardWebRtcCollection.Clear()
    $webRtcRows = New-Object System.Collections.ArrayList
    if ($webRtcRecord) {
        foreach ($propName in @('QueueSummary','DisconnectsByQueue','Queues','Disconnects')) {
            if ($webRtcRecord.PSObject.Properties.Name -contains $propName) {
                foreach ($item in @($webRtcRecord.$propName)) {
                    $webRtcRows.Add($item) | Out-Null
                }
            }
        }
    }
    foreach ($row in $webRtcRows) {
        $queue = Get-FirstPropertyValue -Object $row -PropertyNames @('QueueName','Queue','QueueId')
        if (-not $queue) { $queue = '(unknown queue)' }
        $disconnects = Get-FirstPropertyValue -Object $row -PropertyNames @('Count','Disconnects','Total')
        $disconnects = if ($disconnects) { [string]$disconnects } else { '-' }
        $reason = Get-FirstPropertyValue -Object $row -PropertyNames @('ReasonSummary','Reason','DisconnectType','ErrorCode')

        $script:OperationsDashboardWebRtcCollection.Add([pscustomobject]@{
            Queue         = [string]$queue
            Disconnects   = [string]$disconnects
            ReasonSummary = if ($reason) { [string]$reason } else { '-' }
        }) | Out-Null
    }
    if ($script:OperationsDashboardWebRtcCollection.Count -eq 0) {
        $script:OperationsDashboardWebRtcCollection.Add([pscustomobject]@{
            Queue         = '(no WebRTC data)'
            Disconnects   = '-'
            ReasonSummary = 'Run the WebRTC disconnect insight pack to capture spikes.'
        }) | Out-Null
    }

    if ($script:OperationsDashboardWebRtcSummaryText) {
        if ($webRtcRecord) {
            $intervalStart = Get-FirstPropertyValue -Object $webRtcRecord -PropertyNames @('StartUtc','IntervalStart','Start')
            $intervalEnd = Get-FirstPropertyValue -Object $webRtcRecord -PropertyNames @('EndUtc','IntervalEnd','End')
            $totalDisconnects = Get-FirstPropertyValue -Object $webRtcRecord -PropertyNames @('Total','TotalCount','ConversationCount')
            $parts = New-Object System.Collections.Generic.List[string]
            if ($intervalStart) { $parts.Add("Start: $intervalStart") | Out-Null }
            if ($intervalEnd) { $parts.Add("End: $intervalEnd") | Out-Null }
            if ($totalDisconnects) { $parts.Add("Total: $totalDisconnects disconnects") | Out-Null }
            $script:OperationsDashboardWebRtcSummaryText.Text = ($parts -join ' | ')
        }
        else {
            $script:OperationsDashboardWebRtcSummaryText.Text = 'WebRTC disconnect summary unavailable.'
        }
    }

    if ($script:OpsDashboardStatusText) {
        $elapsed = $script:OperationsDashboardLastRefresh.ToString('yyyy-MM-dd HH:mm:ss')
        $recordsCount = $records.Count
        $script:OpsDashboardStatusText.Text = "Dashboard refreshed at $elapsed ($recordsCount records)."
    }

    $script:OperationsDashboardRecords = $records
    Refresh-OperationsTimelineEntries
}

function Initialize-OperationsDashboardFilters {
    $now = (Get-Date).ToUniversalTime()
    $script:OperationsDashboardFilters = @{
        StartUtc          = $now.AddHours(-1)
        EndUtc            = $now
        Division          = ''
        Queue             = ''
        DisconnectReason  = ''
        SipError          = ''
        DataAction        = ''
        MosThreshold      = 3.5
    }

    if ($opsDashboardMosThresholdSlider) {
        $opsDashboardMosThresholdSlider.Value = $script:OperationsDashboardFilters.MosThreshold
    }
    if ($opsDashboardMosThresholdText) {
        $opsDashboardMosThresholdText.Text = "{0:N2}" -f $script:OperationsDashboardFilters.MosThreshold
    }

    Update-OperationsDashboardFilterInputs
}

function Update-OperationsDashboardFilterInputs {
    if ($opsDashboardStartInput) {
        $opsDashboardStartInput.Text = $script:OperationsDashboardFilters.StartUtc.ToString("yyyy-MM-ddTHH:mm:ssZ")
    }
    if ($opsDashboardEndInput) {
        $opsDashboardEndInput.Text = $script:OperationsDashboardFilters.EndUtc.ToString("yyyy-MM-ddTHH:mm:ssZ")
    }
    if ($opsDashboardDivisionFilterInput) {
        $opsDashboardDivisionFilterInput.Text = $script:OperationsDashboardFilters.Division
    }
    if ($opsDashboardQueueFilterInput) {
        $opsDashboardQueueFilterInput.Text = $script:OperationsDashboardFilters.Queue
    }
    if ($opsDashboardDisconnectReasonInput) {
        $opsDashboardDisconnectReasonInput.Text = $script:OperationsDashboardFilters.DisconnectReason
    }
    if ($opsDashboardSipErrorFilterInput) {
        $opsDashboardSipErrorFilterInput.Text = $script:OperationsDashboardFilters.SipError
    }
    if ($opsDashboardDataActionFilterInput) {
        $opsDashboardDataActionFilterInput.Text = $script:OperationsDashboardFilters.DataAction
    }
}

function Update-OperationsDashboardFiltersFromUi {
    $filters = $script:OperationsDashboardFilters
    if (-not $filters) { Initialize-OperationsDashboardFilters; $filters = $script:OperationsDashboardFilters }

    if ($opsDashboardStartInput -and -not [string]::IsNullOrWhiteSpace($opsDashboardStartInput.Text)) {
        try {
            $filters.StartUtc = [datetime]::Parse($opsDashboardStartInput.Text).ToUniversalTime()
        }
        catch { }
    }
    if ($opsDashboardEndInput -and -not [string]::IsNullOrWhiteSpace($opsDashboardEndInput.Text)) {
        try {
            $filters.EndUtc = [datetime]::Parse($opsDashboardEndInput.Text).ToUniversalTime()
        }
        catch { }
    }

    if ($opsDashboardDivisionFilterInput) {
        $filters.Division = $opsDashboardDivisionFilterInput.Text
    }
    if ($opsDashboardQueueFilterInput) {
        $filters.Queue = $opsDashboardQueueFilterInput.Text
    }
    if ($opsDashboardDisconnectReasonInput) {
        $filters.DisconnectReason = $opsDashboardDisconnectReasonInput.Text
    }
    if ($opsDashboardSipErrorFilterInput) {
        $filters.SipError = $opsDashboardSipErrorFilterInput.Text
    }
    if ($opsDashboardDataActionFilterInput) {
        $filters.DataAction = $opsDashboardDataActionFilterInput.Text
    }
    if ($opsDashboardMosThresholdSlider) {
        $filters.MosThreshold = [math]::Round([double]$opsDashboardMosThresholdSlider.Value, 2)
        if ($opsDashboardMosThresholdText) {
            $opsDashboardMosThresholdText.Text = "{0:N2}" -f $filters.MosThreshold
        }
    }

    $script:OperationsDashboardFilters = $filters
}

function Build-OperationsTimelineEntries {
    param([System.Collections.IEnumerable]$Records)

    $entries = New-Object System.Collections.ArrayList
    foreach ($rec in @($Records)) {
        if (-not $rec) { continue }
        $type = Get-PropertyValueIgnoreCase -Object $rec -PropertyName 'Type'
        $ts = Resolve-DashboardRecordTimestamp -Record $rec
        if (-not $ts -or $ts -eq [datetime]::MinValue) {
            $ts = Get-Date
        }

        switch ($type) {
            'mos-by-division' {
                $divisions = @()
                foreach ($prop in @('Divisions','DivisionMetrics','Division')) {
                    if ($rec.PSObject.Properties.Name -contains $prop) {
                        $divisions += @($rec.$prop)
                    }
                }
                foreach ($division in $divisions) {
                    $name = Get-FirstPropertyValue -Object $division -PropertyNames @('DivisionName','Name','DivisionId','Id')
                    if (-not $name) { $name = '(unknown)' }
                    $mos = Try-ConvertToDouble (Get-FirstPropertyValue -Object $division -PropertyNames @('MosAverage','MOS','Mos','Mean'))
                    $callVolume = Get-FirstPropertyValue -Object $division -PropertyNames @('CallVolume','CallCount','Volume','TotalCalls')
                    $category = if ($mos -gt 0 -and $mos -lt $script:OperationsDashboardFilters.MosThreshold) { 'MOS degradation' } else { 'MOS' }
                    $details = "Volume: $([string]$callVolume); Notes: $([string](Get-FirstPropertyValue -Object $division -PropertyNames @('Notes','Summary','Remarks')))"
                    $entries.Add([pscustomobject]@{
                        TimestampValue   = $ts
                        Timestamp        = $ts.ToString("yyyy-MM-dd HH:mm:ss")
                        Source           = 'MOS Rollup'
                        Category         = $category
                        Summary          = "$name MOS {0:N2}" -f $mos
                        Details          = $details
                        FilterDivision   = $name
                        FilterQueue      = ''
                        FilterDisconnect = ''
                        FilterDataAction = ''
                        MosValue         = $mos
                    }) | Out-Null
                }
            }
            'dataActions.failures' {
                $actions = @()
                foreach ($prop in @('ByAction','Actions','DataActions')) {
                    if ($rec.PSObject.Properties.Name -contains $prop) {
                        $actions += @($rec.$prop)
                    }
                }
                foreach ($action in $actions) {
                    $name = Get-FirstPropertyValue -Object $action -PropertyNames @('DataAction','Action','Name','DataActionName')
                    if (-not $name) { $name = '(unknown)' }
                    $failureCount = Try-ConvertToDouble (Get-FirstPropertyValue -Object $action -PropertyNames @('FailureCount','Failures','FailedCount','ErrorCount'))
                    $successCount = Try-ConvertToDouble (Get-FirstPropertyValue -Object $action -PropertyNames @('SuccessCount','Success','Successes','SuccessfulCount'))
                    $total = Try-ConvertToDouble (Get-FirstPropertyValue -Object $action -PropertyNames @('Total','TotalCount','ConversationCount'))
                    $lastError = Get-FirstPropertyValue -Object $action -PropertyNames @('LastError','LastErrorMessage','ErrorSummary','ErrorCode')
                    $successRate = '-'
                    if ($total -gt 0) { $successRate = "{0:P1}" -f ($successCount / $total) }
                    $details = "Failures: $failureCount; Last: $([string]$lastError)"
                    $entries.Add([pscustomobject]@{
                        TimestampValue = $ts
                        Timestamp      = $ts.ToString("yyyy-MM-dd HH:mm:ss")
                        Source         = 'DataAction'
                        Category       = if ($failureCount -gt 0) { 'Failing' } else { 'Success' }
                        Summary        = "$name success $successRate"
                        Details        = $details
                        FilterDivision   = ''
                        FilterQueue      = ''
                        FilterDisconnect = [string]$lastError
                        FilterDataAction = $name
                    }) | Out-Null
                }
            }
            'webrtc-disconnects' {
                $queues = @()
                foreach ($prop in @('QueueSummary','DisconnectsByQueue','Queues','Disconnects')) {
                    if ($rec.PSObject.Properties.Name -contains $prop) {
                        $queues += @($rec.$prop)
                    }
                }
                foreach ($queue in $queues) {
                    $name = Get-FirstPropertyValue -Object $queue -PropertyNames @('QueueName','Queue','QueueId')
                    if (-not $name) { $name = '(unknown queue)' }
                    $count = Get-FirstPropertyValue -Object $queue -PropertyNames @('Count','Disconnects','Total')
                    $reason = Get-FirstPropertyValue -Object $queue -PropertyNames @('ReasonSummary','Reason','DisconnectType','ErrorCode')
                    $details = "Disconnects: $([string]$count); Reason: $([string]$reason)"
                    $entries.Add([pscustomobject]@{
                        TimestampValue   = $ts
                        Timestamp        = $ts.ToString("yyyy-MM-dd HH:mm:ss")
                        Source           = 'WebRTC'
                        Category         = 'Disconnects'
                        Summary          = "$name $([string]$count) disconnects"
                        Details          = $details
                        FilterDivision   = ''
                        FilterQueue      = $name
                        FilterDisconnect = [string]$reason
                        FilterDataAction = ''
                    }) | Out-Null
                }
            }
            'conversation.details' {
                $convId = Get-FirstPropertyValue -Object $rec -PropertyNames @('ConversationId','conversationId')
                $division = Get-FirstPropertyValue -Object $rec -PropertyNames @('DivisionId','divisionId')
                $detail = $rec.Content
                $mos = $null
                $errorCode = $null
                $queue = ''
                if ($detail) {
                    if ($detail.conversationMetrics -and $detail.conversationMetrics.averageMos) {
                        $mos = Try-ConvertToDouble $detail.conversationMetrics.averageMos
                    }
                    if ($detail.PSObject.Properties.Name -contains 'errorCode') {
                        $errorCode = $detail.errorCode
                    }
                    elseif ($detail.PSObject.Properties.Name -contains 'diagnostics') {
                        $errorCode = $detail.diagnostics.errorCode
                    }
                    foreach ($p in @($detail.participants)) {
                        foreach ($s in @($p.sessions)) {
                            if ($s.queueId) { $queue = $s.queueId }
                            foreach ($seg in @($s.segments)) {
                                if ($seg.queueId) { $queue = $seg.queueId }
                                if (-not $errorCode -and $seg.errorCode) { $errorCode = $seg.errorCode }
                            }
                        }
                    }
                }
                $summaryParts = @()
                if ($mos) { $summaryParts += ("MOS {0:N2}" -f $mos) }
                if ($errorCode) { $summaryParts += "Error $errorCode" }
                if ($summaryParts.Count -eq 0) { $summaryParts += 'Details captured' }
                $entries.Add([pscustomobject]@{
                    TimestampValue   = $ts
                    Timestamp        = $ts.ToString("yyyy-MM-dd HH:mm:ss")
                    Source           = 'Conversation'
                    Category         = 'Conversation'
                    Summary          = "$($convId): $($summaryParts -join ' | ')"
                    Details          = "Division: $division; Queue: $queue; Error: $errorCode"
                    FilterDivision   = [string]$division
                    FilterQueue      = [string]$queue
                    FilterDisconnect = [string]$errorCode
                    FilterDataAction = ''
                    MosValue         = $mos
                }) | Out-Null
            }
            Default {
                $entries.Add([pscustomobject]@{
                    TimestampValue   = $ts
                    Timestamp        = $ts.ToString("yyyy-MM-dd HH:mm:ss")
                    Source           = 'Store'
                    Category         = $type
                    Summary          = "Record: $type"
                    Details          = "Generated: $([string](Get-FirstPropertyValue -Object $rec -PropertyNames @('GeneratedAt','StartUtc','Interval')))"
                    FilterDivision   = ''
                    FilterQueue      = ''
                    FilterDisconnect = ''
                    FilterDataAction = ''
                }) | Out-Null
            }
        }
    }

    return $entries
}

function Refresh-OperationsTimelineEntries {
    if (-not $script:OperationsDashboardRecords) { return }
    $entries = Build-OperationsTimelineEntries -Records $script:OperationsDashboardRecords
    $filters = $script:OperationsDashboardFilters
    $start = if ($filters.StartUtc) { $filters.StartUtc } else { (Get-Date).AddHours(-1) }
    $end = if ($filters.EndUtc) { $filters.EndUtc } else { Get-Date }
    $divisionFilter = if ($filters.Division) { [string]$filters.Division } else { '' }
    $queueFilter = if ($filters.Queue) { [string]$filters.Queue } else { '' }
    $disconnectFilter = if ($filters.DisconnectReason) { [string]$filters.DisconnectReason } else { '' }
    $sipFilter = if ($filters.SipError) { [string]$filters.SipError } else { '' }
    $actionFilter = if ($filters.DataAction) { [string]$filters.DataAction } else { '' }

    $matches = foreach ($entry in @($entries)) {
        $ts = if ($entry.TimestampValue) { $entry.TimestampValue } else {
            try { [datetime]::Parse($entry.Timestamp) } catch { $null }
        }
        if (-not $ts) { continue }
        if ($ts -lt $start -or $ts -gt $end) { continue }
        if ($divisionFilter -and $divisionFilter -ne '' -and -not ([string]$entry.FilterDivision).Contains($divisionFilter, [System.StringComparison]::InvariantCultureIgnoreCase)) { continue }
        if ($queueFilter -and $queueFilter -ne '' -and -not ([string]$entry.FilterQueue).Contains($queueFilter, [System.StringComparison]::InvariantCultureIgnoreCase)) { continue }
        if ($disconnectFilter -and $disconnectFilter -ne '' -and -not ([string]$entry.FilterDisconnect).Contains($disconnectFilter, [System.StringComparison]::InvariantCultureIgnoreCase)) { continue }
        if ($sipFilter -and $sipFilter -ne '' -and -not ([string]$entry.FilterDisconnect).Contains($sipFilter, [System.StringComparison]::InvariantCultureIgnoreCase)) { continue }
        if ($actionFilter -and $actionFilter -ne '' -and -not ([string]$entry.FilterDataAction).Contains($actionFilter, [System.StringComparison]::InvariantCultureIgnoreCase)) { continue }
        if ($filters.MosThreshold -and $entry.MosValue) {
            if ([double]$entry.MosValue -ge [double]$filters.MosThreshold -and $entry.Source -eq 'MOS Rollup') { continue }
        }
        $entry
    }

    $script:OperationsTimelineEntries.Clear()
    foreach ($entry in $matches) { $script:OperationsTimelineEntries.Add($entry) | Out-Null }

    if ($forensicTimelineSummaryText) {
        $count = $script:OperationsTimelineEntries.Count
        $startText = if ($start) { $start.ToString('HH:mm') } else { '-' }
        $endText = if ($end) { $end.ToString('HH:mm') } else { '-' }
        $forensicTimelineSummaryText.Text = "Showing $count forensic events for $startText-$endText UTC"
    }
    if ($forensicTimelineStatusText) {
        $forensicTimelineStatusText.Text = "Last refreshed at $(Get-Date -Format 'HH:mm:ss')"
    }
}

function Investigate-SelectedTimelineEntry {
    $entry = if ($operationsTimelineList) { $operationsTimelineList.SelectedItem } else { $null }
    if (-not $entry) {
        if ($script:OpsDashboardStatusText) {
            $script:OpsDashboardStatusText.Text = "Select a timeline event before investigating."
        }
        return
    }

    $filters = @()
    if ($entry.FilterDivision) { $filters += "Division=$($entry.FilterDivision)" }
    if ($entry.FilterQueue) { $filters += "Queue=$($entry.FilterQueue)" }
    if ($entry.FilterDisconnect) { $filters += "Reason=$($entry.FilterDisconnect)" }
    if ($entry.FilterDataAction) { $filters += "DataAction=$($entry.FilterDataAction)" }
    $message = "Investigating $($entry.Source) / $($entry.Category). Filters: $([string]::Join('; ', $filters))"
    if ($script:OpsDashboardStatusText) {
        $script:OpsDashboardStatusText.Text = $message
    }
}

function Export-SelectedTimelineEntry {
    $entry = if ($operationsTimelineList) { $operationsTimelineList.SelectedItem } else { $null }
    if (-not $entry) {
        if ($script:OpsDashboardStatusText) {
            $script:OpsDashboardStatusText.Text = "Select a timeline event before exporting."
        }
        return
    }

    $dialog = New-Object Microsoft.Win32.SaveFileDialog
    $dialog.Filter = "JSON Files (*.json)|*.json|All Files (*.*)|*.*"
    $dialog.FileName = "ForensicEvent_$((Get-Date).ToString('yyyyMMdd_HHmmss')).json"
    if ($dialog.ShowDialog() -eq $true) {
        ($entry | ConvertTo-Json -Depth 5) | Set-Content -LiteralPath $dialog.FileName -Encoding utf8
        if ($script:OpsDashboardStatusText) {
            $script:OpsDashboardStatusText.Text = "Timeline event exported to $($dialog.FileName)"
        }
    }
}

function Save-CollectionAsCsv {
    param(
        [System.Collections.IEnumerable]$Rows,
        [string[]]$Columns,
        [string]$DialogTitle,
        [string]$DefaultFileName
    )

    if (-not $Rows -or $Rows.Count -eq 0) {
        if ($script:OpsDashboardStatusText) {
            $script:OpsDashboardStatusText.Text = "$DialogTitle has no rows to export."
        }
        return $false
    }

    $dialog = New-Object Microsoft.Win32.SaveFileDialog
    $dialog.Title = $DialogTitle
    $dialog.Filter = "CSV Files (*.csv)|*.csv|All Files (*.*)|*.*"
    $dialog.FileName = $DefaultFileName
    if ($dialog.ShowDialog() -ne $true) { return $false }

    $rowsToExport = @($Rows | Select-Object $Columns)
    try {
        $rowsToExport | Export-Csv -NoTypeInformation -Encoding utf8 -Path $dialog.FileName
        Add-LogEntry "$DialogTitle exported to $($dialog.FileName)"
        if ($script:OpsDashboardStatusText) {
            $script:OpsDashboardStatusText.Text = "$DialogTitle saved to $($dialog.FileName)"
        }
        return $true
    }
    catch {
        if ($script:OpsDashboardStatusText) {
            $script:OpsDashboardStatusText.Text = "$DialogTitle export failed: $($_.Exception.Message)"
        }
        Add-LogEntry "$DialogTitle export failed: $($_.Exception.Message)"
        return $false
    }
}

function Export-DivisionQosSummary {
    Save-CollectionAsCsv -Rows $script:OperationsDashboardMosCollection -Columns @('Division','Mos','CallVolume','Notes') -DialogTitle 'Division QoS Summary' -DefaultFileName 'DivisionQoS_Summary.csv'
}

function Export-WebRtcDisconnectReview {
    Save-CollectionAsCsv -Rows $script:OperationsDashboardWebRtcCollection -Columns @('Queue','Disconnects','ReasonSummary') -DialogTitle 'WebRTC Disconnect Review' -DefaultFileName 'WebRTC_DisconnectReview.csv'
}

function Export-DataActionReliability {
    Save-CollectionAsCsv -Rows $script:OperationsDashboardDataActionCollection -Columns @('DataAction','SuccessRate','Failures','LastError') -DialogTitle 'DataAction Reliability' -DefaultFileName 'DataAction_Reliability.csv'
}

function Export-IncidentPacket {
    $tempDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ("OpsIncident_{0:yyyyMMdd_HHmmss}" -f (Get-Date))
    $dialog = New-Object Microsoft.Win32.SaveFileDialog
    $dialog.Filter = "Zip Archives (*.zip)|*.zip|All Files (*.*)|*.*"
    $dialog.FileName = "IncidentPacket_{0:yyyyMMdd_HHmmss}.zip" -f (Get-Date)

    try {
        if (Test-Path -LiteralPath $tempDir) { Remove-Item -LiteralPath $tempDir -Recurse -Force }
        New-Item -ItemType Directory -Path $tempDir | Out-Null

        $storePath = $script:OperationsDashboardStorePath
        $storeIncluded = $false
        if ($storePath -and (Test-Path -LiteralPath $storePath)) {
            Copy-Item -LiteralPath $storePath -Destination (Join-Path -Path $tempDir -ChildPath 'dashboard-store.jsonl') -Force
            $storeIncluded = $true
        }
        else {
            $missingStorePath = Join-Path -Path $tempDir -ChildPath 'dashboard-store-missing.txt'
            "Dashboard store not found at '$storePath'." | Set-Content -LiteralPath $missingStorePath -Encoding utf8
            Add-LogEntry "Incident packet: dashboard store missing at '$storePath'."
        }

        $timelinePath = Join-Path -Path $tempDir -ChildPath 'timeline.csv'
        $timelineRows = @()
        if ($script:OperationsTimelineEntries.Count -gt 0) {
            $timelineRows = $script:OperationsTimelineEntries | Select-Object Timestamp,Source,Category,Summary,Details
        }
        else {
            $timelineRows = @([pscustomobject]@{
                Timestamp = ''
                Source    = 'Timeline'
                Category  = ''
                Summary   = 'No timeline entries for the selected filters.'
                Details   = ''
            })
        }
        $timelineRows | Export-Csv -NoTypeInformation -Path $timelinePath -Encoding utf8

        $summaryPath = Join-Path -Path $tempDir -ChildPath 'summary.json'
        [pscustomobject]@{
            Timestamp     = (Get-Date).ToString('o')
            Filters       = $script:OperationsDashboardFilters
            EventCount    = $script:OperationsTimelineEntries.Count
            StorePath     = $storePath
            StoreIncluded = $storeIncluded
        } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $summaryPath -Encoding utf8

        if ($dialog.ShowDialog() -ne $true) {
            return
        }

        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::CreateFromDirectory($tempDir, $dialog.FileName)

        if ($script:OpsDashboardStatusText) {
            $script:OpsDashboardStatusText.Text = "Incident packet exported to $($dialog.FileName)"
        }
        Add-LogEntry "Incident packet exported to $($dialog.FileName)"
    }
    catch {
        Add-LogEntry "Incident packet export failed: $($_.Exception.Message)"
        if ($script:OpsDashboardStatusText) {
            $script:OpsDashboardStatusText.Text = "Incident packet export failed: $($_.Exception.Message)"
        }
    }
    finally {
        if (Test-Path -LiteralPath $tempDir) {
            try {
                Remove-Item -LiteralPath $tempDir -Recurse -Force
            }
            catch {
                Add-LogEntry "Failed to clean up incident packet temp folder: $($_.Exception.Message)"
            }
        }
    }
}

$UserProfileBase = if ($env:USERPROFILE) { $env:USERPROFILE } else { $ScriptRoot }
$FavoritesFile = Join-Path -Path $UserProfileBase -ChildPath "GenesysApiExplorerFavorites.json"

$FavoritesData = Get-FavoritesFromDisk -Path $FavoritesFile
$Favorites = Build-FavoritesCollection -Source $FavoritesData

# Load templates at startup
$TemplatesFilePath = Join-Path -Path $UserProfileBase -ChildPath "GenesysApiExplorerTemplates.json"
$TemplatesData = Load-TemplatesFromDisk -Path $TemplatesFilePath

# If no user templates exist, load default templates
if (-not $TemplatesData -or $TemplatesData.Count -eq 0) {
    $DefaultTemplatesPath = Join-Path -Path $ScriptRoot -ChildPath "DefaultTemplates.json"
    if (Test-Path -Path $DefaultTemplatesPath) {
        try {
            $TemplatesData = Load-TemplatesFromDisk -Path $DefaultTemplatesPath
            if ($TemplatesData -and $TemplatesData.Count -gt 0) {
                # Save default templates to user's template file
                Save-TemplatesToDisk -Path $TemplatesFilePath -Templates $TemplatesData
                Write-Host "Initialized with $($TemplatesData.Count) default conversation templates."
            }
        }
        catch {
            Write-Warning "Could not load default templates from '$DefaultTemplatesPath': $($_.Exception.Message)"
        }
    }
}

# Load example POST bodies for conversations endpoints
$ExamplePostBodiesPath = Join-Path -Path $ScriptRoot -ChildPath "ExamplePostBodies.json"
$script:ExamplePostBodies = @{}
if (Test-Path -Path $ExamplePostBodiesPath) {
    try {
        $script:ExamplePostBodies = Get-Content -Path $ExamplePostBodiesPath -Raw | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        Write-Warning "Could not load example POST bodies from '$ExamplePostBodiesPath': $($_.Exception.Message)"
    }
}

function Get-ExamplePostBody {
    param (
        [string]$Path,
        [string]$Method
    )

    if (-not $script:ExamplePostBodies) { return $null }

    $methodLower = $Method.ToLower()

    # Check if this path and method has an example
    $pathData = $script:ExamplePostBodies.PSObject.Properties | Where-Object { $_.Name -eq $Path }
    if ($pathData -and $pathData.Value.$methodLower -and $pathData.Value.$methodLower.example) {
        return ($pathData.Value.$methodLower.example | ConvertTo-Json -Depth 10)
    }

    return $null
}
#endregion Feature tabs (Conversation, Audit, Live Sub, Ops Dash, etc.)
