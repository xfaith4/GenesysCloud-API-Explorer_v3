Describe 'GenesysCloud.NotificationsToolkit' {

    BeforeAll {
        $here = Split-Path -Parent $PSCommandPath
        $repo = Split-Path -Parent $here
        $opsCore = Join-Path $repo 'src\GenesysCloud.OpsInsights\GenesysCloud.OpsInsights.psd1'
        Import-Module $opsCore -Force -ErrorAction Stop
        $module = Join-Path $repo 'Scripts\GenesysCloud.NotificationsToolkit\GenesysCloud.NotificationsToolkit.psd1'
        Import-Module $module -Force -ErrorAction Stop
    }

    It 'Translates API base into notifications host' {
        $base = 'https://api.mypurecloud.com'
        $result = Get-GCNotificationBaseUri -BaseUri $base
        $result | Should -Be 'https://notifications.mypurecloud.com'
    }

    It 'Keeps existing notifications host unchanged' {
        $base = 'https://notifications.usw2.pure.cloud'
        $result = Get-GCNotificationBaseUri -BaseUri $base
        $result | Should -Be 'https://notifications.usw2.pure.cloud'
    }
}
