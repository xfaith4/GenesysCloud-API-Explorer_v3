# Requires: Pester 5+

BeforeAll {
    . "$PSScriptRoot\TestHelpers.ps1"

    $script:RepoRoot = Get-TestRepoRoot -StartPath $PSScriptRoot
    $script:SourcePaths = Get-SourceScriptPaths -StartPath $PSScriptRoot
    $script:FunctionInventory = Get-SourceFunctionInventory -StartPath $PSScriptRoot -IncludeNested
}

Describe 'Source parser contracts' -Tag @('Contract', 'Exhaustive') {
    It 'discovers an exhaustive function inventory across app surfaces' {
        $script:FunctionInventory.Count | Should -BeGreaterThan 200
    }

    foreach ($sourcePath in $script:SourcePaths) {
        $relativePath = $sourcePath.Replace(($script:RepoRoot + '\'), '')

        It "parses with zero syntax errors [$relativePath]" {
            $parse = Get-AstParseInfo -Path $sourcePath
            $parse.Errors.Count | Should -Be 0
        }
    }

    foreach ($group in ($script:FunctionInventory | Group-Object -Property RelativePath)) {
        It "contains no duplicate function names in [$($group.Name)]" {
            $duplicates = $group.Group | Group-Object -Property Name | Where-Object { $_.Count -gt 1 }
            $duplicates.Count | Should -Be 0 -Because ($duplicates.Name -join ', ')
        }
    }

    foreach ($func in $script:FunctionInventory) {
        $name = $func.Name
        $relativePath = $func.RelativePath
        $line = $func.StartLine

        It "compiles function definition [$name] at ${relativePath}:$line" {
            { [void][scriptblock]::Create($func.Definition) } | Should -Not -Throw
            $name | Should -Match '^[A-Za-z][A-Za-z0-9]*-[A-Za-z][A-Za-z0-9]*$'
        }
    }
}

Describe 'Module public surface contracts' -Tag @('Contract', 'PublicSurface') {
    BeforeAll {
        Import-TestPrimaryModules -StartPath $PSScriptRoot
        $notificationsModulePath = Join-TestRepoPath -RelativePath 'Scripts/GenesysCloud.NotificationsToolkit/GenesysCloud.NotificationsToolkit.psm1' -StartPath $PSScriptRoot
        Import-Module -Name $notificationsModulePath -Force -Global -ErrorAction Stop

        $opsInsightsModule = Get-Module -All | Where-Object { $_.Name -eq 'GenesysCloud.OpsInsights' } | Select-Object -First 1
        $coreModule = Get-Module -All | Where-Object { $_.Name -eq 'GenesysCloud.OpsInsights.Core' } | Select-Object -First 1
        $opsConsoleModule = Get-Module -All | Where-Object { $_.Name -eq 'OpsConsole' } | Select-Object -First 1
        $notificationsModule = Get-Module -All | Where-Object { $_.Name -eq 'GenesysCloud.NotificationsToolkit' } | Select-Object -First 1

        $script:OpsInsightsCommands = @($opsInsightsModule.ExportedCommands.Values | Where-Object { $_.CommandType -eq 'Function' } | Sort-Object Name)
        $script:CoreCommands = @($coreModule.ExportedCommands.Values | Where-Object { $_.CommandType -eq 'Function' } | Sort-Object Name)
        $script:OpsConsoleCommands = @($opsConsoleModule.ExportedCommands.Values | Where-Object { $_.CommandType -eq 'Function' } | Sort-Object Name)
        $script:NotificationsCommands = @($notificationsModule.ExportedCommands.Values | Where-Object { $_.CommandType -eq 'Function' } | Sort-Object Name)
    }

    It 'loads expected module command surfaces' {
        $script:OpsInsightsCommands.Count | Should -BeGreaterThan 25
        $script:CoreCommands.Count | Should -BeGreaterThan 0
        $script:OpsConsoleCommands.Count | Should -BeGreaterThan 0
        $script:NotificationsCommands.Count | Should -BeGreaterThan 5
    }

    It 'exposes OpsConsole entrypoint' {
        $script:OpsConsoleCommands.Name | Should -Contain 'Start-GCOpsConsole'
    }

    It 'exposes core HTML exporter' {
        $script:CoreCommands.Name | Should -Contain 'Export-GCInsightPackHtml'
    }

    It 'exposes key OpsInsights commands' {
        $required = @(
            'Invoke-GCRequest',
            'Invoke-GCInsightPack',
            'Invoke-GCInsightPackCompare',
            'Invoke-GCInsightPackTest',
            'Get-GCConversationDetails',
            'Get-GCQueueWaitCoverage',
            'Invoke-GCConversationIngest',
            'Export-GCInsightBriefing',
            'Set-GCContext',
            'Get-GCContext'
        )

        foreach ($name in $required) {
            $script:OpsInsightsCommands.Name | Should -Contain $name
        }
    }

    It 'matches notifications manifest export list exactly' {
        $manifestPath = Join-TestRepoPath -RelativePath 'Scripts/GenesysCloud.NotificationsToolkit/GenesysCloud.NotificationsToolkit.psd1' -StartPath $PSScriptRoot
        $manifest = Import-PowerShellDataFile -LiteralPath $manifestPath
        $expected = @($manifest.FunctionsToExport)
        $actual = @($script:NotificationsCommands.Name)

        $missing = @($expected | Where-Object { $_ -notin $actual })
        $extra = @($actual | Where-Object { $_ -notin $expected })

        $missing.Count | Should -Be 0 -Because "Missing exports: $($missing -join ', ')"
        $extra.Count | Should -Be 0 -Because "Unexpected exports: $($extra -join ', ')"
    }

    $allCommands = @($script:OpsInsightsCommands + $script:CoreCommands + $script:OpsConsoleCommands + $script:NotificationsCommands) |
        Where-Object { $_ -and $_.Name }

    foreach ($cmd in $allCommands) {
        It "publishes command metadata for [$($cmd.Name)]" {
            $resolved = Get-Command -Name $cmd.Name -ErrorAction Stop
            $resolved | Should -Not -BeNullOrEmpty
            $resolved.Parameters.Count | Should -BeGreaterThan 0
        }
    }
}
