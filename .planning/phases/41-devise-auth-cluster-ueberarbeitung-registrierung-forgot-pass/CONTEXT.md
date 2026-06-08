---
phase: 41
phase_name: "Devise/Auth-Cluster Überarbeitung — Registrierung, Forgot-Password, Change-Password, Mailings"
milestone: v7.1
created: 2026-05-15
source: /paul:discuss (interaktive Discuss-Session)
status: discussed → ready-for-plan
---

# Phase 41 — Discussion Context

## Vision

Devise-Auth-Stack zum **verlässlichen, vollständig testabgedeckten Standard** bringen. Heute sind Teilflows defekt (insbesondere Mail-Zustellung und Registrierung), und es fehlt belastbare Test-Coverage, die Regressionen bei Devise-/Rails-Upgrades verhindert. Die Phase ist kein neues Feature, sondern Auth-Hardening + Restoration der Devise-Default-Flows auf produktivem Standard.

**Erfolgsbild:** Ein neuer User kann sich registrieren → Confirmation-Mail erhalten → bestätigen → einloggen. Ein bestehender User kann sein Passwort vergessen → Reset-Mail erhalten → neues Passwort setzen → JWT-Sessions auf allen Geräten sind ungültig. Ein User kann sein Passwort im Account-Edit ändern → bekommt Benachrichtigungsmail. Alle vier Flows sind durch Tests auf 4 Layern (Model, Controller, Mailer, E2E) abgedeckt.

## Locked Decisions

### D-41-A: Test-Pyramide vollständig — 4 Layer Coverage Pflicht

**Layer:**
1. **Model-Tests** — User-Modell + `Devise::JWT::RevocationStrategies::JTIMatcher`-Verhalten bei PW-Change/Reset
2. **Controller/Request-Tests** — `RegistrationsController`, `SessionsController`, Devise-Default `PasswordsController` + `ConfirmationsController` — HTTP-Verhalten + Redirects + Flash-Messages
3. **Mailer-Tests** — `ActionMailer::Base.deliveries` inspizieren: Subject, From, To, Body, Reset/Confirmation-Tokens im Link, Locale-korrekte Texte
4. **End-to-End mit echtem Mail-Receipt** — System-Tests (Capybara + Selenium); in Dev via `letter_opener_web` bzw. SMTP-Roundtrip; klickbarer Reset-/Confirmation-Link → vollständiger Flow

