# ClubCloud-MCP-Server beim Sportwart vor Ort einrichten (Setup-Service)

## Adressat & Abgrenzung

Diese Doku richtet sich an den **Carambus-Admin** (oder Landessportwart mit Dev-Setup),
der den MCP-Server **vor Ort auf dem Rechner eines Club-Sportwarts** installiert.

**Warum vor Ort?** Der Club-Sportwart hat typischerweise nur Browser-Erfahrung — kein
Terminal, kein Code-Editor, keine Dev-Tools. Eine Remote-Installation per
Bildschirm-Sharing ist möglich (siehe Sektion 6), aber vor Ort ist deutlich
verlässlicher: der Admin sieht das Hardware-Setup direkt, kann Pfad-Probleme schnell
beheben und liefert die Credentials persönlich ab.

**Abgrenzung zu anderen Setup-Dokus:**

| Doku | Adressat | Zweck |
|------|----------|-------|
| [`clubcloud-mcp-quickstart.de.md`](clubcloud-mcp-quickstart.de.md) | Technische Stellvertretung (Landessportwart, Carambus-Admin) | 5-Min-Quickstart, erster Tool-Call |
| [`clubcloud-mcp-setup.de.md`](clubcloud-mcp-setup.de.md) | Technische Stellvertretung | Tiefes Setup-Troubleshooting, Entwickler-Setup |
| **diese Doku** (`clubcloud-mcp-setup-service.de.md`) | **Carambus-Admin beim Sportwart** | **Vor-Ort-Setup-Service für einen Sportwart, der nicht selbst installieren kann** |

Nach erfolgreichem Setup-Service kann der Sportwart in Phase 10 (v0.2-Walkthrough)
eigenständig Anmeldungen über Claude Desktop abwickeln.

---

## Sektion 1 — Pre-Visit-Checkliste

Vor dem Termin beim Sportwart prüfen und mitbringen:

### Hardware & OS

| Item | Pflicht | Notiz |
|------|---------|-------|
| Rechner-Owner geklärt? | ✅ | Sportwart-eigener Rechner ODER Admin-Leihrechner? |
| macOS 12+ ODER Windows 10/11 mit WSL2 | ✅ | Linux möglich, aber Quickstart-Doku ist macOS-fokussiert |
| 8 GB RAM, 5 GB freier Festplattenspeicher | ✅ | Ruby + Bundler + Carambus-Repo |
| Stabile Internet-Verbindung | ✅ | 4G-Hotspot als Backup mitbringen |
| Admin-Rechte auf dem Rechner | ✅ | Für Ruby-Installation und Pfad-Setup |

### Software-Vorbereitung

