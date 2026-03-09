# Requires: Pester 5+

BeforeAll {
    . "$PSScriptRoot\TestHelpers.ps1"

    Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase, System.Xaml

    $script:ResourcesRoot = Join-TestRepoPath -RelativePath 'apps/OpsConsole/Resources' -StartPath $PSScriptRoot
    . (Join-TestRepoPath -RelativePath 'apps/OpsConsole/Resources/UI/UI.PreMain.ps1' -StartPath $PSScriptRoot)
}

Describe 'UI filter builder regression coverage' -Tag @('UI', 'Regression', 'Unit') {
    BeforeAll {
        function New-Selector {
            param($SelectedItem)
            return [pscustomobject]@{ SelectedItem = $SelectedItem }
        }

        function New-ValueInput {
            param([string]$Text = '')
            return [pscustomobject]@{ Text = $Text }
        }
    }

    BeforeEach {
        $script:FilterBuilderData = [pscustomobject]@{
            Interval            = '2026-02-01T00:00:00.000Z/2026-02-01T01:00:00.000Z'
            ConversationFilters = New-Object System.Collections.ArrayList
            SegmentFilters      = New-Object System.Collections.ArrayList
        }

        $script:FilterBuilderEnums = [pscustomobject]@{
            Conversation = [pscustomobject]@{
                Dimensions = @('conversationId', 'mediaType')
                Metrics    = @('nConnected')
                Types      = @('dimension', 'metric', 'property')
            }
            Segment = [pscustomobject]@{
                Dimensions    = @('flowName', 'queueId')
                Metrics       = @('tHandle')
                Types         = @('dimension', 'metric', 'property')
                PropertyTypes = @('bool', 'integer', 'string')
            }
            Operators = @('matches', 'exists', 'gt')
        }

        $script:CurrentBodyControl = [pscustomobject]@{
            ValueControl = [System.Windows.Controls.TextBox]::new()
        }
        $script:filterIntervalInput = [System.Windows.Controls.TextBox]::new()
        $script:filterIntervalInput.Text = $script:FilterBuilderData.Interval
    }

    It 'builds a dimension predicate without throwing (regression for dimension assignment crash)' {
        {
            Build-FilterFromInput `
                -Scope 'Conversation' `
                -FilterTypeCombo (New-Selector -SelectedItem 'and') `
                -PredicateTypeCombo (New-Selector -SelectedItem 'dimension') `
                -FieldCombo (New-Selector -SelectedItem 'conversationId') `
                -OperatorCombo (New-Selector -SelectedItem 'matches') `
                -ValueInput (New-ValueInput -Text '34f23434') | Out-Null
        } | Should -Not -Throw

        $result = Build-FilterFromInput `
            -Scope 'Conversation' `
            -FilterTypeCombo (New-Selector -SelectedItem 'and') `
            -PredicateTypeCombo (New-Selector -SelectedItem 'dimension') `
            -FieldCombo (New-Selector -SelectedItem 'conversationId') `
            -OperatorCombo (New-Selector -SelectedItem 'matches') `
            -ValueInput (New-ValueInput -Text '34f23434')

        $result.type | Should -Be 'and'
        $result.predicates.Count | Should -Be 1
        $result.predicates[0].type | Should -Be 'dimension'
        $result.predicates[0].operator | Should -Be 'matches'
        $result.predicates[0].dimension | Should -Be 'conversationId'
        $result.predicates[0].value | Should -Be '34f23434'
    }

    It 'builds a metric predicate and keeps metric/value fields' {
        $result = Build-FilterFromInput `
            -Scope 'Conversation' `
            -FilterTypeCombo (New-Selector -SelectedItem 'or') `
            -PredicateTypeCombo (New-Selector -SelectedItem 'metric') `
            -FieldCombo (New-Selector -SelectedItem 'nConnected') `
            -OperatorCombo (New-Selector -SelectedItem 'gt') `
            -ValueInput (New-ValueInput -Text '10')

        $result.type | Should -Be 'or'
        $result.predicates[0].metric | Should -Be 'nConnected'
        $result.predicates[0].value | Should -Be '10'
    }

    It 'builds a property predicate with propertyType metadata' {
        $propertyName = [System.Windows.Controls.TextBox]::new()
        $propertyName.Text = 'disconnectType'
        $propertyType = New-Selector -SelectedItem 'string'

        $result = Build-FilterFromInput `
            -Scope 'Segment' `
            -FilterTypeCombo (New-Selector -SelectedItem 'and') `
            -PredicateTypeCombo (New-Selector -SelectedItem 'property') `
            -FieldCombo (New-Selector -SelectedItem $null) `
            -OperatorCombo (New-Selector -SelectedItem 'matches') `
            -ValueInput (New-ValueInput -Text 'client') `
            -PropertyTypeCombo $propertyType `
            -PropertyNameInput $propertyName

        $result.predicates[0].property | Should -Be 'disconnectType'
        $result.predicates[0].propertyType | Should -Be 'string'
        $result.predicates[0].value | Should -Be 'client'
    }

    It 'writes range when filter value is JSON object' {
        $result = Build-FilterFromInput `
            -Scope 'Conversation' `
            -FilterTypeCombo (New-Selector -SelectedItem 'and') `
            -PredicateTypeCombo (New-Selector -SelectedItem 'dimension') `
            -FieldCombo (New-Selector -SelectedItem 'mediaType') `
            -OperatorCombo (New-Selector -SelectedItem 'matches') `
            -ValueInput (New-ValueInput -Text '{"gte":"a","lt":"z"}')

        $result.predicates[0].PSObject.Properties.Name | Should -Contain 'range'
        $result.predicates[0].PSObject.Properties.Name | Should -Not -Contain 'value'
        $result.predicates[0].range.gte | Should -Be 'a'
        $result.predicates[0].range.lt | Should -Be 'z'
    }

    It 'allows exists operator with no explicit value' {
        $result = Build-FilterFromInput `
            -Scope 'Conversation' `
            -FilterTypeCombo (New-Selector -SelectedItem 'and') `
            -PredicateTypeCombo (New-Selector -SelectedItem 'dimension') `
            -FieldCombo (New-Selector -SelectedItem 'conversationId') `
            -OperatorCombo (New-Selector -SelectedItem 'exists') `
            -ValueInput (New-ValueInput -Text '')

        $result.predicates[0].operator | Should -Be 'exists'
        $result.predicates[0].PSObject.Properties.Name | Should -Not -Contain 'value'
        $result.predicates[0].PSObject.Properties.Name | Should -Not -Contain 'range'
    }

    It 'applies conversation/segment filters to request body JSON' {
        $conversationFilter = Build-FilterFromInput `
            -Scope 'Conversation' `
            -FilterTypeCombo (New-Selector -SelectedItem 'and') `
            -PredicateTypeCombo (New-Selector -SelectedItem 'dimension') `
            -FieldCombo (New-Selector -SelectedItem 'conversationId') `
            -OperatorCombo (New-Selector -SelectedItem 'matches') `
            -ValueInput (New-ValueInput -Text 'abc-123')

        $segmentFilter = Build-FilterFromInput `
            -Scope 'Segment' `
            -FilterTypeCombo (New-Selector -SelectedItem 'or') `
            -PredicateTypeCombo (New-Selector -SelectedItem 'dimension') `
            -FieldCombo (New-Selector -SelectedItem 'flowName') `
            -OperatorCombo (New-Selector -SelectedItem 'matches') `
            -ValueInput (New-ValueInput -Text 'mainFlow')

        [void]$script:FilterBuilderData.ConversationFilters.Add($conversationFilter)
        [void]$script:FilterBuilderData.SegmentFilters.Add($segmentFilter)
        $script:filterIntervalInput.Text = '2026-01-01T00:00:00.000Z/2026-01-01T02:00:00.000Z'

        Invoke-FilterBuilderBody
        $payload = $script:CurrentBodyControl.ValueControl.Text | ConvertFrom-Json

        $payload.interval | Should -Be '2026-01-01T00:00:00.000Z/2026-01-01T02:00:00.000Z'
        $payload.conversationFilters.Count | Should -Be 1
        $payload.segmentFilters.Count | Should -Be 1
        $payload.conversationFilters[0].predicates[0].dimension | Should -Be 'conversationId'
        $payload.segmentFilters[0].predicates[0].dimension | Should -Be 'flowName'
    }

    It 'updates field dropdown options from enum cache for dimensions' {
        $combo = [System.Windows.Controls.ComboBox]::new()
        Update-FilterFieldOptions -Scope 'Conversation' -PredicateType 'dimension' -ComboBox $combo

        $combo.IsEnabled | Should -BeTrue
        $combo.Items.Count | Should -BeGreaterThan 0
        @($combo.Items) | Should -Contain 'conversationId'
    }

    It 'parses literal and JSON filter values correctly' {
        (Parse-FilterValueInput -Text '  hello ') | Should -Be 'hello'

        $jsonValue = Parse-FilterValueInput -Text '{"min":1,"max":5}'
        $jsonValue.min | Should -Be 1
        $jsonValue.max | Should -Be 5

        (Parse-FilterValueInput -Text '   ') | Should -BeNullOrEmpty
    }
}
