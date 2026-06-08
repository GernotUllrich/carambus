---
phase: 41-devise-auth-cluster-ueberarbeitung-registrierung-forgot-pass
plan: 01
subsystem: testing
tags: [devise, mailer, letter_opener_web, characterization-tests, minitest, jwt]

# Dependency graph
requires: []
provides:
  - "test/mailers/-Verzeichnis + Devise-Mailer-Charakterisierung (Layer 3, 5 Tests)"
  - "Layer-2 Controller-Charakterisierung Forgot/Reset (PasswordsController, 4 Tests)"
  - "Layer-2 Controller-Charakterisierung Resend/Confirm (ConfirmationsController, 3 Tests)"
  - "MailHelpers-Module mit last_email + clear_mail_queue + extract_confirmation_url + extract_reset_password_url"
  - "MailHelpers in 3 Test-Basisklassen included (ActionMailer::TestCase + ActionDispatch::IntegrationTest + ApplicationSystemTestCase)"
  - "letter_opener_web aktiv in Dev (Mailbox unter /letter_opener)"
  - "raise_delivery_errors=true in Dev — frueh sichtbare Mailer-Probleme statt stille Drops"
  - "Skeleton-Files fuer Plan-05: test/system/devise_flows_test.rb, test/support/letter_opener_helper.rb, test/support/devise_test_helpers.rb"
  - "Sender-Diskrepanz dokumentiert (T-41-INFRA-01) — IST: ApplicationMailer.default vs. Devise.mailer_sender"
affects: [41-02, 41-03, 41-04, 41-05]

# Tech tracking
tech-stack:
  added:
    - "letter_opener_web 3.0 (war im Gemfile, aber nicht aktiviert)"
  patterns:
    - "Sauberes include MailHelpers in alle 3 Test-Basisklassen (kein extend-im-setup-Workaround)"
    - "Charakterisierungstests pinnen IST-Zustand bewusst (auch defekt) bevor Plan-02..04 fixen"
    - "Mail-Token-Extraktion via Regex aus Mail-Body (Reset-/Confirmation-URL)"

key-files:
  created:
    - "test/support/mail_helpers.rb"
    - "test/support/letter_opener_helper.rb"
    - "test/support/devise_test_helpers.rb"
    - "test/mailers/devise_mailer_test.rb"
    - "test/controllers/passwords_controller_test.rb"
    - "test/controllers/confirmations_controller_test.rb"
    - "test/system/devise_flows_test.rb"
  modified:
    - "config/environments/development-carambus.rb"
    - "config/routes.rb"
    - "test/test_helper.rb"

key-decisions:
  - "MailHelpers via include in 3 Basisklassen (statt extend-im-setup) — keine Minitest-Parallelisierungs-Fragility"
  - "Sender-Lock-Test pruef Carambus.config.support_email.presence || Devise.mailer_sender (env-aware), statt fixem mailer_sender — IST-Verhalten pinnen"
  - "Confirmation-Invalid-Token-Test pinnt 200-OK (Devise-Default rendert new-View), NICHT 422 — Custom-Mapping ist Plan-04-Entscheidung"
  - "letter_opener_web-Mount via if Rails.env.development? (Production-sicher, kein Info-Disclosure-Risiko)"

patterns-established:
  - "Pattern 1: MailHelpers wired in test_helper.rb fuer alle 3 Test-Basisklassen — Plan-05 baut darauf auf"
  - "Pattern 2: Charakterisierungstest-Konvention — Test-Name beginnt mit IST/Subject; Body dokumentiert was Plan-NN spaeter aendern wird"
  - "Pattern 3: Skeleton-Files mit reichhaltigen Kommentaren (D-41-A Wave-0 Pflichtlieferung) — Plan-05 fuellt"

requirements-completed:
  - REQ-41-01   # 4-Layer-Test-Infrastruktur etabliert
  - REQ-41-02   # letter_opener_web in Dev aktiv (Mailbox + Route)
  - REQ-41-03   # Charakterisierungstests aller 4 Flows dokumentieren IST-Zustand

