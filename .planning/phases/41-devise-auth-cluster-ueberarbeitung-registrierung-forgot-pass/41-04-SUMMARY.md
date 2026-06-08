---
phase: 41-devise-auth-cluster-ueberarbeitung-registrierung-forgot-pass
plan: 04
subsystem: auth
tags: [devise, smtp-hardening, retry-job, bounce-handling, mail-observer, jti-rotation, sender-alignment]

# Dependency graph
requires:
  - "41-01 (Test-Infra: MailHelpers + Layer-3 Mailer-Tests)"
  - "41-02 (Registrierung + invisible_captcha + i18n)"
  - "41-03 (JTI-Rotation-Callback im User-Modell — Plan-04 Task-1 nutzt ihn fuer Change-Password)"
provides:
  - "config.sign_in_after_change_password = false (D-41-C semantisch durchgesetzt)"
  - "ApplicationMailer.default from: proc { Devise.mailer_sender } (Sender-Angleichung, T-41-04-03)"
  - "config/initializers/smtp_guard.rb (Production-Fail-Fast bei fehlender SMTP-ENV)"
  - "config/initializers/mail_observer.rb (MailDeliveryObserver tagged 'MAILER')"
  - "app/jobs/devise_mail_job.rb (retry_on + discard_on, D-41-B Retry+Bounce-Handling)"
  - "User#send_devise_notification-Override (deliver_later via DeviseMailJob)"
  - "Test-Env queue_adapter=:inline fuer IntegrationTest + ActionMailer::TestCase"
  - "3 Layer-2-Tests Change-Password + Email-Change-Reconfirmation (registrations_controller_test.rb)"
  - "4 Layer-2-Tests DeviseMailJob (enqueue, perform, retry, discard)"
affects: [41-05]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Async Devise-Mail-Versand via Job-Override im User-Modell (statt Controller-Layer)"
    - "Proc statt Lambda fuer ActionMailer default from: — ActionMailer ruft mit Mailer-Instance-Arg auf, Lambda mit strikter Arity wuerde ArgumentError werfen"
    - "Define_singleton_method + ensure-Restore fuer Class-Method-Stubs in Minitest"
    - "queue_adapter=:inline pro Test-Basisklasse fuer Backwards-Compat-Charakterisierung (deliveries.size-Assertions bleiben funktional)"

key-files:
  created:
    - "config/initializers/smtp_guard.rb"
    - "config/initializers/mail_observer.rb"
    - "app/jobs/devise_mail_job.rb"
    - "test/jobs/devise_mail_job_test.rb"
  modified:
    - "config/initializers/devise.rb (sign_in_after_change_password = false)"
    - "app/mailers/application_mailer.rb (default from: proc { Devise.mailer_sender })"
    - "app/models/user.rb (send_devise_notification-Override)"
    - "test/controllers/registrations_controller_test.rb (3 neue Tests Change-PW + Email-Change)"
    - "test/test_helper.rb (queue_adapter=:inline fuer IntegrationTest + ActionMailer::TestCase)"

key-decisions:
  - "Proc statt Lambda fuer ApplicationMailer.default from: — ActionMailer-Internals rufen Default-Block mit Mailer-Instance-Arg auf (siehe Test-Logs: ArgumentError 'wrong number of arguments given 1, expected 0' bei Lambda). Proc verwirft das Arg, Lambda nicht."
  - "queue_adapter=:inline fuer Integration+Mailer-TestCase statt Plan-01/02/03 Tests umzuschreiben — minimal-invasiv, alle vorhandenen deliveries-Assertions bleiben gueltig. DeviseMailJobTest behaelt :test-Adapter via ActiveJob::TestCase."
  - "Rails 7.2: :polynomially_longer statt deprecated :exponentially_longer in retry_on"
  - "send_devise_notification public (nicht private) — Devise's send_devise_notification ist im Default public, wird via .send aus authenticatable.rb aufgerufen. Beibehaltung der Sichtbarkeit verhindert NoMethodError-Risiko bei Devise-Internals"
  - "devise_mailer-Aufruf als Instance-Method (nicht self.class.devise_mailer) — Devise definiert devise_mailer als Instance-Helper auf authenticatable; self.class.devise_mailer existiert nicht"

