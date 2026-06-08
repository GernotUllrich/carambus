---
phase: 41-devise-auth-cluster-ueberarbeitung-registrierung-forgot-pass
plan: 03
subsystem: auth
tags: [devise, devise-jwt, jti-rotation, hard-revoke, security-hardening, model-callback]

# Dependency graph
requires:
  - "41-01 (Test-Infra: MailHelpers + Layer-2 PasswordsControllerTest mit 4 Charakterisierungstests)"
provides:
  - "JTI-Rotation-Callback im User-Modell (after_update / saved_change_to_encrypted_password?)"
  - "Hard-Revoke aller JWT bei Passwort-Aenderung (D-41-C) — Forgot-Reset, Change-Password, Admin-Update, Console-Update"
  - "Cross-Repo-Sicherheit: Routine-Updates (Email, Preferences, First-Name) rotieren JTI NICHT — bcw-MCP-JWTs ueberleben"
  - "5 Layer-1-Unit-Tests (user_test.rb): Trigger + Non-Trigger + Devise-Reset-API + jwt_revoked?-E2E"
  - "3 Layer-2-Controller-Tests (passwords_controller_test.rb): JTI-Rotation HTTP-Pfad + Token-Replay + Unknown-Email"
  - "Plan-04 (Change-Password) kann denselben Callback wiederverwenden — keine doppelte JTI-Rotation-Logik"
affects: [41-04, 41-05]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Model-Callback statt Controller-Override fuer cross-cutting Auth-Concern (defense in depth)"
    - "Cross-Repo-sicheres Gating via dirty-tracking-Predicate (saved_change_to_encrypted_password?)"
    - "Charakterisierungstests pinnen Devise-Default-Verhalten (require_no_authentication, paranoid_mode)"

key-files:
  created: []
  modified:
    - "app/models/user.rb"
    - "test/models/user_test.rb"
    - "test/controllers/passwords_controller_test.rb"

key-decisions:
  - "Model-Callback (Option B aus RESEARCH.md) statt Controller-Override (Option A) — greift bei JEDEM encrypted_password-Save-Pfad, nicht nur Devise-Controller"
  - "Callback gegated auf saved_change_to_encrypted_password? — Routine-Updates triggern KEINE JTI-Rotation, MCP-JWTs ueberleben"
  - "Token-Replay-Test pinnt :redirect (302) NICHT :unprocessable_entity (422) — IST ist require_no_authentication-Filter (sign_in_after_reset_password=true loggt User ein, 2. PUT findet eingeloggten User → already_authenticated-Redirect)"
  - "Unknown-Email-Test akzeptiert 200 OR 422 (Devise paranoid=false rendert Form) — Plan-04 koennte paranoid=true einfuehren"
  - "Devise-API-Methode heisst reset_password (ohne Bang), NICHT reset_password! — Plan-Vorgabe korrigiert"

patterns-established:
  - "Pattern 1: Cross-Repo-sicherer Auth-Callback — gated via dirty-tracking-Predicate, nicht per Aufruf-Pfad"
  - "Pattern 2: Model-first JWT-Revocation (vs. Controller-first) — verhindert Drift zwischen Pfaden"
  - "Pattern 3: Token-Replay-Charakterisierung pinnt 2 Schutz-Schichten (clear_reset_password_token + require_no_authentication)"

requirements-completed:
  - REQ-41-07   # Forgot-Password versendet Reset-Mail (HTTP-getestet, schon in Plan-01 charakterisiert + JTI-Erweiterung in Plan-03)
  - REQ-41-08   # Reset-Password-Token wird nach Use invalidiert (Devise-Default + 2. Schicht require_no_authentication)
  - REQ-41-09   # JTI-Rotation nach Password-Reset (D-41-C Hard-Revoke aller JWT bei PW-Reset)

# Metrics
duration: 6min
completed: 2026-05-16
---

# Phase 41 Plan 03: JTI-Rotation bei Password-Reset (D-41-C Hard-Revoke) Summary

**Forgot-Password-Flow auf D-41-C-Hard-Revoke-Standard gehoben: User-Modell rotiert seinen JTI automatisch via after_update-Callback bei jeder encrypted_password-Aenderung. Damit werden ALLE bestehenden JWT-Sessions invalidiert — kompromittierte Accounts mit gestohlenem JWT koennen nach PW-Reset NICHT weiter genutzt werden. Cross-Repo-sicher: Routine-Updates (Email, Preferences) triggern KEINE Rotation, bcw-MCP-JWTs ueberleben.**

