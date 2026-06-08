---
phase: 41-devise-auth-cluster-ueberarbeitung-registrierung-forgot-pass
plan: 05
subsystem: testing
tags: [devise, system-tests, capybara, selenium, e2e, mail-token-click-through]

# Dependency graph
requires:
  - "41-01 (Test-Infra: MailHelpers + Layer-3 Mailer-Tests + Skeleton DeviseFlowsTest)"
  - "41-02 (Registrierung + invisible_captcha + i18n)"
  - "41-03 (JTI-Rotation-Callback im User-Modell)"
  - "41-04 (SMTP-Haertung + sign_in_after_change_password=false + DeviseMailJob)"
provides:
  - "D-41-A Layer-4 vollstaendig: 4 E2E-System-Tests in test/system/devise_flows_test.rb"
  - "Sprachunabhaengige Capybara-Selektoren via input[name=...] (Pattern fuer Custom-Edit-Locale-Drift)"
  - "wait_for_mail + wait_until Polling-Helper fuer Capybara-Server-Async-Races"
  - "InvisibleCaptcha.timestamp_threshold-Override Pattern fuer System-Tests"
  - "queue_adapter=:inline-Override Pattern fuer ApplicationSystemTestCase (analog Plan-04 fuer IntegrationTest+ActionMailer::TestCase)"
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Defensive include MailHelpers im Test-File (Plan-01 test_helper.rb-Wiring greift wegen zirkulaerem require_relative nicht zuverlaessig)"
    - "Field-Selektoren via Input-name statt Label-Text — robust gegen Locale-Drift in Custom-Edit-View"
    - "Polling-Wait fuer Server-Async-Saves nach Capybara-Klick (wait_for_mail / wait_until)"
    - "InvisibleCaptcha.timestamp_threshold = 0 statt travel — Class-Attribute ist thread-shared, travel-Stubs sind es nicht"

key-files:
  created: []
  modified:
    - "test/system/devise_flows_test.rb"

key-decisions:
  - "include MailHelpers im Test-File (defensiv): Plan-01-Wiring in test_helper.rb scheitert weil application_system_test_case.rb sich zirkulaer einliest — ApplicationSystemTestCase ist beim Patch-Aufruf noch nicht body-evaluated. Lokaler include ist idempotent."
  - "Field-Selektoren via name-Attribut (z.B. 'user[current_password]'): Die Custom-Edit-View in app/views/devise/registrations/edit.html.erb rendert Labels in DE selbst bei locale=:en in der URL (User-Preferences ueberschreiben), daher sind sprachunabhaengige Selektoren robust und nicht-flake."
  - "InvisibleCaptcha.timestamp_threshold = 0 via setup/teardown: Layer-2-Tests nutzen travel(InvisibleCaptcha.timestamp_threshold + 1.second) — in System-Tests greift travel aber NICHT verlaesslich, weil Capybara-Puma-Server in einem separaten Thread/Prozess laeuft. Class-Attribut ist thread-shared, das ist der zuverlaessige Weg."
  - "queue_adapter=:inline im setup (analog Plan-04 fuer IntegrationTest+ActionMailer::TestCase): ApplicationSystemTestCase erbt nicht von IntegrationTest, also der Plan-04-test_helper-Patch greift nicht — explizit hier wiederholen."
  - "Polling statt assert_text-wait: assert_text wartet auf DOM-Aenderungen; aber DB-Saves + Job-perform sind ein eigener Async-Pfad. wait_until + wait_for_mail Polling-Helper sind die saubere Bruecke."
  - "Test 3 doppelter visit edit_user_registration_path (im wait_until-Block + danach assert): explizites Polling der Logout-Verzoegerung; falls Server-Save 1-2s braucht, wartet visit-Loop solange. Belt-and-suspenders Pattern."

patterns-established:
  - "Pattern: Field-Selektoren via Input-name in System-Tests fuer Custom-Edit-Views"
  - "Pattern: InvisibleCaptcha.timestamp_threshold-Override im setup fuer System-Tests"
  - "Pattern: wait_for_mail / wait_until Polling-Helper fuer Capybara-Server-Async-Races"

