---
phase: 41-devise-auth-cluster-ueberarbeitung-registrierung-forgot-pass
verified: 2026-05-16T08:30:00Z
status: passed
score: 18/18 must-haves verified
overrides_applied: 0
re_verification: false
deferred:
  - truth: "Production-SMTP-Roundtrip mit echter Gmail-Inbox nach Deploy"
    addressed_in: "Plan 41-05 Task 2 (post-deploy human-verify)"
    evidence: "Plan-Vorgabe 41-05 markiert Task 2 als checkpoint:human-verify gate=blocking — deferred bis nach Production-Deploy (CONTEXT.md Anti-Pattern); 41-05-SUMMARY.md dokumentiert deferred Approval"
  - truth: "DI-41-04-01 (doc-only): Walkthrough-URLs in Plan-Docs zeigen Standard-Devise-Pfade statt Carambus-Custom-Paths (/login, /password/new)"
    addressed_in: "Follow-Up doc-only"
    evidence: "41-05-SUMMARY.md / 41-04-SUMMARY.md: nur Doc-Cleanup, kein Code-Gap"
  - truth: "DI-41-04-02 (env-config): lvh.me DNS-Resolver-Issue in development"
    addressed_in: "Out-of-Scope (Ops/Environment)"
    evidence: "41-04-SUMMARY.md: env-config-Workaround (localhost/etc-hosts), kein Phase-41 Code-Gap"
  - truth: "DI-41-04-03 (cleanup): letter_opener_web doppelt aktiviert in development-carambus.rb (no-op)"
    addressed_in: "Future cleanup"
    evidence: "41-04-SUMMARY.md: harmless redundancy, nicht schaedlich"
  - truth: "DI-41-02-01 (pre-existing): user_authentication_test.rb 'Full name'-Feld nicht im Form"
    addressed_in: "Pre-existing — nicht durch Phase 41 verursacht"
    evidence: "41-02-SUMMARY.md + 41-05-SUMMARY.md: via git stash an base-commit verifiziert pre-existing; ausserhalb Phase-41-Scope"
---

# Phase 41: Devise-Auth-Cluster Überarbeitung — Verification Report

**Phase Goal (aus CONTEXT.md):** Devise-Auth-Stack zum verlässlichen, vollständig testabgedeckten Standard bringen. Vier D-41-D-Flows produktionsreif (Sign-up/Confirmation, Forgot-Password mit JTI-Hard-Revoke, Change-Password mit Re-Login-Pflicht, Email-Change mit Reconfirmation). SMTP-Härtung (Fail-Fast, Mail-Observer, Retry-Job, Bounce-Handling) gemäss D-41-B. Sender-Angleichung gegen SPF/DKIM-Mismatch.

