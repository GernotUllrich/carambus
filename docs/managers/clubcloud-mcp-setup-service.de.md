# ClubCloud-MCP Setup-Service (Per-Region-Admin-Doku)

## Adressat & Abgrenzung

Diese Doku richtet sich an den **Carambus-Admin**, der einen Per-Region-MCP-Server (z.B.
`nbv.carambus.de`, `bcw.carambus.de`) einrichtet, betreibt und User-Authority
konfiguriert.

| Doku | Adressat | Zweck |
|------|----------|-------|
| [Cloud-Quickstart](clubcloud-mcp-cloud-quickstart.de.md) | Sportwart / Turnierleiter / LSW | User-facing Setup in 3 Schritten |
| **Diese Doku** | **Carambus-Admin** | Per-Region-Scenario-Setup, Authority-Console, DSGVO-Operations, Deploy-Workflow |
| [`cc-roles`](clubcloud-scenarios/cc-roles.de.md) | Cross-Ref-Substrate | CC-Rollen + Carambus-Authority-Brücke |
| [`cc-glossary`](clubcloud-scenarios/cc-glossary.de.md) | Cross-Ref-Substrate | ClubCloud-Begriffe |

> **Architektur-Pivot (v0.4):** STDIO-Subprocess-Setup (rbenv / Claude Desktop config) ist
> obsolet. Der MCP-Server läuft heute als **Remote-HTTP-Endpoint** pro Region; Sportwarte
> verbinden sich via Bearer-JWT-Auth, einmalig per Setup-Helper-UI eingerichtet.

---

## 1. Architektur-Überblick

```
                      [Sportwart-Browser]
                              │
                              │ (1) POST /login (Email + Passwort)
                              ▼
                   ┌──────────────────────────┐
                   │  nbv.carambus.de         │
                   │  (Per-Region-Scenario)   │
                   │                          │
                   │  - devise-jwt liefert    │
                   │    Bearer-Token (90d)    │
                   │  - /mcp/setup-Helper-UI  │
                   │    rendert Setup-Befehl  │
                   │  - /mcp Streamable-HTTP  │
                   │    (Authority-Filter)    │
                   └──────────────────────────┘
                              ▲
                              │ (2) Setup-Befehl-Copy
                              │ (3) Bearer-Token in `claude mcp add-json`
                              │
                      [Sportwart-Terminal]
                              │
                              │ (4) MCP-Calls mit Bearer-Header
                              ▼
                  [Claude Code mit carambus-remote]
```

**Per Region eine Carambus-Instanz** (Per-Region-Scenario): jede Region hat ihre
eigene Domain, eigene PostgreSQL-DB, eigene devise-jwt-Secret-Konfig. Der
`Carambus.config.context`-Key (in `config/carambus.yml`) bestimmt, in welcher
Region die Instanz läuft.

---

## 2. Per-Region-Scenario-Setup

Eine neue Region (z.B. `bvbw.carambus.de`) wird als Capistrano-Scenario
aufgesetzt:

1. **Scenario-Verzeichnis** clonen (z.B. `carambus_bvbw` parallel zu `carambus_nbv`):
   ```bash
   cd ~/DEV/carambus
   git clone <upstream-repo> carambus_bvbw
   cd carambus_bvbw
   ```

2. **`config/carambus.yml`** erweitern:
   ```yaml
   bvbw:
     context: bvbw          # Pflicht — Per-Region-Identifier
     application_name: bvbw
     api_url: https://bvbw.carambus.de
     # … weitere Per-Scenario-Werte
   ```

3. **DNS** auf den Hetzner-Server pointen (`bvbw.carambus.de` → A-Record).

4. **NGINX-vhost** ergänzen (`/etc/nginx/sites-enabled/carambus_bvbw.conf`) mit SSL via
   Let's Encrypt.

5. **PostgreSQL-DB** anlegen (`carambus_bvbw_production`).

6. **Capistrano-Stage** `config/deploy/bvbw.rb` als Kopie eines vorhandenen Stages
   konfigurieren.

7. **Initial-Deploy:**
   ```bash
   cap bvbw deploy:setup_secrets   # einmalig
   cap bvbw deploy
   ```

