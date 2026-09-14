# Regionsdumps

Ein neuer Vereinsserver braucht einen ersten Datenbestand: Clubs, Spieler, Spielorte, Turniere, Ligen seiner Region.
Danach hält er sich über den Versions-Sync selbst aktuell. Diesen ersten Bestand baut die Authority (`api.carambus.de`)
**jede Nacht für jede Region** als Datei. Ein Verein lädt ihn mit Zugangsdaten, die der Betreiber einmal ausgibt; einen
SSH-Zugang zur Authority braucht er nicht.

!!! note "Einspielen"
    Wie ein Verein den Dump auf seinem Server einspielt, beschreibt die
    [Raspberry Pi Quickstart](raspberry-pi-quickstart.md), sobald dieser Weg fertig ist (Phase 18, Plan 18-03).

## Was im Dump steht — und was nicht

**Enthalten** sind die globalen Daten der Region:

- Clubs, Spielorte, Tische, Spieler, Turniere mit Setzlisten und Spielen, Ligen, Mannschaften, Spieltage — gefiltert auf
  die Region; Datensätze ohne Region oder mit `global_context` (z. B. internationale Turniere) bleiben erhalten
- alle übrigen Stammdaten vollständig (Regionen, Disziplinen, Turnierpläne, Saisons …)
- `last_version_id`: der Stand, ab dem der Versions-Sync des neuen Servers weitermacht

**Nicht enthalten** (die Authority bereinigt vor dem Filtern und prüft danach, dass nichts übrig ist):

| Was | Warum |
|---|---|
| Benutzerkonten (`users`, `user_tournaments`) | Konten der Authority gehören nicht auf einen Vereinsserver; der erste Admin entsteht dort neu |
| ClubCloud-Zugänge der Regionen (`region_ccs.username/userpw`) | Zugangsdaten |
| API-Zugänge internationaler Quellen | Zugangsdaten |
| MCP-Protokoll, KI-Nutzung | Betriebsdaten der Authority |
| Versionshistorie (`versions`) | Verlauf mit Benutzerbezug; der Sync braucht nur `last_version_id` |
| ClubCloud-Sitzung in `settings` | Sitzungsdaten |

Schlägt eine dieser Prüfungen fehl, legt die Authority für diese Region **keinen** Dump ab. Die übrigen Regionen laufen
weiter.

Die Stammdaten (Clubs mit Adresse und E-Mail, Spieler, Ergebnisse) stammen aus den Verbandsquellen. Deshalb ist der Abruf
nur mit Zugangsdaten möglich.

## Ablauf auf der Authority

Ein Cronjob baut um 1:00 Uhr alle Regionen (`config/schedule.rb`, nur `roles: [:api]`):

```bash
bundle exec rake "region_dump:build[all]"
```

1. Ein Snapshot der Produktionsdatenbank — Daten und `last_version_id` stammen aus demselben Stand, auch wenn während des
   Laufs neue Versionen entstehen.
2. Eine bereinigte Basis-Kopie ohne Versionsdaten.
3. Je Region: eine Kopie davon, der Regionsfilter `cleanup:remove_non_region_records`, die Prüfungen, `pg_dump`.

Einzelne Regionen baut man mit `region_dump:build[NBV]`, mehrere mit Leerzeichen: `region_dump:build[NBV BVW]` (Rake
trennt Argumente am Komma). Gebaut werden Regionen mit mindestens einem Club und einem Kürzel aus Großbuchstaben, derzeit 17.
Lokal gemessen dauert ein Lauf über alle Regionen rund 5 Minuten; ein Dump ist 17–32 MB groß.

Ablage: `/var/www/carambus_api/shared/region_dumps/<REGION>/`

| Datei | Inhalt |
|---|---|
| `latest.sql.gz` | Verweis auf den jüngsten Dump |
| `latest.json` | Manifest: `region`, `file`, `created_at`, `last_version_id`, `schema_version`, `size`, `sha256` |
| `carambus_<region>_<zeitstempel>.sql.gz` | die Dumps; je Region bleiben die zwei jüngsten |
| `filter.log` | Ausgabe des Regionsfilters (wird nicht ausgeliefert) |

## Zugang ausgeben und entziehen {#zugang}

Der Zugang gilt je Region. Auf der Authority:

```bash
bundle exec rake "region_dump:grant[NBV,bc-wedel]"    # neues Passwort, wird nur einmal angezeigt
bundle exec rake "region_dump:revoke[NBV,bc-wedel]"   # Zugang entziehen
bundle exec rake region_dump:list                      # Regionen und Logins
```

`grant` für ein vorhandenes Login erneuert das Passwort. Gespeichert wird nur ein apr1-Hash in
`shared/region_dumps/.htpasswd/<REGION>` (Modus 640). Logins bestehen aus Buchstaben, Ziffern, `.`, `_`, `-`.

Abruf durch den Verein (curl fragt nach dem Passwort):

```bash
curl -fu bc-wedel -O https://api.carambus.de/region_dumps/NBV/latest.json
curl -fu bc-wedel -o carambus_nbv.sql.gz https://api.carambus.de/region_dumps/NBV/latest.sql.gz
shasum -a 256 carambus_nbv.sql.gz     # muss sha256 aus latest.json ergeben
```

Ohne Zugangsdaten antwortet der Server mit 401, mit den Zugangsdaten einer anderen Region wird der Abruf abgewiesen.

## Einrichtung auf der Authority (einmalig)

Die nginx-Konfiguration der Authority wird von Hand gepflegt; der Dump-Zugang kommt als eigenes Snippet dazu:

```bash
sudo cp templates/nginx/carambus_region_dumps.conf /etc/nginx/snippets/
sudo cp templates/nginx/carambus_bot_block.conf /etc/nginx/conf.d/
```

Im `server`-Block für Port 443 von `/etc/nginx/sites-available/carambus_api` die Zeile
`include snippets/carambus_region_dumps.conf;` ergänzen, dann:

```bash
sudo nginx -t && sudo systemctl reload nginx
```

Die geänderte Bot-Block-Datei nimmt `/region_dumps/` von der Abweisung für `curl` aus — sonst bekäme der Abruf 403.
Auf Vereinsservern ist die Ausnahme wirkungslos, dort gibt es keine Dumps.

!!! warning "Versions-Sync ohne Anmeldung"
    `/versions/get_updates` auf der Authority ist weiterhin ohne Anmeldung erreichbar. Er liefert nur die jüngeren
    Versionen, nicht den Bestand — der Dump bleibt der einzige vollständige Stand. Die Absicherung des Syncs ist ein
    eigener Punkt.