requirements-completed:
  - REQ-41-15   # E2E Sign-up -> Confirmation-Mail-Click -> Logged-in
  - REQ-41-16   # E2E Forgot -> Reset-Mail-Click -> Neues PW -> JTI rotated
  - REQ-41-17   # E2E Change-Password eingeloggt -> Notification-Mail -> Re-Login Pflicht
  - REQ-41-18   # E2E Email-Change -> Reconfirm-Mail an neue Adresse -> Bestaetigen -> email gesetzt

# Metrics
duration: ~40min
completed: 2026-05-16
---

# Phase 41 Plan 05: E2E System-Tests fuer Devise-Flows (D-41-A Layer 4) Summary

**Plan 41-05 Task 1 vollstaendig abgeschlossen: 4 Capybara-System-Tests in `test/system/devise_flows_test.rb` simulieren echte Browser-Flows inkl. Mail-Token-Click-Through fuer alle 4 D-41-D-Flows. D-41-A Test-Pyramide auf Layer 4 vervollstaendigt (28+ neue Tests in Phase 41 total). Task 2 (`checkpoint:human-verify gate="blocking"`) ist Production-Deploy-abhaengig und wird auf Post-Deploy-Verification verschoben.**

## Performance

- **Duration:** ~40 min (inkl. 5-Iteration-Loop fuer Capybara-Async-Race-Fixes)
- **Tasks completed autonomously:** 1 (Task 1)
- **Tasks verified via production-walkthrough:** 1 (Task 2 — Production-Mail-Roundtrip am 2026-05-16 auf carambus_nbv verifiziert)
- **Files created:** 0
- **Files modified:** 1 (`test/system/devise_flows_test.rb` — Skeleton aus Plan-01 mit 4 Tests gefuellt)
- **Tests added:** 4 (Layer 4 E2E)
- **Assertions added:** 24 (6 / 4 / 5 / 6 pro Test ungefaehr — sehr saubere Coverage pro Flow)
- **Test-Runtime:** ~3.4s fuer alle 4 Tests (Selenium-headless Chrome)

## Accomplishments

- **D-41-A Layer 4 (E2E System-Tests) vollstaendig** — alle 4 D-41-D-Flows haben jetzt einen Browser-Driven-Test:
  1. **Sign-up + Confirmation:** `/users/sign_up`-Form -> Devise versendet `confirmation_instructions` -> User klickt extrahierten Link -> `User.confirmed_at` gesetzt + Flash "Your email address has been successfully confirmed."
  2. **Forgot + Reset + JTI-Rotation:** `/password/new` -> Mail -> Click -> `/password/edit` -> neues PW -> `User.jti` rotiert (E2E-Verifikation Plan-03)
  3. **Change-Password + Re-Login-Pflicht:** Eingeloggter User aendert PW -> Folge-Request landet auf `/login` (E2E-Verifikation Plan-04 `sign_in_after_change_password=false`) + JTI rotiert + `password_change`-Notification-Mail versendet
  4. **Email-Change + Reconfirmation:** Eingeloggter User aendert email -> `unconfirmed_email` gesetzt + alte email bleibt -> `confirmation_instructions` an NEUE Adresse -> Click -> `email` springt auf neuen Wert
- **5-Seed-Stabilitaets-Verifikation** — Tests gruen mit Seeds 1, 42, 100, 999, 12345 (jeweils 4 runs / 24 assertions / 0 failures / ~3.4s)
- **Sprachunabhaengige Selektor-Strategie** — Field-Selektoren via `input[name="user[...]"]` statt Label-Text, weil die Custom-Edit-View `app/views/devise/registrations/edit.html.erb` ihre Labels via Locale-Preference-Override in DE rendert (auch bei `?locale=en`). Robust gegen kuenftige Locale-Drifts.
- **Cross-Phase-41 verifiziert** — alle Layer-1+2+3 Tests laufen unveraendert: 54 runs / 171 assertions / 0 failures / 0 errors / 0 skips

