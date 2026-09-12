# External Tournament Bridge — Anwender-Anleitung

> **Persona:** Turnierleiter oder Vereinsadmin mit eigener Turnier-App,
> der Setzlisten und Ergebnisse zwischen App und Carambus synchronisieren möchte.

## Was ist das?

Wenn dein Verein eine eigene Turnier-App nutzt (z.B. das 3BandMannschaftsTurnier
für 3-Band-Mannschaftsmeisterschaften), kann diese App jetzt direkt mit Carambus
sprechen — statt Ergebnisse doppelt einzutippen.

Drei Datenflüsse:

1. **Carambus → App**: Setzliste mit Spielern und Teams (App holt sich die
   Spielerdaten aus der Carambus-Datenbank).
2. **App → Carambus**: Tisch-Paarungen (App teilt Carambus mit, welcher Spieler
   an welchem Tisch gegen wen spielt — Carambus aktiviert die Scoreboards).
3. **Carambus → App**: Spielergebnisse (Bälle, Aufnahmen, Höchstserie) aus den
   Scoreboard-Eingaben zurück an die App.

Daneben gibt es weitere Endpoints unter `/api/external_tournament/` (u. a. lokale
App-Turniere, Tisch-Sperre, Ergebnis-Quittung, Liga-Spieltag, Spieler-Abgleich);
Details in der [Entwickler-Doku](../developers/external-tournament-bridge.md).

## Wann brauche ich das?

- Du hast eine eigene Turnier-Software, die Carambus nicht abdeckt (z.B. ein
  spezifisches 3-Band-Mannschaftsformat mit eigener Tabellenlogik).
- Vor-Ort-Setup auf iPad oder Laptop im Clubheim, das offline funktionieren muss.
- Du willst die Doppel-Erfassung zwischen App und Carambus-Scoreboards eliminieren.

Wenn dein Vereinsturnier komplett über Carambus läuft (Anmeldung →
Auslosung → Scoreboards → Endrangliste), brauchst du diese Bridge **nicht**.

## Setup-Workflow

### Wer macht was?

| Rolle | Tätigkeit |
|-------|-----------|
| Sportwart / Admin | Service-Account anlegen, Password sicher übergeben |
| App-Entwickler / Turnierleiter | App mit Email + Password + Base-URL konfigurieren |

### Schritt 1: Service-Account anlegen (Sportwart)

Auf dem Carambus-Server, auf dem die App arbeiten soll (der Account ist ein
Benutzer in dessen Datenbank), im Deploy-Verzeichnis:

```bash
cd /var/www/<basename>/current
RAILS_ENV=production bundle exec rake "service_accounts:create_carambus_app[NBV]"
```

Output: Einmaliges Password — **sicher kommunizieren**, nicht in Chat/Email
klartext. Persönlich übergeben oder über einen vertrauenswürdigen Kanal
(z.B. Passwort-Manager-Share).

Existiert der Account schon, gibt der Task **kein** Passwort aus. Ein neues
Passwort erzeugt `ROTATE=1 RAILS_ENV=production bundle exec rake "service_accounts:create_carambus_app[NBV]"`;
dabei werden alle bisher ausgegebenen Tokens ungültig.

### Schritt 2: App-Konfiguration (App-Entwickler/Turnierleiter)

Die App benötigt:

- **Base-URL** — abhängig von der Topologie:
  - Lokal im Clubheim-WLAN: `http://<IP-des-Local-Servers>:<webserver_port>` (Standard 3131,
    z. B. `http://192.168.2.210:3131`). Liefert Carambus die App selbst unter `/app/` aus, entfällt
    die Base-URL (siehe unten).
  - Per-Region Cloud: `https://nbv.carambus.de`
  - Globale Cloud: `https://carambus.de`
- **Service-Account-Email**: `carambus-app-nbv-bridge@carambus.de` (oder analog für andere Regionen)
- **Password**: aus Schritt 1
- **Region-Shortname**: z.B. `NBV`

Die App führt einmal pro Session einen Login-Call aus und erhält einen
Bearer-Token (gültig 90 Tage). Alle weiteren API-Aufrufe nutzen diesen Token
im `Authorization`-Header.

Login: `POST <Base-URL>/login` mit den Headern `Content-Type: application/json` **und**
`Accept: application/json`, Body `{"user":{"email":"…","password":"…"}}`. Der Token steht im
`Authorization`-Header der Antwort.

### Auslieferung über Carambus (`/app/`)

Carambus kann die Turnier-App selbst unter `/app/` ausliefern. Dann laufen App und Carambus
auf demselben Server (Same-Origin): Die App leitet ihre API-Adresse aus der Browser-Adresse ab,
eine Base-URL ist nicht nötig, und der Chat bietet einen Deep-Link `/app/?…` mit Region und Turnier
an (das Passwort steht nie im Link).

Voraussetzungen, am Werkzeug belegt:

- `serve_tournament_app: true` in `carambus_data/scenarios/<szenario>/config.yml`
- das Repo `carambus_app` auf dem Admin-Rechner **neben** `carambus_data`, mit
  `carambus_app/public/index.html`
- `rake "scenario:prepare_deploy[<szenario>]"` kopiert `carambus_app/public/` nach
  `<deploy_to>/shared/public/app` (Schritt 4.6). Fehlt `index.html`, warnt der Task und das Deployment
  läuft weiter; `/app/` liefert dann 404.

Woher ein fremder Verein das Repo `carambus_app` bekommt, regelt die Doku nicht; das ist offen.

### Schritt 3: Smoke-Test vor dem Turnier

Verifiziere die Anbindung vor dem ersten echten Turnier:

Auf dem Local-Server, im Deploy-Verzeichnis (der Task sucht das Turnier in der
Datenbank, in der er läuft):

