# Requires: Pester 5+

Describe 'GenesysCloud.NotificationsToolkit (exhaustive offline coverage)' -Tag @('Unit', 'Contract') {
    BeforeAll {
        . "$PSScriptRoot\TestHelpers.ps1"

        Import-TestModuleManifest -ManifestRelativePath 'src/GenesysCloud.OpsInsights/GenesysCloud.OpsInsights.psd1' -StartPath $PSScriptRoot
        $notificationsModulePath = Join-TestRepoPath -RelativePath 'Scripts/GenesysCloud.NotificationsToolkit/GenesysCloud.NotificationsToolkit.psm1' -StartPath $PSScriptRoot
        Import-Module -Name $notificationsModulePath -Force -Global -ErrorAction Stop
    }

    BeforeEach {
        $script:CapturedWebRequests = New-Object System.Collections.ArrayList
        $script:WebRequestResponder = {
            param([pscustomobject]$Request)
            return [pscustomobject]@{
                StatusCode = 200
                Headers    = @{}
                Content    = '{}'
            }
        }

        Mock Invoke-WebRequest -ModuleName 'GenesysCloud.OpsInsights' {
            param(
                [string]$Method,
                [string]$Uri,
                [hashtable]$Headers,
                [object]$Body,
                [int]$TimeoutSec,
                [string]$ErrorAction,
                [switch]$UseBasicParsing
            )

            $request = [pscustomobject]@{
                Method     = $Method
                Uri        = $Uri
                Headers    = $Headers
                Body       = $Body
                TimeoutSec = $TimeoutSec
            }
            [void]$script:CapturedWebRequests.Add($request)
            return (& $script:WebRequestResponder $request)
        }
    }

    It 'builds notifications base URI from API base URI' {
        Get-GCNotificationBaseUri -BaseUri 'https://api.usw2.pure.cloud' | Should -Be 'https://notifications.usw2.pure.cloud'
    }

    It 'queries topics through canonical transport' {
        $script:WebRequestResponder = {
            param([pscustomobject]$Request)
            [pscustomobject]@{
                StatusCode = 200
                Headers    = @{}
                Content    = '{"topics":[]}'
            }
        }

        $result = Get-GCNotificationTopics -BaseUri 'https://api.mypurecloud.com' -AccessToken 'token'
        $result.StatusCode | Should -Be 200

        $script:CapturedWebRequests.Count | Should -Be 1
        $request = $script:CapturedWebRequests[0]
        $request.Method | Should -Be 'GET'
        $request.Uri | Should -Be 'https://notifications.mypurecloud.com/api/v2/notifications/topics'
    }

    It 'saves topics cache from parsed response entities' {
        $script:WebRequestResponder = {
            param([pscustomobject]$Request)
            [pscustomobject]@{
                StatusCode = 200
                Headers    = @{}
                Content    = '{"entities":[{"topicName":"v2.users.{id}"},{"topicName":"v2.conversations.{id}"}]}'
            }
        }

        $outPath = Join-Path -Path $TestDrive -ChildPath 'topics.json'
        $saved = Save-GCNotificationTopicsCache -AccessToken 'token' -BaseUri 'https://api.usw2.pure.cloud' -OutputPath $outPath -Force

        $saved | Should -Be $outPath
        (Test-Path -LiteralPath $outPath) | Should -BeTrue

        $json = Get-Content -LiteralPath $outPath -Raw | ConvertFrom-Json
        @($json.topics).Count | Should -Be 2
    }

    It 'requires token for saving topic cache' {
        { Save-GCNotificationTopicsCache -OutputPath (Join-Path $TestDrive 'topics.json') } | Should -Throw
    }

    It 'creates notification channel payload through transport' {
        $result = New-GCNotificationChannel -Name 'Ops Channel' -Description 'desc' -ChannelType websocket -Config @{ heartbeat = 30 } -BaseUri 'https://api.usw2.pure.cloud' -AccessToken 'token'
        $result.StatusCode | Should -Be 200

        $script:CapturedWebRequests.Count | Should -Be 1
        $request = $script:CapturedWebRequests[0]
        $request.Method | Should -Be 'POST'
        $request.Uri | Should -Be 'https://notifications.usw2.pure.cloud/api/v2/notifications/channels'

        $body = $request.Body | ConvertFrom-Json
        $body.name | Should -Be 'Ops Channel'
        $body.type | Should -Be 'websocket'
        $body.description | Should -Be 'desc'
        $body.config.heartbeat | Should -Be 30
    }

    It 'adds topic subscriptions and filters empty topic values' {
        $result = Add-GCNotificationSubscriptions -ChannelId 'ch-1' -Topics @('v2.users.{id}', '   ') -BaseUri 'https://api.usw2.pure.cloud' -AccessToken 'token'
        $result.StatusCode | Should -Be 200

        $request = $script:CapturedWebRequests[0]
        $request.Method | Should -Be 'POST'
        $request.Uri | Should -Be 'https://notifications.usw2.pure.cloud/api/v2/notifications/channels/ch-1/subscriptions'

        $body = $request.Body | ConvertFrom-Json
        @($body.topics).Count | Should -Be 1
        $body.topics[0].topicName | Should -Be 'v2.users.{id}'
    }

    It 'removes subscriptions by id with one request per id' {
        $result = Remove-GCNotificationSubscriptions -ChannelId 'ch-1' -SubscriptionIds @('sub-1', 'sub-2') -BaseUri 'https://api.usw2.pure.cloud' -AccessToken 'token'

        @($result).Count | Should -Be 2
        $script:CapturedWebRequests.Count | Should -Be 2
        $script:CapturedWebRequests[0].Method | Should -Be 'DELETE'
        $script:CapturedWebRequests[0].Uri | Should -Match '/api/v2/notifications/channels/ch-1/subscriptions/sub-1$'
        $script:CapturedWebRequests[1].Uri | Should -Match '/api/v2/notifications/channels/ch-1/subscriptions/sub-2$'
    }

    It 'removes subscriptions by topic names' {
        $result = Remove-GCNotificationSubscriptions -ChannelId 'ch-2' -TopicNames @('v2.users.{id}', '   ') -BaseUri 'https://api.usw2.pure.cloud' -AccessToken 'token'
        $result.StatusCode | Should -Be 200

        $script:CapturedWebRequests.Count | Should -Be 1
        $request = $script:CapturedWebRequests[0]
        $request.Method | Should -Be 'DELETE'
        $request.Uri | Should -Be 'https://notifications.usw2.pure.cloud/api/v2/notifications/channels/ch-2/subscriptions'

        $body = $request.Body | ConvertFrom-Json
        @($body.topics).Count | Should -Be 1
        $body.topics[0].topicName | Should -Be 'v2.users.{id}'
    }

    It 'rejects removal requests without subscription ids or topic names' {
        { Remove-GCNotificationSubscriptions -ChannelId 'ch-3' -BaseUri 'https://api.usw2.pure.cloud' -AccessToken 'token' } | Should -Throw
        $script:CapturedWebRequests.Count | Should -Be 0
    }

    It 'validates capture session input and stop summary flow' {
        { Start-GCNotificationCapture -Connection $null } | Should -Throw

        $capturePath = Join-Path -Path $TestDrive -ChildPath 'capture.jsonl'
        '{}' | Set-Content -LiteralPath $capturePath -Encoding utf8

        $fakeSession = [pscustomobject]@{
            CapturePath  = $capturePath
            Summary      = [ordered]@{
                Topics    = @{ 'v2.users.{id}' = 1 }
                Events    = @{ create = 1 }
                Timeline  = @{}
                Entities  = @{}
                LastEntry = $null
            }
            Processor    = [System.Threading.Tasks.Task]::CompletedTask
            Cancellation = [System.Threading.CancellationTokenSource]::new()
            Connection   = [pscustomobject]@{
                ChannelId               = 'capture-channel'
                CancellationTokenSource = [System.Threading.CancellationTokenSource]::new()
            }
            WriteSummary = $true
        }

        $result = Stop-GCNotificationCapture -CaptureSession $fakeSession -GenerateSummary
        (Test-Path -LiteralPath $result.SummaryPath) | Should -BeTrue
        $summary = Get-Content -LiteralPath $result.SummaryPath -Raw | ConvertFrom-Json
        $summary.Topics.'v2.users.{id}' | Should -Be 1
    }

    It 'rejects websocket connect when channel id is blank' {
        { Connect-GCNotificationWebSocket -ChannelId '' } | Should -Throw
    }

    It 'removes notification channel through transport' {
        $result = Remove-GCNotificationChannel -ChannelId 'ch-remove' -BaseUri 'https://api.usw2.pure.cloud' -AccessToken 'token'
        $result.StatusCode | Should -Be 200

        $script:CapturedWebRequests.Count | Should -Be 1
        $request = $script:CapturedWebRequests[0]
        $request.Method | Should -Be 'DELETE'
        $request.Uri | Should -Match '/api/v2/notifications/channels/ch-remove$'
    }
}