## Cumulative Test-Count Phase 41 (4-Layer-Pyramide vollstaendig)

| Layer | Datei | Test-Count | Erstellung |
|-------|-------|-----------:|------------|
| Layer 1 (Model) | `test/models/user_test.rb` (JTI-Section) | 5+ JTI-Tests | Plan-03 |
| Layer 2 (Controller) | `test/controllers/passwords_controller_test.rb` | 7 | Plan-01 + Plan-03 |
| Layer 2 (Controller) | `test/controllers/confirmations_controller_test.rb` | 3 | Plan-01 |
| Layer 2 (Controller) | `test/controllers/registrations_controller_test.rb` | 7 | Plan-02 + Plan-04 |
| Layer 2 (Controller) | `test/controllers/users/registrations_controller_test.rb` | 7 | Plan-01 + Plan-02 |
| Layer 3 (Mailer) | `test/mailers/devise_mailer_test.rb` | 5 | Plan-01 |
| Layer 4 (System E2E) | `test/system/devise_flows_test.rb` | **4 (NEU)** | **Plan-05** |
| Job | `test/jobs/devise_mail_job_test.rb` | 4 | Plan-04 |
| **TOTAL Phase 41** | | **42 neue/erweiterte Tests** | |

(Plan-Vorgabe sagte "28+ neue Tests" — 4-Layer-Pyramide tatsaechlich ~42 Tests; uebererfuellt.)

## Task Commits

| Task | Commit | Type | Subject |
|------|--------|------|---------|
| 1 | `7599445f` | test | E2E System-Tests fuer alle 4 Devise-Flows (Layer 4) |
| 2 | — | checkpoint:human-verify | ✓ verified am 2026-05-16 auf carambus_nbv (siehe Production-Roundtrip-Status unten) |

## Liste der 4 E2E-Tests in test/system/devise_flows_test.rb

### Test 1: "user registers and confirms via email link"
- **Browser-Flow:** visit `/users/sign_up?locale=en` → fill_in {First name, Last name, Email, Password, Password confirmation} → check "I accept the Terms of Service" → click_button "Sign up"
- **Kern-Assertion:** Mail an neue Email-Adresse versendet, Confirmation-URL extrahiert, nach visit der URL `assert_text(/confirmed|bestätigt/i)` + `User.confirmed_at` gesetzt
- **invisible_captcha:** Timestamp-Threshold im setup auf 0 gesetzt (Server-Thread-Race)
- **Async-Wait:** Polling-Loop auf `User.find_by(email:)` weil Form-Submit + Mail-Versand serverseitig parallel laufen

### Test 2: "user resets password via forgot-password email link"
- **Browser-Flow:** visit `/password/new?locale=en` → fill_in email → click_button "Send me reset password instructions" → extrahiere reset_password_url aus Mail → visit URL mit `?locale=en` → fill_in {New password, Confirm new password} → click_button "Change my password"
- **Kern-Assertion:** `User.jti != old_jti` (E2E-Verifikation Plan-03 Hard-Revoke-Callback feuert ueber HTTP+Browser-Pfad bis ins Model)
- **Async-Wait:** `wait_until { user.reload.jti != old_jti }` (Server-Save asynchron zum Capybara-Klick)

### Test 3: "user changes password and is forced to re-login"
- **Browser-Flow:** `sign_in user` (Devise-Test-Helper) → visit `/users/edit?locale=en` → fill_in `user[current_password]` + `user[password]` + `user[password_confirmation]` (name-basiert, locale-unabhaengig) → click_button "Update"
- **Kern-Assertion:** Nach Folge-`visit /users/edit` redirected zu `/login` (E2E-Verifikation Plan-04 `sign_in_after_change_password=false`) + `User.jti` rotiert + 1 `password_change`-Notification-Mail an User
- **Async-Wait:** Polling-Loop `wait_until { ... current_path.match?(%r{/login}) }` weil Server-Save + Session-Cleanup asynchron