8. **JWT-Secret-Konsistenz prüfen:** `config/credentials/production.yml.enc` muss
   `devise_jwt_secret_key` enthalten (siehe Sektion 4) — pro Region eigene Secrets,
   damit Tokens nicht über Regionen hinweg gelten.

9. **Smoke-Test:** Browser-Login auf `https://bvbw.carambus.de/login` → `/mcp/setup`
   öffnen → Setup-Befehl kopieren → in Terminal pasten → `claude mcp get
   carambus-remote` zeigt `connected`.

---

## 3. Setup-Helper-UI (`/mcp/setup`)

Die Setup-Helper-UI (Plan 14-G.8) rendert pro User einen vollständigen,
copy-paste-fertigen `claude mcp add-json`-Befehl mit eingebettetem Bearer-Token.

**Architektur-Schlüssel:**

- **Per-Region-URL via `request.base_url`-Pattern** — der Setup-Befehl enthält die
  Domain der aufgerufenen Instanz (`https://nbv.carambus.de/mcp?stateless=1`),
  nicht eine hardgecodete URL. Das macht die Helper-UI über alle Regionen ohne
  Code-Branch wiederverwendbar.
- **Sportwart-only-Voice** — der UI-Text spricht den Sportwart in Du-Form an, ohne
  Tech-Jargon (Bearer/JWT als „Login-Token" geframet).
- **Restlaufzeit-Banner** — zeigt verbleibende Token-Lifetime in Tagen prominent an;
  ab <14 Tagen sanfter Renew-Hint.
- **Controller:** `app/controllers/mcp_setup_controller.rb`
- **View:** `app/views/mcp_setup/show.html.erb`

---

## 4. Auth-Layer: devise-jwt + JTIMatcher + Long-Lived-Tokens

### 4.1 Konfiguration

`config/initializers/devise.rb` (Auszug):

```ruby
config.jwt do |jwt|
  jwt.secret = Rails.application.credentials.devise_jwt_secret_key
  jwt.dispatch_requests = [
    ['POST', %r{^/login$}]
  ]
  jwt.revocation_requests = [
    ['DELETE', %r{^/logout$}]
  ]
  jwt.expiration_time = (Carambus.config.jwt_expiration_days || 90).days.to_i
end
```

`app/models/user.rb` (Auszug):

```ruby
include Devise::JWT::RevocationStrategies::JTIMatcher
devise :database_authenticatable, ..., :jwt_authenticatable,
       jwt_revocation_strategy: self
```

### 4.2 Token-Lifetime — `Carambus.config.jwt_expiration_days`

- **Default 90 Tage** (Plan 14-G.5 / D-14-G7) — Per-Scenario in `config/carambus.yml`
  überschreibbar.
- **JTIMatcher-Revoke** über `DELETE /logout` mit Bearer-Header invalidiert den Token
  serverseitig (kein Client-only-Logout).

### 4.3 Console-Befehle (Token-Operationen)

```ruby
# Token-JTI eines Users anzeigen (Forensik):
User.find_by(email: "sportwart@verein.de").jti

# Token revoken (Force-Logout aller aktiven Sessions des Users):
User.find_by(email: "sportwart@verein.de").update!(jti: SecureRandom.uuid)
```

---

## 5. Authority-Layer (Sportwart-Wirkbereich + TL-FK)

Authority entscheidet pro User, welche der 22 MCP-Tools sichtbar + ausführbar sind.
Statt eines globalen Rollen-Enums hängt Authority an konkreten **Wirkbereichen**:

| Persona | Authority-Felder | Tool-Subset |
|---------|------------------|-------------|
| **Sportwart** | `user.sportwart_location_ids = [...]`<br>`user.sportwart_discipline_ids = [...]` | **16 Tools** (Anmeldungs-Lebenszyklus vor Turnier; ohne Akkreditierung am Turniertag) |
| **Turnierleiter** | `tournament.turnier_leiter_user_id = user.id` (pro Turnier; Single-FK) | **19 Tools** (Akkreditierung am Turniertag; ohne Pre-Tournament-Setup) |
| **Landessportwart (LSW)** | `user.admin?` (Bypass aller Wirkbereich-Checks) | **22 Tools** (volle Suite) |
| **SysAdmin** | `user.super_user?` | volle Suite + Override |

### 5.1 Authority-Hook

`lib/mcp_server/tools/base_tool.rb` enthält `authorize!`, das pro Tool prüft,
ob der User Authority für die konkrete Operation hat (z.B. ist die betroffene
Location im `sportwart_location_ids`-Array? Ist der User für das Ziel-Turnier als
TL eingetragen?). Single Source of Truth: `lib/mcp_server/tool_registry.rb`
listet pro Tool das benötigte Authority-Level.

### 5.2 Console-Befehle (Authority-Setup)

```ruby
user = User.find_by(email: "sportwart@verein.de")

# Sportwart-Wirkbereich setzen:
user.update!(
  sportwart_location_ids: [Location.find_by!(shortname: "BCW").id],
  sportwart_discipline_ids: Discipline.where(shortname: %w[FREI EUR DREIBAND]).pluck(:id)
)

# Turnierleiter pro Turnier zuweisen:
Tournament.find_by!(title: "NDM Endrunde Eurokegel").update!(
  turnier_leiter_user_id: user.id
)

# LSW-Bypass:
user.update!(admin: true)
```

### 5.3 Verifikation aus User-Sicht

Der User fragt in Claude: „Welche carambus-remote Tools hast Du?" — die Tool-Anzahl
muss dem erwarteten Subset entsprechen (16 / 19 / 22). Falls nicht: Wirkbereich
stimmt nicht. Details für den User selbst in
[Cloud-Quickstart §Tool-Anzahl](clubcloud-mcp-cloud-quickstart.de.md#smoke-test-in-claude-code).

---

## 6. User-Account-Lifecycle

1. **Account anlegen** (Console oder Admin-UI):
   ```ruby
   User.create!(
     email: "sportwart@verein.de",
     password: "...",
     # admin: false   (default)
   )
   ```
2. **DSGVO-Einwilligung dokumentieren** (siehe Sektion 8 — `mcp_consent_at`).
3. **Wirkbereich setzen** (Sektion 5.2).
4. **User auf [Cloud-Quickstart](clubcloud-mcp-cloud-quickstart.de.md) verweisen** —
   Setup-Helper-UI führt durch den Rest.
5. **Verifikation** durch erstes Tool-Listing in Claude Code (16 / 19 / 22).

**Account-Off-Boarding:**

- **Token-Force-Logout:** `user.update!(jti: SecureRandom.uuid)` (alle aktiven
  Tokens werden ungültig).
- **Account-Löschung:** `user.destroy` — `mcp_audit_trails.user_id` wird NULL
  (`ON DELETE NULLIFY`); Audit-Trail bleibt anonymisiert für Forensik-Pflicht.

---

## 7. Cap-Deploy-Workflow (Per-Region-Deploys)

Jede Region hat einen eigenen Capistrano-Stage:

```bash
# Aus carambus_master (oder dem region-spezifischen Workspace):
cap nbv deploy           # NBV-Region
cap bvbw deploy          # BVBW-Region
cap production deploy    # carambus.de (zentrale Master-API)
```

**Cross-Repo-Deploy-Pattern** (für Doku-Updates):

1. Doku in `carambus_bcw` editieren + committen.
2. Push origin/master.
3. `carambus_master`: `git pull` (fast-forward).
4. `carambus_nbv` (oder Ziel-Region): lokale Drift verwerfen, pull, deploy:
   ```bash
   cd ~/DEV/carambus/carambus_nbv
   git checkout -- public/docs/managers/    # falls lokal abgewichen
   git clean -fd public/docs/managers/
   git pull
   cap production deploy
   ```

---

## <a id="8-dsgvo-compliance--datenschutz"></a>8. DSGVO-Compliance / Datenschutz

> **Pilot-Boundary (D-13-01-E):** Diese Sektion dokumentiert die DSGVO-Erfüllung für
> den ClubCloud-MCP-Server. Vollständige Self-Service-Banner-Implementierung ist
> deferred zu v0.5.

### 8.1 Datenkategorien

| Daten | Format | Sensitivität | Persistenz |
|-------|--------|--------------|------------|
| `users.encrypted_password` | bcrypt | HOCH (Passwort-Material) | bis User-Löschung |
| `users.jti` | String | NIEDRIG (Token-Revocation-ID) | bis User-Löschung |
| `users.sportwart_location_ids` | Array | NIEDRIG (Authority-Wirkbereich) | bis User-Löschung |
| `users.sportwart_discipline_ids` | Array | NIEDRIG (Authority-Wirkbereich) | bis User-Löschung |
| `users.admin` | Boolean | NIEDRIG (LSW-Bypass) | bis User-Löschung |
| `tournaments.turnier_leiter_user_id` | FK | NIEDRIG (Per-Turnier-Authority) | bis Turnier-Löschung |
| `users.mcp_consent_at` | datetime | NIEDRIG (Metadatum) | bis User-Löschung |
| `mcp_audit_trails.*` | DB-Zeile | MITTEL (Tool-Calls + Payload) | 1 Jahr (Retention); `user_id` wird bei User-Löschung NULL (`ON DELETE NULLIFY`) |
| `log/mcp-audit-trail.log` | JSON-Lines-File | MITTEL (analog DB) | bis Datei-Rotation (logrotate) |

### 8.2 Verarbeitungszwecke

- **`encrypted_password` + `jti`:** Authentifizierung via devise-jwt; `jti`
  ermöglicht serverseitige Token-Revocation (JTIMatcher).
- **`sportwart_*` + `admin` + `tournaments.turnier_leiter_user_id`:** Authority-Filterung
  pro Tool-Call (Wirkbereich-Modell, Plan 14-G3+G4).
- **`mcp_audit_trails`:** Forensik bei Live-CC-Fehlern + Multi-User-Filterung;
  `payload[armed]=true` ist Trigger für Daten-Mutations-Audit.
- **`mcp_consent_at`:** Einwilligungs-Nachweis nach Art. 7 DSGVO.

### 8.3 Retention

- `mcp_audit_trails`: **1 Jahr** (Forensik-Pflicht); manuelle Cleanup-Routine:
  ```ruby
  McpAuditTrail.where("created_at < ?", 1.year.ago).delete_all
  ```
  (v0.5 plant Auto-Cleanup via Cron.)
- JSON-Lines-File: bis Datei-Rotation (logrotate).

### 8.4 User-Rechte (Art. 15-21 DSGVO)

| Recht | Wie erfüllt? |
|-------|--------------|
| **Auskunft (Art. 15)** | `User.find(id).mcp_audit_trail_export.to_json` → an User-Email senden. `encrypted_password` wird NICHT exportiert. |
| **Berichtigung (Art. 16)** | Carambus-Admin updated `sportwart_*`-Felder oder `tournaments.turnier_leiter_user_id` über Console. |
| **Löschung / „Recht auf Vergessenwerden" (Art. 17)** | `User.find(id).destroy` — `mcp_audit_trails.user_id` wird NULL; Audit-Trail bleibt anonymisiert für Forensik (Art. 17 Abs. 3). |
| **Widerruf der Einwilligung (Art. 7 Abs. 3)** | `user.update!(sportwart_location_ids: [], sportwart_discipline_ids: [], mcp_consent_at: nil, jti: SecureRandom.uuid)` — User behält Carambus-Account, MCP-Zugriff ist deaktiviert + alle aktiven Tokens revoked. |
| **Datenübertragbarkeit (Art. 20)** | `mcp_audit_trail_export.to_json` ist maschinenlesbar. |

### 8.5 Einwilligungs-Operational-Flow

1. Carambus-Admin erklärt User mündlich oder schriftlich die Datenverarbeitung
   (8.1) und User-Rechte (8.4).
2. User stimmt zu.
3. Admin attestiert via Console:
   ```ruby
   user = User.find_by(email: "sportwart@verein.de")
   user.update!(mcp_consent_at: Time.current)
   ```

### 8.6 Verantwortlicher (Art. 4 Nr. 7 DSGVO)

- **Verantwortlicher** für die Datenverarbeitung: **Carambus-Betreiber** (siehe
  `config/carambus.yml` für Kontaktdaten).
- **Auftragsverarbeiter:** Hetzner Online GmbH (DE) für Hosting.
- **Datenverarbeitung erfolgt in:** Deutschland / EU (Hetzner-Server).
- **AVV:** zwischen Carambus-Betreiber und Hetzner besteht Standard-DSGVO-konformer
  AVV.

---

## 9. Troubleshooting

| Symptom | Ursache | Lösung |
|---------|---------|--------|
| Sportwart sieht im Login-Token-Banner Restlaufzeit „expired" | Token >90 Tage alt | Sportwart re-loginnen + neuen Setup-Befehl pasten |
| `claude mcp get carambus-remote` → 401 trotz frischem Token | JWT-Secret-Inkonsistenz Server / Lokal | `RAILS_MASTER_KEY` + `devise_jwt_secret_key` in production-Credentials prüfen; Per-Region eigene Secrets verwenden |
| Tool-Liste leer (0 Tools) trotz erfolgreichem Connect | Wirkbereich nicht konfiguriert | Sektion 5.2 — `sportwart_location_ids` / `sportwart_discipline_ids` setzen oder TL-FK zuweisen |
| Tool-Anzahl falsch (z.B. 16 statt 22 für LSW) | `user.admin = false` | `user.update!(admin: true)` für LSW |
| `tools/list` 406 Not Acceptable | `Accept`-Header fehlt | Setup-Helper-UI generiert `Accept: application/json, text/event-stream` automatisch — alte manuell gebaute Configs prüfen |
| `Authorization`-Header leer im Login-Response | devise-jwt-Dispatch-Regex matched Login-Route nicht | `dispatch_requests` in `config/initializers/devise.rb` prüfen — muss `^/login$` matchen |
| Sportwart sieht falsche Region im Tool-Output | Falsches Per-Region-Scenario / falsche Domain | User auf richtige Region-Domain (z.B. `nbv.carambus.de`) verweisen — jede Region ist eigene Carambus-Instanz |

Server-Log für Forensik:

```bash
tail -f /var/www/carambus/current/log/production.log
tail -f /var/www/carambus/current/log/mcp-audit-trail.log
```

---

## <a id="power-user-cli-anhang"></a>10. Power-User-CLI-Anhang (für CI / Auto-Provisioning)

Für Automation (Test-Pipeline, Mehrfach-Maschinen-Setup) der direkte CLI-Pfad
ohne Setup-Helper-UI.

### Bash (Mac / Linux / Git Bash / WSL2)

```bash
# 1. Token holen (Bearer kommt im Authorization-Response-Header):
TOKEN=$(curl -sS -X POST https://nbv.carambus.de/login \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -d '{"user":{"email":"DEINE_EMAIL","password":"DEIN_PW"}}' \
  -D - | grep -i '^authorization:' | sed -E 's/^[Aa]uthorization:[[:space:]]*//' | tr -d '\r\n')
echo "$TOKEN"   # erwartet: Bearer eyJ...

# 2. MCP-Server registrieren:
claude mcp add-json --scope user carambus-remote "{
  \"type\": \"http\",
  \"url\": \"https://nbv.carambus.de/mcp?stateless=1\",
  \"headers\": {
    \"Authorization\": \"$TOKEN\",
    \"Accept\": \"application/json, text/event-stream\"
  }
}"

# 3. Verify:
claude mcp get carambus-remote
```

### PowerShell (Windows nativ)

```powershell
$response = Invoke-WebRequest -Uri "https://nbv.carambus.de/login" `
  -Method POST `
  -ContentType "application/json" `
  -Headers @{ "Accept" = "application/json" } `
  -Body '{"user":{"email":"DEINE_EMAIL","password":"DEIN_PW"}}'
$TOKEN = $response.Headers["Authorization"]

$config = @{
  type    = "http"
  url     = "https://nbv.carambus.de/mcp?stateless=1"
  headers = @{
    Authorization = "$TOKEN"
    Accept        = "application/json, text/event-stream"
  }
} | ConvertTo-Json -Depth 3 -Compress

claude mcp add-json --scope user carambus-remote $config
claude mcp get carambus-remote
```

**Token-Refresh:** identisch zum Setup-Helper-UI-Pfad — `claude mcp remove
carambus-remote -s user` + Block neu laufen lassen.

---

*Setup-Service-Doku (Plan 14-G.11, 2026-05-16). Per-Region-Architektur (Plan 14-G3),
Setup-Helper-UI (Plan 14-G.8), Long-Lived-JWT (Plan 14-G.5), Authority-Modell
(Plan 14-G3+G4).*