patterns-established:
  - "Pattern: Async-Mail-Versand via Job-Override im Modell statt Controller — greift bei JEDEM Pfad (Devise-Controller, Admin-Update, Console)"
  - "Pattern: Bounce-Handling im discard_on-Block mit tagged Logging — Audit-Trail im production.log"
  - "Pattern: Class-Method-Stub via define_singleton_method + ensure-Restore (Minitest-stable, ohne Mock-Gem)"

requirements-completed:
  - REQ-41-10   # Change-Password-Flow getestet (PATCH /users mit current_password+password rotiert PW + JTI + sendet Notification)
  - REQ-41-11   # sign_in_after_change_password=false durchgesetzt
  - REQ-41-12   # Mail-Sender vereinheitlicht (Devise.mailer_sender = ApplicationMailer.default_from)
  - REQ-41-13   # SMTP-Haertung (Fail-Fast + Observer + Retry + Bounce)
  - REQ-41-14   # Email-Change Reconfirmation getestet (PATCH /users mit email)

# Metrics
duration: ~30min
completed: 2026-05-16
---

# Phase 41 Plan 04: SMTP-Haertung + Change-Password + Sender-Angleichung Summary

**Plan 41-04 deckt die letzten drei D-41-* Themen ab: D-41-C semantisch durchgesetzt (User-Re-Login Pflicht nach PW-Change), D-41-B vollstaendig (Fail-Fast + Observer + Retry-Job + Bounce-Handling), Sender-Angleichung gegen SPF/DKIM-Mismatch. Tasks 1+2 vollstaendig autonom abgeschlossen mit 54 Phase-41-Tests gruen. Task 3 ist `checkpoint:human-verify` und wartet auf User-Walkthrough im Dev-Browser (letter_opener_web Mailbox + PW-Change-Logout + Production-Boot-Fail-Fast).**

## Performance

- **Duration:** ~30 min (Tasks 1+2 autonom) + ~15 min User-Walkthrough (Task 3)
- **Started:** 2026-05-16T01:36:00Z
- **Tasks completed autonomously:** 2 (Task 1 + Task 2)
- **Tasks verified via human-walkthrough:** 1 (Task 3, am 2026-05-16 verified)
- **Files created:** 4 (smtp_guard.rb + mail_observer.rb + devise_mail_job.rb + devise_mail_job_test.rb)
- **Files modified:** 5 (devise.rb + application_mailer.rb + user.rb + registrations_controller_test.rb + test_helper.rb)
- **Tests added:** 7 (3 Layer-2 Registration + 4 Layer-2 Job)
- **Assertions added:** ~18

## Accomplishments

- **D-41-C Hard-Revoke semantisch durchgesetzt** — PW-Change rotiert weiterhin JTI (Plan-03-Callback) UND meldet jetzt zusaetzlich die aktuelle Session ab (sign_in_after_change_password=false). User muss auf allen Geraeten neu einloggen.
- **Sender-Diskrepanz behoben (T-41-04-03)** — ApplicationMailer.default_from + Devise.mailer_sender = identisch (`Devise.mailer_sender = ENV["SMTP_USERNAME"] || "no-reply@carambus.de"`). Proc-Wrapper statt Lambda noetig wegen ActionMailer-Internals (Mailer-Instance-Arg).
- **SMTP-Haertung vollstaendig (D-41-B Wortlaut-Anforderungen):**
  - "Sender-Verifizierung (Fail-Fast in Production)" — smtp_guard.rb raises bei fehlender SMTP-ENV
  - "Strukturiertes Logging jedes Mail-Versuchs" — MailDeliveryObserver tagged 'MAILER' (Success + Failure)
  - "Retry-Logik bei SMTP-Fehlern (transient vs. permanent)" — DeviseMailJob.retry_on Net::SMTPAuthenticationError (3 Attempts) + Net::SMTPServerBusy (5 Attempts)
  - "Bounce-Handling-Strategie (mindestens Error-Trapping)" — DeviseMailJob.discard_on Net::SMTPFatalError mit Block + tagged Logging
- **D-41-D Flow 3 (Change-Password) Layer-2-getestet** — End-to-End-Integration: PATCH /users mit current_password+password rotiert encrypted_password + jti + sendet password_change-Notification an User
- **D-41-D Flow 4 (Email-Change-Reconfirmation) Layer-2-getestet** — PATCH /users mit email triggert reconfirmation: unconfirmed_email gesetzt, alte email bleibt, confirmation_instructions an NEUE Adresse
- **Async Mail-Versand via DeviseMailJob** — alle Devise-Mails laufen jetzt deliver_later. User-Request wird nicht mehr durch SMTP blockiert. Fehler in Mail-Versand crashen Request nicht.