### Test 4: "user changes email and confirms via reconfirmation link"
- **Browser-Flow:** `sign_in user` → visit `/users/edit?locale=en` → fill_in `user[email]` mit neuer Adresse + `user[current_password]` → click_button "Update" → extrahiere confirmation_url an NEUE Adresse aus Mail → visit URL
- **Kern-Assertion:** Nach PATCH: `user.unconfirmed_email == new_email` + `user.email == original_email`; nach Confirm-Click: `user.email == new_email` + `user.unconfirmed_email == nil`
- **Async-Wait:** `wait_until { user.reload.unconfirmed_email == new_email }` und nach Confirm-Click `wait_until { user.reload.email == new_email }`

## Production-Roundtrip-Status: VERIFIED am 2026-05-16 (carambus_nbv)

Task 2 (`checkpoint:human-verify gate="blocking"`) wurde am 2026-05-16 erfolgreich auf der nbv-Production-Instanz (https://nbv.carambus.de, Hetzner-Server, Hetzner-IPv6 `2a01:4f8:c17:8ac9::1`) verifiziert. Confirmation-Mail wurde an `marcfoster679@gmail.com` versendet:

```
delivered to=marcfoster679@gmail.com subject=Anleitung zur Bestätigung Ihres Kontos
from=gernot.ullrich@gmail.com
Performed DeviseMailJob in 1148.68ms
```

**Production-Lessons-Learned (Setup-Iteration auf carambus_nbv) — als deferred Items für künftige Scenario-Deploys:**

- **DI-41-P-01 (env-config — nbv-spezifisch):** `production.rb` (in `carambus_data/scenarios/carambus_nbv/production/`) hatte ursprünglich **keinen `smtp_settings`-Block**. Rails-Defaults (`localhost:25`, `user_name: nil`) führten zu `Net::ReadTimeout` nach exakt 5s. Fix: smtp_settings + delivery_method + perform_deliveries + default_options-from-Block aus `production-carambus-de.rb` übernommen, **`read_timeout`/`open_timeout` auf 30s erhöht** (5s war im Async-Job-Thread zu knapp).

- **DI-41-P-02 (env-config — nbv-spezifisch):** `Rails.application.routes.default_url_options[:host]` muss **zusätzlich zu** `config.action_mailer.default_url_options` gesetzt werden — Devise-Mailer-Templates rendern url_helpers via routes-proxy, das die ActionMailer-/Controller-Defaults NICHT zieht. Fehler war `Missing host to link to!` im Mailer-Template (`confirmation_url(...)`-Helper).

- **DI-41-P-03 (puma.service — nbv-spezifisch):** Puma-Systemd-Service braucht `EnvironmentFile=/etc/carambus_nbv.env` für SMTP-Creds (chmod 640, root:www-data). `EnvironmentFile=` wird nur beim Web-Server-Boot gelesen, **NICHT** bei `rake db:migrate` via Capistrano (das war Anlass für den `smtp_guard.rb` Hot-Fix v2 in master 64e4ae2a — Detection via `defined?(Rails::Server)` statt `defined?(::Puma::Server)`, weil Bundler eager-loaded Puma-Klassen immer truthy macht).

- **DI-41-P-04 (Setup-Operations — alle Scenarios):** Hetzner und ähnliche Hoster blocken outbound Port 25/465/587 nicht (entgegen Anfangs-Verdacht — UFW/iptables/Provider-FW war OK). Aber: Gmail-SMTP erfordert App-Password (16-stellig, kein normales Account-Passwort), 2FA muss aktiviert sein.

- **DI-41-P-05 (i18n-Polish — master-weit):** `de.yml` Keys `layouts.mailer.copyright_html`, `mailing_address`, `preferences`, `unsubscribe`, `view_in_browser` waren noch englisch. Fix in master Commit `c18619d2`.

**Asset-Pipeline-Note (kein Phase-41-Issue, nur Setup-Erfahrung):** Erster nbv-Deploy hatte `public/assets/` nicht vorhanden → 500-Error wegen "application.js not present". `FORCE_ASSETS=1` als Capistrano-Envvar erzwingt server-side `assets:precompile`. Carambus-spezifisch, nicht in Phase-41-Scope.

**Master-Code-Hotfixes nach Production-Deploy (im master Branch):**
- `64e4ae2a` smtp_guard v2 (defined?(Rails::Server) statt defined?(::Puma::Server))
- `c18619d2` i18n DE-Layout-Mailer-Texte

**carambus_data Commits (lokal, kein remote):**
- nbv production.rb (mit smtp_settings + Rails.application.routes.default_url_options) — committed nach erfolgreichem Roundtrip
- nbv puma.service (mit EnvironmentFile=/etc/carambus_nbv.env)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Worktree-Setup-Luecke] Gitignored Config-Files (database.yml, carambus.yml, cable.yml) fehlten im Worktree**
- **Found during:** Initial Test-Run (bevor Task 1 startete)
- **Issue:** Identisch zu Plan 41-01..04 Deviations — Worktree-Checkout enthielt nur `.erb`-Templates, Rails-Boot scheiterte mit Errno::ENOENT
- **Fix:** Aus `/Users/gullrich/DEV/carambus/carambus_master/config/` kopiert (gitignored, kein Commit-Bedarf)
- **Files modified:** Keine
- **Committed in:** Nicht committed (Worktree-Recovery)

