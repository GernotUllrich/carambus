# Sicherheit im Betrieb

Was ein Verein für die Sicherheit seines eigenen Servers tun muss — **wann es fällig wird, wer
zuständig ist und wo der Handgriff steht**. Die Seite wiederholt keine Anleitungen, sie verweist
darauf.

## Wovon diese Seite ausgeht

Ein Vereinsserver steht im Vereinsnetz, meist als Raspberry Pi im Spiellokal. Dort läuft er
**ohne HTTPS auf Port 3131** — das ist so gewollt und kein Versäumnis: im eigenen Netz gibt es
keinen sinnvollen Zertifikatsnamen, und die Scoreboards sollen ohne Zertifikatswarnung starten.
Die Absicherung übernimmt die Netzgrenze: von außen ist der Server nur erreichbar, wenn der
Verein ihn selbst freigibt.

**Sobald das der Fall ist, ändert sich die Lage** — dafür gibt es unten einen eigenen Abschnitt.

## Einen bestehenden Server übernehmen

Wer einen laufenden Vereinsserver erbt — weil die Person, die ihn aufgesetzt hat, nicht mehr da
ist —, weiß nicht, was davon schon erledigt ist. Die folgenden fünf Fragen klären das. Jede ist
in wenigen Minuten beantwortet.