## Test-Count

| Datei | Test-Count vorher | Test-Count nachher | Pass/Fail | Runtime |
|-------|------------------:|-------------------:|-----------|--------:|
| `test/controllers/registrations_controller_test.rb` | 4 | 7 (+3) | 7 pass | ~0.4s |
| `test/jobs/devise_mail_job_test.rb` (NEU) | 0 | 4 (+4) | 4 pass | ~0.2s |
| `test/mailers/devise_mailer_test.rb` (unveraendert) | 5 | 5 | 5 pass | ~0.3s |
| `test/controllers/passwords_controller_test.rb` (unveraendert) | 7 | 7 | 7 pass | ~0.4s |
| `test/controllers/confirmations_controller_test.rb` (unveraendert) | 3 | 3 | 3 pass | ~0.1s |
| `test/controllers/users/registrations_controller_test.rb` (unveraendert) | 7 | 7 | 7 pass | ~0.4s |
| `test/models/user_test.rb` (unveraendert) | 21 | 21 | 21 pass | ~0.3s |
| **Total Phase-41** | **47** | **54 (+7)** | **54 pass / 0 fail** | **~0.87s** |

## Task Commits

Each completed task committed atomically (`--no-verify`, parallel-executor):

| Task | Commit | Type | Subject |
|------|--------|------|---------|
| 1 | `d92b702b` | feat | Change-Password + Email-Change + Sender-Angleichung (Task 1) |
| 2 | `2e3ede0d` | feat | SMTP-Haertung — Fail-Fast-Guard + Mail-Observer + DeviseMailJob (Task 2) |
| 3 | — | checkpoint:human-verify | ✓ verified am 2026-05-16 (User-Walkthrough im nbv-Scenario) |

## Initializers + Job + Mailer Diff

### Created (4)

| File | Purpose | Lines | Key-Markers |
|------|---------|------:|-------------|
| `config/initializers/smtp_guard.rb` | Fail-Fast bei SMTP-ENV-Fehlend in Production | 27 | `if Rails.env.production?` + `raise` |
| `config/initializers/mail_observer.rb` | MailDeliveryObserver tagged 'MAILER' (Success+Failure) | 42 | `register_observer(MailDeliveryObserver)` + `delivered_email` + `delivery_failed` |
| `app/jobs/devise_mail_job.rb` | Async Devise-Mail-Job mit Retry+Bounce | 40 | `retry_on Net::SMTPAuthenticationError` + `retry_on Net::SMTPServerBusy` + `discard_on Net::SMTPFatalError` |
| `test/jobs/devise_mail_job_test.rb` | 4 Layer-2-Tests fuer Job-Verhalten | 78 | `ActiveJob::TestCase` + `assert_enqueued_with` + `perform_enqueued_jobs` |

### Modified (5)

| File | Change | Verifikation |
|------|--------|--------------|
| `config/initializers/devise.rb` | `config.sign_in_after_change_password = false` (Zeile 331 ersetzt) | `grep -c "sign_in_after_change_password = false"` == 1 |
| `app/mailers/application_mailer.rb` | `default from: proc { Devise.mailer_sender }` (statt support_email) | `grep -c "Devise.mailer_sender"` == 2 (Code + Kommentar) |
| `app/models/user.rb` | `send_devise_notification`-Override → DeviseMailJob.perform_later | `grep -c "DeviseMailJob.perform_later"` == 1 |
| `test/controllers/registrations_controller_test.rb` | 3 Layer-2-Tests Change-PW + Email-Change am File-Ende | 7 Tests, 36 Assertions |
| `test/test_helper.rb` | queue_adapter=:inline fuer IntegrationTest + ActionMailer::TestCase | `grep -c "queue_adapter = :inline"` == 2 |

## DeviseMailJob — Retry+Bounce-Verhalten

| Fehler-Klasse | Disposition | Attempts | Backoff |
|---------------|-------------|---------:|---------|
| `Net::SMTPAuthenticationError` | retry | 3 | `:polynomially_longer` |
| `Net::SMTPServerBusy` | retry | 5 | `:polynomially_longer` |
| `Net::SMTPFatalError` | discard | 1 | n/a (mit Logging-Block) |
| (Alle anderen) | bubble up | 1 | n/a (Standard ActiveJob-Verhalten) |

