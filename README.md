# zulip-desktop-status

Sets your Zulip presence and status text from the state of your Linux desktop:
screen lock, time of day, network, calendar. Deutsche Fassung: [README.de.md](README.de.md).

The Zulip desktop client sees neither idle time nor the screen lock under
Plasma/Wayland, so it reports "active" while you are long gone. This service
asks the desktop instead and sets presence and status through the Zulip API.

## What it does

Presence:

| State                 | Presence                       |
|-----------------------|--------------------------------|
| unlocked, work hours  | visible, active                |
| locked for N minutes  | invisible                      |
| outside work hours    | invisible, even when unlocked  |

Status text, first matching line wins:

| State                                  | Status                       |
|----------------------------------------|------------------------------|
| sick / vacation by hand                | Sick / On vacation until ... |
| chosen by hand (tray or command)       | Break / Focusing until HH:MM |
| all-day event with the vacation word   | On vacation until 12 Oct     |
| event running in the calendar          | In a meeting until HH:MM     |
| unlocked, work hours, home network     | Working from home            |
| unlocked, work hours, other network    | On the road                  |
| unlocked, outside work hours           | empty                        |
| locked for N minutes, work hours       | Away                         |
| locked or service stopped, otherwise   | Off work, back at 08:00      |

Before suspend or hibernate the service delays sleep for a moment and sets
Away or Off work, because the machine cannot report anything afterwards.
NetworkManager takes the network down at the same moment, often too early. The
optional hook `./install.sh --nm-hook` (needs sudo) keeps it up until the
status is set, at most 4 seconds.

A status you set by hand in Zulip is left alone. It is cleared at the first
unlock of the next day; a status with the emoji `hurt` (sick) is never cleared.

## Requirements

- Linux with systemd user services and logind
- a screen locker that offers `org.freedesktop.ScreenSaver` on the session bus
- Python 3 with PyGObject (for the sleep delay; without it the rest still works)
- PySide6 for the tray (optional)
- `busctl` and `ip`

Built and used on Fedora 44 with KDE Plasma on Wayland against Zulip Server
12. Other desktops are untested.

## Install

```sh
git clone <this repository>
cd zulip-desktop-status
./install.sh
```

Everything goes into your home directory, no root needed. Then:

1. Put the Zulip address, your login and your API key into `~/.zuliprc`
   (Zulip: Settings, Account & privacy, API key). The file is created with
   mode 0600.
2. Adjust `~/.config/zulip-status/config.env`.
3. `systemctl --user restart zulip-status.service`

Log: `journalctl --user -u zulip-status.service -f`
Try without changing anything in Zulip: `zulip-status --dry-run`
Remove: `./install.sh --remove`

## Settings

`~/.config/zulip-status/config.env`, see [config.env.example](config.env.example).
Environment variables of the same name win.

| Setting                        | Default    | Meaning                                          |
|--------------------------------|------------|--------------------------------------------------|
| `ZULIP_STATUS_LANG`            | locale     | `de` or `en`: language of status texts and log   |
| `ZULIP_STATUS_VON`             | `08:00`    | start of work, Monday to Friday                  |
| `ZULIP_STATUS_BIS`             | `16:30`    | end of work                                      |
| `ZULIP_STATUS_HEIMNETZE`       | empty      | home networks as CIDR; empty = always at home    |
| `ZULIP_STATUS_UNSICHTBAR_MIN`  | `5`        | minutes of lock until invisible and Away         |
| `ZULIP_STATUS_URLAUB_WORT`     | `vacation` | word in an all-day event that means vacation     |

## Break, focus, sick, vacation

```sh
zulip-status pause        # break until you unlock again after a lock
zulip-status pause 30     # break for 30 minutes
zulip-status fokus        # focusing until end of work
zulip-status fokus 90     # focusing for 90 minutes
zulip-status krank        # sick until 'zulip-status auto'
zulip-status krank 2026-10-20   # sick up to and including that day
zulip-status urlaub 2026-10-31  # on vacation up to and including that day
zulip-status auto         # back to automatic
```

Sick and vacation also hold while the machine is off: sleep and shutdown leave
the status in place, and so does the watchdog.

`zulip-tray` offers the same in the system tray: right click for the menu,
left click for a small window.

## Calendar (optional)

For the meeting and vacation status, create
`~/.config/zulip-status/kalender` with mode 0600:

```ini
[caldav]
url = https://cloud.example.org/remote.php/dav/calendars/me/work/
user = me
password = app-password
```

Events marked as "free" and cancelled events are ignored.

## Dead man's switch (optional)

If the machine crashes or loses its network, nobody can correct the status.
The service can therefore report to a small server of your own, which sets
Away or Off work when the reports stop. The server is not part of this
repository; the protocol is described in [docs/watchdog.md](docs/watchdog.md).
Without the file `~/.config/zulip-status/waechter` nothing is sent anywhere
but to your Zulip server.

## Limits

- Work hours are Monday to Friday with one time range. Public holidays are not known.
- Working on another device while this machine is off shows Away or Off work.
- If you change your visibility in another client, the service sets it back
  within ten minutes.
- Identifiers and comments in the code are German.

## License

Copyright (C) 2026 Michael Maurer

Free software under the GNU Affero General Public License, version 3
(AGPL-3.0-only). You may use, change and pass it on; whoever distributes it or
a changed version, or runs one as a network service, has to publish the source
under the same license. There is no warranty. Full text in [LICENSE](LICENSE).