## Performance

- **Duration:** ~6 min (364s)
- **Started:** 2026-05-15T23:23:36Z
- **Completed:** 2026-05-15T23:29:40Z
- **Tasks:** 2
- **Files modified:** 3
- **Files created:** 0
- **Tests added:** 8 (5 Layer-1 in user_test.rb + 3 Layer-2 in passwords_controller_test.rb)
- **Assertions added:** ~17 (Layer-1: 9 / Layer-2: 8)
- **Test runtime:** ~0.59s fuer 47 Cross-Phase-41-Tests

## Accomplishments

- **D-41-C Hard-Revoke implementiert via Model-Callback** — `after_update :rotate_jti_on_password_change!, if: :saved_change_to_encrypted_password?` in app/models/user.rb. Greift bei JEDEM Pfad: Devise-Controller-Reset, Admin-Update, Rails-Console, direkter ActiveRecord-Save.
- **Cross-Repo-Sicherheit dokumentiert + getestet** — 2 Non-Trigger-Tests (first_name-Update, email-Update) beweisen, dass JTI bei Routine-Updates STABIL bleibt → carambus_bcw-MCP-JWTs werden NICHT unbeabsichtigt revoked.
- **End-to-End-Integration verifiziert** — Layer-2 HTTP-Test "PUT /users/password rotiert User.jti" beweist: Devise-Default-Controller → User-Save → Callback → JTI-Rotation → alter JWT ungueltig. Keine Custom-Controller-Aenderung noetig.
- **2 Token-Replay-Schutz-Schichten gepinnt** — Test dokumentiert Devise's Verhalten:
  1. `Recoverable#reset_password` loescht reset_password_token nach erstem Use
  2. `PasswordsController#prepend_before_action :require_no_authentication` redirected den nach erstem Reset eingeloggten User mit `already_authenticated`-Flash
- **Plan-04-Vorbereitung** — Change-Password-Flow (PATCH /users mit neuem Passwort) wird denselben Callback automatisch nutzen → KEIN zusaetzlicher Code-Pfad fuer JTI-Rotation noetig.

## Test-Count Layer-1 + Layer-2

| Layer | Datei | Test-Count vorher | Test-Count nachher | Pass/Fail | Runtime |
|-------|-------|------------------:|-------------------:|-----------|--------:|
| Layer 1 (Model) | `test/models/user_test.rb` | 16 | 21 (+5 JTI-Rotation) | 21 pass | ~0.34s |
| Layer 2 (Controller) | `test/controllers/passwords_controller_test.rb` | 4 | 7 (+3 D-41-C) | 7 pass | ~0.40s |
| **Plan-03 Total Neu** | | **20** | **28 (+8 neue Tests)** | **28 pass / 0 fail** | **~0.74s** |
| **Cross-Phase-41 Verifikation** | (alle 6 Devise-Test-Files) | — | 47 | 47 pass / 0 fail | ~0.59s |

## Task Commits

Each task committed atomically (`--no-verify`, parallel-executor):

1. **Task 1: JTI-Rotation-Callback im User-Modell + 5 Layer-1-Tests** — `cdafcab0` (feat)
2. **Task 2: Layer-2 Reset-Password JTI-Rotation + Token-Replay-Schutz** — `98d00a3d` (test)

## Files Modified (3)

- `app/models/user.rb` — `after_update :rotate_jti_on_password_change!` Callback (oben bei validates) + `rotate_jti_on_password_change!` private Methode (in private-Block)
- `test/models/user_test.rb` — 5 neue JTI-Rotation-Tests am File-Ende (Trigger + Non-Trigger + Devise-Reset-API + jwt_revoked?-E2E)
- `test/controllers/passwords_controller_test.rb` — 3 neue Tests nach Plan-01-Charakterisierung (JTI-Rotation HTTP-Pfad + Token-Replay-Schicht-2 + Unknown-Email-Devise-Verhalten)

## Implementation-Approach: Model-Callback (Option B) vs. Controller-Override (Option A)

Aus RESEARCH.md "Architecture Patterns":

**Option A (Controller-Override) — VERWORFEN:**
- Custom PasswordsController + Custom RegistrationsController#update_resource noetig
- Anti-Pattern aus CONTEXT.md: "Don't rewrite Devise"
- Drift-Risiko: Admin-Updates, Console-Updates, direkte API-Saves wuerden umgangen

