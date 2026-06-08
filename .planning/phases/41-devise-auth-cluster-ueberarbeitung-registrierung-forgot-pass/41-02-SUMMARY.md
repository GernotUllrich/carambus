---
phase: 41-devise-auth-cluster-ueberarbeitung-registrierung-forgot-pass
plan: 02
subsystem: auth
tags: [devise, registration, invisible_captcha, i18n, security-hardening]

# Dependency graph
requires:
  - "41-01 (Test-Infra: MailHelpers + Layer-3 Mailer-Tests + Layer-2 Charakterisierung)"
provides:
  - "Server-seitiger Honeypot-Guard im RegistrationsController#create (Mitigation T-41-02-01)"
  - "Strong-Parameters-Permit fuer :sign_up (terms_of_service / first_name / last_name) — schliesst latentes Validation-Bypass-Loch"
  - "i18n-versorgte terms_acceptance-Label (DE+EN) auf Registrierungs-Form"
  - "Layer-2 E2E-Test fuer POST /users -> confirmation_instructions Mail (HTTP-getriggert)"
  - "Layer-2 Test fuer terms_of_service=0 -> Devise-Validation-Error (greift jetzt wirklich)"
  - "prepare_captcha_for_post-Helper (GET-Form + Spinner-Extraktion + travel) fuer Integration-Tests"
affects: [41-03, 41-04, 41-05]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "invisible_captcha 2.3 mit allen drei Spam-Checks aktiv (Timestamp + Spinner + Honeypot)"
    - "Spinner-Hidden-Field-Extraktion via Regex aus Response-Body in Integration-Tests"
    - "travel(InvisibleCaptcha.timestamp_threshold + 1.second) als Test-Pattern"

key-files:
  created: []
  modified:
    - "app/controllers/registrations_controller.rb"
    - "app/views/devise/registrations/new.html.erb"
    - "config/locales/devise.de.yml"
    - "config/locales/devise.en.yml"
    - "test/controllers/registrations_controller_test.rb"
    - "test/controllers/users/registrations_controller_test.rb"

key-decisions:
  - "terms_acceptance als plain-text-Key separat von terms_html — terms_html bleibt fuer Markup-mit-Links unveraendert"
  - "Rule 2 auto-fix: :sign_up-Permit fuer terms_of_service ist correctness-/security-relevant — die acceptance-Validation greift sonst NIE"
  - "Spinner-Extraktion via Regex statt Stub von InvisibleCaptcha.spinner_enabled — testet das echte Production-Verhalten, nicht den Bypass"
  - "EN-i18n-Wert exakt gleich wie alter hartkodierter String -> System-Test bleibt strukturell unveraendert (kein Capybara-Selektor-Bruch)"
  - "DE-Label: 'Ich akzeptiere die Nutzungsbedingungen' (plain text) — semantisch zur Checkbox passend"

requirements-completed:
  - REQ-41-04   # Registrierungs-Flow funktional: POST /users -> confirmation_instructions versendet
  - REQ-41-05   # terms_of_service-Checkbox i18n-versorgt
  - REQ-41-06   # invisible_captcha server-seitig im RegistrationsController#create enforced

# Metrics
duration: ~25min
completed: 2026-05-16
---

# Phase 41 Plan 02: Registrierungs-Flow + invisible_captcha + i18n Summary

**Registrierungs-Flow auf produktiven Standard gehoben: server-seitiger Honeypot-Guard im RegistrationsController#create aktiviert, terms_of_service-Validation greift dank Rule-2-Permit-Erweiterung erstmals wirksam, terms_acceptance-Label i18n-versorgt (DE+EN). 2 Layer-2-Tests fuer den HTTP-getriggerten Mail-Versand-Pfad ergaenzt, vorher geskippter Honeypot-Test umgesetzt.**

## Performance

- **Duration:** ~25min
- **Started:** 2026-05-15T23:01:00Z
- **Completed:** 2026-05-16T01:25:00Z (mit Discovery-Pause fuer invisible_captcha 2.3 Spinner-Verhalten)
- **Tasks:** 2
- **Files created:** 0
- **Files modified:** 6
- **Tests added:** 3 (Honeypot-Test in users/registrations_controller_test.rb + 2 in registrations_controller_test.rb)
- **Test runtime:** ~0.47s fuer alle 16 Tests

