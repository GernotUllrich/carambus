# Deployment-Optionen

Wie ein Verein oder Landesverband Carambus betreibt. Belegt ist ein Weg: der Vereinsserver auf einem Raspberry Pi.
Er wurde im September 2026 auf frischer Hardware vollständig durchlaufen.

## Überblick

| Einsatz | Weg | Stand |
|---|---|---|
| Verein | Vereinsserver auf einem Raspberry Pi — Server und Scoreboard in einem Gerät | belegt: [Raspberry-Pi-Quickstart](../administrators/raspberry-pi-quickstart.md) |
| Weitere Tische im Verein | ein Raspberry Pi als reines Anzeigegerät oder ein Browser | Anzeige-Pi auf frischer Hardware noch nicht durchlaufen ([Raspberry Pi als Client](../administrators/raspberry-pi-client.md)) |
| Landesverband | Region Server (z. B. `nbv.carambus.de`) | vom Betreiber von Carambus betrieben |
| Eigener Server oder VPS | wie der Vereinsserver, auf anderer Hardware | nicht belegt, auf Anfrage |

## So hängt alles zusammen

Jeder Carambus-Server gehört zu einem Verbund:

```
Authority (api.carambus.de, vom Betreiber betrieben)
    ├─ Stammdaten, stündlich → Vereinsserver (Raspberry Pi im Spiellokal)
    └─ Stammdaten            → Region Server (Landesverband)
```

- Spieler, Vereine, Turniere und Turnierpläne liest die Authority aus der DBU-ClubCloud. Die Vereinsserver erhalten
  sie per Abgleich und können sie nicht ändern.
- Was im Verein entsteht — lokale Turniere, Spiele, Trainingsergebnisse, Tischreservierungen —, bleibt auf dem
  Vereinsserver.
- Der Spielbetrieb vor Ort läuft auch ohne Internet. Internet braucht der Vereinsserver für die Einrichtung, den
  stündlichen Abgleich mit der Authority und den Ergebnis-Upload in die ClubCloud.

Mehr: [Server-Architektur](../administrators/server-architecture.md)

## Der Vereinsserver auf dem Raspberry Pi

Ein Raspberry Pi ist zugleich Server und Scoreboard: Er läuft im Kiosk-Modus an einem Monitor oder Touch-Display.
Weitere Tische bekommen je ein Anzeigegerät.

**Hardware** (so im Einsatz):

- Raspberry Pi 4 oder 5; 4 GB RAM empfohlen, 2 GB laufen knapp
- microSD-Karte mit mindestens 16 GB (32 GB empfohlen), offizielles Netzteil, Monitor über HDMI
- Netzwerk per Kabel empfohlen, WLAN funktioniert
- Betriebssystem: Raspberry Pi OS (64 Bit) **mit Desktop** — der Kiosk braucht eine grafische Sitzung

**Ablauf** (gemessen auf frischer Hardware):

1. SD-Karte mit dem Raspberry Pi Imager schreiben
2. System per Ansible einrichten, mit einem Aufruf: gut 60 Minuten (Härtung, Ruby, PostgreSQL, nginx)
3. Anwendung per Rake-Tasks vom Admin-Rechner aus deployen: rund 15 Minuten
4. Danach startet der Pi von selbst ins Scoreboard; nach dem Einschalten dauert das rund 3 Minuten

Anleitung: [Raspberry-Pi-Quickstart](../administrators/raspberry-pi-quickstart.md)

<a id="voraussetzungen"></a>
## Voraussetzungen für den eigenen Betrieb

| Was | Warum |
|---|---|
| **Der Betreiber von Carambus** | Die Erstbefüllung der Datenbank holt die Stammdaten per SSH aus der Datenbank der Authority; diesen Zugang hat nur der Betreiber. Auch die Zugangsschlüssel des Servers (`production.key`) kommen heute von ihm. Wie ein Verein beides künftig selbst erledigen kann, ist offen. |
| **Ein Admin-Rechner (Mac oder Linux)** | Von hier aus laufen Ansible und die Rake-Tasks. Nötig sind der Raspberry Pi Imager, ein Carambus-Checkout, die Szenario-Konfiguration (`carambus_data`), das Ansible-Repository, ein lokales PostgreSQL und ein SSH-Schlüssel. |
| **Linux- und SSH-Kenntnisse** | für die Einrichtung und für Fehler, die dabei auftreten |
| **Die DBU-ClubCloud** | Spieler und Vereine werden dort gepflegt; den Ergebnis-Upload macht die Turnierleitung mit ihrem ClubCloud-Zugang. |
| **Ein Mail-Konto** | Carambus startet in Produktion nur mit SMTP-Zugangsdaten — oder mit bewusst abgeschaltetem Mailversand. |
| **Internet** | für Einrichtung, stündlichen Abgleich und ClubCloud-Upload, nicht für den Spielbetrieb |

Details: [Installations-Übersicht](../administrators/installation-overview.md)

## Im laufenden Betrieb

- **Updates des Betriebssystems:** Sicherheitsupdates laufen automatisch.
- **Carambus-Updates** spielt man vom Admin-Rechner aus ein (`scenario:deploy`, gemessen rund 9 Minuten).
- **Backup:** Ein neuer Vereinsserver hat kein automatisches Backup. Es muss eingerichtet werden, etwa auf einen
  USB-Stick ([Wartungs-Checkliste](../administrators/index.md#wartungs-checkliste)).
- **Wenn die SD-Karte ausfällt:** Neuaufbau nach dem Quickstart; die Turniere und Spiele des Vereins lassen sich
  nur aus einem Backup wiederherstellen.
- **Zugriff:** im Vereinsnetz über `http://<name>.local:3131`, ohne HTTPS; von außen z. B. über einen
  DynDNS-Namen (so beim BC Wedel).
- **Firewall:** Die Einrichtung öffnet nur den Web- und den SSH-Port.

## Für Landesverbände

Ein Landesverband nutzt einen **Region Server** (Beispiel `nbv.carambus.de`). Dort arbeiten die Sportwarte des
Verbands — mit dem ClubCloud-Assistenten ([Quickstart](../managers/clubcloud-mcp-cloud-quickstart.md)) oder, für
Einzelmeisterschaften, ohne ClubCloud
([CC-loses Turniermanagement](../administrators/cc-less-tournament-management.md)). Die Vereinsserver der Region
hängen direkt an der Authority, nicht am Region Server. Region Server betreibt heute der Betreiber von Carambus.

## Eigener Server oder VPS

Die Server des Betreibers (Authority, Region Server) laufen auf einem gemieteten Server. Als Weg für einen Verein
ist das nicht beschrieben: Einen Carambus-Server auf anderer Hardware als dem Raspberry Pi — Mini-PC, eigener
Server, gemieteter VPS — hat bisher niemand nach dieser Anleitung frisch aufgesetzt, und ob die Einrichtung per
Ansible dort gleichwertig läuft, ist nicht geprüft. Bei Interesse: [Kontakt](index.md#kontakt).

## Kosten

- Keine Lizenzgebühren (MIT-Lizenz)
- Hardware: Raspberry Pi, Netzteil, microSD-Karte, Monitor oder Touch-Display; für jeden weiteren Tisch ein
  Anzeigegerät
- Laufende Kosten nur für Strom und optionale Dienste (etwa den Anthropic-Schlüssel der KI-Suche)
