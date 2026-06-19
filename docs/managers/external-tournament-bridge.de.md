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

Im Server-Verzeichnis des Carambus-Scenarios:

```bash
rake service_accounts:create_carambus_app[NBV]
```

Output: Einmaliges Password — **sicher kommunizieren**, nicht in Chat/Email
klartext. Persönlich übergeben oder über einen vertrauenswürdigen Kanal
(z.B. Passwort-Manager-Share).

### Schritt 2: App-Konfiguration (App-Entwickler/Turnierleiter)

Die App benötigt:

- **Base-URL** — abhängig von der Topologie:
  - Lokal im Clubheim-WLAN: `http://carambus.local:3000` oder `http://192.168.X.X:3000`
  - Per-Region Cloud: `https://nbv.carambus.de`
  - Globale Cloud: `https://carambus.de`
- **Service-Account-Email**: `carambus-app-nbv-bridge@carambus.de` (oder analog für andere Regionen)
- **Password**: aus Schritt 1
- **Region-Shortname**: z.B. `NBV`, `BCW`

Die App führt einmal pro Session einen Login-Call aus und erhält einen
Bearer-Token (gültig 90 Tage). Alle weiteren API-Aufrufe nutzen diesen Token
im `Authorization`-Header.

### Schritt 3: Smoke-Test vor dem Turnier

Verifiziere die Anbindung vor dem ersten echten Turnier:

```bash
SERVICE_ACCOUNT_PASSWORD="<password>" rake external_tournament:smoke_test[NBV]
```

Erfolgreicher Output zeigt 6 Schritte mit `✓` (Login → Tournament-Lookup →
Seeding → Round-Start → Round-Result → Player-Reconcile). Bei Fehler siehe
Abschnitt "Was läuft schief?" weiter unten.

## Deployment-Topologie

Die Bridge funktioniert in drei Topologien — gleich aus App-Sicht, nur die
Base-URL ändert sich:

| Topologie | Beispiel | App-Base-URL |
|-----------|----------|--------------|
| **Lokal am Spielort** | carambus_bcw im Clubheim, App auf iPad im selben WLAN | `http://carambus.local:3000` |
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

### "422 TableMonitor not found for table_no=N"

Beim Round-Start: Carambus findet keinen Tisch mit `Table.name == "N"` in der
Tournament-Location. Lösung: Sportwart prüft die Tables in der
Carambus-Admin-UI — entweder Tische mit App-erwarteten Namen anlegen
(typisch `"1"`, `"2"`, …) oder die App-Konvention anpassen.

### "422 Player not resolved"

Bei Round-Start: ein Spieler-Match ist gescheitert. Carambus probiert in der
Reihenfolge:

1. Region + Club-Cloud-ID
2. DBU-Mitgliedsnummer
3. Vorname + Nachname (optional + Verein)

Lösung: Sportwart legt den unbekannten Spieler manuell in der CC-UI an
(Vorname, Nachname, Verein) und die App schickt den Round-Start erneut.

## Pilot-Story

BC Wedel 3-Band-Mannschaftsmeisterschaft 2026-05-17 — erste Anwendung der
Bridge mit der 3BandMannschaftsTurnier-App auf iPad im Clubheim-WLAN gegen
lokales `carambus_bcw`-Scenario.

Status: Live-Roundtrip-Validierung mit der App steht aus (zeitlich abhängig
von der nächsten Turnier-Gelegenheit; technisches Smoke-Test-Substrate ist
verfügbar).

## Verwandte Doku

- [Developer-Doku — Technische Details und Mapping-Tabellen](../developers/external-tournament-bridge.md)
- [API-Referenz — Vollständige Endpoint-Spezifikation](../reference/api.md)
- [ClubCloud MCP Setup-Service (Sportwart-Setup-Pendant)](clubcloud-mcp-setup-service.md)