Rails 7.2: `:polynomially_longer` ist der neue Backoff-Name. `:exponentially_longer` ist deprecated (DeprecationWarning beim Boot).

## Decisions Made

### Proc statt Lambda fuer `ApplicationMailer.default from:`

**Discovery during Task 1 GREEN-Phase:** Lambda `-> { Devise.mailer_sender }` fuehrte zu `ArgumentError: wrong number of arguments (given 1, expected 0)` in ALLEN ActionMailer-Aufrufen. ActionMailer ruft `default`-Blocks mit dem Mailer-Instance als Arg auf (siehe `actionmailer-7.2.2.2/lib/action_mailer/base.rb#default_value_for`). Lambda mit strikter Arity-Pruefung scheitert; Proc verwirft das Arg. **Fix:** `proc { Devise.mailer_sender }`.

### queue_adapter=:inline fuer IntegrationTest + ActionMailer::TestCase

**Trade-off Analysis:** User#send_devise_notification-Override queued ueber DeviseMailJob — vorher synchron via deliver_now. Plan-01/02/03-Tests pruefen `ActionMailer::Base.deliveries.size` direkt nach POST/PATCH — wuerden mit `:test`-Adapter brechen (Job enqueued, nicht executed).

**Option A:** Alle 9 Plan-01/02/03-Tests mit `perform_enqueued_jobs`-Wrapper umbauen — invasiv.
**Option B (gewaehlt):** queue_adapter=:inline pro Test-Basisklasse in test_helper.rb. Sauber, minimal-invasiv, Charakterisierung bleibt gueltig (deliveries.size pinnt das Verhalten was im Production-Job-Worker passiert).

DeviseMailJobTest selbst nutzt `ActiveJob::TestCase`, das bringt `:test`-Adapter mit + `assert_enqueued_with` funktioniert.

### send_devise_notification: public statt private

Devise's Default-`send_devise_notification` ist im Default **public** (siehe `devise-4.9.4/lib/devise/models/authenticatable.rb`). Devise ruft die Methode via `send` aus internen Hooks auf — Sichtbarkeit irrelevant fuer Devise-Aufrufer, aber ein `private`-Marker koennte bei Future-Devise-Updates oder Reflection-API-Aenderungen brechen. Beibehaltung der public-Visibility ist Risk-Minimization.

### devise_mailer-Aufruf als Instance-Method

Plan-Vorgabe schlug `self.class.devise_mailer.name` vor — `devise_mailer` ist aber Instance-Helper in `authenticatable.rb`. `self.class.devise_mailer` wirft `NoMethodError` (Discovery in Task 2 RED-Phase). Fix: `devise_mailer.name` (Instance-Aufruf).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug in plan-prescribed code] Lambda `-> { Devise.mailer_sender }` wirft ArgumentError**
- **Found during:** Task 1 GREEN-Phase (alle bestehenden Tests scheiterten mit `wrong number of arguments (given 1, expected 0)` aus `app/mailers/application_mailer.rb:9`)
- **Issue:** Plan-Vorgabe sagt `default from: -> { Devise.mailer_sender }`. ActionMailer ruft Default-Blocks mit Mailer-Instance-Arg auf — Lambda mit strikter Arity-Pruefung scheitert.
- **Fix:** `proc { Devise.mailer_sender }` (Proc verwirft das Arg)
- **Files modified:** `app/mailers/application_mailer.rb`
- **Verification:** Alle Tests GREEN nach Fix
- **Committed in:** `d92b702b` (Task 1)

**2. [Rule 1 - Bug in plan-prescribed code] devise_mailer ist Instance-Method, nicht Class-Method**
- **Found during:** Task 2 GREEN-Phase (4/4 Job-Tests scheiterten mit `NoMethodError: undefined method 'devise_mailer' for User:Class`)
- **Issue:** Plan-Vorgabe sagt `devise_mailer_class = self.class.devise_mailer.name`. `devise_mailer` ist aber in Devise's `authenticatable.rb` als Instance-Helper definiert.
- **Fix:** `devise_mailer_class = devise_mailer.name` (Instance-Aufruf)
- **Files modified:** `app/models/user.rb`
- **Verification:** Alle 4 Job-Tests GREEN nach Fix
- **Committed in:** `2e3ede0d` (Task 2)

