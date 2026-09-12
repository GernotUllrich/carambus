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

Welche Tools ein User sieht, hängt seit Phase 34-01 von seiner **Persona** ab
(`ToolRegistry.tools_for` in `lib/mcp_server/tool_registry.rb`, Tool-Tiers in
`lib/mcp_server/role_tool_map.rb`):

- **Jeder authentifizierte User** bekommt die 29 lesenden Tools und das Self-Service-Tool
  `cc_link_my_player`, zusammen **30 Tools**.
- **Die 16 Schreib-Tools** kommen nur dazu (zusammen **46**), wenn der User CC-Schreibrecht hat
  (`user.cc_write_access?`: role `system_admin`, Sportwart-Persona oder Turnierleitung) **und**
  die Instanz ein Region- oder Local-Server ist (`carambus_api_url` gesetzt).
- **Auf der Authority** (api.carambus.de) ist der Chat für alle read-only, auch für `system_admin`.

Danach prüft der Server **jeden Schreib-Aufruf** am konkreten Turnier (`BaseTool.authorize!`,
siehe 5.1):

| Persona | Voraussetzung | Wirkbereich |
|---------|---------------|-------------|
| **Sportwart** | `persona_grants: ["sportwart"]` | nur die zugeordneten Spielorte (`sportwart_locations`); Disziplinen laut Zuordnung (`sportwart_disciplines`, leer = alle; eine Oberdisziplin wie „Karambol“ deckt ihre Unterdisziplinen ab) |
| **Landessportwart (LSW)** | `persona_grants: ["landessportwart"]` | alle Spielorte; der Disziplin-Filter gilt weiter |
| **Turnierleiter** | `tournament.turnier_leiter_user_id = user.id` **oder** eine `UserTournament`-Zuordnung mit `role: "turnier_leiter"` | die zugewiesenen Turniere |
| **Club-Admin / SysAdmin** | role `club_admin` bzw. `system_admin` (`user.admin?`) | `admin?`-Bypass in der TournamentPolicy. Schreib-Tools bekommt ein `club_admin` trotzdem nur mit Sportwart-Persona oder Turnierleitung |

> **Hinweis:** Die Persona setzt nur ein `system_admin`, im Admin-Formular unter `/admin/users`
> (Feld „Sportwart-Persona“). Spielorte und Disziplinen verfeinern den Wirkbereich; ohne Persona
> bleiben sie wirkungslos. Einen „LSW-Bypass“ über `user.admin?` gibt es nicht.

### 5.1 Authority-Hook

`lib/mcp_server/tools/base_tool.rb` enthält `authorize!`. Es fragt für jeden Schreib-Aufruf die
`TournamentPolicy` (Aktionen `assign_leiter`, `update_deadline`, `manage_teilnehmerliste`,
`enter_results`, `prepare_tournament`): Liegt das Turnier im Wirkbereich des Sportwarts? Ist der
User Turnierleiter dieses Turniers? Welche Tools es gibt und in welchem Tier sie stehen, steht in
`lib/mcp_server/role_tool_map.rb`; wer welche Aktion darf, in `app/policies/tournament_policy.rb`.

### 5.2 Console-Befehle (Authority-Setup)

```ruby
user = User.find_by(email: "sportwart@verein.de")

# Sportwart-Persona und Wirkbereich setzen (ohne Persona wirkt der Wirkbereich nicht):
user.update!(
  persona_grants: ["sportwart"],
  sportwart_location_ids: [Location.find_by!(name: "<Name des Spielorts>").id],
  sportwart_discipline_ids: Discipline.where(name: ["Freie Partie klein", "Dreiband klein"]).pluck(:id)
)

# Landessportwart (alle Spielorte; der Disziplin-Filter bleibt):
user.update!(persona_grants: ["landessportwart"])

# Turnierleiter pro Turnier zuweisen. Auf einem Local-Server ist ein gescraptes Turnier
# schreibgeschützt (LocalProtector); dort über die lokale Zuordnung (auch /admin/user_tournaments):
turnier = Tournament.find_by!(title: "NDM Endrunde Eurokegel")
UserTournament.create!(user: user, tournament: turnier, role: "turnier_leiter",
  granted_by: User.find_by(email: "sportwart@verein.de"))  # einsetzender Sportwart, optional
```

Das Admin-Formular `/admin/users` setzt dieselben Felder (Persona, Spielorte, Disziplinbaum) ohne Console.

```ruby
# Persona entziehen (Wirkbereich bleibt gespeichert, wirkt aber nicht mehr):
user.update!(persona_grants: [])
```

### 5.3 Verifikation aus User-Sicht