**Option B (Model-Callback) — GEWAEHLT:**
- Single Source of Truth im User-Modell
- Greift bei ALLEN Pfaden — defense in depth
- Plan-04 (Change-Password) kann denselben Callback wiederverwenden
- Cross-Repo-Sicher via `saved_change_to_encrypted_password?` (nur explizite PW-Aenderung)

## Cross-Repo-Vertraeglichkeit (verifiziert)

Tests in user_test.rb beweisen, dass JTI bei diesen Updates STABIL bleibt:

| Update | JTI-Verhalten | Test |
|--------|---------------|------|
| `user.update!(first_name: "...")` | bleibt | `jti bleibt stabil bei first_name-Update` |
| `user.update!(email: "...")` | bleibt (Reconfirmable: aendert `unconfirmed_email`, nicht `encrypted_password`) | `jti bleibt stabil bei email-Update` |
| `user.update!(password: "...")` | rotiert | `jti rotates after encrypted_password update` |
| `user.reset_password("...", "...")` | rotiert | `jti rotates via reset_password (Devise-Reset-API)` |

Damit ist sichergestellt: **bcw-MCP-JWTs (90 Tage Lifetime) werden NUR bei tatsaechlicher Passwort-Aenderung revoked**, nicht bei Routine-Operationen.

## Devise-Defaults-Verhalten dokumentiert

| Setting | IST in carambus | Auswirkung im Test gepinnt |
|---------|------------------|----------------------------|
| `sign_in_after_reset_password = true` | aktiv | Nach erstem Reset wird User via `bypass_sign_in` eingeloggt → 2. PUT geht in `require_no_authentication`-Filter → 302 Redirect mit `already_authenticated`-Flash |
| `clear_reset_password_token` (Recoverable-Callback) | aktiv | Nach erstem Use wird `reset_password_token` + `reset_password_sent_at` geloescht — 2. PUT findet keinen User mehr ueber Token (greift hier aber NICHT, weil Schicht-2 vorher zuschlaegt) |
| `paranoid` | nicht gesetzt (= false) | POST mit unbekannter Email rendert Form mit Error (200 oder 422), KEIN identischer Redirect — Account-Enumeration moeglich. Plan-04-Evaluation. |
| `reconfirmable = true` | aktiv | Email-Update aendert `unconfirmed_email`, NICHT `encrypted_password` → JTI bleibt stabil (gewollt) |

## Decisions Made

- **Model-Callback ueber Controller-Override:** RESEARCH.md Architecture Pattern Option B; CONTEXT.md Anti-Pattern "Don't rewrite Devise"; Plan-04 wiederverwendet ohne weiteren Code.
- **Gating via `saved_change_to_encrypted_password?`:** Aktiv-State des dirty-tracking nach save (NICHT `password_changed?` o.ae., das nur waehrend Save aktiv waere). Cross-Repo-Sicherheit ist hartcodiert in der Bedingung.
- **Token-Replay-Test pinnt `:redirect` (302) NICHT 422:** Plan-Vorgabe ging von 422 aus (clear_reset_password_token-Schicht). IST ist 302 (require_no_authentication-Schicht greift zuerst, weil sign_in_after_reset_password=true den User nach erstem Reset eingeloggt hat). Test charakterisiert das echte Devise-Verhalten + dokumentiert beide Schutz-Schichten in Kommentar.
- **Unknown-Email-Test akzeptiert 200 OR 422:** Devise paranoid=false rendert Form mit Error (kein Redirect). Test pinnt `assert_no_difference` auf Mail-Queue + erlaubt beide Statusses fuer Devise-Versions-Resilienz.
- **Plan-Vorgabe `reset_password!` korrigiert auf `reset_password`:** Devise 4.9.4 API hat KEINE Bang-Variante (devise-4.9.4/lib/devise/models/recoverable.rb:37). Plan-Vorgabe enthielt einen Tippfehler.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug in plan-prescribed test API] `reset_password!` (Bang) existiert nicht in Devise 4.9.4**
- **Found during:** Task 1 RED-Phase (NoMethodError beim ersten Test-Run)
- **Issue:** Plan-Vorgabe Zeile 200 nutzt `user.reset_password!("Reset123Passwort!", "Reset123Passwort!")` — die Devise-API-Methode heisst aber `reset_password` ohne Bang (verifiziert in `devise-4.9.4/lib/devise/models/recoverable.rb:37 def reset_password(new_password, new_password_confirmation)`). Methode persistiert direkt via `save(validate: false)`, daher kein Bang noetig.
- **Fix:** Test-Methodenaufruf von `reset_password!` auf `reset_password` umgestellt + Test-Name angepasst
- **Files modified:** `test/models/user_test.rb`
- **Verification:** Test GREEN nach Anpassung
- **Committed in:** `cdafcab0` (Task 1)