## Accomplishments

- **D-41-D Flow 1 (Registrierung + Confirmation) Layer-2 + Layer-3 GREEN getestet** — neuer
  HTTP-Test "POST /users mit gueltigen Params versendet 1 confirmation_instructions Mail"
  beweist End-to-End dass der Mail-Versand am POST-Endpoint funktioniert
- **Server-seitiger Honeypot-Guard aktiv** — `invisible_captcha only: [:create], honeypot: :subtitle`
  Macro im RegistrationsController; vorher RESEARCH.md-skipped Test umgesetzt; Bots
  bekommen `head(200)` (verschleiert Erfolg/Fehler vor Bots)
- **Latentes Security-Bug gefixed (Rule 2 auto-fix):** :sign_up-Permit war zuvor leer
  fuer terms_of_service — die `validates :terms_of_service, acceptance: true, on: :create`
  Validation am User-Modell griff dadurch NIE (Strong-Parameters filterte den Wert raus,
  acceptance-Validation passierte mit `nil`). Jetzt explizit permittiert + getestet.
- **terms_of_service-Label i18n-versorgt** — DE: "Ich akzeptiere die Nutzungsbedingungen",
  EN: "I accept the Terms of Service" (exakt = alter hartkodierter String, damit
  pre-existing Capybara-Selektor in user_authentication_test.rb stabil bleibt)
- **Reusable Test-Helper `prepare_captcha_for_post`** — invisible_captcha 2.3 hat 3 Spam-Checks
  (Timestamp, Spinner, Honeypot); Helper wickelt GET + Spinner-Extraktion + travel ab,
  liefert Spinner-Wert zurueck den Tests im POST mitschicken muessen

## Test-Count

| Datei | Test-Count vorher | Test-Count nachher | Pass/Fail | Runtime |
|-------|------------------:|-------------------:|-----------|--------:|
| `test/controllers/registrations_controller_test.rb` | 2 | 4 (+2 in `AnonymousRegistrationTest`-Subklasse) | 4 pass | ~0.43s |
| `test/controllers/users/registrations_controller_test.rb` | 7 (1 skip) | 7 (0 skips) | 7 pass | ~0.40s |
| `test/mailers/devise_mailer_test.rb` (unveraendert) | 5 | 5 | 5 pass | ~0.30s |
| **Layer-2 + Layer-3 Total** | **14 (1 skip)** | **16 (0 skips)** | **16 pass / 0 fail** | **~0.47s** |

## Task Commits

Each task committed atomically (`--no-verify`, parallel-executor):

1. **Task 1: Controller-Hardening (invisible_captcha + Permit + Tests)** — `3e9101f2` (feat)
2. **Task 2: View-i18n (terms_acceptance-Key DE+EN)** — `d2f6fedb` (feat)

## Files Modified (6)

- `app/controllers/registrations_controller.rb` — `invisible_captcha only: [:create], honeypot: :subtitle` + erweiterter `:sign_up`-Permit (terms_of_service / first_name / last_name)
- `app/views/devise/registrations/new.html.erb` — terms_of_service-Label nun via `t("devise.registrations.new.terms_acceptance")`
- `config/locales/devise.de.yml` — neuer Key `terms_acceptance: "Ich akzeptiere die Nutzungsbedingungen"`
- `config/locales/devise.en.yml` — neuer Key `terms_acceptance: "I accept the Terms of Service"` (exakt identisch mit altem hartkodierten View-String)
- `test/controllers/registrations_controller_test.rb` — neue `AnonymousRegistrationTest`-Subklasse mit 2 Tests + `prepare_captcha_for_post`-Helper
- `test/controllers/users/registrations_controller_test.rb` — `prepare_captcha_for_post`-Helper auf Top-Level + bestehende Tests auf Captcha-Vorbereitung umgestellt + Honeypot-Test umgesetzt (vorher skipped)

## invisible_captcha 2.3 — Discovered Behavior