**3. [Rule 3 - Blocking] User#send_devise_notification-Override bricht Plan-01/02/03-Tests (queue_adapter-Issue)**
- **Found during:** Task 2 nach Override-Aktivierung
- **Issue:** Plan-01/02/03 hatten 9 Tests die `deliveries.size` direkt nach POST/PATCH inspizieren. Mit Override + Default-`:test`-Adapter werden Jobs nur enqueued, nicht executed → deliveries.size bleibt 0.
- **Fix:** test_helper.rb-Erweiterung: `queue_adapter = :inline` pro setup/teardown fuer IntegrationTest + ActionMailer::TestCase. DeviseMailJobTest erbt von ActiveJob::TestCase, bleibt mit :test-Adapter.
- **Files modified:** `test/test_helper.rb`
- **Verification:** 54/54 Tests GREEN
- **Committed in:** `2e3ede0d` (Task 2)

**4. [Rule 1 - Deprecated API] `:exponentially_longer` deprecated in Rails 7.2**
- **Found during:** Task 2 Implementation (Plan-Vorgabe nutzt deprecated Wert)
- **Issue:** Plan-Vorgabe nutzt `wait: :exponentially_longer` — Rails 7.1+ deprecated, Rails 7.2 fuehrt `:polynomially_longer` als Ersatz ein. Plan-04-Konvention: keine Deprecation-Warnings im Production-Log.
- **Fix:** Beide `retry_on`-Aufrufe nutzen `:polynomially_longer`
- **Files modified:** `app/jobs/devise_mail_job.rb`
- **Committed in:** `2e3ede0d` (Task 2)

**5. [Rule 3 - Worktree-Setup-Luecke] Gitignored Config-Files (database.yml, carambus.yml, cable.yml)**
- **Found during:** Initial Setup (analog Plan 41-01/02/03)
- **Issue:** Worktree-Checkout enthielt nur `.erb`-Templates
- **Fix:** Aus `/Users/gullrich/DEV/carambus/carambus_master/config/` kopiert (gitignored)
- **Files modified:** Keine (gitignored)
- **Committed in:** Nicht committed

**6. [Information] Worktree-Setup hatte keine production-Sektion in database.yml**
- **Found during:** smtp_guard-Verifikation via `RAILS_ENV=production bin/rails runner`
- **Issue:** Worktree's database.yml fehlt `production:`-Sektion → AdapterNotSpecified-Error vor smtp_guard.rb geladen wird. Smtp_guard-Logik selbst ist korrekt; in echter Production-Umgebung mit korrekter DB-Config greift smtp_guard wie erwartet.
- **Verifikation:** Isolated-Test via `load Rails.root.join("config/initializers/smtp_guard.rb")` mit `Rails.env = "production"` → raises wie erwartet mit Message "FATAL: SMTP-ENV nicht gesetzt — Devise-Mails wuerden Production-Boot brechen."
- **Files modified:** Keine
- **Action:** In Production-Deploy nochmal verifizieren (Plan-05 System-Tests koennten Production-Boot in CI durchspielen mit Test-DB-Override)

---

**Total deviations:** 6 (2 Plan-prescribed Code-Bugs via Rule 1, 1 Blocking Test-Inkompatibilitaet via Rule 3, 1 Deprecated-API via Rule 1, 1 Worktree-Recovery via Rule 3, 1 Information-only Verifikations-Limit). Alle Auto-Fixes direkt mit Task-Aenderungen verbunden — kein Scope-Creep.

**Impact on plan:**
- Rule-1-Fix #1 (Proc statt Lambda) ist plan-prescribed-Bug, ohne den Fix wuerde **kein einziger Mailer-getriggerter Request** funktionieren — kritisch fuer Rest der Phase
- Rule-1-Fix #2 (devise_mailer als Instance) ist plan-prescribed-Bug, wuerde User#send_devise_notification crash machen
- Rule-3-Fix #3 (queue_adapter=:inline) ist die wichtigste Architektur-Entscheidung — beweist dass der Plan-04-Mail-Versand-Override Backward-Compat mit Plan-01/02/03-Tests behaelt
- Rule-1-Fix #4 (Polynomially-Longer) ist proaktiv — verhindert Deprecation-Warnings in production.log

## Plan Acceptance Criteria

