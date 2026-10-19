# zulip-desktop-status

Setzt Anwesenheit und Status-Text in Zulip aus dem Zustand des Linux-Desktops:
Bildschirmsperre, Uhrzeit, Netz, Kalender. English version: [README.md](README.md).

Der Zulip-Client sieht unter Plasma/Wayland weder Leerlauf noch
Bildschirmsperre und meldet „aktiv“, wenn man längst weg ist. Dieser Dienst
fragt stattdessen den Desktop und setzt Anwesenheit und Status über die
Zulip-API.

## Was er tut

Anwesenheit:

| Zustand                   | Anwesenheit                     |
|---------------------------|---------------------------------|
| entsperrt, Arbeitszeit    | sichtbar, aktiv                 |
| N Minuten gesperrt        | unsichtbar                      |
| außerhalb der Arbeitszeit | unsichtbar, auch entsperrt      |

Status-Text, die erste zutreffende Zeile gewinnt:

| Zustand                                   | Status                            |
|-------------------------------------------|-----------------------------------|
| Krank / Urlaub von Hand                   | Krank / Im Urlaub bis …           |
| von Hand gewählt (Tray oder Befehl)       | Pause / Konzentriert bis HH:MM    |
| ganztägiger Termin mit dem Urlaubswort    | Im Urlaub bis 12.10.              |
| Termin läuft im Kalender                  | Im Meeting bis HH:MM              |
| entsperrt, Arbeitszeit, Heimnetz          | Arbeitet von zu Hause             |
| entsperrt, Arbeitszeit, anderes Netz      | Unterwegs                         |
| entsperrt, außerhalb der Arbeitszeit      | leer                              |
| N Minuten gesperrt, Arbeitszeit           | Abwesend                          |
| gesperrt oder Dienst beendet, sonst       | Feierabend, wieder da ab 08:00    |

Vor Bereitschaft und Ruhezustand hält der Dienst das Einschlafen kurz auf und
setzt Abwesend oder Feierabend, weil der Rechner danach nichts mehr melden
kann. NetworkManager baut das Netz im selben Moment ab, oft zu früh. Der
optionale Hook `./install.sh --nm-hook` (braucht sudo) hält es offen, bis der
Status gesetzt ist, höchstens 4 Sekunden.

Ein in Zulip von Hand gesetzter Status bleibt stehen. Er wird beim ersten
Entsperren des nächsten Tages weggeräumt; ein Status mit dem Emoji `hurt`
(krank) nie.

## Voraussetzungen

- Linux mit systemd-Benutzerdiensten und logind
- eine Bildschirmsperre, die `org.freedesktop.ScreenSaver` am Sitzungsbus anbietet
- Python 3 mit PyGObject (für die Schlafverzögerung; ohne läuft der Rest trotzdem)
- PySide6 für das Tray (optional)
- `busctl` und `ip`

Gebaut und im Einsatz auf Fedora 44 mit KDE Plasma unter Wayland gegen
Zulip Server 12. Andere Desktops sind ungetestet.

## Installation

```sh
git clone <dieses Repository>
cd zulip-desktop-status
./install.sh
```

Alles landet im Home-Verzeichnis, root ist nicht nötig. Danach:

1. Zulip-Adresse, Anmeldeadresse und API-Schlüssel in `~/.zuliprc` eintragen
   (Zulip: Einstellungen, Konto & Datenschutz, API-Schlüssel). Die Datei wird
   mit den Rechten 0600 angelegt.
2. `~/.config/zulip-status/config.env` anpassen, für deutsche Texte
   `ZULIP_STATUS_LANG=de` (bei deutscher Locale ist das der Standard).
3. `systemctl --user restart zulip-status.service`

Protokoll: `journalctl --user -u zulip-status.service -f`
Ausprobieren, ohne in Zulip etwas zu ändern: `zulip-status --dry-run`
Entfernen: `./install.sh --remove`