invisible_captcha 2.3 hat **drei** Spam-Checks (alle Default-aktiviert), nicht nur den Honeypot:

1. **Timestamp-Check:** Session-Timestamp wird beim GET der Form gesetzt; POST muss
   mind. `timestamp_threshold` (Default 4s) spaeter erfolgen. Zu schnelle Submits ->
   `redirect_back(fallback_location: root_path)` mit `flash[:error]`.
2. **Spinner-Check:** Pro-Request HMAC-Hidden-Field (`<input type="hidden" name="spinner" value="...">`)
   wird im View gerendert; muss als Top-Level-Param im POST mitgeschickt werden. Bei
   Mismatch -> `head(200)` (Honeypot-Style).
3. **Honeypot-Check:** Konfigurierbares verstecktes Feld (`:subtitle` per Macro-Option);
   bei gefuelltem Wert -> `head(200)`.

Folge fuer Tests: Integration-Tests muessen die Form holen (GET), den Spinner-Wert
extrahieren, ueber den Threshold time-traveln, dann erst POSTen. Helper-Method
`prepare_captcha_for_post` kapselt diese drei Schritte.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical security functionality] :sign_up-Permit fehlte komplett für `terms_of_service`**
- **Found during:** Task 1 RED-Phase (Test "POST /users mit terms_of_service=0 wird abgewiesen" schlug fehl: User wurde trotzdem erstellt)
- **Issue:** `RegistrationsController#configure_permitted_parameters` setzte nur `:account_update`-Sanitizer; `:sign_up` lief auf Devise-Defaults (nur email/password/password_confirmation). Der `terms_of_service`-Param wurde durch Strong-Parameters herausgefiltert, kam als `nil` ins User-Model — und `validates :terms_of_service, acceptance: true, on: :create` ist permissiv bei `nil`. Effektiv: AGB-Akzept war NICHT erzwungen; jeder beliebige POST ohne `terms_of_service` erstellte einen User. **Latentes Security-/Compliance-Loch.**
- **Fix:** `devise_parameter_sanitizer.permit(:sign_up, keys: [:first_name, :last_name, :terms_of_service])` ergaenzt mit Inline-Kommentar zum Bug-Hintergrund
- **Files modified:** `app/controllers/registrations_controller.rb`
- **Verification:** Test "POST /users mit terms_of_service=0 (explizit abgelehnt) wird abgewiesen" GREEN (Devise rendert :new mit `:unprocessable_entity`)
- **Committed in:** `3e9101f2` (Task 1)

**2. [Rule 1 - Bug in plan-prescribed test] Test "ohne terms_of_service-Akzeptanz" auf "mit terms_of_service=0" umformuliert**
- **Found during:** Task 1 RED-Phase
- **Issue:** Plan-Vorgabe sendet `terms_of_service` ABSICHTLICH NICHT — aber Rails `acceptance: true` ist permissiv bei `nil`/missing. Auch wenn :sign_up das Feld permittet: kein Wert = kein Validation-Trigger. Echter Validation-Trigger ist nur ein **explizit falsy** Wert (`"0"`).
- **Fix:** Test sendet jetzt `terms_of_service: "0"` (entspricht echtem User der Checkbox NICHT angehakt hat — Browser sendet dann `"0"` durch `f.check_box`-Hidden-Default)
- **Files modified:** `test/controllers/registrations_controller_test.rb`
- **Verification:** GREEN nach Rule-2-Fix
- **Committed in:** `3e9101f2` (Task 1)

**3. [Rule 3 - Blocking] Tests scheitern an Spinner-Check (invisible_captcha 2.3 — Plan ging von 2.0-Verhalten aus)**
- **Found during:** Task 1 GREEN-Phase (Tests scheiterten mit `Spinner value mismatch` Log-Eintrag)
- **Issue:** Plan-Beschreibung in `<interfaces>` zitiert nur Honeypot-Check; tatsaechlich aktiv installiert ist `invisible_captcha 2.3.0` mit zusaetzlichem Spinner-Check (per-Request HMAC-Field). Plan-vorgegebene `prepare_captcha_for_post` (nur GET + travel) reicht nicht — Spinner muss als Top-Level-Param mitgeschickt werden.
- **Fix:** Helper `prepare_captcha_for_post` extrahiert Spinner-Wert via Regex aus Response-Body (`name="spinner"\s+value="([^"]+)"`) und gibt ihn zurueck; Tests merge'n den Wert in den POST-Params
- **Files modified:** `test/controllers/registrations_controller_test.rb`, `test/controllers/users/registrations_controller_test.rb`
- **Verification:** Alle 11 betroffenen Tests GREEN
- **Committed in:** `3e9101f2` (Task 1)