# Metrics
duration: 7min
completed: 2026-05-15
---

# Phase 41 Plan 01: Wave-0 Test-Infrastruktur + Devise-Charakterisierung Summary

**4-Layer Test-Infrastruktur etabliert (Mailer + Controller + Skeleton fuer System), MailHelpers in 3 Basisklassen wired, letter_opener_web in Dev aktiv, 12 Charakterisierungstests pinnen IST-Zustand der Devise-Auth-Flows fuer Plan-02..05 als Acceptance-Gate.**

## Performance

- **Duration:** 7 min (442s)
- **Started:** 2026-05-15T22:46:33Z
- **Completed:** 2026-05-15T22:53:55Z
- **Tasks:** 4
- **Files created:** 7
- **Files modified:** 3
- **Tests added:** 12 (5 Mailer + 4 Passwords + 3 Confirmations)
- **Assertions added:** 36
- **Test runtime:** ~0.43s fuer alle 12 Tests

## Accomplishments

- **Wave-0 Definition-of-Done erreicht:** alle 6 Pflichtlieferungen aus VALIDATION.md vorhanden
- **Test-Pyramide fundamentiert:** Layer-3 (Mailer) und Layer-2 (Controller) Charakterisierung deterministisch in <1s
- **Sender-Diskrepanz T-41-INFRA-01 dokumentiert:** Test 5 in `devise_mailer_test.rb` lockt env-spezifisches IST (Test: `Devise.mailer_sender` greift weil `Carambus.config.support_email = nil`; Production: `support_email` greift); Plan-04 angleicht
- **letter_opener_web in Dev aktiv:** Mailer-Probleme nicht mehr stille Drops (`raise_delivery_errors=true`)
- **MailHelpers sauber wired:** `include MailHelpers` in 3 Basisklassen via `test_helper.rb`, kein extend-im-setup-Workaround in einzelnen Tests noetig
- **Skeleton-Files fuer Plan-05 vorhanden:** `test/system/devise_flows_test.rb` + 2 Support-Module geladen + lint-clean

## Test-Count pro Layer (Initial)

| Layer | Datei | Test-Count | Pass/Fail | Runtime |
|-------|-------|-----------:|-----------|--------:|
| Layer 3 (Mailer) | `test/mailers/devise_mailer_test.rb` | 5 | 5 pass / 0 fail | ~0.36s |
| Layer 2 (Controller) | `test/controllers/passwords_controller_test.rb` | 4 | 4 pass / 0 fail | ~0.12s |
| Layer 2 (Controller) | `test/controllers/confirmations_controller_test.rb` | 3 | 3 pass / 0 fail | ~0.05s |
| Layer 4 (System) | `test/system/devise_flows_test.rb` | 0 (Skeleton) | n/a | n/a |
| **Total** | | **12** | **12 pass / 0 fail** | **~0.43s** |

## Task Commits

Each task was committed atomically (--no-verify, parallel-executor):

1. **Task 1: letter_opener_web in Dev aktivieren + Route mounten** - `7b26b858` (feat)
2. **Task 2: Mail-Helper + Layer-3 Charakterisierungstests** - `c049a7a7` (test)
3. **Task 3: Layer-2 Controller-Charakterisierung (passwords + confirmations)** - `01ebcbf5` (test)
4. **Task 4: Wave-0-Skeleton-Files + standardrb-Cleanup** - `bbe97079` (test)

## Files Created/Modified

### Created (7)

- `test/support/mail_helpers.rb` — Module mit `last_email`, `clear_mail_queue`, `extract_confirmation_url`, `extract_reset_password_url`
- `test/support/letter_opener_helper.rb` — Skeleton-Module fuer letter_opener-Mailbox-Parsing (Reserve)
- `test/support/devise_test_helpers.rb` — Skeleton-Module mit `generate_raw_confirmation_token` (Reserve)
- `test/mailers/devise_mailer_test.rb` — 5 Layer-3 Charakterisierungstests
- `test/controllers/passwords_controller_test.rb` — 4 Layer-2 Charakterisierungstests
- `test/controllers/confirmations_controller_test.rb` — 3 Layer-2 Charakterisierungstests
- `test/system/devise_flows_test.rb` — Klassen-Skeleton DeviseFlowsTest (Plan-05 fuellt)