**2. [Rule 3 - Blocking] MailHelpers-Wiring aus Plan-01 greift in ApplicationSystemTestCase NICHT zuverlaessig**
- **Found during:** Task 1 erste Test-Run (NameError: undefined local variable 'clear_mail_queue')
- **Issue:** test_helper.rb (Plan-01) hat am Ende `require_relative "application_system_test_case" if File.exist?(...)` + `if defined?(ApplicationSystemTestCase); class ASTC; include MailHelpers; end; end`. Wenn aber das Test-File via `require "application_system_test_case"` zuerst geladen wird (Standard-Rails-System-Tests), entsteht ein zirkulaeres Loading: `application_system_test_case.rb` macht selbst `require "test_helper"` (Z.1), test_helper.rb laeuft bis Ende, will `require_relative "application_system_test_case"` ausfuehren — Ruby's `$LOADED_FEATURES` sieht das File als "schon am Laden" und ueberspringt. Dann ist `defined?(ApplicationSystemTestCase)` zwar TRUE (Konstante mit `class` autoset), aber der Body ist noch nicht eval'd. Das `include MailHelpers` greift dann auf eine "leere" Klasse — und der spaeter folgende Body-Eval ueberschreibt nichts (include ist idempotent, aber zu spaet).
- **Fix:** Defensive `include MailHelpers` direkt im DeviseFlowsTest-Klassenbody — idempotent dank Ruby's Module-Tracking, lokal robust ohne Plan-01-Korrekturen anzuruehren
- **Files modified:** `test/system/devise_flows_test.rb`
- **Verification:** Test-Run ohne NameError
- **Committed in:** `7599445f` (Task 1)
- **Hinweis fuer Future:** Plan-01-Pattern koennte sauber gefixt werden durch direktes `include MailHelpers` in `test/application_system_test_case.rb` (statt test_helper.rb-Patch). Out-of-Scope fuer Plan-05.

**3. [Rule 1 - Bug in Plan-prescribed Test-Code] invisible_captcha-Threshold via `travel` greift nicht zuverlaessig in System-Tests**
- **Found during:** Task 1 nach BLOCKER-3-Fix (Test failed mit "Confirmation-Mail muss versendet werden — deliveries.size == 0", obwohl `travel 5.seconds` im Plan-Vorgabe-Code stand)
- **Issue:** Plan-Vorgabe nutzt `travel 5.seconds` analog zu `user_authentication_test.rb`. Aber: In System-Tests laeuft der Capybara-Puma-Server in einem separaten Thread/Prozess vom Test-Prozess. `travel` patcht `Time.now` nur im Test-Prozess — der Server-Thread sieht die echte (nicht-getravelte) Zeit. Die Server-seitige InvisibleCaptcha-Timestamp-Vergleichslogik laeuft also IMMER unter der 4s-Threshold und verwirft den POST.
- **Fix:** Im setup-Block: `InvisibleCaptcha.timestamp_threshold = 0` (Class-Attribute ist thread-shared) + im teardown-Block: Restore. Damit kann der Browser sofort submitten.
- **Files modified:** `test/system/devise_flows_test.rb` (setup + teardown)
- **Verification:** Form-Submit funktioniert, Mail wird versendet
- **Committed in:** `7599445f` (Task 1)
- **Hinweis:** `user_authentication_test.rb#test_user_can_register_with_valid_credentials` (mit `travel 4.seconds`) failed pre-existing mit "Full name"-Feld — falls je gefixed wird, sollte gleiche Threshold-Override-Strategie verwendet werden.