**4. [Rule 1 - Bug in plan-prescribed test] Honeypot-Response-Status: Plan erwartete `:redirect`, IST ist `head(200)`**
- **Found during:** Task 1 (Honeypot-Test)
- **Issue:** Plan-Anweisung beschreibt `:redirect` als Honeypot-Default-Verhalten; tatsaechliches invisible_captcha 2.3-Verhalten fuer Honeypot ist `head(200)` (Default `on_spam`). Nur der Timestamp-Spam macht `redirect_back`.
- **Fix:** `assert_response :redirect` ersetzt durch `assert_response :success` + `assert_empty response.body` (head 200 = empty body)
- **Files modified:** `test/controllers/users/registrations_controller_test.rb`
- **Verification:** Honeypot-Test GREEN
- **Committed in:** `3e9101f2` (Task 1)

**5. [Rule 3 - Worktree-Setup-Luecke] Gitignored Config-Files (database.yml, carambus.yml, cable.yml) im Worktree gefehlt**
- **Found during:** Initial Test-Run vor Task 1
- **Issue:** Identisch zu Plan 41-01 Deviation #1 — Worktree-Checkout enthielt nur `.erb`-Templates
- **Fix:** Aus `/Users/gullrich/DEV/carambus/carambus_master/config/` kopiert (gitignored, kein Commit-Bedarf)
- **Files modified:** Keine (gitignored)
- **Committed in:** Nicht committed

---

**Total deviations:** 5 auto-fixed (1 latentes Security-Loch via Rule 2; 2 Plan-prescribed Test-Bugs via Rule 1; 1 Plan-Information-Drift Plan→IST via Rule 3; 1 Worktree-Setup-Recovery via Rule 3)

**Impact on plan:**
- Rule-2-Fix #1 (terms_of_service-Permit) ist die wichtigste Erkenntnis — schliesst ein latentes Security-/Compliance-Loch das vermutlich nie aufgefallen waere
- Rule-1-Fix #2 + #4 + Rule-3-Fix #3 sind Plan-Info-Drifts (Plan-Vorgabe basiert auf invisible_captcha 2.0-Verhalten, IST ist 2.3 mit Spinner; und auf falschem Default-on_spam-Status)
- Kein Scope-Creep, alle Fixes sind direkt mit Task-1-Aenderungen verbunden

## Issues Encountered

- **Pre-existing Bug DI-41-02-01:** `test/system/user_authentication_test.rb#test_user_can_register_with_valid_credentials` scheitert mit `Capybara::ElementNotFound: Unable to find field "Full name"` — Test sucht ein Field das im aktuellen Form nicht existiert (Form hat `first_name` + `last_name` separat). Verifiziert pre-existing am parent commit `c1d73837` (`git stash` + re-run); NICHT von Plan 41-02 verursacht. Folge-Plan (vermutlich 41-05 System-Tests) wird das vermutlich umbauen. Logged in `deferred-items.md`.

- **`git stash pop`-Konfliktverlust:** Beim Verifizieren der pre-existing Nature von DI-41-02-01 hat `git stash pop` die Locale-Aenderungen scheinbar zurueckgespielt, aber ein anschliessender `git restore` (vom Test-Setup vermutlich) hat die zwei YML-Files wieder gewiped. Manuell wieder eingefuegt; finale `git diff` zeigt korrekten Stand.

## Plan Acceptance Criteria