### Modified (3)

- `config/environments/development-carambus.rb` — `delivery_method = :letter_opener_web`, `raise_delivery_errors = true`, `default_url_options host=localhost port=3000`
- `config/routes.rb` — `mount LetterOpenerWeb::Engine, at: "/letter_opener"` (dev-only)
- `test/test_helper.rb` — `include MailHelpers` in `ActionDispatch::IntegrationTest` + `ActionMailer::TestCase` + `ApplicationSystemTestCase` (3 Klassen)

## MailHelpers-Methoden-Signatur

| Methode | Signatur | Zweck |
|---------|----------|-------|
| `last_email` | `() -> Mail::Message` | `ActionMailer::Base.deliveries.last` |
| `clear_mail_queue` | `() -> void` | `ActionMailer::Base.deliveries.clear` |
| `extract_confirmation_url` | `(mail = last_email) -> String?` | Regex `/confirmation\?...` aus Mail-Body |
| `extract_reset_password_url` | `(mail = last_email) -> String?` | Regex `/password/edit\?...` aus Mail-Body |

## MailHelpers-Includes in test_helper.rb

3 Test-Basisklassen — alle via `include MailHelpers` (kein extend-im-setup-Workaround):

| Basisklasse | Verwendung |
|-------------|------------|
| `ActionMailer::TestCase` | Layer-3 Mailer-Tests (`test/mailers/`) |
| `ActionDispatch::IntegrationTest` | Layer-2 Controller-/Request-Tests |
| `ApplicationSystemTestCase` | Layer-4 Capybara-System-Tests (Plan-05) |

## Devise-Routen-Diskrepanz: KEINE

Alle in den Layer-2-Tests genutzten Devise-Routen existieren wie erwartet:

- `user_password_path` (POST + PUT) ✓
- `edit_user_password_path` (GET) ✓
- `user_confirmation_path` (POST + GET) ✓
- `new_user_session_path` (GET, fuer redirect) ✓

Keine Custom-Override-Routen noetig.

## Decisions Made

- **MailHelpers via include in 3 Basisklassen statt extend-im-setup:** Vermeidet Minitest-Parallelisierungs-Fragility; kein Bedarf an `extend MailHelpers if !respond_to?(:last_email)`-Workaround in einzelnen Tests.
- **Sender-Lock-Test env-aware:** `expected_sender = Carambus.config.support_email.presence || Devise.mailer_sender` statt fix `Devise.mailer_sender` — pinnt das echte IST pro Env (Test: nil → mailer_sender; Production: support_email).
- **Confirmation-Invalid-Token: 200 OK pinnen, nicht 422:** Devise-Default-`ConfirmationsController#show` rendert `new`-View mit 200 + Form-Error. Custom-`unprocessable_entity`-Mapping ist Plan-04-Entscheidung. Hauptaussage des Tests: kein Crash.
- **`if Rails.env.development?`-Gate fuer LetterOpenerWeb-Mount:** T-41-01-01 Information-Disclosure-Mitigation; Production-Mount bleibt unmoeglich.
- **`require_relative "application_system_test_case"` mit `File.exist?`-Guard:** Schuetzt frueheren require-Pfad falls test_helper geladen wird bevor application_system_test_case.rb existiert.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Worktree fehlte gitignored Config-Files (database.yml, carambus.yml, cable.yml)**
- **Found during:** Task 2 (DB-Prepare via `bin/rails db:test:prepare`)
- **Issue:** Worktree-Checkout hatte nur die `.erb`-Templates und `database.development.yml` — Rails wirft `Errno::ENOENT` beim Boot. Drittes File `cable.yml` fehlte ebenfalls (NoMethodError on nil bei ActionCable-Pubsub).
- **Fix:** Aus dem Master-Working-Tree (`/Users/gullrich/DEV/carambus/carambus_master/config/`) kopiert: `database.yml`, `carambus.yml`, `cable.yml`. Diese sind via `.gitignore` ausgeschlossen, kein Commit-Bedarf.
- **Files modified:** Keine (gitignored config-Files im Worktree)
- **Verification:** `bin/rails test` boot ohne Errno; alle 12 Tests gruen
- **Committed in:** Nicht committed (gitignored, lokale Worktree-Recovery)

