# Per-User-ClubCloud-Identität — Entwickler-Handbuch

> **Status:** v1.1 Phase 39 ✅ SHIPPED (2026-06-16, Tag `v1.1.0`; TL-Vererbung live verifiziert).
> **Übergeordnete Architektur:** [MCP-Server — Architektur-Naht](mcp-architektur-naht.de.md) (Identität/Autorisierung/Domänen-Grenze)
> **Endnutzer-Anleitung:** [`docs/managers/clubcloud-eigener-zugang.de.md`](../managers/clubcloud-eigener-zugang.de.md)
> **Region-Admin-Credentials (geteilt):** [`docs/managers/clubcloud_credentials.md`](../managers/clubcloud_credentials.md)

## Problem & Ziel

CC-Schreibaktionen (Akkreditieren, Schnellanmeldung, Storno, Meldeschluss …) liefen
bisher unter **einer geteilten Region-Admin-Identität** (`Setting.login_to_cc` mit
`clubcloud.<context>`-Credentials). In der ClubCloud waren damit alle Änderungen
demselben Account zugeschrieben — falsche Attribution.

**Ziel (Phase 39):** Jeder User schreibt unter seiner **eigenen** CC-Identität.
Reads bleiben bewusst auf der geteilten Admin-Session (siehe Grenzen unten).

## Datenmodell (39-01)

- `users.cc_username` (string) + `users.cc_password` (**`encrypts deterministic: false`**,
  Klartext at rest verschlüsselt; der bestehende Login-Flow macht intern MD5 daraus).
- `User#cc_credentials_present?` → `cc_username.present? && cc_password.present?`.
- `user_tournaments.granted_by_user_id` → der Sportwart, der den TL eingesetzt hat
  (von `assign_tournament_leiter` befüllt via `server_context[:user_id]`).

## Resolver (39-02) — `McpServer::CcAccountResolver`

```ruby
McpServer::CcAccountResolver.resolve(user:, tournament: nil) # => CcAccount
```

`CcAccount = Struct.new(:login_username, :password, :source, :acting_user_id, :granted_by_user_id)`
mit `#resolved? == (source != :none)`.

Auflösungs-Reihenfolge (`source`):

| source | Bedingung | login_username/password |
|--------|-----------|--------------------------|
| `:own` | `user.cc_credentials_present?` | eigene Creds des Users |
| `:tl_inherited` | User ist TL für `tournament` UND dessen `granted_by` hat eigene Creds | Creds des einsetzenden Sportwarts |
| `:none` | sonst | leer — **KEIN** Fallback auf den geteilten Region-Admin (D-39-6) |

`acting_user_id` bleibt IMMER der echte Carambus-Akteur (auch bei `:tl_inherited`
und `:none`) — Basis der zweischichtigen Audit-Attribution.

## Session-Handling (39-02) — `McpServer::CcSession`

Vom **Klassen-Singleton** (eine geteilte PHPSESSID) zu einem **per-Account-Cache**
(`class << self`, Mutex-geschützt), gekeyt am `login_username`:

- `DEFAULT_KEY = :__shared_default__` → der geteilte Region-Admin (Legacy-/Read-Pfad).
- `cookie` → Cookie der geteilten Default-Session (setzt `DEFAULT_KEY` als aktiv).
- `cookie_for(account)` → Cookie der **account-spezifischen** Session; fällt auf den
  Default zurück, wenn `account` nil/`login_username` blank ist (`:none`-sicher).
- `cc_login_user(account_key = nil)` → Login-Username der aktiven Session (für Audit).
- `with_session_recovery(account:, server_context:)` → Re-Login + Single-Retry bei
  Auto-Logout (`reset!(account.login_username)` bzw. `reset!(DEFAULT_KEY)`).
- Aktiver Account pro Request: `Thread.current[:cc_active_account_key]` (thread-safe
  für Multi-User-HTTP).

Credential-Quelle: `Setting.resolve_login_credentials(context, username:, password:)`
— explizite per-User-Args übersteuern `get_cc_credentials(context)` (Region-Admin);
bei Override wird die globale Default-Session NICHT überschrieben.

## Tool-Verdrahtung (39-03) — die 7 CC-Write-Tools

Verdrahtet sind **genau die 7 CC-Write-Tools**:
`register_for_tournament`, `fast_assign_to_teilnehmerliste`,
`assign_player_to_teilnehmerliste`, `unregister_for_tournament`,
`finalize_teilnehmerliste`, `remove_from_teilnehmerliste`, `update_tournament_deadline`.

Gemeinsame Naht in `BaseTool` (hält den Per-Tool-Diff klein, analog `authorize!`):