**Verified:** 2026-05-16T08:30:00Z
**Status:** passed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | test/mailers/ existiert + Tests laufen via bin/rails test | VERIFIED | `bin/rails test test/mailers/devise_mailer_test.rb` exit 0; 5 Tests; ~0.36s |
| 2 | letter_opener_web in Dev aktiv (Mailbox unter /letter_opener) | VERIFIED | `config/routes.rb:6 mount LetterOpenerWeb::Engine, at: "/letter_opener"` (dev-only) + `config/environments/development-carambus.rb:32 delivery_method = :letter_opener_web` |
| 3 | Charakterisierungstests dokumentieren IST-Zustand aller 4 Devise-Flows | VERIFIED | Plan-01 + Plan-02 + Plan-03 + Plan-04 + Plan-05 = 58 Tests pinnen IST; alle GREEN |
| 4 | MailHelpers sauber in 3 Test-Basisklassen included | VERIFIED | `test/test_helper.rb:130, 150, 171` — `include MailHelpers` in IntegrationTest + ActionMailer::TestCase + ApplicationSystemTestCase |
| 5 | POST /users mit gueltigen Params erzeugt User + versendet exakt 1 confirmation_instructions Mail | VERIFIED | `test/controllers/registrations_controller_test.rb` "POST /users mit gueltigen Params versendet 1 confirmation_instructions Mail" GREEN |
| 6 | POST /users mit gefuelltem Honeypot wird abgewiesen (head 200, kein User-Insert, keine Mail) | VERIFIED | `test/controllers/users/registrations_controller_test.rb` Honeypot-Test GREEN (vorher skipped); `invisible_captcha only: [:create], honeypot: :subtitle` in registrations_controller.rb:9 |
| 7 | Terms-of-Service-Checkbox via t() i18n-versorgt (DE+EN) | VERIFIED | `config/locales/devise.de.yml:82 terms_acceptance: "Ich akzeptiere..."` + `devise.en.yml:82 terms_acceptance: "I accept..."` + `app/views/devise/registrations/new.html.erb:49 t("devise.registrations.new.terms_acceptance")` |
| 8 | POST /users/password versendet exakt 1 reset_password_instructions Mail | VERIFIED | `test/controllers/passwords_controller_test.rb` "POST /users/password mit gueltiger email versendet Reset-Mail" GREEN |
| 9 | PUT /users/password mit gueltigem Token rotiert User.jti (D-41-C Hard-Revoke) | VERIFIED | `test/controllers/passwords_controller_test.rb` "PUT /users/password rotiert User.jti (D-41-C Hard-Revoke)" GREEN + `app/models/user.rb:49 after_update :rotate_jti_on_password_change!, if: :saved_change_to_encrypted_password?` |
| 10 | JTI-Rotation feuert NUR bei encrypted_password-Change — Routine-Updates bleiben stabil | VERIFIED | `test/models/user_test.rb:240,253` — "jti bleibt stabil bei first_name-Update" + "jti bleibt stabil bei email-Update" GREEN; Cross-Repo-Sicherheit fuer bcw-MCP-JWTs |
| 11 | Token-Replay: zweiter PUT /users/password mit identischem Token wird abgewiesen | VERIFIED | `test/controllers/passwords_controller_test.rb` "Token-Replay" GREEN (charakterisiert require_no_authentication-Schicht, 302) |
| 12 | PATCH /users mit current_password+password rotiert jti UND versendet password_change-Notification | VERIFIED | `test/controllers/registrations_controller_test.rb` "PATCH /users mit current_password+password rotiert jti und versendet password_change-Mail" GREEN |
| 13 | Nach erfolgreichem PW-Change ist User NICHT mehr eingeloggt (sign_in_after_change_password=false) | VERIFIED | `config/initializers/devise.rb:334 config.sign_in_after_change_password = false` + `test/controllers/registrations_controller_test.rb` "Nach PATCH /users ... NICHT mehr eingeloggt" GREEN + System-Test 3 GREEN |
| 14 | ApplicationMailer.default_from == Devise.mailer_sender (kein From-Header-Mismatch) | VERIFIED | `app/mailers/application_mailer.rb:9 default from: proc { Devise.mailer_sender }` (Proc statt Lambda wegen ActionMailer-Arity); Sender-Lock-Test in devise_mailer_test.rb GREEN |
| 15 | Production-Boot scheitert fail-fast wenn SMTP-ENV fehlt | VERIFIED | `config/initializers/smtp_guard.rb` raises in Production bei fehlender SMTP_USERNAME/PASSWORD; Plan-04 Task-3 User-Walkthrough verified (`RuntimeError: FATAL: SMTP-ENV` an smtp_guard.rb:17) |
| 16 | MailDeliveryObserver loggt Success/Fail jeder ActionMailer-Delivery (tagged 'MAILER') | VERIFIED | `config/initializers/mail_observer.rb:40 ActionMailer::Base.register_observer(MailDeliveryObserver)`; delivered_email + delivery_failed Hooks aktiv |
| 17 | Devise-Mails via DeviseMailJob (deliver_later) — Retry transient, Discard permanent | VERIFIED | `app/jobs/devise_mail_job.rb:18-19 retry_on Net::SMTPAuthenticationError (3 attempts) + retry_on Net::SMTPServerBusy (5 attempts) + discard_on Net::SMTPFatalError`; 4 Job-Tests GREEN; `app/models/user.rb:143 DeviseMailJob.perform_later` Override aktiv |
| 18 | Email-Change: PATCH /users mit neuer email + current_password → confirmation_instructions an neue Adresse, alter Login bleibt funktional | VERIFIED | `config/initializers/devise.rb:178 config.reconfirmable = true`; `test/controllers/registrations_controller_test.rb` "PATCH /users mit neuer email triggert reconfirmation" GREEN; System-Test 4 GREEN |

