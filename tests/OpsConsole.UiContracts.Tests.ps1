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
        Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase, System.Xaml
        $raw = Get-Content -LiteralPath $script:XamlPath -Raw
        { [void][System.Windows.Markup.XamlReader]::Parse($raw) } | Should -Not -Throw
    }

    It 'contains every control referenced by UI.Run FindName calls' {
        $optionalTargets = @(
            # Existing runtime alias that may be conditionally introduced during XAML edits.
            'ExportRedactedKpiButton'
        )
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