**4. [Rule 3 - Blocking] Capybara-Server-Async-Race: Mail-Polling/DB-Polling noetig**
- **Found during:** Tests 1, 2, 3, 4 (jeweils nach click_button schlug `last_email` / `User.find_by` / `user.reload.jti` fehl)
- **Issue:** Capybara-Selenium-Klick gibt Kontrolle zurueck SOBALD der Browser den Klick gemacht hat; Server-Side-Verarbeitung (DB-Save + Job-Perform + Mail-Versand) laeuft asynchron. Direkter `last_email` / `user.reload` Zugriff im Test-Thread ist Race-anfaellig.
- **Fix:** `wait_for_mail(to:, timeout:)` + `wait_until(timeout:) { block }` Polling-Helper am File-Ende; alle direkt-nach-click Zugriffe auf das Polling-Pattern umgestellt
- **Files modified:** `test/system/devise_flows_test.rb`
- **Verification:** 5 Seeds stabil (1, 42, 100, 999, 12345) — keine Flakes
- **Committed in:** `7599445f` (Task 1)

**5. [Rule 1 - Bug in Plan-prescribed Selektoren] Field-Selektoren via Label-Text scheitern in Custom-Edit-View**
- **Found during:** Test 3 + Test 4 ("Capybara::ElementNotFound: Unable to find field 'Current password'")
- **Issue:** Plan-Vorgabe nutzt `fill_in "Current password"` — die Custom-Edit-View `app/views/devise/registrations/edit.html.erb` rendert aber Labels via `t('.current_password')`-Scope, der durch User-Preferences-Locale ueberschrieben wird. Sogar mit `?locale=en` in der URL erscheinen die Labels in DE ("Aktuelles Passwort", "Neues Passwort"). Capybara findet das Label-Text-Selektor nicht.
- **Fix:** Field-Selektoren via Input-name-Attribut (`fill_in "user[current_password]"` etc.) — sprachunabhaengig, robust gegen Locale-Drifts
- **Files modified:** `test/system/devise_flows_test.rb` (Test 3 + Test 4)
- **Verification:** Beide Tests GREEN
- **Committed in:** `7599445f` (Task 1)

**6. [Rule 1 - Bug in Plan-prescribed Assertion] Test 3 `assert_current_path %r{/users/sign_in}` falsch — IST ist `/login`**
- **Found during:** Test 3 erster Run
- **Issue:** Plan-Vorgabe pruefte `%r{/users/sign_in}`. Carambus nutzt aber Custom-Route-Names (`devise_for :users, path_names: { sign_in: "login" }` in `config/routes.rb`), daher ist die echte Login-URL `/login` (nicht `/users/sign_in`).
- **Fix:** Regex auf `%r{/login}` umgestellt + Polling-Wait drumherum gewickelt (Server-PW-Save + Session-Cleanup asynchron)
- **Files modified:** `test/system/devise_flows_test.rb` (Test 3)
- **Verification:** Test 3 stable ueber 5 Seeds
- **Committed in:** `7599445f` (Task 1)

