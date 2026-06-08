---
phase: 41
slug: devise-auth-cluster-ueberarbeitung-registrierung-forgot-pass
status: ready-for-execution
nyquist_compliant: true   # Revision 1: alle auto-Tasks haben <automated>-verify (incl. DeviseMailJob-Tests in Plan-04 + Wave-0-Skeletons in Plan-01 Task-4)
wave_0_complete: false    # set on Plan-01 completion (alle 6 Wave-0-Pflichtlieferungen geliefert via Plan-01 Tasks 1-4)
created: 2026-05-15
revised: 2026-05-16
---

# Phase 41 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Phase ist Auth-Hardening + Test-Coverage-Effort — Validation ist hier nicht nur Gate, sondern Kern-Deliverable.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Minitest (Rails 7.2 / Ruby 3.2.1) |
| **Config file** | `test/test_helper.rb` (vorhanden) |
| **Quick run command** | `bin/rails test test/models/user_test.rb test/mailers test/jobs/devise_mail_job_test.rb test/controllers/{registrations,sessions,passwords,confirmations}_controller_test.rb` |
| **Full suite command** | `bin/rails test && bin/rails test:system` |
| **Estimated runtime** | ~15-40s (quick) / ~3-6min (full inkl. System) |

**Wave 0 Bedarf (per Research):**
- `test/mailers/` Verzeichnis fehlt komplett — anlegen
- `letter_opener_web` Aktivierung in `config/environments/development.rb` (delivery_method)
- `test/system/devise_flows_test.rb` Skeleton (Plan-01 Task-4)
- `test/support/letter_opener_helper.rb` Skeleton (Plan-01 Task-4)
- `test/support/devise_test_helpers.rb` Skeleton (Plan-01 Task-4)

---

## Sampling Rate

- **After every task commit:** Run quick command für die betroffene Test-Datei (Minitest single-file)
- **After every plan wave:** Full quick command (alle Devise-bezogenen Tests)
- **Before `/gsd-verify-work`:** Full suite (inkl. system) muss grün sein
- **Max feedback latency:** ~40s für Quick (Minitest Single + Mailer); System ~3min einmal pro Wave

---

## Per-Task Verification Map

> Plan-Phase fillt die konkreten Task-IDs (41-NN-MM). Hier die Skelett-Mapping zwischen RESEARCH-Bug-Hypothesen und Test-Layer.

| Bug / Feature (Research-Befund) | Test-Layer | Geplantes Test-File | Verify-Command-Pattern |
|---|---|---|---|
| Keine Mailer-Tests existieren | Mailer | `test/mailers/devise_mailer_test.rb` | `bin/rails test test/mailers/devise_mailer_test.rb` |
| JTI-Rotation bei PW-Change fehlt | Model | `test/models/user_test.rb` (JWT-Section) | `bin/rails test test/models/user_test.rb -n /jti/` |
| `sign_in_after_change_password` blockiert Revoke-UX | Controller | `test/controllers/registrations_controller_test.rb` | `bin/rails test test/controllers/registrations_controller_test.rb` |
| `skip_confirmation!` ist leere Override | Model | `test/models/user_test.rb` (confirmation-Section) | `bin/rails test test/models/user_test.rb -n /confirm/` |
| letter_opener_web nicht aktiviert | Controller + System | `test/system/devise_mail_flows_test.rb` | `bin/rails test:system TEST=test/system/devise_mail_flows_test.rb` |
| Sender-Diskrepanz ApplicationMailer.from vs. mailer_sender | Mailer | `test/mailers/devise_mailer_test.rb` | s.o. |
| Registrierung defekt (terms_of_service / invisible_captcha) | Controller + System | `test/controllers/registrations_controller_test.rb` + `test/system/registration_flow_test.rb` | Quick + System |
| i18n DE/EN Mail-Coverage | Mailer | `test/mailers/devise_mailer_test.rb` (mit `I18n.with_locale`) | s.o. |
| D-41-B Retry-Logik (transient SMTP-Errors) | Job | `test/jobs/devise_mail_job_test.rb` | `bin/rails test test/jobs/devise_mail_job_test.rb` |
| D-41-B Bounce-Handling (permanent SMTPFatalError) | Job | `test/jobs/devise_mail_job_test.rb` | s.o. |