**2. [Rule 1 - Bug in plan-prescribed test expectation] Token-Replay erwartete 422, IST ist 302 (Devise-Schicht-2)**
- **Found during:** Task 2 GREEN-Phase
- **Issue:** Plan-Vorgabe Zeile 293-294 erwartet `assert_response :unprocessable_entity` fuer Token-Replay. IST ist `:redirect` (302), weil `sign_in_after_reset_password=true` (carambus-Default) nach erstem Reset den User via `bypass_sign_in` einloggt → 2. PUT geht in `prepend_before_action :require_no_authentication` Filter → Redirect mit `already_authenticated`-Flash. Devise's clear_reset_password_token-Schutz wuerde greifen, aber require_no_authentication ist VOR der Token-Pruefung in der Filter-Chain.
- **Fix:** Test-Erwartung auf `:redirect` umgestellt + Inline-Kommentar dokumentiert beide Schutz-Schichten + zusaetzliche Assertion `assert_equal old_encrypted_after_first, @user.reload.encrypted_password` beweist, dass der 2. PUT das Passwort NICHT erneut aendert
- **Files modified:** `test/controllers/passwords_controller_test.rb`
- **Verification:** Test GREEN, beide Schutz-Schichten gepinnt
- **Committed in:** `98d00a3d` (Task 2)

**3. [Rule 1 - Bug in plan-prescribed test expectation] Unknown-Email Response: Plan erwartete `:redirect`, IST kann 200 oder 422 sein**
- **Found during:** Task 2 (geplante Antizipation)
- **Issue:** Plan-Vorgabe Zeile 306 erwartet `assert_response :redirect` fuer POST /users/password mit unbekannter Email. Devise's `paranoid_messages`-Setting ist standardmaessig false in carambus (devise.rb:329 bleibt unkommentiert) — Devise rendert dann die Form mit "email not found" Error (Status 200 oder 422 je nach Devise-Version), KEIN Redirect.
- **Fix:** Test-Erwartung auf `assert_includes [200, 422], response.status` umgestellt + Inline-Kommentar dokumentiert paranoid_mode-IST + Plan-04-Evaluation
- **Files modified:** `test/controllers/passwords_controller_test.rb`
- **Verification:** Test GREEN
- **Committed in:** `98d00a3d` (Task 2)

**4. [Rule 3 - Worktree-Setup-Luecke] Gitignored Config-Files (database.yml, carambus.yml, cable.yml) fehlten im Worktree**
- **Found during:** Initial Setup
- **Issue:** Identisch zu Plan 41-01 + 41-02 Deviations — Worktree-Checkout enthaelt nur `.erb`-Templates
- **Fix:** Aus `/Users/gullrich/DEV/carambus/carambus_master/config/` kopiert (gitignored, kein Commit-Bedarf)
- **Files modified:** Keine (gitignored)
- **Committed in:** Nicht committed

**5. [Rule 3 - Lint Fix] Useless Assignment Warning behoben**
- **Found during:** Pre-Commit standardrb-Run
- **Issue:** `old_encrypted_after_first = nil` vor dem ersten PUT war useless assignment (Variable wird in der naechsten Zeile mit `@user.reload.encrypted_password` belegt)
- **Fix:** Initialisierung mit `nil` entfernt
- **Files modified:** `test/controllers/passwords_controller_test.rb`
- **Verification:** standardrb exit 0
- **Committed in:** `98d00a3d` (Task 2, im selben Commit)

**6. [Rule 3 - Test-Fixture-Anpassung] Fixture `valid` hat kein jti-Feld — Backfill in jedem Test**
- **Found during:** Task 1 Test-Design
- **Issue:** Plan-Vorgabe Zeile 223-224 sagt: "Verifizieren dass test/fixtures/users.yml fuer `valid`-User ein jti-Feld gesetzt hat. Falls nicht: `jti: <%= SecureRandom.uuid %>` einfuegen". Bewusste Entscheidung: Fixture NICHT modifizieren, weil 8 weitere User-Fixtures betroffen waeren UND Plan-01-SUMMARY-Test `BackfillJtiForExistingUsers` explizit auf jti=NULL initial setzt. Stattdessen: Backfill-Pattern `user.update_column(:jti, SecureRandom.uuid) if user.jti.blank?` in jedem JTI-Test (entspricht dem Production-Backfill-Pfad).
- **Fix:** Backfill-Pattern in 5 neue Layer-1-Tests + 1 Layer-2-Test eingebaut
- **Files modified:** `test/models/user_test.rb`, `test/controllers/passwords_controller_test.rb`
- **Verification:** Alle Tests GREEN; kein Fixture-Konflikt mit Plan-01
- **Committed in:** `cdafcab0` + `98d00a3d`