**7. [Rule 3 - queue_adapter-Override] ApplicationSystemTestCase erbt nicht von IntegrationTest**
- **Found during:** Task 1 Test-Design
- **Issue:** Plan-04 hat queue_adapter=:inline in test_helper.rb fuer IntegrationTest + ActionMailer::TestCase gesetzt. ApplicationSystemTestCase erbt aber von ActionDispatch::SystemTestCase — der Plan-04-Patch greift NICHT. Ohne Override wuerden Devise-Mails nur enqueued, nicht versendet → deliveries.size bleibt 0 → Tests scheitern.
- **Fix:** Im setup-Block: `ActiveJob::Base.queue_adapter = :inline` + im teardown-Block: Restore (analog Plan-04-Pattern in test_helper.rb)
- **Files modified:** `test/system/devise_flows_test.rb`
- **Verification:** Mails werden versendet, Tests GREEN
- **Committed in:** `7599445f` (Task 1)

---

**Total deviations:** 7 (1 Worktree-Recovery, 2 Plan-Wiring-Drifts in 41-01/04, 3 Plan-prescribed Code-Bugs via Rule 1, 1 Plan-Async-Race-Pattern via Rule 3). Alle Auto-Fixes direkt mit Task-Aenderungen verbunden — kein Scope-Creep.

**Impact on plan:**
- Devs #2 + #3 sind die wichtigsten technischen Erkenntnisse: System-Tests haben fundamentale Async-Properties die Layer-2-Tests nicht haben (Capybara-Server-Thread + travel-Stub-Limitation + queue_adapter-Vererbung)
- Dev #5 + #6 sind sprachunabhaengige Robustheits-Verbesserungen (Field-Selektoren + Custom-Route-Names)
- Plan-Drift in Vorgaengern (Plan-01-test_helper-Wiring) wurde lokal ueberbrueckt statt Plan-01 ex-post zu korrigieren — Cross-Plan-Stabilitaet bewahrt

## Pre-existing System-Test-Issue (DI-41-02-01)

`test/system/user_authentication_test.rb` hat pre-existing 4 errors + 1 failure (`Capybara::ElementNotFound: Unable to find field 'Full name'` u.a.). Verifiziert via `git stash` auf base-commit `2e3ede0d` — diese Failures sind **NICHT** durch Plan 41-05 verursacht.

Diese Failures sind seit Plan 41-02 dokumentiert (`deferred-items.md`). Der pre-existing Test sucht ein "Full name"-Feld, das nicht (mehr) im Form ist (Form hat `first_name` + `last_name` separat). Mein neuer Test demonstriert das **korrekte** Pattern: Field-Selektoren via Label oder Input-name, beide getrennt.

**Empfehlung fuer Folge-Plan:** `user_authentication_test.rb` auf `first_name` + `last_name`-Separator + Field-Selektor-Pattern aus Plan-05 umstellen.

## Verbleibende Deferred-Items

- **DI-41-02-01:** Pre-existing `user_authentication_test.rb`-Failures — separater Folge-Plan
- **DI-41-04-01 (doc-only):** Walkthrough-URLs in vergangenen Plan-Docs zeigen Standard-Devise-Pfade; Carambus nutzt Custom-Paths (`/login`, `/password/new`)
- **DI-41-04-02 (env-config):** `lvh.me`-DNS-Resolver-Problem in dev environment — Workaround: `localhost` in Mail-Links, oder `/etc/hosts`-Entry
- **DI-41-04-03 (cleanup):** Plan-41-01-Redundanz `development-carambus.rb` `letter_opener_web` (no-op, nicht schaedlich)
- **Production-Roundtrip-Smoketest (Task 2):** Wartet auf Post-Deploy-Verifikation
- **SPF/DKIM-Setup:** Falls Production-Roundtrip fehlschlaegt, Operations-Task (out-of-scope Phase 41)

## Cross-Repo Sync-Hinweis

Phase 41 ist mit Plan-05 (Task 1 abgeschlossen, Task 2 deferred) komplett funktionsfertig im **carambus_master**. Per `.agents/skills/scenario-management/SKILL.md`-Workflow kann der Master-Stand auf `carambus_phat`, `carambus_api`, `carambus_bcw` deployed werden. Cross-Repo-Vertraeglichkeit ist bereits in Plan-03 dokumentiert: JTI-Rotation greift NUR bei `saved_change_to_encrypted_password?`, also bcw-MCP-JWTs (90 Tage Lifetime) sind nicht betroffen durch Routine-Updates.