**2. [Rule 1 - Bug] Sender-Lock-Test scheiterte initial mit nil-Erwartung**
- **Found during:** Task 2 (erster Mailer-Test-Run)
- **Issue:** Test war auf `Carambus.config.support_email` gepinnt — im Test-Env aber `nil` (carambus.yml `test:`-Section setzt nichts). Devise.mailer_sender greift als Fallback ("no-reply@carambus.de").
- **Fix:** Test-Erwartung auf env-aware Pattern umgestellt: `Carambus.config.support_email.presence || Devise.mailer_sender`. Damit pinnt der Test das echte IST in beiden Envs (Test: mailer_sender; Production: support_email).
- **Files modified:** `test/mailers/devise_mailer_test.rb`
- **Verification:** Test 5 gruen
- **Committed in:** `c049a7a7` (Task 2 Commit, mit angepasster Erwartung)

**3. [Rule 1 - Bug] Confirmation-Invalid-Token-Test erwartete 422, IST war 200**
- **Found during:** Task 3 (erster Controller-Test-Run)
- **Issue:** `assert_response :unprocessable_entity` falsch; Devise-Default rendert `new`-View mit 200.
- **Fix:** Test-Erwartung auf `assert_response :success` + dokumentierten Kommentar umgestellt — pinnt IST, Plan-04 koennte Custom-Mapping zu `:unprocessable_entity` einfuehren.
- **Files modified:** `test/controllers/confirmations_controller_test.rb`
- **Verification:** Test 3 gruen
- **Committed in:** `01ebcbf5` (Task 3 Commit)

**4. [Rule 3 - Blocking] standardrb-Lint-Issues (Hash-Literal-Spaces) in Controller-Tests**
- **Found during:** Task 4 (Lint-Verification)
- **Issue:** 8 `Layout/SpaceInsideHashLiteralBraces`-Issues in passwords/confirmations Controller-Tests
- **Fix:** `bundle exec standardrb --fix` autofixed
- **Files modified:** `test/controllers/passwords_controller_test.rb`, `test/controllers/confirmations_controller_test.rb`
- **Verification:** `bundle exec standardrb` exit 0
- **Committed in:** `bbe97079` (Task 4 Commit)

---

**Total deviations:** 4 auto-fixed (1 missing critical funktionalitaet via Worktree-Recovery, 2 bug-fixes IST-Erwartung, 1 blocking lint)
**Impact on plan:** Alle Auto-Fixes essentiell — die 2 Bug-Fixes (Tests 2.5 + 3.3) sind sogar **per Definition** korrekte Charakterisierung (Tests pinnen IST, nicht Soll). Worktree-Recovery + Lint-Autofix sind Infrastruktur-Hygiene. Kein Scope-Creep.

## Issues Encountered

- **Worktree-Setup-Luecke:** Beim ersten Test-Run wurde klar, dass `.gitignore`-ausgeschlossene Config-Files (`database.yml`, `carambus.yml`, `cable.yml`) im frischen Worktree-Checkout fehlen. Aus Master-Working-Tree manuell kopiert (Plan-Phase nicht ueber Worktree-Setup-Detail informiert). Dauerhafte Loesung waere ein Worktree-Bootstrap-Skript — out-of-scope fuer Phase 41.
- **`bin/rails runner` mit `require_relative` schlaegt fehl:** Rails-Runner resolved Pfade gegen Gem-Path. Workaround mit `load Rails.root.join(...)`. Verifikation in Task 4 erfolgreich.

