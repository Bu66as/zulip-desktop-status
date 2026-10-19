# Dead man's switch: protocol

The watchdog server is not part of this repository. This page describes what
the client sends, so that you can build your own. The server needs your Zulip
API key to act on your behalf, so run it only on a machine you trust.

## Client side

`~/.config/zulip-status/waechter`, mode 0600:

```ini
[waechter]
url = https://watchdog.example.org/meldung
token = long-random-string
```

## Report

Every round (60 s) the client sends:

```
POST <url>
Authorization: Bearer <token>
Content-Type: application/json

{
  "gueltig_s": 300,
  "status": {"text": "Working from home", "emoji_name": "house"},
  "notfall": {"text": "On vacation until 12 Oct", "emoji_name": "palm_tree",
              "emoji_code": "1f334", "sichtbar": false}
}
```

- `gueltig_s`: the report is valid for this many seconds. If no new report
  arrives in time, the server takes over. Before suspend and at service stop
  the client sends a last report with 20 seconds.
- `status`: what the client has set in Zulip at the moment.
- `notfall` (optional): what the server should set instead of its own rule,
  for example the vacation status.

## What the server should do when reports stop

1. Read the current status from Zulip. Replace it only if it is empty or equal
   to the last reported `status`. A status set by hand stays.
2. Set `notfall` if given. Otherwise: during work hours "Away" with the emoji
   `walking`, outside "Off work, back at HH:MM" with the emoji `moon`.
3. Switch presence to invisible (`PATCH /api/v1/settings`,
   `presence_enabled=false`).
4. Do nothing more as soon as reports arrive again.

The client recognises exactly these two default statuses (in German and
English) as set by the watchdog and replaces them when it is back. If your
server uses other texts, the client treats them as set by hand.
