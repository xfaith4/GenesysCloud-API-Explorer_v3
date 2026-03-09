# Live Subscriptions & Notifications Toolkit

This document outlines the new Live Events/Notifications subsystem introduced for the Genesys Cloud API Explorer.

## Overview

- `Scripts/GenesysCloud.NotificationsToolkit` exposes a lightweight helper module that:
  - Creates and manages Notifications channels via `New-GCNotificationChannel`.
  - Adds/removes topic subscriptions (`Add-GCNotificationSubscriptions`, `Remove-GCNotificationSubscriptions`).
  - Connects to the channel over WebSockets (`Connect-GCNotificationWebSocket`) and queues received events.
  - Captures the live stream into append-only JSONL files plus optional summary files (`Start-/Stop-GCNotificationCapture`).
- The new Live Subscriptions tab in the Ops Console surfaces a topic catalog (the `/api/v2/notifications/topics` list with descriptions) so you can visually select endpoints, double-click to append them, and combine presets or custom values before starting a feed.
- A compact analytics panel keeps topic/event counts and timeline buckets fresh via a dispatcher timer plus periodic summary reprocessing, so the UI shows up-to-date totals while the capture runs or after it stops.

## Key paths

1. **UI path** - now surfaces in the revamped *Live Subscriptions* tab (topic catalog + picker, start/stop buttons, filters, analytics, and exports) so you can discover endpoints & metrics without leaving the console.
2. **Raw export path** – capture files are stored under `captures/<yyyy-MM-dd>/<channelId>_<topicGroup>_<timestamp>.jsonl`.
3. **Summary path** – ending with `.summary.json` next to each capture; Excel/graphic exports are TBD but the summary file contains counts by topic, severity (when provided), timeline buckets, and entity references.
4. **Smoke/test path** – `tests/NotificationsToolkit.Tests.ps1` verifies the module loads and base URI normalization logic.

## Topic catalog cache

- `GenesysCloudNotificationTopics.json` (repo root) stores the available notification topics so the Live Subscriptions tab can show a catalog even before the UI has a token. The file mirrors the `/api/v2/notifications/topics` payload and can be regenerated via the Notifications toolkit:

```powershell
Import-Module Scripts/GenesysCloud.NotificationsToolkit/GenesysCloud.NotificationsToolkit.psd1
Save-GCNotificationTopicsCache -AccessToken '<your token>' -OutputPath GenesysCloudNotificationTopics.json
```

- Point the UI at another cache file by setting `GENESYS_API_EXPLORER_NOTIFICATION_TOPICS_PATH`. The binding logic will load the cached topics before calling the live API, so the list of endpoints is always available when the app launches.

## Setup & Troubleshooting

1. Launch the API Explorer (powershell entry point `GenesysCloudAPIExplorer.ps1`). The UI will automatically import the Notifications toolkit when the `Scripts/GenesysCloud.NotificationsToolkit` folder exists.
2. Grab an OTP or OAuth token as usual (tokens are never written to disk or logs).
3. Create a Notifications channel via `New-GCNotificationChannel -Name 'Live Events' -ChannelType websocket`.
4. Subscribe to topics (`Add-GCNotificationSubscriptions -ChannelId <id> -Topics @('topic1','topic2')`).
5. Call `Connect-GCNotificationWebSocket` to begin receiving events and feed the returned connection into `Start-GCNotificationCapture`.
6. A scheduler inside the UI periodically reprocesses the active `.summary.json` file (and any persisted summaries) so the topic/event analytics stay current even after the capture stops.
7. When capturing stops, call `Stop-GCNotificationCapture` to flush the capture and produce the final summary.

### Limitations

- Excel export is not yet implemented; summary data is written in JSON for the time being.
- WebSocket reconnection/backoff is handled at a minimal level; the `ReceiverTask` breaks when the socket closes, so UI wiring will need to restart the connection.
- Operational Events tab and UI workflows are still TBD; this module lays the groundwork for future tabs.