| Criterion | Status |
|-----------|--------|
| `grep -c "config.sign_in_after_change_password = false" config/initializers/devise.rb` == 1 | OK |
| `grep -c "Devise.mailer_sender" app/mailers/application_mailer.rb` >= 1 | OK (=2) |
| `config/initializers/smtp_guard.rb` existiert, enthaelt `Rails.env.production?` + `raise` | OK |
| `config/initializers/mail_observer.rb` existiert, enthaelt `register_observer(MailDeliveryObserver)` + `delivery_failed`-Hook | OK |
| `app/jobs/devise_mail_job.rb` existiert, enthaelt `retry_on Net::SMTPAuthenticationError` + `retry_on Net::SMTPServerBusy` + `discard_on Net::SMTPFatalError` | OK |
| `grep -c "DeviseMailJob.perform_later" app/models/user.rb` >= 1 | OK (=1) |
| 3 neue Tests in registrations_controller_test.rb GREEN | OK |
| `bin/rails test test/jobs/devise_mail_job_test.rb` exit 0 — 4 Job-Tests GREEN | OK |
| `bin/rails runner 'puts MailDeliveryObserver.name'` exit 0 + Output "MailDeliveryObserver" | OK |
| `bin/rails runner 'puts DeviseMailJob.name'` exit 0 + Output "DeviseMailJob" | OK |
| smtp_guard raises in production-env ohne SMTP-ENV | OK (isolated-Test, Worktree-Production-Boot-Issue separat) |
| `bundle exec standardrb` exit 0 fuer alle Plan-04-Files | OK |
| KEINE Regression in Phase-41-Tests | OK (54/54 GREEN inkl. Plan-01/02/03-Tests) |

## Threat Model — Mitigations Status

| Threat ID | Mitigation Plan-04 | Status |
|-----------|---------------------|--------|
| T-41-04-01 (Session-Hijacking nach PW-Change) | sign_in_after_change_password=false + JTI-Rotation (Plan-03) | MITIGATED — Test "Nach PATCH /users nicht mehr eingeloggt" gepinnt |
| T-41-04-02 (SMTP-Credential-Leak via Logs) | Observer loggt nur subject+to+from, kein Body/Token | MITIGATED — Observer-Implementation enthaelt KEIN message.body/token |
| T-41-04-03 (Sender-Spoofing SPF/DKIM-Mismatch) | ApplicationMailer.default = Devise.mailer_sender (identisch zu ENV["SMTP_USERNAME"]) | MITIGATED |
| T-41-04-04 (DoS Production-Boot kaputter SMTP-Config) | smtp_guard raises FATAL bei fehlender ENV | MITIGATED — Isolated-Test bestaetigt |
| T-41-04-05 (Email-Change ohne Reconfirmation) | reconfirmable=true bleibt aktiv | MITIGATED — Test "PATCH /users mit neuer email" gepinnt |
| T-41-04-06 (Repudiation Mail-Delivery-Status) | MailDeliveryObserver tagged 'MAILER' | MITIGATED — Observer.delivered_email + .delivery_failed-Hooks aktiv |
| T-41-04-07 (Mail-Loss bei transienten SMTP-Errors) | DeviseMailJob.retry_on (3/5 Attempts, polynomially_longer) | MITIGATED — Test "retry_on Net::SMTPAuthenticationError: 3 Attempts" gepinnt |
| T-41-04-08 (Mail-Loss bei permanenten Bounces) | DeviseMailJob.discard_on Net::SMTPFatalError + Logging | MITIGATED — Test "discard_on Net::SMTPFatalError: kein Crash" gepinnt |

## Threat Flags

Keine zusaetzliche Threat-Surface ueber den Threat-Model im PLAN hinaus. Alle 8 Threats sind dokumentiert + Mitigations gepinnt.

## Task 3 — Human-Verify VERIFIED (2026-05-16)

Task 3 (`checkpoint:human-verify gate="blocking"`) wurde am 2026-05-16 vom User im carambus_nbv-Scenario verifiziert. Plan-04 hat alle vier Lieferpunkte erfüllt:

1. config.sign_in_after_change_password = false (Devise-Config) ✓
2. ApplicationMailer.default_from = Devise.mailer_sender (Sender-Angleichung via Proc) ✓
3. SMTP-Guard + Mail-Observer-Initializers ✓
4. DeviseMailJob (Retry + Bounce-Handling) + User#send_devise_notification-Override ✓

**Walkthrough-Ergebnis (alle Schritte im carambus_nbv-Scenario, Port 3301):**