## VALIDATION.md Wave-0 Requirements (6/6 vollstaendig)

| # | Requirement | Lieferant | Status |
|---|-------------|-----------|--------|
| 1 | `test/mailers/`-Verzeichnis | Task 2 | ✓ |
| 2 | `test/mailers/devise_mailer_test.rb` (Skeleton + 5 Tests) | Task 2 | ✓ |
| 3 | `test/system/devise_flows_test.rb` (Skeleton) | Task 4 | ✓ |
| 4 | `test/support/letter_opener_helper.rb` (Skeleton) | Task 4 | ✓ |
| 5 | `test/support/devise_test_helpers.rb` (Skeleton) | Task 4 | ✓ |
| 6 | `config/environments/development-carambus.rb` letter_opener_web | Task 1 | ✓ |

**Empfehlung:** `wave_0_complete: true` in `41-VALIDATION.md` setzen (durch Orchestrator nach Wave-0 Merge).

## Threat Flags

Keine zusaetzliche Threat-Surface ueber den Threat-Model im PLAN hinaus. Threats T-41-01-01 (Information Disclosure via LetterOpenerWeb) und T-41-01-02 (Spoofing via Mail-Helper) sind weiterhin durch die im PLAN dokumentierten Mitigations abgedeckt.

## User Setup Required

None — alle Aenderungen sind via standard `bin/rails test` lauffaehig. `letter_opener_web` ist bereits im Gemfile (Group :development) und wird beim naechsten `bundle install` ggf. aktualisiert.

## Next Phase Readiness

- **Plan 41-02 (Registrierung-Fix):** Layer-3 + Layer-2 Test-Infra steht; charakterisiert IST. Plan-02 kann gegen die 5 Mailer-Tests + 4 Passwords-Tests + 3 Confirmations-Tests als Acceptance-Gate arbeiten.
- **Plan 41-03 (JTI-Rotation):** Kann an `test/controllers/passwords_controller_test.rb` JTI-Rotation-Tests anhaengen — MailHelpers + IntegrationHelpers wired.
- **Plan 41-04 (Sender-Angleichung + DeviseMailJob):** Sender-Diskrepanz-Lock in `devise_mailer_test.rb` Test 5 wird ggf. angepasst, sobald `ApplicationMailer.default from:` und `Devise.mailer_sender` angeglichen sind.
- **Plan 41-05 (System-Tests):** `DeviseFlowsTest`-Skeleton vorhanden; `MailHelpers` automatisch via `include` verfuegbar; `extract_reset_password_url` + `extract_confirmation_url` einsatzbereit fuer Click-Through-Flow.

**Keine Blocker** fuer Plan-02..05.

## Self-Check: PASSED

- ✓ `test/support/mail_helpers.rb` exists
- ✓ `test/support/letter_opener_helper.rb` exists
- ✓ `test/support/devise_test_helpers.rb` exists
- ✓ `test/mailers/devise_mailer_test.rb` exists (5 tests)
- ✓ `test/controllers/passwords_controller_test.rb` exists (4 tests)
- ✓ `test/controllers/confirmations_controller_test.rb` exists (3 tests)
- ✓ `test/system/devise_flows_test.rb` exists (skeleton, 0 tests)
- ✓ `config/environments/development-carambus.rb` modified (letter_opener_web aktiv)
- ✓ `config/routes.rb` modified (LetterOpenerWeb::Engine mounted)
- ✓ `test/test_helper.rb` modified (3 include MailHelpers)
- ✓ Commit `7b26b858` exists (Task 1)
- ✓ Commit `c049a7a7` exists (Task 2)
- ✓ Commit `01ebcbf5` exists (Task 3)
- ✓ Commit `bbe97079` exists (Task 4)
- ✓ All 12 tests pass (0 failures, 0 errors)
- ✓ standardrb lint clean

---
*Phase: 41-devise-auth-cluster-ueberarbeitung-registrierung-forgot-pass*
*Completed: 2026-05-15*