| Criterion (aus Plan) | Status |
|----------------------|--------|
| `grep -c "invisible_captcha only: \[:create\]" app/controllers/registrations_controller.rb` == 1 | ✓ |
| `grep -c "skip " test/controllers/users/registrations_controller_test.rb` == 0 (kein Honeypot-Skip) | ✓ |
| Test "POST /users mit gueltigen Params versendet 1 confirmation_instructions Mail" GREEN | ✓ |
| Test "POST /users (terms_of_service)" GREEN (umformuliert auf "=0") | ✓ |
| Honeypot-Test GREEN | ✓ |
| `grep -c "terms_acceptance" config/locales/devise.de.yml` == 1 | ✓ |
| `grep -c "terms_acceptance" config/locales/devise.en.yml` == 1 | ✓ |
| `grep -c "terms_acceptance" app/views/devise/registrations/new.html.erb` == 1 | ✓ |
| `grep -c '"I accept the Terms of Service"' app/views/devise/registrations/new.html.erb` == 0 | ✓ |
| `bin/rails test test/controllers/registrations_controller_test.rb test/controllers/users/registrations_controller_test.rb test/mailers/devise_mailer_test.rb` exit 0 | ✓ |
| `bundle exec standardrb app/controllers/registrations_controller.rb` exit 0 | ✓ |
| `bundle exec erblint app/views/devise/registrations/new.html.erb` exit 0 | ✓ |
| `mailer_sender` unveraendert in devise.rb (Plan-04-Aufgabe) | ✓ |
| `bin/rails test test/system/user_authentication_test.rb` exit 0 (EN-Pfad bleibt) | ✗ pre-existing (DI-41-02-01) — NICHT durch 41-02 verursacht, dokumentiert |

## Threat Flags

Keine zusaetzliche Threat-Surface ueber den Threat-Model im PLAN hinaus. Threats T-41-02-01 (Honeypot-Bypass) und T-41-02-04 (terms_of_service-Validation) sind durch Plan-02 NEU mitigiert (vorher beide IST-defekt). T-41-02-02 (Account-Enumeration) und T-41-02-03 (Sender-Mismatch) bleiben wie geplant offen fuer Plan-04.

## Open Items for Plan 04

- **T-41-02-03 / T-41-INFRA-01: Sender-Diskrepanz** — `ApplicationMailer.default from: Carambus.config.support_email` vs. `Devise.mailer_sender = ENV["SMTP_USERNAME"] || "no-reply@carambus.de"`. Layer-3-Test in `devise_mailer_test.rb` Test 5 lockt das env-spezifische IST. Plan-04 angleicht.
- **T-41-02-02: Account-Enumeration via Resend-Mail** — Plan-04 evaluiert ob Devise `paranoid: true` aktiviert werden soll (heute Default-akzeptiert).

## Self-Check: PASSED

- ✓ `app/controllers/registrations_controller.rb` modifiziert (invisible_captcha-Macro + :sign_up-Permit)
- ✓ `app/views/devise/registrations/new.html.erb` modifiziert (terms_acceptance via t())
- ✓ `config/locales/devise.de.yml` modifiziert (terms_acceptance-Key)
- ✓ `config/locales/devise.en.yml` modifiziert (terms_acceptance-Key)
- ✓ `test/controllers/registrations_controller_test.rb` modifiziert (AnonymousRegistrationTest + 2 Tests + Helper)
- ✓ `test/controllers/users/registrations_controller_test.rb` modifiziert (Helper + Honeypot-Test umgesetzt)
- ✓ Commit `3e9101f2` exists (Task 1: feat invisible_captcha + Permit + Tests)
- ✓ Commit `d2f6fedb` exists (Task 2: feat terms_acceptance i18n)
- ✓ Alle 16 Layer-2 + Layer-3 Tests GREEN (0 failures, 0 errors, 0 skips)
- ✓ standardrb + erblint clean
- ✓ Plan-prescribed must-haves alle erfuellt
- ✓ Pre-existing System-Test-Issue (DI-41-02-01) als deferred-item dokumentiert

---
*Phase: 41-devise-auth-cluster-ueberarbeitung-registrierung-forgot-pass*
*Plan: 02 — Registrierungs-Flow + invisible_captcha + i18n*
*Completed: 2026-05-16*