| # | Schritt | Status |
|---|---------|--------|
| 1 | `bin/rails server -p 3301` | ✓ |
| 2 | `http://localhost:3301/letter_opener` leer | ✓ |
| 3 | `/users/sign_up` mit Terms-Checkbox + Honeypot | ✓ |
| 4 | Sign-Up → Submit | ✓ |
| 5 | Confirmation-Mail in `/letter_opener` | ✓ |
| 6 | `/password/new` Forgot-PW-Form | ✓ (URL: `/password/new`, nicht `/users/password/new`) |
| 7 | `/users/edit` PW-Change → Redirect zu Login + Notification | ✓ |
| 8 | SMTP-Guard Production-Fail-Fast | ✓ (`RuntimeError: FATAL: SMTP-ENV` an `smtp_guard.rb:17`) |
| 9 | `DeviseMailJob.new.class.name` | ✓ |

**Walkthrough-Findings → Deferred Items (für spätere Phasen):**

- **DI-41-04-01 (doc-only):** Plan-04 + Plan-01 Walkthrough-URLs zeigen Standard-Devise-Pfade (`/users/password/new`, `/users/sign_in`). Carambus-Routes verwenden custom Paths (`/password/new`, `/login`). Keine Code-Änderung nötig — nur Walkthrough-Dokumentation für künftige Phasen aktualisieren.
- **DI-41-04-02 (env-config):** `config/environments/development.rb` setzt Mail-Default-URL-Host auf `lvh.me`. Bei DNS-Resolver-Problemen (z.B. macOS-DNS-Cache, ISP-Filter) löst `lvh.me` nicht zu 127.0.0.1 auf → Mail-Links unreachable. Workaround: `localhost` in URL ersetzen, oder `127.0.0.1 lvh.me` in `/etc/hosts`. Out-of-Scope für Phase 41.
- **DI-41-04-03 (cleanup):** Plan-41-01 hat `letter_opener_web` redundant in `development-carambus.rb:33` aktiviert, obwohl `development.rb:113` es bereits hat. `development-carambus.rb` ist im NBV-Scenario nicht das aktive Environment-File (Standard ist `RAILS_ENV=development` → `development.rb`). Plan-01-Änderung ist no-op aber nicht schädlich.

**Resume-Signal:** "hat funktioniert" (2026-05-16, User-Approval) — Task 3 als verified geschlossen.

## Open Items for Plan 05

- **System-Tests (D-41-A Layer 4):** Plan-05 fuellt `test/system/devise_flows_test.rb`-Skeleton. Mit deliver_later-Pfad muss System-Test ggf. `perform_enqueued_jobs` wrappen oder ApplicationSystemTestCase ebenfalls auf `:inline`-Adapter setzen (test_helper.rb-Pattern aus Plan-04 wiederverwendbar).
- **DI-41-02-01 (System-Test "Full name"-Field):** Pre-existing Bug aus Plan-02 deferred-items.md. Plan-05 muss das wahrscheinlich beheben oder Test umbauen.

## Self-Check: PASSED

- `config/initializers/smtp_guard.rb` exists with `Rails.env.production?` + `raise`
- `config/initializers/mail_observer.rb` exists with `register_observer` + `delivery_failed`
- `app/jobs/devise_mail_job.rb` exists with `retry_on` (2x) + `discard_on`
- `test/jobs/devise_mail_job_test.rb` exists with 4 Tests
- `app/mailers/application_mailer.rb` modified — `proc { Devise.mailer_sender }`
- `app/models/user.rb` modified — `send_devise_notification` queued ueber DeviseMailJob
- `config/initializers/devise.rb` modified — `sign_in_after_change_password = false`
- `test/controllers/registrations_controller_test.rb` modified — 3 neue Layer-2-Tests
- `test/test_helper.rb` modified — queue_adapter=:inline fuer IntegrationTest + ActionMailer::TestCase
- Commit `d92b702b` exists (Task 1)
- Commit `2e3ede0d` exists (Task 2)
- 54/54 Phase-41-Tests GREEN (0 failures, 0 errors, 0 skips)
- standardrb clean fuer alle Plan-04-Files
- Plan-prescribed Acceptance-Criteria erfuellt (mit dokumentierten Bug-Fixes wo Plan != IST)

---
*Phase: 41-devise-auth-cluster-ueberarbeitung-registrierung-forgot-pass*
*Plan: 04 — SMTP-Haertung + Change-Password + Sender-Angleichung*
*Tasks 1+2 autonom abgeschlossen, Task 3 via User-Walkthrough verified*
*Completed: 2026-05-16*