## Einstellungen

`~/.config/zulip-status/config.env`, siehe [config.env.example](config.env.example).
Gleichnamige Umgebungsvariablen gewinnen.

| Einstellung                    | Standard  | Bedeutung                                              |
|--------------------------------|-----------|--------------------------------------------------------|
| `ZULIP_STATUS_LANG`            | Locale    | `de` oder `en`: Sprache der Status-Texte und Meldungen |
| `ZULIP_STATUS_VON`             | `08:00`   | Arbeitsbeginn, Montag bis Freitag                      |
| `ZULIP_STATUS_BIS`             | `16:30`   | Arbeitsende                                            |
| `ZULIP_STATUS_HEIMNETZE`       | leer      | Heimnetze als CIDR; leer = immer zu Hause              |
| `ZULIP_STATUS_UNSICHTBAR_MIN`  | `5`       | Minuten Sperre bis unsichtbar und Abwesend             |
| `ZULIP_STATUS_URLAUB_WORT`     | `urlaub`  | Wort im ganztägigen Termin, das Urlaub bedeutet        |

## Pause, Konzentriert, Krank, Urlaub

```sh
zulip-status pause        # Pause, bis du nach einer Sperre wieder entsperrst
zulip-status pause 30     # 30 Minuten Pause
zulip-status fokus        # konzentriert bis Arbeitsende
zulip-status fokus 90     # 90 Minuten konzentriert
zulip-status krank        # krank bis 'zulip-status auto'
zulip-status krank 2026-10-20   # krank bis einschließlich dieses Tages
zulip-status urlaub 2026-10-31  # im Urlaub bis einschließlich dieses Tages
zulip-status auto         # zurück zur Automatik
```

Krank und Urlaub gelten auch bei ausgeschaltetem Rechner: Schlaf und
Herunterfahren lassen den Status stehen, der Wächter ebenso.

`zulip-tray` bietet dasselbe im Systemabschnitt: Rechtsklick für das Menü,
Linksklick für ein kleines Fenster.

## Kalender (optional)

Für Meeting- und Urlaubsstatus `~/.config/zulip-status/kalender` mit den
Rechten 0600 anlegen:

```ini
[caldav]
url = https://cloud.example.org/remote.php/dav/calendars/ich/arbeit/
user = ich
password = app-passwort
```

Als „frei“ markierte und abgesagte Termine zählen nicht.

## Totmann (optional)

Stürzt der Rechner ab oder verliert er das Netz, korrigiert niemand mehr den
Status. Der Dienst kann sich deshalb bei einem kleinen eigenen Server melden,
der Abwesend oder Feierabend setzt, sobald die Meldungen ausbleiben. Der
Server gehört nicht zu diesem Repository; das Protokoll steht in
[docs/watchdog.md](docs/watchdog.md). Ohne die Datei
`~/.config/zulip-status/waechter` geht nichts an andere Stellen als an den
eigenen Zulip-Server.

## Grenzen

- Arbeitszeit ist Montag bis Freitag mit einem Zeitfenster. Feiertage kennt der Dienst nicht.
- Wer an einem anderen Gerät arbeitet, während dieser Rechner aus ist, steht auf Abwesend oder Feierabend.
- Stellt man die Sichtbarkeit in einem anderen Client um, setzt der Dienst sie innerhalb von zehn Minuten zurück.
- Bezeichner und Kommentare im Code sind deutsch.

## Lizenz

Copyright (C) 2026 Michael Maurer

Freie Software unter der GNU Affero General Public License, Version 3
(AGPL-3.0-only). Nutzen, Ändern und Weitergeben ist erlaubt; wer das Programm
oder eine geänderte Fassung weitergibt oder als Netzwerkdienst betreibt, muss
den Quelltext unter derselben Lizenz offenlegen. Es gibt keine Gewährleistung.
Maßgeblich ist der englische Text in [LICENSE](LICENSE).