---

**Total deviations:** 6 auto-fixed (3 Plan-prescribed Test-Bugs via Rule 1, 1 Worktree-Recovery + 1 Lint-Fix + 1 Fixture-Strategie via Rule 3). Alle Fixes sind direkt mit Plan-Tasks verbunden — kein Scope-Creep.

**Impact on plan:**
- Rule-1-Fix #1 (`reset_password!` → `reset_password`) ist Plan-Tippfehler-Korrektur
- Rule-1-Fix #2 (Token-Replay 302 vs 422) ist die wichtigste Erkenntnis: Devise hat 2 Schutz-Schichten, IST greift Schicht-2 zuerst (require_no_authentication). Test pinnt das echte IST + dokumentiert beide Schichten.
- Rule-1-Fix #3 (Unknown-Email Status) ist paranoid_mode-IST-Charakterisierung — Plan-04-Open-Item bleibt
- Rule-3-Fix #6 (Fixture-Backfill-Pattern) ist Cross-Plan-Compatibility-Entscheidung — Plan-01's `BackfillJtiForExistingUsers`-Test bleibt funktionsfaehig

## Issues Encountered

- **Devise's clear_reset_password_token-Schutz nicht direkt testbar:** Wegen `sign_in_after_reset_password=true` greift `require_no_authentication`-Filter VOR dem Token-Check. Um die clear_reset_password_token-Schicht isoliert zu testen, muesste man `Devise.sign_in_after_reset_password = false` temporaer setzen — dies waere ein invasive Test-Setup-Aenderung. Plan-04 (das diese Devise-Config potentiell auf `false` setzen wird fuer D-41-C-strenge-UX) wird die clear_reset_password_token-Schicht dann automatisch sichtbar machen.

## Plan Acceptance Criteria

| Criterion (aus Plan) | Status |
|----------------------|--------|
| `grep -c "rotate_jti_on_password_change" app/models/user.rb` >= 2 | ✓ (= 2) |
| `grep -c "saved_change_to_encrypted_password?" app/models/user.rb` == 1 | ✓ |
| 5 neue Tests in user_test.rb, alle GREEN | ✓ (21 runs / 51 assertions / 0 failures) |
| `bin/rails test test/models/user_test.rb` exit 0 (KEINE Regression) | ✓ |
| 3 neue Tests in passwords_controller_test.rb (`/rotiert User.jti/`, `/Token-Replay/`, `/unbekannter Email/`) | ✓ |
| Test "rotiert User.jti" GREEN — End-to-End-Integration | ✓ |
| Test "Token-Replay" GREEN — Devise-Default-Schutz | ✓ (charakterisiert :redirect statt :unprocessable_entity) |
| Test "unbekannter Email keine Mail" GREEN | ✓ (charakterisiert 200/422 statt :redirect) |
| `bin/rails test test/controllers/passwords_controller_test.rb` exit 0 | ✓ (7 runs / 19 assertions / 0 failures) |
| Test-Runtime gesamtes File < 8s | ✓ (~0.40s) |
| `bundle exec standardrb app/models/user.rb` exit 0 | ✓ |
| KEINE Aenderung an config/routes.rb | ✓ |
| KEINE Aenderung an config/initializers/devise.rb | ✓ |

## Threat Model — Mitigations Status