**Rationale:** User-Anweisung — die ganzen Devise-/Auth-Abläufe müssen verlässlich mit Tests abgedeckt werden. Mailer-Layer ist heute defekt („Mails kommen nicht an"), Registrierung defekt — beides ist ohne Coverage nicht abdeckbar.

### D-41-B: Mailing-Backend bleibt Gmail-SMTP + Härtung

**Beibehaltung:**
- `ENV["SMTP_USERNAME"]` / `ENV["SMTP_PASSWORD"]` als Gmail-SMTP-Credentials
- `mailer_sender = ENV["SMTP_USERNAME"] || "no-reply@carambus.de"` Fallback
- ApplicationMailer als parent_mailer

**Härtung (zu spezifizieren in Plan-Phase):**
- Retry-Logik bei SMTP-Fehlern (transient vs. permanent)
- Strukturiertes Logging jedes Mail-Versuchs (success/fail + Rails.logger.tagged?)
- Bounce-Handling-Strategie (auch wenn Gmail-SMTP keine native Bounce-API hat — mindestens Error-Trapping)
- Sender-Verifizierung (kein Versand wenn `mailer_sender` auf Default-Fallback fällt + ENV fehlt — Fail-Fast in Production)

**Rationale:** User-Entscheidung. Wechsel zu transaktionalem Anbieter (Postmark/Sendgrid) wäre nice-to-have, aber Gmail-SMTP ist Stack-Bestand und funktioniert grundsätzlich; aktuelles Problem liegt vermutlich an fehlender Resilience, nicht am Provider.

### D-41-C: Hard-Revoke aller JWT bei Password-Change/Reset

**Verhalten:**
- Bei `PUT /users` mit `password`-Update → alle existierenden JWT für diesen User invalidieren (JTIMatcher-Rotation: neuer `jti` schreibt alte ungültig)
- Bei `PUT /password` (Devise-Reset über Reset-Token) → ebenfalls JTI-Rotation
- User muss sich auf allen Geräten neu einloggen — explizite Benachrichtigung in der UI/Mail

**Rationale:** Security-Best-Practice. carambus.de ist Multi-User mit langer MCP-JWT-Lifetime (v0.4 Authority-Re-Architecture im carambus_bcw nutzt Long-Lived-JWT) — bei PW-Reset infolge kompromittiertem Account dürfen alte Tokens auf keinen Fall weiterleben. Soft-Variante (nur aktuelle Session) wurde verworfen.

### D-41-D: Scope = alle 4 Hauptflows + zugehörige Mails

**In-Scope:**
- **Registrierung** (`POST /users` → confirmation_instructions Mail → `GET /confirmation?token=...` → einloggbar)
- **Forgot-Password** (`POST /password` → reset_password_instructions Mail → `GET /password/edit?reset_password_token=...` → neues PW)
- **Change-Password** (eingeloggt: `PATCH /users` → password-Update → JWT-Revoke + send_password_change_notification Mail)
- **Email-Change mit Reconfirmation** (`reconfirmable = true` aktiv: Email-Update → neue confirmation_instructions an neue Adresse, alte bleibt bestehend bis Bestätigung)

**Out-of-Scope (Deferred):**
- Lockable-Modul aktivieren (nicht in der derzeitigen Devise-Module-Liste — wäre neue Capability)
- OmniAuth / Social-Login (nicht erforderlich für Restoration)
- 2FA / OTP (existierende `sessions/otp.html.erb`-View deutet auf vorhandenen OTP-Versuch hin — wenn defekt, nicht in dieser Phase fixen)
- Account-Invitations-Mailer (`account_invitations_mailer.rb`) — separater Flow, nicht Teil der Devise-Default-Cluster
- Devise-View-Restyling (Tailwind-Verfeinerung) — kosmetisch, nicht funktional, eigene UX-Phase

## Open for Planning (Claude's Discretion)

### Vorgehensweise: Diagnose-Spike vs. Re-Build flow-by-flow

User-Anweisung: **Claude's Discretion** — in Plan-Phase entscheiden basierend auf Erstdiagnose-Befund.

**Empfehlung-Substrat für gsd-planner:**
- Plan-01 als **Diagnose-Spike**: Tests für alle 4 Flows schreiben, die den IST-Zustand charakterisieren (auch wenn rot). Output: Liste an konkret defekten Stellen mit Test-Reproduktion.
- Plan-02..N: Sobald Diagnose-Spike Befund-Liste hat, je defektem Flow ein Plan (Mailer-Fix, Registration-Fix, Reset-Fix, etc.) — mit Tests von Plan-01 als Acceptance-Gate (rot → grün).
- Hybrid ist vermutlich sinnvoller als reines „erst alles testen, dann alles fixen", weil Mailer-Fix möglicherweise Voraussetzung für E2E-Tests anderer Flows ist (zirkuläre Abhängigkeit).

### Test-Daten-Strategie für E2E mit echtem Mail-Receipt

- **Dev:** `letter_opener_web` ist im Stack — Mails landen unter `/letter_opener`. System-Tests könnten letter_opener-Output programmatisch parsen (Verfahren: Test-Helper, der den letzten letter_opener-Mail-Ordner liest und Reset-Token extrahiert).
- **Test-Env (Minitest):** `ActionMailer::Base.deliveries` reicht für Mailer-Tests; E2E-Tests können den Mail-Body direkt aus `deliveries.last.body.to_s` parsen — kein echter SMTP nötig.
- **Production-Sanity:** Eine isolierte Smoke-Sequenz auf Staging gegen echte Gmail-Inbox (manueller Walkthrough nach Deploy) — als finales Akzeptanz-Substrat, NICHT als CI-Test.

### Locale-Coverage

Carambus default_locale = `:de`, fallback `:en`. Mailer-Templates und Devise-Views müssen in **beiden Sprachen** korrekt rendern. Test-Coverage sollte mind. den DE-Pfad voll abdecken, EN-Pfad zumindest stichprobenartig (Subject + 1-2 Key-Strings pro Mail).

### `terms_of_service`-Validation auf Create

User-Modell hat `validates :terms_of_service, acceptance: true, on: :create`. Registrations-View muss eine sichtbare Checkbox haben; ohne Klick → Validation-Error. Plan-Phase soll prüfen, ob diese Checkbox in der aktuellen `app/views/devise/registrations/new.html.erb` korrekt eingebunden + i18n-versorgt ist.

## Anti-Patterns

- **Don't rewrite Devise.** Nutze Devise-Defaults wo möglich. Custom-Controller nur wenn zwingend erforderlich (bestehende `registrations_controller.rb` + `sessions_controller.rb` als minimale Overrides beibehalten, nicht ausweiten).
- **Don't add new Devise modules.** `lockable`, `omniauthable`, `timeoutable` sind out-of-scope.
- **Don't restyle views in dieser Phase.** Optisches Polish ist eine separate UX-Phase. Hier nur funktionale Restoration.
- **Don't mock SMTP-Backend in Mailer-Tests.** ActionMailer-Test-Adapter ist OK (das ist Rails-Standard, kein „Mock" im problematischen Sinn). Aber NICHT die SMTP-Layer per WebMock mocken, sondern Mailer-Klassen-Verhalten direkt testen.
- **Don't ship without echtem Mail-Roundtrip-Verifikation.** Mindestens einmal nach Deploy: echte Registrierung mit echter Inbox-Adresse. Tests reichen nicht — Gmail-SMTP-Auth ist environment-spezifisch.
- **Don't break v0.4-MCP-JWT-Compatibility.** carambus_bcw läuft auf langer JWT-Lifetime (Phase 14-G.5 noch in Arbeit dort). Diese Phase-41-Arbeit darf den JTIMatcher-Mechanismus nicht so verändern, dass MCP-JWTs unbeabsichtigt revoked werden bei Routine-Mail-Versand o.ä.

## Cross-Repo Awareness

- **carambus_bcw** läuft parallel v0.4 Authority-Re-Architecture (Phase 14-G im MCP-Sub-Projekt). Long-Lived-JWT-Strategie dort. **Keine JWT-Stack-Änderungen in Phase 41, die den MCP-Flow brechen.**
- **carambus_phat / carambus_api** — Deployment-Checkouts; nach erfolgreicher Phase 41 im Master via Scenario-Sync verteilen (siehe `.agents/skills/scenario-management/`).

## Discussion Trace (für Audit)

Discuss-Session 2026-05-15 mit User:

| Frage | Antwort |
|-------|---------|
| Was hakt konkret? | Devise/Auth-Abläufe brauchen verlässliche Test-Coverage; Mails kommen nicht an; Registrierung defekt |
| Mailing-Backend? | Gmail-SMTP beibehalten + härten |
| JWT bei PW-Change? | Hard-Revoke alle JWT |
| Diagnose vs. Re-Build? | Claude's Discretion (Plan-Phase entscheidet) |
| Test-Tiefe? | Alle 4 Layer: Model, Controller/Request, Mailer, E2E mit echtem Mail-Receipt |

---

## ▶ Next Steps

1. `/gsd-plan-phase 41` — Plan-Phase ausführen; Diagnose-Spike als Plan-01 priorisieren
2. Plan-Phase entscheidet konkrete Plan-Sequenz basierend auf Erstdiagnose
3. Vor Execution: Phase 41 ggf. aus Backlog-Bereich der ROADMAP.md in den aktiven v7.1-Block verschieben (oder eigenes Milestone v7.x „Auth-Hardening" eröffnen — User-Entscheidung)
