# Requires: Pester 5+

BeforeAll {
    . "$PSScriptRoot\TestHelpers.ps1"

    $script:RepoRoot = Get-TestRepoRoot -StartPath $PSScriptRoot
    $script:UiRunPath = Join-TestRepoPath -RelativePath 'apps/OpsConsole/Resources/UI/UI.Run.ps1' -StartPath $PSScriptRoot
    $script:XamlPath = Join-TestRepoPath -RelativePath 'apps/OpsConsole/Resources/UI/MainWindow.xaml' -StartPath $PSScriptRoot
    $script:FindNameTargets = Get-UiRunFindNameTargets -UiRunScriptPath $script:UiRunPath
    $script:XamlNamedTargets = Get-XamlNamedTargets -XamlPath $script:XamlPath
}

Describe 'OpsConsole UI contracts' -Tag @('UI', 'Contract') {
    It 'parses main window xaml' {
        if (-not $IsWindows) {
            Set-ItResult -Skipped -Because 'WPF assemblies are only available on Windows'
            return
        }
        Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase, System.Xaml
        $raw = Get-Content -LiteralPath $script:XamlPath -Raw
        { [void][System.Windows.Markup.XamlReader]::Parse($raw) } | Should -Not -Throw
    }

    It 'contains every control referenced by UI.Run FindName calls' {
        $optionalTargets = @()
        $missing = @(
            $script:FindNameTargets |
                Where-Object { $_ -notin $script:XamlNamedTargets } |
                Where-Object { $_ -notin $optionalTargets }
        )
        $missing.Count | Should -Be 0 -Because "Missing controls in MainWindow.xaml: $($missing -join ', ')"
    }

    It 'has no duplicate named elements in MainWindow.xaml' {
        $duplicates = @(
            $script:XamlNamedTargets |
                Group-Object |
                Where-Object { $_.Count -gt 1 } |
                Select-Object -ExpandProperty Name
        )

        $duplicates.Count | Should -Be 0 -Because "Duplicate xaml names: $($duplicates -join ', ')"
    }

    It 'retains required filter-builder controls in the UI surface' {
        $required = @(
            'FilterBuilderBorder',
            'FilterBuilderHintText',
            'FilterBuilderExpander',
            'FilterIntervalInput',
            'RefreshFiltersButton',
            'ResetFiltersButton',
            'ConversationFiltersList',
            'ConversationFilterTypeCombo',
            'ConversationPredicateTypeCombo',
            'ConversationFieldCombo',
            'ConversationOperatorCombo',
            'ConversationValueInput',
            'AddConversationPredicateButton',
            'RemoveConversationPredicateButton',
            'SegmentFiltersList',
            'SegmentFilterTypeCombo',
            'SegmentPredicateTypeCombo',
            'SegmentFieldCombo',
            'SegmentOperatorCombo',
            'SegmentPropertyTypeCombo',
            'SegmentValueInput',
            'AddSegmentPredicateButton',
            'RemoveSegmentPredicateButton'
        )

        foreach ($name in $required) {
            $script:XamlNamedTargets | Should -Contain $name
        }
    }
}

Describe 'OpsConsole UI tab status labels' -Tag @('UI', 'Contract') {
    BeforeAll {
        $script:XamlTabHeaders = @(
            ([xml](Get-Content -LiteralPath $script:XamlPath -Raw)).SelectNodes(
                "//*[local-name()='TabItem']"
            ) | ForEach-Object { $_.GetAttribute('Header') } | Where-Object { $_ }
        )
    }

    It 'Ops Insights tab is labelled Experimental' {
        $script:XamlTabHeaders | Where-Object { $_ -like '*[Experimental]*Ops Insights*' } |
            Should -Not -BeNullOrEmpty -Because "Ops Insights should have [Experimental] prefix"
    }

    It 'Ops Dashboard tab is labelled Experimental' {
        $script:XamlTabHeaders | Where-Object { $_ -like '*[Experimental]*Ops Dashboard*' } |
            Should -Not -BeNullOrEmpty -Because "Ops Dashboard should have [Experimental] prefix"
    }

    It 'Forensic Timeline tab is labelled Experimental' {
        $script:XamlTabHeaders | Where-Object { $_ -like '*[Experimental]*Forensic Timeline*' } |
            Should -Not -BeNullOrEmpty -Because "Forensic Timeline should have [Experimental] prefix"
    }

    It 'Queue Wait Coverage tab is labelled Experimental' {
        $script:XamlTabHeaders | Where-Object { $_ -like '*[Experimental]*Queue Wait Coverage*' } |
            Should -Not -BeNullOrEmpty -Because "Queue Wait Coverage should have [Experimental] prefix"
    }

    It 'Live Subscriptions tab is labelled Experimental' {
        $script:XamlTabHeaders | Where-Object { $_ -like '*[Experimental]*Live Subscriptions*' } |
            Should -Not -BeNullOrEmpty -Because "Live Subscriptions should have [Experimental] prefix"
    }

    It 'Operational Events tab is labelled Experimental' {
        $script:XamlTabHeaders | Where-Object { $_ -like '*[Experimental]*Operational Events*' } |
            Should -Not -BeNullOrEmpty -Because "Operational Events should have [Experimental] prefix"
    }

    It 'Conversation Report tab retains its plain header (no status prefix needed)' {
        $script:XamlTabHeaders | Where-Object { $_ -eq 'Conversation Report' } |
            Should -Not -BeNullOrEmpty -Because "Conversation Report is a stable tab and needs no label prefix"
    }

    It 'Audit Investigator tab retains its plain header (no status prefix needed)' {
        $script:XamlTabHeaders | Where-Object { $_ -eq 'Audit Investigator' } |
            Should -Not -BeNullOrEmpty -Because "Audit Investigator is a stable tab and needs no label prefix"
    }
}