```ruby
account = resolve_cc_account(tournament:, server_context:)   # User aus server_context[:user_id] → Resolver
block   = cc_write_identity_block(account, armed:)           # :none-Gate (s.u.) ODER nil
return block if block
# ... POST mit cookie_for(account) ...
# Audit: operator: cc_audit_operator (CC-Login-Account) + user_id: account.acting_user_id
```

- **`:none`-Block am armed-Schreib-Gate (D-39-8):** `armed: true` + `account.source == :none`
  → jargonfreie Absage („Bitte hinterlege deinen ClubCloud-Zugang im Profil…"),
  **kein** CC-POST. `armed: false` (Dry-Run) → Vorschau/Pre-Validation läuft weiter
  über die geteilte Lese-Session + derselbe Hinweis als Note (`cc_identity_hint`).
- **Nur authentifizierter Kontext (D-39-10):** der Block greift nur, wenn
  `acting_user_id` gesetzt ist. Der User-lose Stdio-/Legacy-Pfad (`bin/mcp-server`,
  technische Stellvertretung) behält die geteilte Admin-Session.
- **Zweischichtige Audit-Attribution:** `operator` = CC-Login-Account
  (`cc_audit_operator`/`cc_login_user`), `user_id` = `account.acting_user_id`
  (echter Carambus-Akteur). Die ClubCloud kennt nur den Login-Account; Carambus hält
  den wahren Akteur.

## Provisionierungs-UI (39-04)

- `RegistrationsController#configure_permitted_parameters`: `cc_username` + `cc_password`
  in `:account_update` permittiert.
- `RegistrationsController#update_resource` — Blanking-Schutz (**D-39-11**):
  - `cc_username`-Key NICHT im Update → beide CC-Felder unberührt (Wipe-Schutz).
  - `cc_username` leer → beide Felder löschen (bewusstes Entfernen).
  - `cc_username` gesetzt + `cc_password` leer → Passwort behalten.
  - beide gesetzt → übernehmen.
- View `app/views/devise/registrations/edit.html.erb`: Sektion „ClubCloud-Zugang"
  für **alle** angemeldeten User (**D-39-12**), mit Status + Erklärung. Keine
  `current_password`-Re-Auth (folgt dem App-Muster für Profilfelder).

## Grenzen (bewusst)

- **Reads bleiben geteilt (D-39-9):** die ~10 CC-Read-Tools (Meldeliste/Teilnehmerliste/
  Lookups) nutzen weiter die geteilte Admin-Session (`cookie`/`client_for`). Per-User-
  Creds greifen **nur** bei den 7 Write-Tools. Grund: read-only-Personas sollen den
  Lesezugriff behalten. **Konsequenz:** auf einem Server ohne geteilten Admin-Zugang
  scheitern Admin-Reads — unabhängig von eigenen Creds.
- **DB-Write-Tools unverändert:** `assign/remove_tournament_leiter`, `link_my_player`
  schreiben lokal in Carambus und attribuieren via `user.email` — keine CC-Identität.
- **Stdio-Pfad geteilt (D-39-10):** kein `acting_user_id` → geteilte Admin-Session.

## Deploy-Hinweis

⚠️ **39-03 + 39-04 müssen ZUSAMMEN deployt werden** — es gibt **keinen Backfill**.
Nach 39-03 sind echte Writes für alle Sportwarte ohne hinterlegte Creds geblockt
(`:none`), bis sie über die 39-04-UI ihren Zugang hinterlegen.

## Datei-Landkarte

| Datei | Rolle |
|-------|-------|
| `app/models/user.rb` | `cc_username`/`encrypts :cc_password`/`cc_credentials_present?` |
| `app/models/user_tournament.rb` | `granted_by_user_id` (TL-Vererbung) |
| `lib/mcp_server/cc_account_resolver.rb` | `CcAccountResolver.resolve` + `CcAccount` |
| `lib/mcp_server/cc_session.rb` | per-Account-Session-Cache, `cookie_for`, `cc_login_user` |
| `lib/mcp_server/tools/base_tool.rb` | `resolve_cc_account` / `cc_write_identity_block` / `cc_identity_hint` / `cc_audit_operator` |
| `lib/mcp_server/tools/{register,fast_assign,assign_player,unregister,finalize,remove_from_teilnehmerliste,update_tournament_deadline}*.rb` | die 7 verdrahteten Write-Tools |
| `app/controllers/registrations_controller.rb` + `app/views/devise/registrations/edit.html.erb` | Provisionierungs-UI |
| `app/models/setting.rb` | `resolve_login_credentials` / `login_to_cc` / `get_cc_credentials` |

Entscheidungen im Detail: **D-39-1 bis D-39-12** (siehe `.paul/STATE.md` Accumulated
Context bzw. PROJECT.md Key Decisions).