Der User fragt in Claude: „Welche carambus-remote Tools hast Du?" — erwartet sind **rund 30
Tools** ohne CC-Schreibrecht und **rund 46** mit Schreibrecht auf einem Region- oder Local-Server
(Zahlen siehe Sektion 5). Ist die Liste **leer (0 Tools)**, ist der Login-Token nicht verbunden,
abgelaufen oder widerrufen — nicht der Wirkbereich. Fehlen nur die Schreib-Tools, fehlt die
Persona bzw. Turnierleitung, oder die Instanz ist die Authority. Der Wirkbereich entscheidet
danach beim Aufruf, welche Schreib-Aktionen durchgehen (siehe 5.1). Details für den User selbst in
[Cloud-Quickstart, Schritt 3](clubcloud-mcp-cloud-quickstart.de.md#schritt-3-setup-befehl-in-terminal-pasten).

---

## 6. User-Account-Lifecycle

1. **Account anlegen** (Console oder Admin-UI):
   ```ruby
   User.create!(
     email: "sportwart@verein.de",
     password: "...",
     confirmed_at: Time.current   # sonst erst nach Klick auf die Bestätigungsmail anmeldbar
   )
   ```
   `User` ist `:confirmable`, ein unbestätigter Account kann sich nicht anmelden
   (`allow_unconfirmed_access_for = 0.days`) und bekommt damit auch keinen Token. `skip_confirmation!`
   ist in `User` überschrieben und wirkungslos. Ohne `confirmed_at` braucht es die Bestätigungsmail,
   also funktionierenden Mailversand.
2. **DSGVO-Einwilligung dokumentieren** (siehe Sektion 8 — `mcp_consent_at`).
3. **Persona und Wirkbereich setzen** (Sektion 5.2).
4. **User auf [Cloud-Quickstart](clubcloud-mcp-cloud-quickstart.de.md) verweisen** —
   Setup-Helper-UI führt durch den Rest.
5. **Verifikation** durch erstes Tool-Listing in Claude Code (rund 30 bzw. 46 Tools, siehe 5.3;
   bei 0 Tools → Login-Token nicht verbunden).

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
| `users.cc_password` | verschlüsselt (Rails `encrypts`) | HOCH (eigener ClubCloud-Zugang) | bis User-Löschung |
| `users.cc_username` | String | MITTEL (ClubCloud-Benutzername) | bis User-Löschung |
| `users.jti` | String | NIEDRIG (Token-Revocation-ID) | bis User-Löschung |
| `users.role`, `users.persona_grants` | Enum, jsonb-Array | NIEDRIG (Rolle, Sportwart-Persona) | bis User-Löschung |
| `sportwart_locations`, `sportwart_disciplines` | M:N-Zuordnung | NIEDRIG (Authority-Wirkbereich) | bis User-Löschung |
| `user_tournaments` | Zuordnung User × Turnier (inkl. `granted_by_user_id`) | NIEDRIG (lokale Turnierleitung) | bis User-Löschung |
| `tournaments.turnier_leiter_user_id` | FK | NIEDRIG (Per-Turnier-Authority) | bis Turnier-Löschung |
| `users.mcp_consent_at` | datetime | NIEDRIG (Metadatum) | bis User-Löschung |
| `mcp_audit_trails.*` | DB-Zeile | MITTEL (Tool-Calls + Payload) | 1 Jahr (Retention); `user_id` wird bei User-Löschung NULL (`ON DELETE NULLIFY`) |
| `log/mcp-audit-trail.log` | JSON-Lines-File | MITTEL (analog DB) | bis Datei-Rotation (logrotate) |

### 8.2 Verarbeitungszwecke

- **`encrypted_password` + `jti`:** Authentifizierung via devise-jwt; `jti`
  ermöglicht serverseitige Token-Revocation (JTIMatcher).
- **`role`, `persona_grants`, Wirkbereich, `user_tournaments` + `tournaments.turnier_leiter_user_id`:**
  Tool-Gating und Authority-Prüfung pro Tool-Call (Persona- und Wirkbereich-Modell, Phasen 34-01/38).
- **`cc_username` + `cc_password`:** eigener ClubCloud-Zugang für Schreibaktionen in der ClubCloud.
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
| **Berichtigung (Art. 16)** | Carambus-Admin passt Persona, Wirkbereich oder Turnierleitung an (Admin-Formular `/admin/users` bzw. `/admin/user_tournaments` oder Console, Sektion 5.2). |
| **Löschung / „Recht auf Vergessenwerden" (Art. 17)** | `User.find(id).destroy` — `mcp_audit_trails.user_id` wird NULL; Audit-Trail bleibt anonymisiert für Forensik (Art. 17 Abs. 3). |
| **Widerruf der Einwilligung (Art. 7 Abs. 3)** | `user.update!(persona_grants: [], sportwart_location_ids: [], sportwart_discipline_ids: [], mcp_consent_at: nil, jti: SecureRandom.uuid)`, dazu `user.user_tournaments.destroy_all` und ggf. `turnier_leiter_user_id` an Turnieren entfernen. Damit entfallen Schreibrecht und Wirkbereich, alle aktiven Tokens sind ungültig. **Aber:** Carambus kennt keine Sperre, die an der Einwilligung hängt — `mcp_consent_at` wird nirgends geprüft. Mit einem neuen Login bekommt der User einen neuen Token und behält die lesenden Tools. Eine Kontosperre kennt `User` nicht; wer den MCP-Zugang ganz entziehen will, muss den Account löschen (Zeile darüber). |
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

`mcp_consent_at` ist ein Nachweis, keine Zugangsbedingung: Der MCP-Endpoint verlangt nur einen
angemeldeten User (`authenticate_user!`) und prüft die Einwilligung nicht.

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
| Tool-Liste leer (0 Tools) trotz erfolgreichem Connect | Login-Token fehlt, ist abgelaufen oder widerrufen (Auth-Problem; jeder angemeldete User bekommt mindestens die lesenden Tools) | Re-Login und neuen Setup-Befehl pasten (Sektion 3) |
| Nur rund 30 Tools, Schreib-Tools fehlen | Keine Sportwart-Persona und keine Turnierleitung, oder die Instanz ist die Authority | Persona setzen bzw. Turnierleitung zuweisen (Sektion 5.2); für Schreibaktionen mit dem Region- oder Local-Server verbinden |
| Schreib-Aktion abgelehnt trotz gelisteter Schreib-Tools | Wirkbereich deckt Spielort/Disziplin des Turniers nicht ab, oder User ist nicht Turnierleiter dieses Turniers | Wirkbereich oder Persona anpassen (`persona_grants: ["landessportwart"]` für alle Spielorte) bzw. Turnierleitung zuweisen (Sektion 5.2) |
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