```bash
cd /var/www/<basename>/current
BASE_URL=http://localhost:<webserver_port> SERVICE_ACCOUNT_PASSWORD="<password>" \
  RAILS_ENV=production bundle exec rake "external_tournament:smoke_test[NBV]"
```

Ohne `BASE_URL` nimmt der Task `http://localhost:3000` und scheitert schon beim Login.

Erfolgreicher Output zeigt 6 Schritte mit `✓` (Login → Tournament-Lookup →
Seeding → Round-Start → Round-Result → Player-Reconcile). Bei Fehler siehe
Abschnitt "Was läuft schief?" weiter unten.

!!! warning "Der Smoke-Test schreibt"
    Er nimmt das erste mit der ClubCloud verknüpfte Turnier der Region, legt dort
    ein Testspiel an und belegt Tisch 1 der Turnier-Location. Nicht während des
    Spielbetriebs ausführen. Aufräumen danach mit
    `rake "external_tournament:reset_app_tournament[<tournament_id>]"` (Turnier auf
    Anfang, `DRY_RUN=1` zeigt vorher, was passiert) bzw.
    `rake "external_tournament:end[<tournament_id>]"` (beenden und Tische freigeben).

## Deployment-Topologie

Die Bridge funktioniert in drei Topologien — gleich aus App-Sicht, nur die
Base-URL ändert sich:

| Topologie | Beispiel | App-Base-URL |
|-----------|----------|--------------|
| **Lokal am Spielort** | carambus_bcw im Clubheim, App auf iPad im selben WLAN | `http://<IP-des-Local-Servers>:3131` bzw. entfällt bei `/app/` |
| **Per-Region Cloud** | nbv.carambus.de | `https://nbv.carambus.de` |
| **Globale Cloud** | carambus.de | `https://carambus.de` |

**Realer Default für Vereinsturniere: Lokal.** Kein Internet erforderlich, alle
Daten bleiben im Clubheim-WLAN. Sync zu der übergeordneten Per-Region- oder
Global-Instanz läuft entkoppelt über den Carambus-Sync-Layer — die App ist
davon unabhängig.

Technische Details:
[Developer-Doku External Tournament Bridge](../developers/external-tournament-bridge.md)

## Was läuft schief?

### "401 Unauthorized"

Bearer-Token fehlt oder ist ungültig. Lösung: App-seitig einen neuen
Login-Call machen und den Token aus dem `Authorization`-Response-Header
extrahieren.

### "404 Not Found" auf `/seeding` oder `/round_result`

`tournament_cc_id` oder `region` passt nicht. Prüfe:

- Korrekter Region-Shortname (z.B. `NBV` statt `nbv` — Carambus normalisiert
  zwar, aber konsistente Schreibung hilft)
- `tournament_cc_id` existiert tatsächlich in Carambus (Sportwart prüft das
  über die Admin-UI oder über ClubCloud-MCP)

### "422 Region mismatch"

Tournament-Region passt nicht zum übergebenen Region-Param. Prüfe ob das
Turnier wirklich der angegebenen Region zugeordnet ist.

### "422 Table not found: N"

Beim Round-Start: Carambus findet keinen Tisch mit diesem Namen in der
Turnier-Location. Gesucht wird nach `table_name` aus dem Payload (z. B. `"Tisch 5"`),
sonst nach `table_no` als Text. Die Location kommt aus dem Payload (`location.id`
bzw. `cc_id`), sonst aus dem Turnier. Lösung: Sportwart prüft die Tische in der
Carambus-Admin-UI — entweder Tische mit den App-erwarteten Namen anlegen oder die
App-Konvention anpassen.

### "422 TableMonitor not found for N"

Der Tisch existiert, aber es lässt sich kein Tisch-Monitor anlegen. Das passiert,
wenn der Server kein Local-Server ist.

### "422" beim Login

Der Header `Accept: application/json` fehlt (siehe Schritt 2).

### "422 Player not resolved"

Bei Round-Start: ein Spieler-Match ist gescheitert. Carambus probiert in der
Reihenfolge:

1. Region + Club-Cloud-ID
2. DBU-Mitgliedsnummer
3. Vorname + Nachname (optional + Verein)

Lösung: Sportwart legt den unbekannten Spieler manuell in der CC-UI an
(Vorname, Nachname, Verein). Der neue Spieler muss danach erst per Sync auf dem
Carambus-Server ankommen, bevor ein erneuter Round-Start greift. Für den Abgleich
gibt es außerdem den Endpoint `POST /api/external_tournament/player_reconcile`.

## Pilot-Story

BC Wedel 3-Band-Mannschaftsmeisterschaft 2026-05-17 — erste Anwendung der
Bridge mit der 3BandMannschaftsTurnier-App auf iPad im Clubheim-WLAN gegen
lokales `carambus_bcw`-Scenario.

Status: Im Juni 2026 lief ein Live-Test der Anbindung mit der App (Befunde u. a.
zur Same-Origin-Auslieferung unter `/app/`, Commit `52337e16`); seit August gibt es
Werkzeuge für lokale App-Turniere (`external_tournament:end`,
`reset_app_tournament`, `release_stale_local_tables`). Ob der vollständige Roundtrip
mit Scoreboards im Live-Betrieb validiert ist, geht aus dem Code nicht hervor.

## Verwandte Doku

- [Developer-Doku — Technische Details und Mapping-Tabellen](../developers/external-tournament-bridge.md)
- [API-Referenz — Vollständige Endpoint-Spezifikation](../reference/api.md)
- [ClubCloud MCP Setup-Service (Sportwart-Setup-Pendant)](clubcloud-mcp-setup-service.md)