- [ ] **Claude Desktop** auf dem Sportwart-Rechner installieren (oder schon installiert?)
  → [claude.ai/download](https://claude.ai/download)
- [ ] **Git** vorhanden (`git --version`)?
- [ ] **rbenv** oder vergleichbare Ruby-Versionsverwaltung installiert?
- [ ] **Editor** (VS Code oder TextEdit) für claude_desktop_config.json-Editierung?

### CC-Credentials

- [ ] **Sportwart-CC-Login** (Username + Password) bei Sportwart geklärt — wird beim Termin verwendet (NICHT vorher übertragen!)
- [ ] **region_cc_id** des Vereins bekannt (z.B. NBV = 20)
- [ ] **base_url** der CC-Region (z.B. `https://nbv.club-cloud.de`)
- [ ] Sportwart-Rechte in CC verifiziert (Anmelden + Meldeschluss verschieben + Teilnehmerliste pflegen)

### Backup-Plan

- [ ] **Remote-Bildschirm-Sharing** (Zoom/TeamViewer) als Fallback installiert, falls vor-Ort-Setup scheitert
- [ ] **Mein eigener Admin-Rechner** mitbringen, um Test-Calls parallel zu fahren
- [ ] **USB-Stick** mit lokalem Carambus-Repo-Clone (falls Internet beim Sportwart schwach)

---

## Sektion 2 — Installation macOS

### 2.1 Ruby 3.2.1 via rbenv

```bash
# rbenv installieren (falls nicht vorhanden)
brew install rbenv ruby-build

# In ~/.zshrc oder ~/.bashrc einfügen:
echo 'eval "$(rbenv init -)"' >> ~/.zshrc
source ~/.zshrc

# Ruby 3.2.1 installieren
rbenv install 3.2.1
rbenv global 3.2.1
ruby --version  # → ruby 3.2.1
```

### 2.2 Bundler

```bash
gem install bundler
bundler --version  # → Bundler 2.7+
```

### 2.3 Carambus-Repo

```bash
mkdir -p ~/DEV/carambus
cd ~/DEV/carambus
git clone <repo-url> carambus_local  # ODER USB-Stick-Kopie
cd carambus_local
bundle install
```

### 2.4 Datenbank-Verbindung verifizieren

```bash
bin/rails db:version
# Erwartung: Migration-Version-Nummer (KEIN Connection-Error)
```

Wenn DB-Connection-Error: PostgreSQL-Setup mit dem Sportwart-Rechner abklären
(lokale Carambus-DB ODER Remote-Connection zu Carambus-Produktion).

### 2.5 claude_desktop_config.json

Pfad: `~/Library/Application Support/Claude/claude_desktop_config.json`

```json
{
  "mcpServers": {
    "carambus-cc": {
      "command": "/Users/<USERNAME>/.rbenv/shims/bundle",
      "args": ["exec", "/Users/<USERNAME>/DEV/carambus/carambus_local/bin/mcp-server"],
      "env": {
        "RAILS_ENV": "development",
        "CC_REGION": "nbv",
        "CARAMBUS_MCP_MOCK": "0"
      }
    }
  }
}
```

`<USERNAME>` ersetzen mit dem macOS-Username des Sportwarts. `CC_REGION` an die Region anpassen.

### 2.6 Berechtigungen

```bash
chmod 600 ~/Library/Application\ Support/Claude/claude_desktop_config.json
```

Verhindert, dass Credentials in Backups/iCloud-Sync versehentlich landen.

---

## Sektion 3 — Installation Windows (WSL2)

### 3.1 WSL2 Ubuntu installieren

PowerShell (als Admin):

```powershell
wsl --install -d Ubuntu-22.04
# Nach Reboot: Ubuntu-User + Password anlegen
```

### 3.2 Innerhalb WSL: gleiche Schritte wie macOS Sektion 2

Ruby + Bundler + Repo via `apt install build-essential libssl-dev libreadline-dev zlib1g-dev` plus rbenv.
Carambus-Repo unter `~/DEV/carambus/carambus_local` (WSL-Pfad).

### 3.3 claude_desktop_config.json (Windows-Native)

Pfad: `%APPDATA%\Claude\claude_desktop_config.json` (Windows-Pfad, NICHT WSL-Pfad)

```json
{
  "mcpServers": {
    "carambus-cc": {
      "command": "wsl",
      "args": [
        "-d", "Ubuntu-22.04",
        "bash", "-c",
        "cd /home/<USERNAME>/DEV/carambus/carambus_local && bundle exec bin/mcp-server"
      ],
      "env": {
        "RAILS_ENV": "development",
        "CC_REGION": "nbv",
        "CARAMBUS_MCP_MOCK": "0"
      }
    }
  }
}
```

`<USERNAME>` ist der WSL-Linux-Username (NICHT der Windows-Username).

### 3.4 Berechtigungen

PowerShell:

```powershell
icacls "$env:APPDATA\Claude\claude_desktop_config.json" /inheritance:r /grant:r "$env:USERNAME:F"
```

Falls Windows-Pfad-Übersetzung Probleme macht: **direkt auf Sektion 6 (Remote-Bildschirm-Sharing-Fallback)** ausweichen.

---

## Sektion 4 — Credentials-Übertragung

### Erlaubte Übertragungswege

| Methode | Sicherheit | Empfehlung |
|---------|------------|------------|
| 1Password Shared Item (kurz, mit Auto-Expire) | Hoch | ✅ Bevorzugt |
| Verschlüsselte E-Mail (ProtonMail, Tutanota) | Hoch | ✅ |
| USB-Stick beim Termin abgeben + sofort vernichten | Mittel-Hoch | ✅ Falls digitaler Weg unmöglich |
| **Beim Termin direkt vom Sportwart einsehen + eintippen** | Hoch (kein Transit) | ✅ Bevorzugt |

### Verbotene Übertragungswege

| Methode | Risiko |
|---------|--------|
| Slack/Discord/Telegram/SMS im Klartext | ❌ Logs/Backups bei den Anbietern |
| E-Mail im Klartext | ❌ Mail-Server-Logs |
| Dropbox/iCloud/Google Drive | ❌ Cloud-Sync, Backup-Historie |
| Browser-Notiz / Sticky Note | ❌ Sync-Risiko |

### Schritt-für-Schritt vor Ort

1. Sportwart-CC-Login direkt in CC-Browser einloggen → Username/Password aus Browser-Password-Manager ablesen
2. claude_desktop_config.json **vor Ort** mit den Credentials befüllen (NICHT vorbereitet)
3. `chmod 600` (macOS) / `icacls` (Windows) ausführen
4. Sportwart-Rechner-Cloud-Sync prüfen — falls aktiv, Hinweis: claude_desktop_config.json **nicht** in iCloud Drive / OneDrive / Dropbox legen
5. CC-Credentials beim Sportwart verbleiben (Browser-Password-Manager); Carambus-Admin notiert sie sich NICHT für späteren Zugriff

---

## Sektion 5 — Smoke-Test-Drehbuch (Akzeptanz-Step)

Nach Setup ist Akzeptanz erreicht, wenn der Sportwart **ohne Admin-Hilfe** folgenden Dialog in Claude Desktop führen kann:

### Test-Dialog

> **Sportwart tippt:**
> „Hallo Claude — zeig mir den Status zu meinem Verein in ClubCloud."

> **Erwartung Claude-Antwort:**
> Claude ruft `cc_lookup_region` + `cc_lookup_club` auf und zeigt:
> - Region-Name (z.B. „NBV")
> - Sportwart-eigener Verein mit cc_id, Spielerliste, Trainer-Info, etc.

### Erweiterter Test (Walkthrough-Vorbereitung)

> **Sportwart tippt:**
> „Welche offenen Turniere stehen aktuell in Kegel an?"

> **Erwartung:**
> Claude ruft `cc_list_open_tournaments` mit branch_cc_id=8 auf und zeigt Liste mit Deadline-Daten.

### Wenn der Smoke-Test gelingt

✅ Sportwart ist Phase-10-walkthrough-fähig
✅ Carambus-Admin kann den Sportwart-Termin schließen
✅ Sportwart bekommt:
- Eine 1-Seiten-PDF mit häufigen NL-Befehlen (Quickstart-Excerpt)
- Telefonnummer/E-Mail des Carambus-Admins für Notfälle
- Hinweis: bei Claude-Desktop-Update / OS-Update muss ggf. neu installiert werden

### Wenn der Smoke-Test scheitert

**Häufige Fehler:**

| Fehler | Diagnose | Fix |
|--------|----------|-----|
| Claude antwortet „MCP-Server nicht erreichbar" | claude_desktop_config.json Pfad falsch | Pfad-Trace via Claude Desktop Devtools |
| Claude antwortet „CC-Auth-Failure" | Credentials in Rails Credentials nicht gesetzt | Rails-Credentials in carambus-Repo prüfen, ggf. neu eintragen |
| Claude antwortet „DB-Connection-Error" | PostgreSQL nicht erreichbar | `bin/rails db:version` testen; ggf. SSH-Tunnel zur Carambus-Produktion |
| Tool-Call funktioniert, aber Rückgabe leer | DB-Sync veraltet | Tool mit `force_refresh: true` erneut aufrufen |

Bei wiederholtem Scheitern: Remote-Bildschirm-Sharing vereinbaren und Logs analysieren (siehe `clubcloud-mcp-setup.de.md` Sektion „Lokales Debug").

---

## Sektion 5.5 — Permission-Setup in Claude Desktop („Always allow")

**Warum diese Sektion?** (Adressiert Befund #6 aus dem Plan-10-03-Sportwart-Walkthrough; siehe `.paul/phases/10-walkthrough-sportwart/10-03-WALKTHROUGH-LOG.md`.)

Claude Desktop fragt **per Default** bei jedem MCP-Tool-Call nach Erlaubnis. Für die typischen
Carambus-Workflows (Anmeldung, Akkreditierung, Liste finalisieren) bedeutet das pro Spickzettel
**4–8 Permission-Prompts**, weil jeder Spickzettel mehrere Tools nacheinander aufruft und destruktive
Tools im Dry-Run-First-Modus zweimal laufen (`armed:false` → `armed:true`).

**Auswirkung beim Sportwart:**
- Jeder Workflow wird durch 4–8 Klicks unterbrochen.
- Sportwart denkt „Passt das? Muss ich das wirklich erlauben?" → Vertrauens-Lücke.
- Abbruch-Risiko: bei zu vielen Prompts klickt der Sportwart auf „Verweigern" oder schließt Claude.

**Lösung:** Permission-Modus für den `carambus-clubcloud` MCP-Server auf **„Always allow for this
server"** stellen. Die Permission-Prompts entfallen dann komplett für die laufende Session und
(je nach Claude-Desktop-Version) auch persistent für künftige Sessions.

**Schritt-für-Schritt (Stand 2026-05; Claude-Desktop-UI kann sich ändern):**

1. Claude Desktop öffnen → **Einstellungen** (Cmd+, auf macOS / Ctrl+, auf Windows).
2. Tab „Erweitert" / „Developer" / „Tools & Extensions" suchen — der exakte Pfad variiert je nach
   Claude-Desktop-Version.
3. **MCP-Servers**-Liste suchen, den Eintrag `carambus-clubcloud` finden.
4. Permission-Modus auf **„Always allow for this server"** stellen (Dropdown oder Toggle).
5. **Alternative**, falls Du den Einstellungs-Pfad nicht findest: warte auf den ersten Tool-Call
   im Dialog (z.B. via Spickzettel „Status Eurokegel?") und klicke beim Permission-Prompt auf
   **„Don't ask again for this server"** (oder „Immer erlauben — dieser Server").

**Verifikation:** Nach dem Setting einen Spickzettel-Workflow durchspielen (z.B.
`cc://workflow/scenarios/sportwart-tagesablauf-vor-turnier`). Es sollten **0 Permission-Prompts**
mehr erscheinen.

**Sicherheits-Hinweis:** Permission-Bypass nur für **vertrauenswürdige** MCP-Server aktivieren.
Beim Carambus-Setup-Service ist Vertrauen begründet:

- Du (der Carambus-Admin) hast den MCP-Server selbst installiert (Sektionen 2 + 3).
- `claude_desktop_config.json` ist per `chmod 600` geschützt (Sektion 4).
- Der MCP-Server hat 4-Schichten-Sicherheitsnetz + Pre-Validation-First-Pattern (Plan 10-05.1) +
  Audit-Trail (JSON-Lines `log/mcp-audit-trail.log`). Auch ohne Permission-Prompt kann der Sportwart
  destruktive Operationen nur via expliziten `armed:true`-Step ausführen, und alle armed-Calls werden
  vollständig auditiert.

**Sportwart-Briefing (kurz):** Erkläre dem Sportwart vor dem ersten Workflow:
„Claude führt jetzt jeden Spickzettel ohne Rückfragen aus, weil ich (Dein Admin) Claude den Server
einmalig erlaubt habe. Bei destruktiven Aktionen (Anmelden, Liste schließen, Spieler entfernen)
zeigt der MCP-Server vorher trotzdem den Trockenlauf — Du musst noch immer aktiv mit „Anmelden" /
„Schließen" / „Entfernen" bestätigen, BEVOR es scharf wird."

---

## Sektion 6 — Remote-Bildschirm-Sharing-Fallback

Wenn vor-Ort-Besuch nicht möglich ist (Distanz, Termin-Konflikte, COVID-Risiko, etc.):

### Setup-Voraussetzungen

- Zoom oder TeamViewer auf beiden Rechnern installiert
- Sportwart-Rechner kann Bildschirm freigeben (NICHT nur Maus-/Tastatur-Steuerung)
- Verschlüsselte Channel für Credentials (1Password Shared Item ODER Signal-Nachricht mit Selbstzerstörung)

### Ablauf

1. Video-Call starten, Sportwart teilt Bildschirm
2. Carambus-Admin **diktiert** Befehle (Sportwart tippt selbst — wichtig für späteres Re-Install)
3. Credentials: Sportwart liest aus Browser-Password-Manager vor; ODER Admin schickt 1Password-Shared-Item mit 5-Min-Expire
4. claude_desktop_config.json: Sportwart erstellt die Datei mit Editor; Admin diktiert Inhalt
5. Smoke-Test: gleicher Dialog wie Sektion 5

### Nachteile gegen vor Ort

- Admin sieht keine Hardware-Pfade direkt
- Pfad-Probleme schwerer zu debuggen
- Sportwart sieht alle Schritte mit (Wissenstransfer-Vorteil, aber auch Confidentiality-Risk für Admin-Workflows)
- Sportwart kann später NICHT eigenständig re-installieren (Admin muss erneut ran)

---

## Sektion 7 — MCP-Server-Subprocess neu starten (nach Code-Changes)

Claude Desktop und Claude Code fahren den MCP-Server als langlebigen Subprocess. Code-Changes in `lib/mcp_server/**` oder `bin/mcp-server` greifen NICHT automatisch — Tool-Schemas und Tool-Logik bleiben im Stale-Zustand bis zum Restart. Diese Sektion erklärt **wann** Du den Subprocess neu starten musst und **wie** das pro Client geht.

### 7.1 Wann neu starten?

Restart ist nötig nach jeder der folgenden Aktionen:

- **`git pull`** mit Änderungen in `lib/mcp_server/**` oder `bin/mcp-server` (Tool-Code, Schemas, PATH_MAP, ApiSurface-ALLOWLIST)
- **Lokaler Code-Edit** an Tool-Schema, Pre-Validation-Constraints, AuditTrail-Logik oder BaseTool-Helpers
- **`bundle install`** mit MCP-relevanten Gem-Updates (z.B. `mcp`-Gem-Bump auf neue Version)
- **Änderung von Rails Credentials** (`config/credentials/{env}.yml.enc`) oder `.env`-Variablen wie `CC_REGION`, `CARAMBUS_MCP_MOCK` — der Subprocess liest ENV nur beim Start

### 7.2 Stale-Subprocess-Symptome

Diese Beobachtungen sind verlässliche Hinweise, dass der Subprocess auf altem Code-Stand läuft:

- **Tool-Schemas zeigen alten Parameter-Stand** (z.B. fehlende `name`/`shortname`-Params in `cc_lookup_tournament`, fehlende Convenience-Wrapper `club_name`/`player_name` in Write-Tools)
- **Tool-Calls liefern Pre-Edit-Verhalten** (Region-Filter wird ignoriert, alte Disambiguation-Output-Form, fehlendes `pre_read_*`-Output in Write-Tools)
- **Neu hinzugefügte Tools tauchen nicht in der Tool-Liste auf** (z.B. nach `git pull` mit Plan-XX-Tool-Erweiterung)
- **Tool-Descriptions ohne Use-Case-Präfix** (kein „Wann nutzen?" + „Was tippt der User typisch?" sichtbar — sollte seit Plan 10-07 in allen 22 öffentlichen Tools zu sehen sein)

Wenn eines dieser Symptome auftritt: Vor jeglicher Diagnose erst Restart durchführen, dann Re-Verify.

### 7.3 Restart in Claude Desktop (macOS + Windows)

**Primär-Pfad:**

1. **Settings öffnen** (macOS: Claude → Settings; Windows: Datei → Settings)
2. **„Developer"-Tab auswählen** (oder „Extensions" je nach Claude-Desktop-Version)
3. **MCP-Server-Liste suchen** — Eintrag `carambus-clubcloud` (oder gewählter Server-Name) erscheint mit Status-Indikator
4. **Restart-Icon klicken** (typisch: Refresh-Symbol neben dem Server-Namen). Falls Icon in Deiner Claude-Desktop-Version nicht verfügbar ist → Fallback.

**Fallback (jede Claude-Desktop-Version):**

1. **Claude Desktop komplett beenden**: macOS `Cmd+Q` (NICHT nur Fenster schließen — Hintergrund-Process muss enden); Windows `Alt+F4` + ggf. via Task-Manager prüfen dass `Claude.exe` nicht mehr läuft
2. **Claude Desktop neu öffnen** — Subprocess wird beim ersten Chat-Öffnen automatisch neu hochgezogen

**Verifikations-Step:**

Nach Restart einmal `cc_lookup_region` aufrufen (oder ein beliebiges Tool, das im jüngsten Code-Edit betroffen war). Wenn der neue Tool-State sichtbar ist (z.B. neue Parameter im Schema, neuer Description-Präfix, neues Output-Format), ist der Subprocess fresh.

### 7.4 Restart in Claude Code (Carambus-Admin / technische Stellvertretung)

Claude Code als MCP-Client wird typisch nur in Dev/Test-Szenarien verwendet (siehe Plan 09-03 D-09-03-A-Pragmatik). Restart-Pfade:

- **`/mcp` Subcommand** listet alle MCP-Server-Subprocesses inkl. Status (connected / disconnected / restarting)
- **`/mcp` ermöglicht** (je nach Claude-Code-Version) Reconnect oder Reload pro Server-Eintrag direkt aus der Subcommand-UI
- **Fallback:** Claude-Code-Session beenden (`/exit` oder Ctrl+D), neue Session starten — Subprocess wird beim Session-Start neu hochgezogen

### 7.5 Audit-Trail (Plan 10-08 Befund #1)

Diese Sektion existiert wegen CRITICAL-Befund #1 aus Plan 10-08 Externer Walkthrough (2026-05-12). Der MCP-Subprocess startete vor Plan-10-05/06/07-Commits; ToolSearch-Schemas zeigten Pre-Plan-10-06-Stand (kein `name`/`shortname`-Param, kein Use-Case-Präfix); die Plan-Boundary „0 versehentliche Live-Datenänderungen" griff defensiv → Walkthrough wurde im Limited-Mode geschlossen.

Lesson: Bevor jegliche Live-Validation gegen Prod-CC gestartet wird (insbesondere durch externen Sportwart oder Turnierleiter), MUSS der Subprocess nach allen jüngsten Code-Changes neu gestartet sein. Diese Doku-Sektion ist die Operator-Defense; eine strukturelle Lösung (Dev-Mode-Reload-Watcher analog Rails-autoload) ist als v0.2.1-Backlog-Item A1 vorgesehen.

Vollständiges Audit-Trail: `.paul/phases/10-walkthrough-sportwart/10-08-WALKTHROUGH-LOG.md` (Sektion 1 + Sektion 8 mit konsolidiertem v0.2.1-Backlog).

---

## 8. DSGVO-Compliance / Datenschutz

> **v0.3-Pilot-Boundary (D-13-01-E minimal-pragmatic):** Diese Sektion dokumentiert die DSGVO-Erfüllung für den Carambus ClubCloud MCP-Server in der Pilot-Phase. Vollständige Self-Service-Banner-Implementierung ist deferred zu v0.4.

### 8.1 Datenkategorien (was wird gespeichert?)

| Daten | Format | Sensitivität | Persistenz |
|-------|--------|--------------|------------|
| `users.cc_credentials` | encrypted JSON | HOCH (Passwort-Material) | Rails-`encrypts`-Strategie; bis User-Löschung oder Widerruf |
| `users.mcp_role` | enum | NIEDRIG (Rolle) | bis User-Löschung |
| `users.cc_region` | String | NIEDRIG (öffentlich) | bis User-Löschung |
| `users.mcp_consent_at` | datetime | NIEDRIG (Metadatum) | bis User-Löschung |
| `mcp_audit_trails.*` | DB-Zeile | MITTEL (Tool-Calls + payload) | 1 Jahr (Retention); `user_id` wird bei User-Löschung NULL (FK `ON DELETE NULLIFY`) |
| `log/mcp-audit-trail.log` | JSON-Lines-File | MITTEL (analog DB) | bis Datei-Rotation (logrotate-Config) |

### 8.2 Verarbeitungszwecke

- **`cc_credentials`**: Authentifizierung gegen ClubCloud-API für Tool-Calls; nur Tool-internal lesbar (`Setting.login_to_cc`-Override im v0.3-Pilot single-global).
- **`mcp_role` + `cc_region`**: Per-User-Tool-Subset + Region-Routing (Plan 13-02 + Plan 13-04 + Plan 13-04.1).
- **`mcp_audit_trails`**: Forensik bei Live-CC-Fehlern + Multi-User-Filterung für Sicherheit; `payload[armed]=true` ist Trigger für Daten-Mutations-Audit.
- **`mcp_consent_at`**: Einwilligungs-Nachweis nach Art. 7 DSGVO.

### 8.3 Retention (Aufbewahrung)

- `cc_credentials`: bis User explizit widerruft (`user.mcp_role := :mcp_public_read`) oder Carambus-Admin User löscht.
- `mcp_audit_trails`: **1 Jahr** (Forensik-Pflicht); manuelle Cleanup-Routine via
  ```ruby
  McpAuditTrail.where('created_at < ?', 1.year.ago).delete_all
  ```
  durch Carambus-Admin (v0.4 plant Auto-Cleanup via Cron).
- JSON-Lines-File: bis Datei-Rotation (siehe `logrotate`-Konfig in Plan 13-06.1 Hetzner-Deploy-Setup).

### 8.4 User-Rechte (Art. 15-21 DSGVO)

| Recht | Wie erfüllt? |
|-------|--------------|
| **Auskunft (Art. 15)** | Carambus-Admin: `User.find(id).mcp_audit_trail_export.to_json` → an User-Email senden. `cc_credentials` sind encrypted; werden NICHT exportiert (Sicherheitsbalance) |
| **Berichtigung (Art. 16)** | Carambus-Admin updated `cc_region`, `cc_credentials`, `mcp_role` über Console oder Admin-Dashboard |
| **Löschung / „Recht auf Vergessenwerden" (Art. 17)** | `User.find(id).destroy` — `mcp_audit_trails.user_id` wird NULL (FK `ON DELETE NULLIFY` aus Plan 13-05); Audit-Trail bleibt anonymisiert für Forensik-Pflicht (gerechtfertigt Art. 17 Abs. 3) |
| **Widerruf der Einwilligung (Art. 7 Abs. 3)** | Carambus-Admin: `User.find(id).update!(mcp_role: :mcp_public_read, cc_credentials: nil, mcp_consent_at: nil)` — User behält Carambus-Account, MCP-Zugriff ist deaktiviert |
| **Datenübertragbarkeit (Art. 20)** | `mcp_audit_trail_export.to_json` ist maschinenlesbares Format (analog Auskunft) |

### 8.5 Einwilligungs-Operational-Flow (v0.3-Pilot)

1. Carambus-Admin trifft User für Setup-Service-Besuch (Sektion 5 dieser Doku).
2. Admin erklärt mündlich die Datenverarbeitung (Datenkategorien aus 8.1) und User-Rechte (8.4).
3. User stimmt mündlich zu.
4. Admin attestiert via Console:
   ```ruby
   user = User.find_by(email: 'sportwart@verein.de')
   user.grant_mcp_consent!  # setzt mcp_consent_at = Time.current
   ```
5. Admin notiert Einwilligungs-Zeitpunkt im Setup-Service-Visit-Log.

**v0.4-Plan**: Self-Service-Banner im User-Profile-Settings ersetzt den Admin-attestierten Flow.

### 8.6 Verantwortlicher (Art. 4 Nr. 7 DSGVO)

- **Verantwortlicher** für die Datenverarbeitung des MCP-Servers: **Carambus-Betreiber** (siehe `config/carambus.yml` für Kontaktdaten).
- **Auftragsverarbeiter**: Hetzner Online GmbH (DE) für Hosting (v0.3-Pilot-Hosting auf carambus.de; siehe Plan 13-06.1 Deploy-Doku).
- **Datenverarbeitung erfolgt in**: Deutschland / EU (Hetzner-Server in Falkenstein/Nürnberg).
- **AVV (Auftragsverarbeitungsvertrag)**: zwischen Carambus-Betreiber und Hetzner besteht Standard-DSGVO-konformer AVV.

---

## 9. Cloud-Setup-Pfad (HTTP-Transport ab v0.3)

Ab v0.3 unterstützt der ClubCloud-MCP-Server zusätzlich zum Stdio-Pfad (Sektionen 1-7) einen **Remote-HTTP-Transport** auf einem Carambus-Hetzner-Server. Damit braucht der Sportwart/Turnierleiter **kein lokales MCP-Setup mehr** — Claude Desktop verbindet sich direkt mit dem Server.

> **Backwards-Compat:** Der Stdio-Pfad (Sektionen 2-7) bleibt parallel gültig für die technische Stellvertretung des Sportwarts und für Dev/Test. Beide Pfade führen zu identischer Tool-Funktionalität.

### 9.1 Voraussetzungen

- **Claude Desktop** (Unified-App mit integriertem Claude-Code-Daemon, Plan 13-06.1 getestet mit `claude-code/2.1.138`) ODER **Claude Code CLI** (`claude` Command verfügbar)
- **Devise-User auf dem Carambus-MCP-Server** existiert + Sportwart-/Turnierleiter-/Landessportwart-Rolle gesetzt (siehe Plan 13-02 Rollen-Modell — `landessportwart` sieht alle 22 Tools, `sportwart` sieht 16, `turnierleiter` sieht 19)
- **DSGVO-Einwilligung erteilt** (`mcp_consent_at` gesetzt — siehe Sektion 8.4 + 8.5)
- **`cc_region` + `cc_credentials`** am User gesetzt (Multi-Region-Routing — Plan 13-04.1)
- **Browser** für Erst-Login + Cookie-Extract (Devise-Session-Cookie wird im Browser-Cookie-Store hinterlegt — Claude.app teilt diese Cookies **nicht** automatisch)

> **Plan 13-06.1 Empirical-Verify-Befund (D-13-06.1-A, 2026-05-13):** Die neue Unified Claude.app liest `claude_desktop_config.json` **nicht** mehr — MCP-Server-Setup erfolgt via `claude mcp add` CLI (schreibt in `~/.claude.json`).

> **Plan 13-06.2 (D-13-06.1-C, 2026-05-14):** **JWT-Token-Auth ist Primary-Pfad** ab v0.3.0. Cookie-Inject (Plan 13-06.1) bleibt als Legacy-Option in Sektion 9.7. JWT-Token hat 24h-Lifetime (statt 120min Cookie) und ist Industry-Standard für MCP-Clients.

### 9.2 MCP-Server-Setup via Claude Code CLI (JWT-Token-Auth) ⭐ EMPFOHLEN

**Vorbereitung — JWT-Token via Login-Call holen:**

```bash
# 1. Login + Token extrahieren (Token kommt im `Authorization`-Response-Header):
TOKEN=$(curl -sS -X POST https://carambus.de/login \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -d '{"user":{"email":"DEIN_USER@example.com","password":"DEIN_PW"}}' \
  -D - | grep -i '^authorization:' | sed -E 's/^[Aa]uthorization:[[:space:]]*//' | tr -d '\r\n')

# Sanity-Check (Token muss mit "Bearer eyJ..." beginnen — Bearer-Prefix + Base64-encoded JWT):
echo "Token: $TOKEN"
```

> **Plan 13-06.4 / Fix:** `sed -E 's/^[Aa]uthorization:[[:space:]]*//'` extrahiert alles **nach** dem `authorization:`-Prefix und erhält den gesamten Token-Wert inkl. `Bearer`-Prefix. Der frühere `awk '{print $2}'`-Pipe schnitt die Zeile `authorization: Bearer eyJ...` und lieferte nur das zweite Feld (`Bearer`) ohne den Token-Wert — der `add-json`-Header war dann nutzlos.

**MCP-Server registrieren via CLI:**

```bash
claude mcp add-json --scope user carambus-remote "{
  \"type\": \"http\",
  \"url\": \"https://carambus.de/mcp?stateless=1\",
  \"headers\": {
    \"Authorization\": \"$TOKEN\",
    \"Accept\": \"application/json, text/event-stream\"
  }
}"
```

> Falls Shell-Quoting Probleme macht: Token-Wert kopieren und `add-json` mit Single-Quotes + manuell ersetztem Token aufrufen (kein Variable-Substitution).

**Verify:**

```bash
claude mcp get carambus-remote   # Status sollte "connected" zeigen
claude mcp list                  # Übersicht aller MCP-Server
```

**Wichtige Detail-Hinweise:**

- **`?stateless=1` query-param** umgeht den `Mcp-Session-Id`-Header-Stateful-Flow (D-13-06.1-E). Für Claude Code MCP-Client der einfachste robuste Weg.
- **`Accept`-Header dual** (`application/json, text/event-stream`): Streamable-HTTP-Transport-Pflicht (D-13-06-A). Ohne → 406 Not Acceptable.
- **`Authorization: Bearer <jwt>`**: Industry-Standard-Bearer-Token. Token-Lifetime **24 Stunden** ab Login. Bei Ablauf → erneuter Login-Call (Schritt 1 wiederholen) + `claude mcp remove ... && claude mcp add-json ...` neu.
- **Force-Logout**: `curl -X DELETE https://carambus.de/logout -H "Authorization: $TOKEN"` invalidiert den Token über JTIMatcher-Revocation. Alle weiteren Calls mit diesem Token → 401.

### 9.3 Aktivierung in Claude.app

Nach `claude mcp add-json` wird der Eintrag in `~/.claude.json` (user-scope) persistiert. **Claude.app Restart** (Cmd+Q + Re-Open) lädt die neue Konfig.

In neuer Chat-Session: „Welche carambus-remote Tools hast du?" → erwartete Antwort enthält die Per-Rolle gefilterte Tool-Liste (22 Tools für `mcp_landessportwart`, 16 für `mcp_sportwart`, 19 für `mcp_turnierleiter`).

### 9.4 Verifikations-Schritte

Nach Setup folgenden Dialog mit Claude führen (Read-only — KEIN `armed:true`, kein Live-CC-Write):

1. **„Welche MCP-Tools hast du?"** → erwartet Per-User-Rollen-Tool-Subset:
   - **landessportwart** → 22 Tools (volle Suite)
   - **sportwart** → 16 Tools (kein cc_assign/cc_remove/cc_finalize/cc_unregister — Akkreditierung am Turniertag fehlt)
   - **turnierleiter** → 19 Tools (kein cc_register/cc_update_deadline/cc_unregister — Pre-Tournament-Setup fehlt)
2. **„Welche Region bin ich?"** oder konkreter: **„Liste die Vereine in meiner Region für Disziplin Dreiband"** → erwartet Vereinsliste aus der eigenen `cc_region` (Multi-Region-Routing funktioniert)
3. **„Welche offenen Turniere gibt es in NBV?"** (oder eigene Region) → erwartet Read-only Turnier-Liste

> **Wichtig — Plan-Boundary v0.3:** Im Erst-Verify-Cycle KEIN `armed:true`-Call ausführen. Sicherheits-Pflicht „0 versehentliche Live-Datenänderungen" bleibt kumulativ gewahrt.

### 9.5 Troubleshooting

| Symptom | Ursache | Lösung |
|---|---|---|
| **`Failed to connect` bei `claude mcp get`** | Cookie fehlt / expired / falscher Name (Plan 13-06.1 D-13-06.1-A häufigstes Pilot-Symptom) | DevTools-Cookie-Extract erneut (`_session_id`-Wert frisch nach Browser-Login); `claude mcp remove` + neu via `add-json` |
| **400 „Missing session ID"** | `?stateless=1`-Query-Param fehlt in URL (D-13-06.1-E) | URL in `claude mcp add-json` muss `https://carambus.de/mcp?stateless=1` enthalten (mit Query-Param) |
| **401 Unauthorized** mit JSON `{"error":"Sie müssen sich anmelden..."}` | Cookie-Wert ungültig/expired oder falsches Cookie-Name (z.B. `_carambus_session` statt `_session_id`) | Browser-Re-Login → DevTools → `_session_id`-Wert kopieren; `claude mcp` Konfig erneuern |
| **406 Not Acceptable** bei tools/list oder initialize | `Accept`-Header fehlt oder nur `application/json` (D-13-06-A) | In `add-json` Header-Block beide Mime-Types: `"Accept": "application/json, text/event-stream"` |
| **„DSGVO-Einwilligung erforderlich"** | `mcp_consent_at` nicht gesetzt | Sektion 8.5 Einwilligungs-Operational-Flow durchlaufen (Browser-Banner oder Admin-Setting) |
| **Tool-Liste leer / kürzer als erwartet** | `User.mcp_role` falsch oder nicht gesetzt | Admin-Korrektur am User-Account (Rolle z.B. auf `mcp_landessportwart` setzen für volle 22-Tool-Suite) |
| **Falsche Region in Tool-Output** | `User.cc_region` falsch gesetzt | Admin-Korrektur am User-Account (Rails-Console oder Admin-UI); danach Browser-Re-Login |
| **Tool-Calls dauern lang / Timeout** | Multi-Region-Routing geht zur falschen `region_cc.base_url` (D-13-04-A) | Befund-Capture; ggf. Plan 13-06.2 Nachbesserung |
| **Claude.app ignoriert `~/.claude.json`-Eintrag** | Claude.app nicht restarted nach `claude mcp add-json` | Cmd+Q + Re-Open (kein Hot-Reload) |
| **Login-Call liefert leeren Authorization-Header** | devise-jwt-Config falsch (z.B. `dispatch_requests`-Regex matched Login-Route nicht) ODER `Accept: application/json`-Header fehlte beim Login | Server-Log `tail -f /var/www/carambus/current/log/production.log` während Login-Call; `Accept: application/json` Header zwingend setzen |
| **401 mit Bearer-Token (`{"error":"Sie müssen sich anmelden..."}`)** | Token expired (>24h alt) ODER Token revoked via `DELETE /logout` ODER JWT-Secret-Inkonsistenz Server/Lokal | Neuen Token holen via Login-Call; auf Server `RAILS_MASTER_KEY` / `devise_jwt_secret_key` in production-Credentials verifizieren |
| **Token-Wert beginnt nicht mit `eyJ`** | devise-jwt-Gem nicht geladen ODER Login-Endpoint liefert keinen Bearer-Header | `gem list devise-jwt` auf Server prüfen; `bundle exec rails routes \| grep -E 'login\|logout'` → POST `/login`-Route muss existieren; `dispatch_requests`-Regex in `config/initializers/devise.rb` muss `^/login$` matchen (Plan 13-06.3 D-13-06.3-A) |
| **`$TOKEN` enthält nur `Bearer` (ohne `eyJ...`)** | Setup-Doku-Pre-13-06.4-Versionen nutzten `awk '{print $2}'`-Pipe; dieser schnitt die Zeile `authorization: Bearer eyJ...` und lieferte nur das zweite Feld (`Bearer`) | Heutige Sektion 9.2 nutzt `sed -E 's/^[Aa]uthorization:[[:space:]]*//'`-Extraktion; bei kopierten Snippets aus älteren Doku-Versionen den Token-Extract-Block durch die aktuelle Sektion-9.2-Variante ersetzen (Plan 13-06.4-Fix) |

> **Plan 13-06.1 + 13-06.2 Live-Validation-Befunde (2026-05-13/14):** 22 Tools via `claude mcp add-json ... carambus-remote` mit `?stateless=1` erfolgreich gelistet auf carambus.de. JWT-Token-Auth (Plan 13-06.2) ist Production-Primary; Cookie-Inject (Plan 13-06.1) bleibt als Legacy-Option in Sektion 9.7 erhalten. McpController-Fix `skip_forgery_protection` (Commit `66cd3b33`) Plan-13-03-Update: Rails 7.2 nullt Session-State trotz `skip_before_action :verify_authenticity_token`. Diese Tabelle wird mit Phase-14-Walkthrough-Erfahrungen erweitert.

### 9.6 (reserviert)

### 9.7 Legacy Cookie-Auth (v0.3-Pilot Plan 13-06.1) — DEPRECATED

> **Status:** Plan 13-06.1 hat Cookie-Inject als initialen Pilot-Workaround eingeführt; Plan 13-06.2 hat JWT-Token-Auth als Phase-14-Primary etabliert. Cookie-Inject bleibt für Backwards-Compat erhalten, aber **NICHT empfohlen** für neue Setups — JWT-Token (Sektion 9.2) hat längere Lifetime und ist robuster.

**Wann diese Sektion verwenden:**
- Plan-13-06.1-Pilot-Setup bleibt funktional (keine Migration erzwungen)
- Bei spezifischen MCP-Client-Limitationen wo Bearer-Header nicht unterstützt wird (selten)
- Als Fallback falls JWT-Token-Login (Sektion 9.2) scheitert

**Cookie-Extract-Workflow:**

1. Browser-Login auf https://carambus.de/login mit Carambus-Credentials
2. Browser-DevTools öffnen (F12, oder ⌥+⌘+I in Safari)
3. Tab `Application` (Chrome/Edge) bzw. `Storage` (Firefox) → `Cookies` → `https://carambus.de`
4. Wert von Cookie **`_session_id`** kopieren (32-stelliger Hex-String, Rails-Default-Cookie-Name)

**MCP-Server registrieren mit Cookie-Header:**

```bash
claude mcp add-json --scope user carambus-remote '{
  "type": "http",
  "url": "https://carambus.de/mcp?stateless=1",
  "headers": {
    "Cookie": "_session_id=DEIN_COOKIE_HIER",
    "Accept": "application/json, text/event-stream"
  }
}'
```

**Limitierungen:**

- **Cookie-Expire 120 Minuten** (vs 24h JWT) — Re-Login alle 2h notwendig
- **Cookie-Sharing** zwischen Browser und Claude.app erfolgt NICHT automatisch (manueller DevTools-Extract)
- Bei Carambus-Scenarios mit anderem `session_store key:`-Parameter kann Cookie-Name abweichen (im DevTools sichtbar)

**Migration auf JWT:** `claude mcp remove carambus-remote -s user` + Sektion 9.2 Schritt 1+2 ausführen.

---

## Quellen & Weiterführendes

- [`clubcloud-mcp-setup.de.md`](clubcloud-mcp-setup.de.md) — Setup-Troubleshooting für technische Stellvertretung
- [`clubcloud-mcp-quickstart.de.md`](clubcloud-mcp-quickstart.de.md) — 5-Min-Quickstart-NL-Dialoge
- `docs/developers/clubcloud-mcp-server.de.md` — Entwickler-Handbuch für tieferes Tool-Debugging

---

*Plan 09-03 (Phase 9 Live-Härten + Setup-Service) — adressiert Q-v02-2 (Setup vor Ort) + Q-09-A (Phase 9). Phase-10-Voraussetzung.*
*Updated: 2026-05-12*