## Plan Acceptance Criteria

| Criterion | Status |
|-----------|--------|
| `test/system/devise_flows_test.rb` enthaelt 4 `test "..."`-Blocks | OK |
| Alle 4 System-Tests GREEN (exit 0) | OK |
| Test "user registers and confirms via email link" — visit signup → fill terms → submit → Mail extrahiert → URL navigiert → assert confirmed | OK |
| Test "user resets password" — JTI-Rotation assertet (E2E-Verifikation Plan-03) | OK |
| Test "user changes password and is forced to re-login" — assert_current_path /login (E2E-Verifikation Plan-04) | OK |
| Test "user changes email and confirms via reconfirmation link" — assert email == new_email nach Confirm-Click | OK |
| KEINE Regression in test/system/user_authentication_test.rb (DI-41-02-01 ist pre-existing, nicht durch 41-05 verursacht) | OK (pre-existing dokumentiert) |
| Gesamte System-Test-Laufzeit < 90s | OK (~3.4s) |
| KEIN `extend MailHelpers`-Aufruf im File | OK (defensiver `include MailHelpers` statt extend) |
| `bundle exec standardrb test/system/devise_flows_test.rb` exit 0 | OK |
| KEINE Aenderung an config/routes.rb oder config/initializers/devise.rb | OK |

## Threat Model — Mitigations Status

| Threat ID | Mitigation Plan-05 | Status |
|-----------|---------------------|--------|
| T-41-05-01 (Capybara-Session-Cookies persist zwischen Tests) | ApplicationSystemTestCase-Default-Cleanup; jeder Test startet mit fresh visit | MITIGATED — kein Cross-Test-Cookie-Leak in 5-Seed-Stabilitaet beobachtet |
| T-41-05-02 (Spoofing — Test-Mail-Extraktor liest fremde Mails) | accept (ActionMailer::Base.deliveries Process-local in Tests) | ACCEPTED — out-of-scope |
| T-41-05-03 (Tampering — extract_*_url Regex-Bypass) | accept (Token von Devise generiert) | ACCEPTED — out-of-scope |
| T-41-05-04 (Production-Mail-Receipt nicht nachvollziehbar) | Plan-04 Mail-Observer + Human-Verify-Task-2 | PARTIALLY — Task 2 deferred bis Post-Deploy |

## Threat Flags

Keine zusaetzliche Threat-Surface ueber den Threat-Model im PLAN hinaus.

## Next Phase Readiness

Phase 41 ist mit Plan-05 abschliessbar (Task 1 GREEN, Task 2 als deferred Approval gefuehrt). Empfohlener Folge-Aktion:

1. **Sofort merge-fähig:** Plan-05 Task 1 + alle vorherigen Plans (54/54 Phase-41-Tests gruen)
2. **Post-Deploy:** Task 2 Human-Verify via Production-Smoketest mit echter Gmail-Inbox
3. **Optional Folge-Plan:** Reparatur von `user_authentication_test.rb` (DI-41-02-01) mit Field-Selektor-Pattern aus Plan-05

## Self-Check: PASSED

- `test/system/devise_flows_test.rb` modifiziert (4 Tests + 2 Helper-Methoden + setup/teardown)
- Commit `7599445f` exists (Task 1)
- Alle 4 Tests GREEN (24 Assertions, ~3.4s)
- 5 verschiedene Seeds gepruefe: alle 5 GREEN (Stabilitaet)
- Cross-Phase-41 Verifikation: 54/54 Tests GREEN
- standardrb clean
- Pre-existing DI-41-02-01 dokumentiert (nicht durch 41-05 verursacht — verified via git-stash)

---
*Phase: 41-devise-auth-cluster-ueberarbeitung-registrierung-forgot-pass*
*Plan: 05 — E2E System-Tests fuer Devise-Flows (D-41-A Layer 4)*
*Task 1 + Task 2 vollstaendig abgeschlossen (Task 2 via Production-Walkthrough auf carambus_nbv am 2026-05-16 verifiziert)*
*Completed: 2026-05-16*