**Pro Layer (D-41-A) Pflicht-Coverage:**

| Layer | Mindest-Tests | Files (geplant) |
|---|---|---|
| **Model** | User Devise-Module-Setup, JTIMatcher revoke_jwt, PW-Change-Callback rotiert JTI, Email-Change triggert Reconfirm, confirmed_at-Setting | `test/models/user_test.rb` |
| **Controller/Request** | RegistrationsController#create + #update, SessionsController#create (login), Devise-Default PasswordsController + ConfirmationsController (HTTP-Flow + Redirect + Flash) | `test/controllers/{registrations,sessions}_controller_test.rb` + neue für passwords/confirmations |
| **Mailer** | confirmation_instructions, reset_password_instructions, password_change, email_changed (Subject, From, To, Token im Body, DE+EN-Pfad) | `test/mailers/devise_mailer_test.rb` (NEU) |
| **Job** | DeviseMailJob: enqueue durch User#send_devise_notification, perform liefert Mail, retry_on transient SMTP-Errors, discard_on permanent SMTPFatalError (D-41-B) | `test/jobs/devise_mail_job_test.rb` (NEU, Plan-04) |
| **System (E2E)** | Sign-up → Confirmation-Mail → Click-Link → Logged-in. Forgot → Reset-Mail → Click-Link → New PW → All-JWT-Revoked. Change-PW eingeloggt → Notification-Mail → JWT-Rotation. Email-Change → Reconfirm-Mail | `test/system/devise_flows_test.rb` (NEU, mehrere Tests darin) |

---

## Wave 0 Requirements

- [ ] `test/mailers/` Verzeichnis angelegt (durch Plan-01 Task 2)
- [ ] `test/mailers/devise_mailer_test.rb` Skeleton mit Test-Helper-Setup (`ActionMailer::TestCase`) (Plan-01 Task 2)
- [ ] `test/system/devise_flows_test.rb` Skeleton mit `ApplicationSystemTestCase` (Plan-01 Task 4)
- [ ] `test/support/letter_opener_helper.rb` Skeleton-Module (Plan-01 Task 4)
- [ ] `test/support/devise_test_helpers.rb` Skeleton-Module (Plan-01 Task 4)
- [ ] `config/environments/development.rb` setzt `config.action_mailer.delivery_method = :letter_opener_web` (Plan-01 Task 1)

**Wave 0 Definition-of-Done:** Bevor irgendein Devise-Fix gestartet wird, müssen Test-Infra-Files existieren und mindestens 1 charakterisierender Test pro Layer rot/grün (= dokumentiert IST-Zustand) sein.

**Revision 1 (2026-05-16):** Plan-01 Task 4 ergänzt — alle 6 Wave-0-Pflichtlieferungen sind nun durch Plan-01 abgedeckt. `wave_0_complete: true` wird nach erfolgreicher Plan-01-Execution gesetzt.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Echter Gmail-SMTP-Roundtrip nach Production-Deploy | D-41-B (Härtung) | SMTP-Auth ist environment-spezifisch (echte Credentials, echte Inbox); CI darf das nicht ausführen | Nach Deploy auf carambus.de: Test-User registrieren mit echter Inbox-Adresse, Confirmation-Mail-Receipt verifizieren, dann PW-Reset durchspielen |
| Spam-Filter-Verhalten der versandten Mails | D-41-B (Härtung) | Spam-Reputation lässt sich nicht testen; nur in Real-Inbox sichtbar | Manuell prüfen: landet Mail im Spam-Folder bei Gmail/Outlook/GMX-Empfängern? |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies (Revision 1 verifiziert: Plan-01..05 alle auto-Tasks haben automated-verify, Plan-04 Task-3 + Plan-05 Task-2 sind explizit `checkpoint:human-verify`)
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references (Mailer-Dir, System-Test-Skeleton, Helpers) — durch Plan-01 Task 4 (Revision 1) vollstaendig
- [x] No watch-mode flags (Minitest läuft single-shot, kein `--watch`)
- [x] Feedback latency < 60s für Quick-Tests
- [x] `nyquist_compliant: true` gesetzt (Revision 1)

**Approval:** ready-for-execution (Revision 1 nach gsd-plan-checker BLOCKER-Fixes — 2026-05-16)