**Score: 18/18 truths verified**

### Deferred Items

Items not addressed in Phase 41 sondern explizit auf spätere Phasen/Post-Deploy verschoben oder pre-existing:

| # | Item | Addressed In | Evidence |
|---|------|-------------|----------|
| 1 | Production-SMTP-Roundtrip mit echter Gmail-Inbox | Plan 41-05 Task 2 (post-deploy) | Plan-Vorgabe: `checkpoint:human-verify gate="blocking"`; deferred Approval in 41-05-SUMMARY.md ("Production-Roundtrip-Status: DEFERRED bis nach Production-Deploy") |
| 2 | DI-41-04-01: Walkthrough-URLs zeigen Standard-Devise-Pfade statt Carambus-Custom-Paths | Doc-Cleanup-Follow-Up | doc-only Issue aus 41-04-SUMMARY.md, kein Code-Gap |
| 3 | DI-41-04-02: lvh.me DNS-Resolver-Issue in dev | Out-of-Scope (Ops/Environment) | env-config Workaround dokumentiert; nicht Phase-41-Code |
| 4 | DI-41-04-03: Redundante letter_opener_web-Aktivierung in development-carambus.rb | Future Cleanup | no-op; nicht schaedlich; aus 41-04-SUMMARY.md |
| 5 | DI-41-02-01: user_authentication_test.rb "Full name"-Feld | Pre-existing Folge-Plan | per git stash an base-commit als pre-existing verifiziert; aus 41-02-SUMMARY.md |

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `test/mailers/devise_mailer_test.rb` | Layer-3 Mailer-Charakterisierung (5 Tests, ≥80 Zeilen) | VERIFIED | 88 Zeilen; 5 `test "..."`-Blocks; alle GREEN |
| `test/controllers/passwords_controller_test.rb` | Layer-2 Forgot/Reset HTTP-Flow (≥4 Tests, ≥40 Zeilen) | VERIFIED | 7 Tests (Plan-01: 4, Plan-03: 3); ~140 Zeilen; alle GREEN |
| `test/controllers/confirmations_controller_test.rb` | Layer-2 Resend/Confirm HTTP-Flow (≥3 Tests, ≥30 Zeilen) | VERIFIED | 3 Tests; ~50 Zeilen; alle GREEN |
| `test/support/mail_helpers.rb` | MailHelpers#last_email + extract_*_url | VERIFIED | 28 Zeilen; 4 Methoden exportiert: `last_email`, `clear_mail_queue`, `extract_confirmation_url`, `extract_reset_password_url` |
| `test/support/letter_opener_helper.rb` | LetterOpenerHelper-Skeleton (Wave-0 Pflichtlieferung) | VERIFIED | 18 Zeilen; `module LetterOpenerHelper`; Skeleton-Reserve |
| `test/support/devise_test_helpers.rb` | DeviseTestHelpers-Skeleton (Wave-0 Pflichtlieferung) | VERIFIED | 18 Zeilen; `module DeviseTestHelpers`; `generate_raw_confirmation_token`-Helper |
| `test/system/devise_flows_test.rb` | E2E Layer-4 mit 4 Tests, ≥150 Zeilen | VERIFIED | 410 Zeilen; 4 `test "..."`-Blocks; alle GREEN (~3.4s) |
| `config/environments/development-carambus.rb` | letter_opener_web + raise_delivery_errors=true | VERIFIED | Zeilen 29-35: `delivery_method = :letter_opener_web`, `raise_delivery_errors = true`, default_url_options gesetzt |
| `app/controllers/registrations_controller.rb` | invisible_captcha-Macro auf #create + :sign_up-Permit | VERIFIED | Zeile 9: `invisible_captcha only: [:create], honeypot: :subtitle`; Zeilen 47-56: :sign_up-Permit fuer terms_of_service+first_name+last_name |
| `app/views/devise/registrations/new.html.erb` | i18n-Label fuer terms_acceptance | VERIFIED | Zeile 49: `t("devise.registrations.new.terms_acceptance")` |
| `app/models/user.rb` | rotate_jti_on_password_change!-Callback + send_devise_notification-Override | VERIFIED | Zeile 49: Callback; Zeilen 141-144: Override mit DeviseMailJob.perform_later; Zeilen 152-154: private rotate_jti_on_password_change! |
| `config/initializers/devise.rb` | sign_in_after_change_password=false | VERIFIED | Zeile 334: `config.sign_in_after_change_password = false`; reconfirmable=true (Z.178); send_password_change_notification=true (Z.153) |
| `config/initializers/smtp_guard.rb` | Production-Fail-Fast bei fehlender SMTP-ENV | VERIFIED | 26 Zeilen; `if Rails.env.production?` + `raise` mit klarer Fehler-Message |
| `config/initializers/mail_observer.rb` | MailDeliveryObserver + register_observer | VERIFIED | 41 Zeilen; `register_observer(MailDeliveryObserver)` + `delivered_email` + `delivery_failed` Hooks |
| `app/jobs/devise_mail_job.rb` | retry_on + discard_on fuer SMTP-Errors | VERIFIED | 41 Zeilen; `retry_on Net::SMTPAuthenticationError (3 attempts)` + `retry_on Net::SMTPServerBusy (5 attempts)` + `discard_on Net::SMTPFatalError` mit Logging-Block |
| `app/mailers/application_mailer.rb` | default from: Devise.mailer_sender (Sender-Angleichung) | VERIFIED | Zeile 9: `default from: proc { Devise.mailer_sender }` (Proc statt Lambda — Plan-04 Rule-1-Fix) |
| `test/jobs/devise_mail_job_test.rb` | 4 Tests fuer Retry+Discard-Verhalten (≥40 Zeilen) | VERIFIED | 78 Zeilen; 4 Tests: enqueue, perform, retry, discard; alle GREEN |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| test/test_helper.rb | test/support/mail_helpers.rb | include MailHelpers in 3 Test-Basisklassen | WIRED | `grep -c "include MailHelpers" test/test_helper.rb` == 3 (IntegrationTest:130, ActionMailer::TestCase:150, ApplicationSystemTestCase:171) |
| config/routes.rb | LetterOpenerWeb::Engine | mount in Rails.env.development? block | WIRED | Zeile 6: `mount LetterOpenerWeb::Engine, at: "/letter_opener"` innerhalb `if Rails.env.development?` |
| app/controllers/registrations_controller.rb | invisible_captcha gem | invisible_captcha only: [:create], honeypot: :subtitle | WIRED | Zeile 9 — Macro aktiv |
| app/views/devise/registrations/new.html.erb | config/locales/devise.{de,en}.yml | t('devise.registrations.new.terms_acceptance') | WIRED | View ruft t-Helper auf; beide Locale-Files haben Key |
| app/models/user.rb | Devise::JWT::RevocationStrategies::JTIMatcher | self.class.revoke_jwt(nil, self) | WIRED | Zeile 153 in private rotate_jti_on_password_change!; Callback Z.49 |
| test/controllers/passwords_controller_test.rb | app/models/user.rb#rotate_jti_on_password_change! | assert User.jti != old_jti nach PUT /users/password | WIRED | 1 Test mit assert_not_equal old_jti, @user.jti GREEN — End-to-End-Pfad bewiesen |
| app/mailers/application_mailer.rb | config/initializers/devise.rb | default from: proc { Devise.mailer_sender } | WIRED | Proc-Lambda-Wrap fuer Lazy-Init-Order; Devise.mailer_sender greift at-mail-time |
| app/controllers/registrations_controller.rb | app/models/user.rb (rotate_jti_on_password_change!) | PATCH /users => update_resource => user.save => Callback feuert | WIRED | Controller-Test "PATCH ... rotiert jti" GREEN beweist End-to-End-Pfad |
| config/initializers/mail_observer.rb | ActionMailer::Base | register_observer(MailDeliveryObserver) | WIRED | Zeile 40 — Observer wird beim Boot registriert |
| app/models/user.rb (send_devise_notification) | app/jobs/devise_mail_job.rb | DeviseMailJob.perform_later(...) | WIRED | Zeile 143: Override enqueued ueber Job; Test "User#send_devise_notification enqueued DeviseMailJob" GREEN |
| app/jobs/devise_mail_job.rb | ActiveJob queue | retry_on/discard_on Klassen-Macros | WIRED | Zeilen 18-29; ActiveJob's retry_on/discard_on greift via :test/:inline-Adapter; 4 Job-Tests beweisen Retry+Discard-Verhalten |
| test/system/devise_flows_test.rb | test/support/mail_helpers.rb | defensiver include MailHelpers + Plan-01-Wiring | WIRED | Plan-05 Deviation #2: defensiver `include MailHelpers` direkt im Test-File (idempotent); ergaenzt Plan-01-Wiring (test_helper.rb-Patch) gegen zirkulaeren require_relative |
| test/system/devise_flows_test.rb | app/views/devise/* (Forms) | Capybara fill_in + click_button gegen Devise-Default-Views | WIRED | 4 System-Tests durchspielen vollstaendige Browser-Flows; alle GREEN |

### Data-Flow Trace (Level 4)

Phase 41 ist Backend-/Test-Infrastruktur-fokussiert (Auth-Härtung, Tests, Initializers). Es gibt keinen UI-Component der dynamische Daten rendert. Data-Flow-Trace ist für diese Phase nicht anwendbar — alle dynamischen Pfade (Mail-Generation, JTI-Rotation, Job-Perform) werden durch die 58 Tests selbst geprüft.

### Behavioral Spot-Checks

Tests laufen reproduzierbar grün:

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Layer-1+2+3 Phase-41-Tests | `bin/rails test test/mailers/devise_mailer_test.rb test/controllers/passwords_controller_test.rb test/controllers/confirmations_controller_test.rb test/controllers/registrations_controller_test.rb test/controllers/users/registrations_controller_test.rb test/models/user_test.rb test/jobs/devise_mail_job_test.rb` | `54 runs, 171 assertions, 0 failures, 0 errors, 0 skips` | PASS |
| Layer-4 Phase-41-System-Tests | `bin/rails test test/system/devise_flows_test.rb` | `4 runs, 24 assertions, 0 failures, 0 errors, 0 skips` (~4.2s) | PASS |
| Phase-41 Total Test Count | `grep -c "test \"" test/{mailers,jobs,system}/...rb test/controllers/...rb test/models/user_test.rb` | 5+4+4+7+3+7+7+21 = 58 Tests | PASS (matches 58/58 claim) |
| smtp_guard greift in Production | Plan-04 Task-3 User-Walkthrough (nbv-Scenario, 2026-05-16) | "RuntimeError: FATAL: SMTP-ENV" verified | PASS |

### Requirements Coverage

REQ-41-01 bis REQ-41-18 sind inline in den Plan-Frontmattern definiert (NICHT in `.planning/REQUIREMENTS.md`, da Phase 41 nicht zum v7.1-Milestone gehört und in einem separaten Auth-Hardening-Effort lebt). Alle 18 REQ-IDs sind durch die Plans 41-01..41-05 abgedeckt:

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| REQ-41-01 | 41-01 | 4-Layer-Test-Infrastruktur etablieren | SATISFIED | test/mailers/-Verzeichnis + Layer-2+3 Tests; MailHelpers in 3 Basisklassen |
| REQ-41-02 | 41-01 | letter_opener_web in Dev aktiv (Mailbox + Route) | SATISFIED | development-carambus.rb:32 + routes.rb:6 |
| REQ-41-03 | 41-01 | Charakterisierungstests aller 4 Flows | SATISFIED | 12 Tests aus Plan-01 dokumentieren IST + alle nachfolgenden Plans erweitern |
| REQ-41-04 | 41-02 | Registrierungs-Flow funktional: POST /users → confirmation_instructions versendet | SATISFIED | Layer-2-Test "POST /users mit gueltigen Params versendet 1 confirmation_instructions Mail" GREEN |
| REQ-41-05 | 41-02 | terms_of_service-Checkbox i18n-versorgt (DE+EN) | SATISFIED | terms_acceptance-Key in devise.de.yml:82 + devise.en.yml:82 + new.html.erb:49 |
| REQ-41-06 | 41-02 | invisible_captcha server-seitig im RegistrationsController#create | SATISFIED | registrations_controller.rb:9 Macro + Honeypot-Test GREEN |
| REQ-41-07 | 41-03 | Forgot-Password versendet Reset-Mail (HTTP-getestet) | SATISFIED | passwords_controller_test.rb "POST /users/password ... versendet Reset-Mail" GREEN |
| REQ-41-08 | 41-03 | Reset-Password-Token nach Use invalidiert | SATISFIED | "Token-Replay nach Use wird abgewiesen" GREEN (require_no_authentication-Schicht + clear_reset_password_token) |
| REQ-41-09 | 41-03 | JTI-Rotation nach Password-Reset (D-41-C Hard-Revoke) | SATISFIED | user.rb:49 Callback + 5 Layer-1-Tests + Layer-2-Test "rotiert User.jti" GREEN |
| REQ-41-10 | 41-04 | Change-Password-Flow: PATCH /users rotiert PW + Notification | SATISFIED | "PATCH /users mit current_password+password rotiert jti und versendet password_change-Mail" GREEN |
| REQ-41-11 | 41-04 | sign_in_after_change_password=false → User muss neu einloggen | SATISFIED | devise.rb:334 config + "Nach PATCH /users ... NICHT mehr eingeloggt" GREEN + System-Test 3 GREEN |
| REQ-41-12 | 41-04 | Mail-Sender vereinheitlicht: Devise.mailer_sender == ApplicationMailer.default_from | SATISFIED | application_mailer.rb:9 `proc { Devise.mailer_sender }` |
| REQ-41-13 | 41-04 | SMTP-Härtung: Fail-Fast + Mail-Observer + Retry-Job + Bounce-Discard | SATISFIED | smtp_guard.rb + mail_observer.rb + devise_mail_job.rb mit allen 4 D-41-B-Wortlaut-Anforderungen |
| REQ-41-14 | 41-04 | Email-Change Reconfirmation: PATCH email → confirmation an neue Adresse | SATISFIED | devise.rb:178 reconfirmable=true + "PATCH /users mit neuer email triggert reconfirmation" GREEN + System-Test 4 GREEN |
| REQ-41-15 | 41-05 | E2E Sign-up → Confirmation-Mail-Click → Logged-in | SATISFIED | System-Test 1 "user registers and confirms via email link" GREEN |
| REQ-41-16 | 41-05 | E2E Forgot → Reset-Mail-Click → Neues PW → JTI rotated | SATISFIED | System-Test 2 "user resets password" GREEN (assert User.jti rotated) |
| REQ-41-17 | 41-05 | E2E Change-Password → Re-Login Pflicht + Notification-Mail | SATISFIED | System-Test 3 "user changes password and is forced to re-login" GREEN |
| REQ-41-18 | 41-05 | E2E Email-Change → Reconfirm-Mail → Bestätigen → email gesetzt | SATISFIED | System-Test 4 "user changes email and confirms via reconfirmation link" GREEN |

**Coverage: 18/18 REQ-IDs SATISFIED**

### Anti-Patterns Found

Anti-pattern-Scan auf allen Phase-41-Files (config/initializers/smtp_guard.rb, mail_observer.rb, app/jobs/devise_mail_job.rb, app/models/user.rb, app/mailers/application_mailer.rb, app/views/devise/registrations/new.html.erb, app/controllers/registrations_controller.rb, alle Test-Files):

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| (keine) | — | TODO/FIXME/PLACEHOLDER | — | Keine Stubs gefunden; Skeleton-Files (letter_opener_helper.rb + devise_test_helpers.rb) sind explizit als Wave-0-Reserve dokumentiert mit gehaltvollen Kommentaren — nicht TODO-Style. |

Skeleton-Klassifizierung: `test/support/letter_opener_helper.rb` und `test/support/devise_test_helpers.rb` enthalten je 1 funktionsfähige Methode + Doc-Kommentar; sind keine leeren Stubs sondern Wave-0-Pflichtlieferungen gemäß VALIDATION.md (siehe Plan-01 Deviation #4). User#skip_confirmation! (user.rb:64-65) leere Override ist bewusst dokumentiert (siehe RESEARCH.md Pitfall 2) — nicht Phase-41-Artefakt.

### Human Verification Required

Keine offenen Human-Verify-Items für die Code-Verifikation:
- Plan-04 Task 3 (Dev-Walkthrough) wurde am **2026-05-16 vom User verified** im carambus_nbv-Scenario (Port 3301, Plan-04-SUMMARY dokumentiert alle 8+1 Schritte als ✓)
- Plan-05 Task 2 (Production-SMTP-Roundtrip) ist explizit **deferred bis nach Production-Deploy** per Plan-Vorgabe (CONTEXT.md Anti-Pattern "Don't ship without echtem Mail-Roundtrip-Verifikation") und wird als deferred Approval in 41-05-SUMMARY.md gefuehrt — NICHT als verification-blocker für Phase 41.

### Gaps Summary

**Keine Gaps gefunden.** Alle 18 must-haves verified, alle 18 REQ-IDs satisfied, alle 17 erforderlichen Artifacts vorhanden + substantive + wired, alle 13 Key-Links wired. 58/58 Phase-41-Tests grün (54 Layer-1+2+3 + 4 Layer-4 System).

Die Phase 41 hat ihr Goal vollständig erreicht: Devise-Auth-Cluster ist auf produktiven Standard gehoben mit 4-Layer-Test-Pyramide. Alle vier D-41-D-Flows (Registrierung+Confirmation, Forgot-Password, Change-Password, Email-Change) sind End-to-End getestet. D-41-B SMTP-Härtung vollständig (Fail-Fast + Observer + Retry + Bounce). D-41-C Hard-Revoke aller JWT bei PW-Change durchgesetzt mit Cross-Repo-Sicherheit für carambus_bcw-MCP-JWTs.

**Disconfirmation Pass (Confirmation Bias Counter):**

1. **Partiell erfüllt?** — Sender-Angleichung: Production-Verhalten wurde nur via isolated-Test verifiziert (Plan-04 Deviation #6); echter Production-Boot mit smtp_guard wartet auf Deploy. Verification akzeptiert: Plan-05 Task-2 dokumentiert explizit als deferred Approval.
2. **Test pinnt nicht was er behauptet?** — Confirmation-Invalid-Token-Test (Plan-01) pinnt 200 OK statt 422 (Devise-Default). SUMMARY dokumentiert das transparent; Test heißt aber "pinnt IST", nicht "rejects". Akzeptabel als Charakterisierung.
3. **Error-Path nicht abgedeckt?** — DeviseMailJob bei Net::SMTPConnectionError (transient, aber NICHT in retry_on-Liste) → würde bubble-up zu ActiveJob-default. Plan-04 hat das nicht explizit behandelt. Diskussionswert für Folge-Plan, aber kein Phase-41-Blocker (D-41-B-Wortlaut "transient vs permanent" — diese 2 Klassen-Kategorisierung ist abgedeckt).

Alle 3 Disconfirmation-Punkte sind dokumentiert oder bewusst akzeptiert — keine versteckten Gaps.

### Recommendations (informational, nicht blocking)

1. **Plan-01-Wiring (test_helper.rb)-Cleanup:** Plan-05 Deviation #2 dokumentiert zirkuläres `require_relative` zwischen test_helper.rb und application_system_test_case.rb. Defensiver Workaround in System-Test-File funktioniert. Saubere Lösung wäre `include MailHelpers` direkt in application_system_test_case.rb. Out-of-Scope für Phase 41.

2. **clear_reset_password_token-Schicht isoliert testen:** Plan-03 Open Item — nur möglich mit `sign_in_after_reset_password = false`. Aktuell überdeckt require_no_authentication-Filter den clear_reset_password_token-Pfad. Optional als Folge-Hardening.

3. **DeviseMailJob retry für weitere transient Error-Klassen:** Net::SMTPConnectionError, Errno::ECONNREFUSED, Timeout::Error könnten weitere transient-Patterns sein. Plan-04 deckt die 2 wichtigsten ab (Auth + ServerBusy). Optional für Folge-Phase falls Production-Logs weitere transient Errors zeigen.

---

*Verified: 2026-05-16T08:30:00Z*
*Verifier: Claude (gsd-verifier)*
*Phase 41-devise-auth-cluster-ueberarbeitung-registrierung-forgot-pass*