| Frage | Wie man es herausfindet | Wenn die Antwort ungünstig ist |
|---|---|---|
| **Sind wir von außen erreichbar?** | In `carambus_data/scenarios/<szenario>/config.yml` steht unter `environments.production` der `webserver_host`. Ist das ein Name im lokalen Netz (`<name>.local`), ist der Server nur im Vereinsnetz. Ein DynDNS-Name bedeutet: er ist öffentlich — dann gilt der Abschnitt [Wenn der Server von außen erreichbar sein soll](#wenn-der-server-von-auen-erreichbar-sein-soll) | Prüfen, ob HTTPS und der Bot-Block eingerichtet sind |
| **Haben wir eigene Zugangsschlüssel?** | Nicht direkt ablesbar. Wurde der Server vor Mitte 2026 aufgesetzt und seitdem nicht rotiert, hat er womöglich noch den damals gemeinsamen, öffentlich lesbaren Schlüsselsatz | Im Zweifel einfach rotieren — das schafft in jedem Fall eigene Schlüssel ([Credentials rotieren](index.md#credentials-rotieren)) |
| **An welche Adresse melden die Update-Läufe?** | Auf dem Pi in `/etc/apt/apt.conf.d/50unattended-upgrades` unter `Unattended-Upgrade::Mail` | Steht dort die Adresse der ausgeschiedenen Person, gehen alle Meldungen ins Leere — Adresse ändern |
| **Wer kann überhaupt deployen und rotieren?** | Beides läuft **nicht auf dem Pi**, sondern von einem Admin-Rechner mit den [drei Verzeichnissen](raspberry-pi-quickstart.md#die-drei-verzeichnisse) — zwei davon sind nicht öffentlich | Ist dieser Rechner mit der Person gegangen, kann derzeit niemand Updates einspielen. Dann beim Betreiber melden |
| **Wann läuft unser Zertifikat ab?** | Nur relevant, wenn der Server öffentlich erreichbar ist. Im Browser am Schloss-Symbol ablesbar | Erneuern, bevor es abläuft — sonst warnt der Browser und HTTPS bricht ([Troubleshooting](index.md#troubleshooting-guide)) |

**Und unabhängig davon:** Ist die Person, die den Server aufgesetzt hat, ausgeschieden, ist damit
einer der Anlässe unten eingetreten. Siehe
[Was wiederkehrt](#was-wiederkehrt-und-wodurch-es-ausgelost-wird).

## Einmalig bei der Einrichtung

Diese Punkte fallen genau einmal an. Drei davon erledigt die Ansible-Einrichtung von selbst.

Bei einem **übernommenen** Server ist nicht gesagt, dass alle erledigt sind — die zwei, die der
Verein selbst tun muss (eigene Schlüssel, Backup), werden erfahrungsgemäß übersehen. Der
Abschnitt oben sagt, wie man es prüft.

| Was | Wer | Wo der Handgriff steht |
|---|---|---|
| **Eigene Zugangsschlüssel des Servers** (`production.key`, `production.yml.enc`) | Verein | [Konfigurationsdateien](index.md#wichtige-konfigurationsdateien) — beim neuen Szenario `NEW_KEY=true` |
| **Firewall** (nur Port 3131 und 8910 offen, SSH als `www-data`) | Ansible | [Quickstart, Schritt 1–2](raspberry-pi-quickstart.md) |
| **Automatische Betriebssystem-Updates** | Ansible | siehe „Was die Automatik abdeckt" unten |
| **Datenbank-Backup** auf einen USB-Stick | Verein | [Wartungs-Checkliste](index.md#wartungs-checkliste) — ohne diesen Schritt gibt es **kein** Backup |
| **Zugangsdaten für den Regionsdump** verwahren | Betreiber gibt aus, Verein verwahrt | [Regionsdumps](region-dumps.md) |

!!! warning "Der Backup-Schritt ist der wichtigste dieser Tabelle"
    Eine SD-Karte fällt irgendwann aus — das ist der wahrscheinlichste Totalverlust eines
    Vereinsservers. Für einen neu aufgesetzten Pi ist **kein** automatisches Backup eingerichtet;
    es muss einmal von Hand eingerichtet werden.

    **Woran man sieht, dass es läuft:**

    ```bash
    ssh -p 8910 www-data@<name>.local 'ls -la /mnt/backup/'
    ```

    Dort steht je Lauf ein Verzeichnis mit Zeitstempel (`20260921_012000`) mit einer
    `.dump`-Datei je Datenbank; sonntags kommt eine Kopie unter `weekly/` dazu. Ist das jüngste
    Verzeichnis älter als ein Tag oder das Verzeichnis leer, läuft das Backup **nicht** — dann
    stimmt etwas mit dem eingehängten Stick oder dem Eintrag in `STANDALONE_BACKUP_SCENARIOS`
    nicht.

**Warum eigene Schlüssel:** Bis 2026 teilten sich alle Carambus-Server einen gemeinsamen
Schlüsselsatz, der öffentlich lesbar war. Seitdem hat jeder Server seinen eigenen. Wer ein
Szenario ohne `NEW_KEY=true` anlegt, bekommt keinen eigenen — deshalb steht es hier.

## Was wiederkehrt — und wodurch es ausgelöst wird

Kein Kalender, sondern Anlässe. Tritt einer ein, ist der zugehörige Handgriff fällig.

| Anlass | Was zu tun ist | Wo |
|---|---|---|
| **Jemand mit Serverzugang verlässt den Verein** | **Erst den SSH-Schlüssel entfernen** (siehe Kasten unten), dann die Zugangsschlüssel des Servers rotieren; ClubCloud-Zugang und Admin-Konten prüfen | [Credentials rotieren](index.md#credentials-rotieren) |
| **Ein Passwort oder Schlüssel ist irgendwo aufgetaucht**, wo es nicht hingehört (Chat, E-Mail, Screenshot, Repository) | Denselben Wert rotieren — **überall**, wo er benutzt wird. Der Wert gilt bis dahin unverändert weiter | [Credentials rotieren](index.md#credentials-rotieren) |
| **Verdacht auf einen fremden Zugriff** | Erst rotieren, dann nachsehen — nicht umgekehrt | wie oben |
| **Das Admin-Passwort ist verloren** | Zweiten Administrator über eine andere E-Mail-Adresse anlegen | [Quickstart, Schritt 3.2](raspberry-pi-quickstart.md) |
| **Nach jedem Deploy** | Nichts Zusätzliches — die Konfigurationsdateien auf dem Server werden dabei neu geschrieben | [Konfigurationsdateien](index.md#wichtige-konfigurationsdateien) |
| **Der USB-Stick für das Backup fehlt oder wurde getauscht** | Prüfen, dass er wieder unter `/mnt/backup` eingehängt ist — sonst bricht der Backup-Lauf ab (mit Absicht) | [Wartungs-Checkliste](index.md#wartungs-checkliste) |

!!! danger "Die Rotation entfernt keinen SSH-Zugang"
    `scenario:generate_credentials` mit `ROTATE=true` erneuert den Rails-Schlüssel,
    `secret_key_base` und das JWT-Geheimnis (`lib/tasks/scenarios.rake:94`) — **den SSH-Zugang
    zum Server rührt es nicht an.** Wer nur rotiert, hat den Zugang des Ausgeschiedenen nicht
    geschlossen.

    SSH-Schlüssel liegen auf dem Pi in `~/.ssh/authorized_keys` des Benutzers `www-data`.
    Nachsehen, welche dort stehen:

    ```bash
    ssh -p 8910 www-data@<name>.local 'cat ~/.ssh/authorized_keys'
    ```

    Jede Zeile endet mit einem Kommentar, meist `benutzer@rechner` — daran ist erkennbar, wem
    sie gehört. Die Zeile der ausgeschiedenen Person entfernen und danach **prüfen, dass ihr
    Zugang wirklich weg ist**. Bleibt nur noch ein Schlüssel übrig, vorher sicherstellen, dass
    es der eigene ist — sonst sperrt man sich selbst aus.

!!! note "Rotieren heißt: der alte Wert wird ungültig"
    Eine Rotation hilft nur, wenn sie den alten Wert ersetzt. Ein Geheimnis, das einmal
    öffentlich war, bleibt öffentlich — aufräumen allein macht es nicht wieder geheim.

## Was die Automatik abdeckt — und was nicht

Die Ansible-Einrichtung richtet **unbeaufsichtigte Sicherheitsupdates** des Betriebssystems ein
(`unattended-upgrades`, Quellen `security` und `updates`; Meldungen gehen an die beim Aufsetzen
hinterlegte Admin-Adresse).

**Das betrifft ausschließlich die Pakete des Betriebssystems.** Nicht erfasst sind:

- **Ruby und Rails.** Carambus läuft auf Ruby 3.2 und Rails 7.2; beide bekommen seit 2026 keine
  Sicherheitsupdates ihrer Hersteller mehr. Der Umstieg steht aus. Solange der Server nur im
  Vereinsnetz erreichbar ist, ist das Risiko begrenzt — bei einer Freigabe nach außen ist es eine
  bewusste Entscheidung.
- **Carambus selbst.** Neue Stände kommen mit einem Deploy, den jemand auslöst.

## Wenn der Server von außen erreichbar sein soll

Ein Vereinsserver kann über einen DynDNS-Namen aus dem Internet erreichbar gemacht werden (so
macht es der BC Wedel). Das ist möglich, ändert aber drei Dinge auf einmal:

1. **HTTPS wird nötig.** Das Scenario Management stellt **keine** Zertifikate aus — das Zertifikat
   muss vor dem Deploy vorliegen, sonst schlägt `nginx -t` fehl. Siehe
   [Installations-Übersicht](installation-overview.md).
2. **Der Bot-Block wird relevant.** Im LAN ist er bedeutungslos, an einer öffentlichen Adresse
   fängt er automatisierte Zugriffe ab: [nginx Bot-Block](nginx-bot-block.md).
3. **Der Wartungsstand von Ruby und Rails zählt jetzt.** Siehe oben — im LAN eine Randnotiz, an
   einer öffentlichen Adresse ein Abwägungspunkt.

Zusätzlich muss im Router eine Portfreigabe eingerichtet und ein DynDNS-Dienst betrieben werden.
Beides liegt beim Verein und ist nicht Teil der Carambus-Einrichtung.

## Was nur der Betreiber kann

Ehrlichkeitshalber, damit niemand danach sucht:

- **Die Zugangsdaten für den Regionsdump** der eigenen Region — einmalig anzufragen.
- **Die beiden nicht öffentlichen Repositories** `carambus_data` und `ansible`, die die
  Installation voraussetzt (siehe
  [Die drei Verzeichnisse](raspberry-pi-quickstart.md#die-drei-verzeichnisse)).
- **Einträge auf der Authority** — existiert der eigene Verein oder Spielort dort noch nicht,
  kann ihn nur der Betreiber anlegen.

## Kurzfassung

Ein Verein hat genau **zwei** wiederkehrende Sicherheitsaufgaben, die niemand sonst übernimmt:
Er sorgt dafür, dass das **Backup läuft**, und er **rotiert Zugangsdaten**, wenn einer der
Anlässe oben eintritt. Alles Übrige ist einmalig eingerichtet oder läuft automatisch.
