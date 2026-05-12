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

## Quellen & Weiterführendes

- [`clubcloud-mcp-setup.de.md`](clubcloud-mcp-setup.de.md) — Setup-Troubleshooting für technische Stellvertretung
- [`clubcloud-mcp-quickstart.de.md`](clubcloud-mcp-quickstart.de.md) — 5-Min-Quickstart-NL-Dialoge
- `docs/developers/clubcloud-mcp-server.de.md` — Entwickler-Handbuch für tieferes Tool-Debugging

---

*Plan 09-03 (Phase 9 Live-Härten + Setup-Service) — adressiert Q-v02-2 (Setup vor Ort) + Q-09-A (Phase 9). Phase-10-Voraussetzung.*
*Updated: 2026-05-12*