| Threat ID | Mitigation Plan-03 | Status |
|-----------|---------------------|--------|
| T-41-03-01 (Reset-Token-Replay nach Use) | Devise's clear_reset_password_token-Callback + require_no_authentication-Filter | ✓ MITIGATED — 2 Schutz-Schichten, gepinnt durch Token-Replay-Test |
| T-41-03-02 (JWT-Survival nach PW-Reset) | after_update-Callback rotiert jti bei encrypted_password-Change; jwt_revoked? klassifiziert alten Payload als revoked | ✓ MITIGATED — Layer-1-Test `jwt_revoked? klassifiziert alten Token` + Layer-2-Test "rotiert User.jti" |
| T-41-03-03 (Cross-Repo: bcw-MCP-JWTs unbeabsichtigt revoked) | Callback gegated via saved_change_to_encrypted_password? — Routine-Updates triggern KEINE Rotation | ✓ MITIGATED — 2 Non-Trigger-Tests (first_name, email) pinnen das Verhalten |
| T-41-03-04 (Account-Enumeration via Reset-Mail) | accept (Devise paranoid=false IST gepinnt) | ⚠ ACCEPTED — Unknown-Email-Test charakterisiert IST, Plan-04 koennte paranoid=true einfuehren |
| T-41-03-05 (reset_password_token-Spoofing) | accept (Devise.token_generator hash-basiert kryptografisch sicher) | ✓ ACCEPTED — Don't-Hand-Roll-Pattern, keine Custom-Logik |

## Threat Flags

Keine zusaetzliche Threat-Surface ueber den Threat-Model im PLAN hinaus. Alle 5 Threats sind dokumentiert + Mitigations gepinnt.

## Open Items for Plan 04

- **`sign_in_after_change_password = false` setzen:** D-41-C "User muss sich auf allen Geraeten neu einloggen" — RegistrationsController#update muss nach PW-Change KEIN bypass_sign_in machen (oder auf false config setzen). Ohne diese Aenderung rotiert JTI zwar, aber die aktuelle Browser-Session bekommt sofort eine neue valid Cookie-Session.
- **`paranoid = true` global evaluieren:** Heute paranoid=false (Account-Enumeration via Unknown-Email moeglich). Plan-04 entscheidet ob Hardening lohnt.
- **password_change Notification-Mail:** D-41-D Flow 3 — Devise sendet `send_password_change_notification` automatisch (config aktiv), aber kein Layer-3-Test charakterisiert die Mail-Inhalte. Plan-04 ergaenzt.
- **clear_reset_password_token-Schicht isoliert testen:** Nur moeglich mit `sign_in_after_reset_password=false` — automatisch sichtbar wenn Plan-04 das setzt.

## Next Phase Readiness

- **Plan 41-04 (Change-Password + Notification + Sender-Angleichung):** Callback aus Plan-03 wird automatisch fuer Change-Password-Pfad wiederverwendet (PATCH /users mit password). Plan-04 muss nur:
  1. `sign_in_after_change_password = false` setzen (oder im Controller bypass entfernen)
  2. password_change-Notification-Mail-Layer-3-Test ergaenzen
  3. Sender-Diskrepanz aufloesen (`Devise.mailer_sender` vs. `Carambus.config.support_email`)
- **Plan 41-05 (E2E-System-Tests):** Forgot-Password-System-Test kann jetzt JTI-Rotation als Acceptance-Gate nutzen — Capybara-Flow + JTI-Re-Assertion.

**Keine Blocker** fuer Plan-04 + Plan-05.

## Self-Check: PASSED

- ✓ `app/models/user.rb` modifiziert (after_update Callback + private rotate_jti_on_password_change!)
- ✓ `test/models/user_test.rb` modifiziert (5 neue JTI-Rotation-Tests)
- ✓ `test/controllers/passwords_controller_test.rb` modifiziert (3 neue D-41-C-Tests)
- ✓ Commit `cdafcab0` exists (Task 1: feat JTI-Rotation-Callback + 5 Layer-1-Tests)
- ✓ Commit `98d00a3d` exists (Task 2: test Layer-2 Reset-Password JTI + Token-Replay)
- ✓ Alle 21 Layer-1 user_test.rb Tests GREEN
- ✓ Alle 7 Layer-2 passwords_controller_test.rb Tests GREEN
- ✓ Cross-Phase-41 Verifikation: 47 runs / 150 assertions / 0 failures
- ✓ standardrb clean (alle 3 modifizierten Files)
- ✓ Plan-prescribed Acceptance-Criteria alle erfuellt (mit dokumentierten Test-Anpassungen wo IST != Plan)
- ✓ KEINE Aenderung an routes.rb oder devise.rb (Don't-rewrite-Devise gewahrt)

---
*Phase: 41-devise-auth-cluster-ueberarbeitung-registrierung-forgot-pass*
*Plan: 03 — JTI-Rotation bei Password-Reset (D-41-C Hard-Revoke)*
*Completed: 2026-05-16*
