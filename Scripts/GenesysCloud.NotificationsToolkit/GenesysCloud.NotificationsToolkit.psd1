@{
    ModuleVersion = '0.1.0'
    GUID = 'b1d8fae0-3cce-4dfb-9c64-d0a4c7bc9c39'
    Author = 'Genesys Cloud API Explorer'
    CompanyName = 'Genesys Cloud API Explorer'
    Copyright = '(c) 2026 Genesys Cloud API Explorer'
    Description = 'Support for Notifications channels, live topic subscriptions, and capture persistence.'
    RootModule = 'GenesysCloud.NotificationsToolkit.psm1'
    PrivateData = @{
        PSData = @{
            Tags = @('Genesys','Notifications','Observability','Live Events')
            ProjectUri = 'https://github.com/xfaith4/Genesys-API-Explorer'
            LicenseUri = 'https://opensource.org/licenses/MIT'
        }
    }
    FunctionsToExport = @(
        'Get-GCNotificationBaseUri',
        'Get-GCNotificationTopics',
        'Save-GCNotificationTopicsCache',
        'New-GCNotificationChannel',
        'Add-GCNotificationSubscriptions',
        'Remove-GCNotificationSubscriptions',
        'Connect-GCNotificationWebSocket',
        'Start-GCNotificationCapture',
        'Stop-GCNotificationCapture',
        'Remove-GCNotificationChannel'
    )
    RequiredModules = @('GenesysCloud.OpsInsights')
}
