# Phase 41: Devise/Auth-Cluster Überarbeitung — Research

**Researched:** 2026-05-15
**Domain:** Devise 4.9.4 + devise-jwt 0.13.0, Auth-Flow-Hardening, Mailer-Testing
**Confidence:** HIGH (Code direkt gelesen, keine externen Quellen nötig für Kernbefunde)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**D-41-A: Test-Pyramide vollständig — 4 Layer Coverage Pflicht**
- Layer 1: Model-Tests — User + JTIMatcher bei PW-Change/Reset
- Layer 2: Controller/Request-Tests — RegistrationsController, SessionsController, Devise-Default PasswordsController + ConfirmationsController — HTTP-Verhalten, Redirects, Flash-Messages
- Layer 3: Mailer-Tests — ActionMailer::Base.deliveries inspizieren: Subject, From, To, Body, Reset-/Confirmation-Token im Link, Locale-korrekte Texte
- Layer 4: End-to-End — System-Tests (Capybara + Selenium); in Dev via letter_opener_web; klickbarer Reset-/Confirmation-Link → vollständiger Flow

**D-41-B: Mailing-Backend bleibt Gmail-SMTP + Härtung**
- ENV["SMTP_USERNAME"] / ENV["SMTP_PASSWORD"] als Credentials bleiben
- Härtung: Retry-Logik (transient vs. permanent), strukturiertes Logging, Bounce-Error-Trapping, Fail-Fast wenn ENV fehlt (Production)

**D-41-C: Hard-Revoke aller JWT bei Password-Change/Reset**
- PUT /users mit password-Update → JTI-Rotation (neuer jti schreibt alte ungültig)
- PUT /password (Devise-Reset über Reset-Token) → ebenfalls JTI-Rotation
- User muss sich auf allen Geräten neu einloggen

**D-41-D: Scope = alle 4 Hauptflows + zugehörige Mails**
- Registrierung (POST /users → confirmation_instructions → GET /confirmation?token= → einloggbar)
- Forgot-Password (POST /password → reset_password_instructions → GET /password/edit?token= → neues PW)
- Change-Password (eingeloggt: PATCH /users → JWT-Revoke + password_change Notification Mail)
- Email-Change mit Reconfirmation (reconfirmable=true: Email-Update → neue confirmation_instructions an neue Adresse)

### Claude's Discretion

- Vorgehensweise: Diagnose-Spike vs. Re-Build flow-by-flow (Plan-Phase entscheidet nach Diagnose)
- Test-Daten-Strategie für E2E: ActionMailer::Base.deliveries in Tests; letter_opener für Dev-Verification
- Locale-Coverage: DE vollständig, EN stichprobenartig
- `terms_of_service`-Validation auf Create: Checkbox in View vorhanden und i18n-versorgt prüfen

### Deferred Ideas (OUT OF SCOPE)

- Lockable-Modul aktivieren
- OmniAuth / Social-Login
- 2FA / OTP (otp.html.erb-View — nicht anfassen)
- Account-Invitations-Mailer (account_invitations_mailer.rb) — separater Flow
- Devise-View-Restyling / Tailwind-Verfeinerung
</user_constraints>

---

## Summary

**Was hakt heute (Ist-Zustand):** Die vier Devise-Auth-Flows (Registrierung, Forgot-Password, Change-Password, Email-Change) sind funktional im Code vorhanden, aber nie systematisch getestet. Es gibt kein `test/mailers/`-Verzeichnis. Kein einziger Test prüft `ActionMailer::Base.deliveries` für Devise-Mails. Die E2E-Tests in `user_authentication_test.rb` testen nur Login/Logout und Role-Redirects. Der Forgot-Password-Flow ist komplett ungetestet. JTI-Rotation bei Passwortänderung ist nicht implementiert — `revoke_jwt` existiert als Klassenmethode, wird aber nirgendwo bei Password-Change/Reset aufgerufen.

**Mailer-Sender-Diskrepanz:** `ApplicationMailer` verwendet `from: Carambus.config.support_email` (gernot.ullrich@gmx.de), `Devise.mailer_sender` in devise.rb dagegen `ENV["SMTP_USERNAME"] || "no-reply@carambus.de"`. Diese Diskrepanz könnte dazu führen, dass Devise-Mails mit einer falschen From-Adresse versendet werden, die nicht mit dem SMTP-Sender übereinstimmt (Gmail-SMTP lehnt das unter Umständen ab).

**letter_opener:** Im Gemfile korrekt im `group :development`-Block, aber keine `delivery_method: :letter_opener_web`-Konfiguration in development-carambus.rb gefunden — Dev-Mailer-Preview funktioniert möglicherweise nicht.

**Primäre Empfehlung:** Plan-01 als Diagnose-Spike (Charakterisierungstests schreiben, Ist-Stand dokumentieren). Erst danach Flow-by-Flow fixen in der Reihenfolge: Mailer-Setup → Registrierung+Confirmation → Forgot/Reset-Password + JTI-Rotation → Change-Password + JTI-Rotation → Email-Change Reconfirmation.

---

## Projekt-Constraints (aus CLAUDE.md)

| Direktive | Inhalt |
|-----------|--------|
| Test-Framework | Minitest (NICHT RSpec), Fixtures + FactoryBot |
| Linting | `bundle exec standardrb` (Standard-Ruby), `bundle exec erblint` |
| Security Scan | `bundle exec brakeman --no-pager` |
| Frozen String Literal | `# frozen_string_literal: true` in allen Ruby-Dateien |
| Sprache Kommentare | Deutsch für Business-Logik, Englisch für technische Terme |
| Anti-Pattern | Don't rewrite Devise, Don't add new Devise modules |
| Behavior Preservation | Alle bestehenden Flows müssen identisch weiterarbeiten |

---

## Current State Analysis (Code-Befunde)

### Devise-Konfiguration (VERIFIED)

| Parameter | Wert | Datei |
|-----------|------|-------|
| `mailer_sender` | `ENV["SMTP_USERNAME"] \|\| "no-reply@carambus.de"` | `config/initializers/devise.rb` |
| `allow_unconfirmed_access_for` | `7.days` | `config/initializers/devise.rb` |
| `reconfirmable` | `true` | `config/initializers/devise.rb` |
| `send_password_change_notification` | `true` | `config/initializers/devise.rb` |
| `stretches` | `Rails.env.test? ? 1 : 12` | `config/initializers/devise.rb` |
| `reset_password_within` | `6.hours` | `config/initializers/devise.rb` |
| `sign_in_after_reset_password` | `-> (user) { !user.otp_required_for_login? }` | `config/initializers/devise.rb` |
| `sign_in_after_change_password` | `true` (Devise-Default, auskommentiert) | `config/initializers/devise.rb:331` |
| JWT expiration | `jwt_expiration_days * 86_400` (Default: 90 Tage) | `config/initializers/devise.rb` |

**Kritisch:** `sign_in_after_change_password` ist auf den Devise-Default `true` belassen. Für D-41-C (Hard-Revoke aller JWT bei PW-Change) muss dieser Wert auf `false` gesetzt werden, damit der User nach PW-Änderung neu einloggen muss (sonst wäre `bypass_sign_in` aktiv und der User bleibt angemeldet trotz JTI-Rotation).

### User Model (VERIFIED)

```ruby
# app/models/user.rb
devise :database_authenticatable, :registerable,
  :recoverable, :rememberable, :validatable, :confirmable,
  :jwt_authenticatable, jwt_revocation_strategy: self

include Devise::JWT::RevocationStrategies::JTIMatcher

validates :terms_of_service, acceptance: true, on: :create
attr_accessor :terms_of_service  # nicht persistiert, nur Validierungs-Flag

def skip_confirmation!
  # LEER — überschreibt Devise-Default, tut nichts
end
```

**Problem 1 — skip_confirmation!:** Die leere `skip_confirmation!`-Methode überschreibt Devise's Standard-Implementation, die `confirmed_at = Time.current` setzt. Das bedeutet: jeder User der via `User.create!` in Tests oder Seeds angelegt wird und `skip_confirmation!` aufruft, wird NICHT als confirmed gesetzt. **Analyse: Das ist beabsichtigt**, da alle Fixture-User explizit `confirmed_at: <%= Time.current %>` in der YAML setzen. Für neue Tests müssen Fixtures ebenfalls `confirmed_at` setzen.

**Problem 2 — JTI-Rotation fehlt:** `JTIMatcher` stellt `User.revoke_jwt(_payload, user)` bereit, das `user.update_column(:jti, generate_jti)` ausführt. Diese Methode wird nirgendwo bei Password-Change oder Password-Reset aufgerufen. D-41-C erfordert explizite Integration.

### JTIMatcher-Mechanismus (VERIFIED, Quellcode gelesen)

```ruby
# devise-jwt-0.13.0 — JTIMatcher
def self.jwt_revoked?(payload, user)
  payload['jti'] != user.jti  # Token ungültig wenn jti nicht übereinstimmt
end

def self.revoke_jwt(_payload, user)
  user.update_column(:jti, generate_jti)  # Neues UUID → alle alten Tokens ungültig
end
```

**Hard-Revoke-Mechanismus:** JTI-Rotation über `User.revoke_jwt(nil, user)` invalidiert sofort alle ausgestellten JWTs für diesen User. `update_column` bypassed Callbacks und Validierungen — schnell und sicher. Der Aufruf muss nach erfolgreichem Passwort-Save passieren (nicht davor).

**Cross-Repo-Risiko (bcw/MCP):** Die JTI-Rotation ist nur bei bewusster Passwortänderung auszulösen — NICHT bei normalen Requests. carambus_bcw-MCP-JWTs laufen 90 Tage und werden durch die Rotation ungültig, wenn der zugehörige User sein Passwort ändert. Das ist das korrekte, beabsichtigte Verhalten (D-41-C). **Kein Breaking Change für bcw**, solange die Rotation ausschließlich on password-change/reset ausgelöst wird.

### Custom Controller-Overrides (VERIFIED)

**RegistrationsController:**
- Überschreibt `update` (Password-Change + Preferences-Update)
- `update_resource`: Wählt zwischen `super` (mit Passwort) und `update_without_password` (ohne Passwort)
- `redirect_to root_path` — hartkodiert, ignoriert `after_update_path_for(resource)` (Zeile 19 kommentiert aus)
- `bypass_sign_in resource, scope: resource_name if sign_in_after_change_password?` — aktiv, weil `sign_in_after_change_password?` Default `true`
- **JTI-Rotation nach PW-Change fehlt komplett**

**SessionsController:**
- JSON-Support für MCP-JWT-Login (`POST /login` mit `Accept: application/json`)
- `skip_forgery_protection if: -> { request.format.json? }` — korrekt
- Keine Probleme identifiziert

**Devise-Default-Controller** (PasswordsController, ConfirmationsController):
- Keine eigenen Controller-Overrides — Devise-Defaults aktiv
- Routes: `/password/new`, `/password/edit`, `/confirmation`

### Mailer-Infrastruktur (VERIFIED)

**Mailer-Views vorhanden:**
- `app/views/devise/mailer/confirmation_instructions.html.erb` — nutzt `custom_link_to`-Helper
- `app/views/devise/mailer/reset_password_instructions.html.erb` — nutzt `custom_link_to`-Helper
- Kein `*.text.erb` für confirmation oder reset (nur für invitation vorhanden)

**Fehlende Mailer-Views:**
- `password_change.html.erb` — Devise sendet diese Mail via `send_password_change_notification`, aber kein Custom-Template → Devise-Gem-Default-View aktiv (funktioniert, aber nicht custom)
- `email_changed.html.erb` — fehlt ebenfalls, Devise-Default aktiv

**Sender-Diskrepanz (KRITISCH):**
- `ApplicationMailer` (Parent von Devise::Mailer): `default from: Carambus.config.support_email` (= `gernot.ullrich@gmx.de`)
- Devise-Initializer: `config.mailer_sender = ENV["SMTP_USERNAME"] || "no-reply@carambus.de"`
- Devise's `devise_mail`-Methode respektiert `config.mailer_sender`, aber der Parent-Mailer setzt `default from:` — welcher gewinnt, ist von der Prioritäts-Auflösung in ActionMailer abhängig. In der Praxis überschreibt `devise_mail` den `headers[:from]` mit `config.mailer_sender` — das könnte mit dem SMTP-Auth-Username divergieren.

**Production-SMTP-Config (carambus-de.rb):**
```ruby
config.action_mailer.smtp_settings = {
  address: 'smtp.gmail.com', port: 587,
  user_name: ENV['SMTP_USERNAME'],
  password: ENV['SMTP_PASSWORD'],
  authentication: 'plain', enable_starttls_auto: true,
  open_timeout: 5, read_timeout: 5  # ← feste Timeouts, kein Retry
}
config.action_mailer.raise_delivery_errors = true  # gut für Fail-Fast
```
**Fehlend:** Kein Retry bei transientem SMTP-Fehler, kein strukturiertes Logging.

**Development-Config:**
- `raise_delivery_errors = false` — Mails scheitern still
- Kein `delivery_method: :letter_opener_web` konfiguriert — letter_opener_web ist im Gemfile, aber nicht aktiviert. Dev-Mails werden wahrscheinlich via `:test`-Adapter oder einfach not delivered.

**Test-Config:**
- `delivery_method = :test` — korrekt, `ActionMailer::Base.deliveries` ist nutzbar

### Registrierungs-View (VERIFIED)

`app/views/devise/registrations/new.html.erb`:
- `f.check_box :terms_of_service` ist vorhanden (Zeile 48) — kein i18n-Key, Hardcode `"I accept the Terms of Service"`
- `invisible_captcha` ist gerendert (Zeile 44), aber kein `invisible_captcha`-Controller-Macro in `RegistrationsController` → Honeypot wird nicht server-seitig enforced (bestätigt durch Skip-Test in `users/registrations_controller_test.rb:52`)
- Labels für `first_name`, `last_name` sind hartkodiert ("First name", "Last name"), keine `t()`-Calls

### Existing Test-Coverage-Gaps (VERIFIED)

| Layer | Was existiert | Was fehlt |
|-------|--------------|-----------|
| Model (Layer 1) | JTI-Spalten-Tests, jwt_revoked?, revoke_jwt in user_test.rb | Kein Test: JTI-Rotation bei PW-Change, JTI-Rotation bei PW-Reset |
| Controller (Layer 2) | 2 Tests: update preferences, update password | Kein Test: POST /users (Registrierung), POST /confirmation (resend), POST /password (forgot), GET/PATCH /password (reset), Forgot-Password-Flow HTTP |
| Mailer (Layer 3) | Kein `test/mailers/`-Verzeichnis | Komplett fehlend: confirmation_instructions, reset_password_instructions, password_change, email_changed — Subject/From/To/Body/Token |
| E2E (Layer 4) | user_authentication_test.rb: Login, Logout, Roles | Kein Test: vollständiger Registrierungs-Confirmation-Flow, Forgot-Password+Reset-Link-Klick, PW-Change mit JTI-Revoke, Email-Change Reconfirmation |

---

## Standard Stack

### Core (bereits im Gemfile — keine Installation nötig)

| Library | Version | Purpose |
|---------|---------|---------|
| devise | 4.9.4 | Auth-Framework |
| devise-jwt | 0.13.0 | JWT-Revocation via JTIMatcher |
| devise-i18n | ~> 1.10 | i18n-Strings für Devise-Views |
| letter_opener_web | ~> 3.0 | Dev-Mail-Preview (group :development) |
| invisible_captcha | ~> 2.0 | Honeypot-Spam-Schutz |

**Keine neuen Gems nötig.** Alle Dependencies bereits vorhanden.

### Patterns für Test-Layer

```ruby
# Layer 3: Mailer-Test (ActionMailer::TestCase)
class Devise::MailerTest < ActionMailer::TestCase
  test "confirmation_instructions mail" do
    user = users(:valid)
    user.update!(confirmed_at: nil, confirmation_token: nil)
    user.send_confirmation_instructions
    
    mail = ActionMailer::Base.deliveries.last
    assert_equal [user.email], mail.to
    assert_includes mail.subject, I18n.t("devise.mailer.confirmation_instructions.subject")
    assert_includes mail.body.to_s, "/confirmation?confirmation_token="
  end
end

# Layer 2: Controller/Request-Test
class PasswordsControllerTest < ActionDispatch::IntegrationTest
  test "forgot password email is sent" do
    user = users(:valid)
    assert_difference "ActionMailer::Base.deliveries.size", 1 do
      post user_password_path, params: { user: { email: user.email } }
    end
    assert_redirected_to new_user_session_path
  end
end
```

---

## Architecture Patterns

### JTI-Rotation bei Password-Change/Reset

**Muster:** `after_update`-Callback auf User-Modell oder direkte Integration im Controller.

**Empfohlener Ansatz — Controller-Integration (D-41-A Compliance):**

```ruby
# app/controllers/registrations_controller.rb
def update_resource(resource, params)
  # ... bestehender Code ...
  if params[:password].present?
    result = super
    if result
      # D-41-C: Hard-Revoke aller JWT nach erfolgreichem PW-Change
      User.revoke_jwt(nil, resource)
    end
    result
  else
    resource.update_without_password(params.except(:current_password))
  end
end
```

**ACHTUNG:** `sign_in_after_change_password` muss auf `false` gesetzt werden (oder explizit in der After-Action behandelt), damit der User wirklich neu einloggen muss. Sonst: JTI rotiert, aber `bypass_sign_in` setzt neue Session → User merkt nichts.

**Für Password-Reset (Devise-Default PasswordsController):**
```ruby
# OPTION A: Custom PasswordsController (minimal) mit After-Hook
class PasswordsController < Devise::PasswordsController
  def update
    super do |resource|
      if resource.errors.empty?
        User.revoke_jwt(nil, resource)
      end
    end
  end
end
```

**OPTION B: Model-Callback (einfacher, weniger Controller-Proliferation):**
```ruby
# app/models/user.rb
after_update :rotate_jti_on_password_change, if: :saved_change_to_encrypted_password?

private

def rotate_jti_on_password_change
  self.class.revoke_jwt(nil, self)
end
```

Option B ist cleaner (kein neuer Controller), aber läuft bei JEDEM encrypted_password-Update (auch bei admin-gesteuerten Updates). Option A ist gezielter. Empfehlung für Plan-Phase: **Option B bevorzugen** als minimaler Eingriff (CONTEXT.md Anti-Pattern: "Don't rewrite Devise").

### Gmail-SMTP-Härtung

**Fail-Fast in Production bei fehlender ENV:**
```ruby
# config/initializers/smtp_guard.rb (NEU)
if Rails.env.production? && ENV["SMTP_USERNAME"].blank?
  raise "SMTP_USERNAME not set — Devise mailer will use wrong sender. Aborting."
end
```

**Retry-Pattern via ActionMailer-Job:**
Devise sendet Mails via `deliver_now` (synchron). Für Retry-Logik muss man entweder:
- `deliver_later` verwenden (Sidekiq-Queue) mit `retry_on` auf dem Job
- Oder einen Mail-Interceptor/Observer für Logging registrieren

**ACHTUNG:** Devise-Mailer-Calls (`send_devise_notification`) nutzen intern `deliver_now`. Umschaltung auf `deliver_later` erfordert Devise-Config:
```ruby
# config/initializers/devise.rb
config.mailer.delivery_method = :async  # Devise-spezifisch, nicht Standard-Rails
```
Oder Alternative: `config.action_mailer.deliver_later_queue_name = :mailers` und Devise-Mails via `deliver_later` in Custom-Mailer-Klasse.

**Empfehlung für Plan-Phase:** Einfacher Logging-Observer ist ausreichend für D-41-B (kein komplexes Retry nötig):

```ruby
# config/initializers/mail_observer.rb
class MailDeliveryObserver
  def self.delivered_email(message)
    Rails.logger.tagged("MAILER") do
      Rails.logger.info "Mail delivered: to=#{message.to&.join(',')} subject=#{message.subject}"
    end
  end

  def self.delivery_failed(message, error)
    Rails.logger.tagged("MAILER") do
      Rails.logger.error "Mail FAILED: to=#{message.to&.join(',')} error=#{error.class}: #{error.message}"
    end
  end
end
ActionMailer::Base.register_observer(MailDeliveryObserver)
```

Für Retry: ActiveJob `retry_on` auf einem Custom-MailJob (Devise liefert `:async`-Delivery-Method-Support seit 4.x):

```ruby
# app/jobs/devise_mail_job.rb
class DeviseMailJob < ApplicationJob
  retry_on Net::SMTPAuthenticationError, wait: 30.seconds, attempts: 3
  retry_on Net::SMTPServerBusy, wait: :exponentially_longer, attempts: 5
  discard_on Net::SMTPFatalError  # Permanenter Fehler → nicht retrien

  def perform(mailer_class, mailer_method, *args)
    mailer_class.constantize.send(mailer_method, *args).deliver_now
  end
end
```

### letter_opener_web Aktivierung

letter_opener_web ist im Gemfile vorhanden, aber nicht konfiguriert in development-carambus.rb. Fehlende Konfiguration:

```ruby
# config/environments/development-carambus.rb (ergänzen)
config.action_mailer.delivery_method = :letter_opener_web
config.action_mailer.perform_deliveries = true
config.action_mailer.raise_delivery_errors = true
```

```ruby
# config/routes.rb (ergänzen, falls nicht vorhanden)
if Rails.env.development?
  mount LetterOpenerWeb::Engine, at: "/letter_opener"
end
```

### Test-Infrastruktur: letter_opener für E2E-Tests

In Minitest-System-Tests kann der Mail-Body aus `ActionMailer::Base.deliveries` extrahiert werden (kein echter letter_opener-Ordner nötig):

```ruby
# test/support/mail_helpers.rb (NEU)
module MailHelpers
  def last_email
    ActionMailer::Base.deliveries.last
  end

  def extract_confirmation_url(mail)
    body = mail.body.to_s
    uri = body.match(%r{http[s]?://[^\s"]+/confirmation\?[^\s"]+})
    uri&.to_s
  end

  def extract_reset_password_url(mail)
    body = mail.body.to_s
    uri = body.match(%r{http[s]?://[^\s"]+/password/edit\?[^\s"]+})
    uri&.to_s
  end
end
```

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Confirmation-Token-Generierung | Custom Token-Logik | Devise `:confirmable` Modul | Devise nutzt `Devise.token_generator` mit Hashing; Custom-Tokens sind kryptografisch schwächer |
| SMTP-Retry | Custom Net::SMTP-Retry-Loop | `retry_on` auf ActiveJob | ActiveJob bietet exponential backoff + discard_on für permanente Fehler |
| JWT-Revocation | Eigene JWT-Blocklist-Table | `JTIMatcher.revoke_jwt` | JTIMatcher ist bereits installiert, getestet, patternkonform |
| Mail-Logging | Custom Mail-Hooks | `ActionMailer::Base.register_observer` | Standard-Rails-API, testbar, kein Monkey-Patching |
| Honeypot-Enforcement | Eigene Spam-Guard | `invisible_captcha`-Macro im Controller | Gem bereits im Stack; Controller-Macro fehlt nur |

---

## Common Pitfalls

### Pitfall 1: sign_in_after_change_password blockiert JTI-Revoke-Effekt

**Was schief geht:** `User.revoke_jwt` rotiert den JTI korrekt, aber `bypass_sign_in` setzt sofort eine neue Session → User bleibt eingeloggt → alle anderen Devices sehen die neuen JTIs korrekt als ungültig, aber der aktuelle Browser-Request erhält sofort eine neue valid Session. Das ist technisch korrekt für Browser-Auth (Cookie-basiert), aber kontraintuitiv für die User-Experience.

**Warum:** `config.sign_in_after_change_password = true` (Devise-Default, auskommentiert in devise.rb:331 = aktiv).

**Lösung:** `config.sign_in_after_change_password = false` setzen — User muss sich nach PW-Änderung neu einloggen. Das ist D-41-C-konform: "User muss sich auf allen Geräten neu einloggen."

**Warning signs:** Test `"should update password..."` redirected to `root_path(locale: "en")` — wenn der User weiterhin eingeloggt ist nach PW-Change, fehlt der Revoke-Effekt für die aktuelle Session.

### Pitfall 2: Fixture-User sind confirmed_at, aber neue User in Tests nicht

**Was schief geht:** Tests die `User.create!` aufrufen (ohne Fixture), erzeugen un-confirmed User. `allow_unconfirmed_access_for = 7.days` lässt sie zwar einloggen, aber Devise-Mailer sendet bei jedem Login eine neue confirmation_instructions-Mail → `ActionMailer::Base.deliveries` enthält unerwartete Mails.

**Lösung:** In Tests entweder `user.skip_confirmation!` aufrufen (ACHTUNG: ist in user.rb überschrieben und tut nichts!) oder `user.confirm!` aufrufen, oder Fixtures nutzen.

**KRITISCH:** `skip_confirmation!` in user.rb ist eine leere Methode (Zeile 55-56). Das ist ein bewusster Override der Devise-Methode. Tests die `skip_confirmation!` aufrufen, werden nicht bestätigt. Stattdessen: `user.update_column(:confirmed_at, Time.current)` für Tests.

### Pitfall 3: Devise-Mailer From-Adresse divergiert von SMTP-Auth

**Was schief geht:** `ApplicationMailer` (Parent) setzt `default from: Carambus.config.support_email` = `gernot.ullrich@gmx.de`. Gmail-SMTP-Auth-Username ist `ENV["SMTP_USERNAME"]`. Falls beide divergieren, kann Gmail den Versand ablehnen (5xx-Error) oder die Mail in Spam einstufen.

**Lösung:** `Devise.mailer_sender` explizit auf den SMTP-Auth-Username setzen, ODER ApplicationMailer-`default from:` angleichen. In Tests: `ENV["SMTP_USERNAME"]` setzen oder direkt die From-Adresse im Mailer-Test assertieren.

### Pitfall 4: Confirmation-URL nutzt custom_link_to — Mailer-Kontext fehlende Helper

**Was schief geht:** `app/views/devise/mailer/confirmation_instructions.html.erb` nutzt `custom_link_to`. Devise::Mailer erbt von ApplicationMailer, der `helper ApplicationHelper` includiert. Falls `custom_link_to` in einem Mailer-Context einen Request erwartet (z.B. für URL-Generierung), kann das im Test-Kontext zu Fehlern führen.

**Analyse (Low Risk):** `custom_link_to` ist in `ApplicationHelper` definiert und nutzt `link_to` + `capture` — keine Request-Abhängigkeit. Turbo-Attribute werden gesetzt. Sollte in Mailer-Context funktionieren.

### Pitfall 5: JTI-Rotation bei Password-Reset (Devise-Default PasswordsController)

**Was schief geht:** Devise's `PasswordsController#update` ruft `resource.reset_password(params)` → `save` auf User auf. Wenn JTI-Rotation per `after_update`-Callback auf User implementiert wird, feuert dieser bei JEDEM `encrypted_password`-Update, auch bei Admin-Updates.

**Analyse:** Der `after_update`-Callback auf `saved_change_to_encrypted_password?` ist der einfachste sichere Ansatz — er ist unabhängig vom Aufruf-Pfad korrekt. Wenn Admin-Updates ebenfalls JTI rotieren sollen (Security-Best-Practice: ja), ist das das richtige Verhalten.

### Pitfall 6: letter_opener_web nicht aktiviert in Development

**Was schief geht:** Gem ist im Gemfile, aber `delivery_method: :letter_opener_web` fehlt in development-carambus.rb. Dev-Mails werden still gedroppt oder via `:test`-Adapter in `deliveries`-Array gesammelt aber nie angezeigt.

**Lösung:** delivery_method konfigurieren + Route mounten (siehe Architecture Patterns).

---

## Code Examples

### Layer-3-Mailer-Test-Pattern (Standard für diese Phase)

```ruby
# test/mailers/devise_mailer_test.rb (NEU)
# frozen_string_literal: true

require "test_helper"

class DeviseMailerTest < ActionMailer::TestCase
  setup do
    ActionMailer::Base.deliveries.clear
    @user = users(:valid)
  end

  test "confirmation_instructions: korrekte Empfänger, Subject, Token-URL" do
    @user.update_columns(confirmed_at: nil)
    @user.send_confirmation_instructions

    assert_equal 1, ActionMailer::Base.deliveries.size
    mail = ActionMailer::Base.deliveries.last
    assert_equal [@user.email], mail.to
    assert_includes mail.subject, I18n.t("devise.mailer.confirmation_instructions.subject")
    assert_includes mail.body.to_s, "/confirmation?confirmation_token="
  end

  test "reset_password_instructions: Token-URL enthält reset_password_token" do
    @user.send_reset_password_instructions

    mail = ActionMailer::Base.deliveries.last
    assert_includes mail.body.to_s, "/password/edit?reset_password_token="
    assert_includes mail.body.to_s, @user.reset_password_token  # raw token
  end

  test "password_change_notification bei send_password_change_notification=true" do
    I18n.with_locale(:de) do
      @user.send(:send_password_change_notification)
    end
    mail = ActionMailer::Base.deliveries.last
    assert_includes mail.subject, "Passwort"  # DE locale
  end
end
```

### JTI-Rotation via Model-Callback (Empfehlung)

```ruby
# app/models/user.rb (Ergänzung, NICHT Neuentwurf)
after_update :rotate_jti_on_password_change!, if: :saved_change_to_encrypted_password?

private

# D-41-C: Hard-Revoke aller JWT bei jedem Passwort-Update
# Neue jti macht alle vorher ausgestellten JWTs ungültig.
# carambus_bcw-MCP-JWTs sind davon betroffen — gewollt bei PW-Kompromittierung.
def rotate_jti_on_password_change!
  self.class.revoke_jwt(nil, self)
end
```

### Fail-Fast für SMTP in Production

```ruby
# config/initializers/smtp_guard.rb (NEU)
# frozen_string_literal: true

# D-41-B: Fail-Fast bei fehlendem SMTP_USERNAME in Production.
# Verhindert, dass Devise-Mails mit "no-reply@carambus.de" als Sender abgesendet
# werden, wenn Gmail-Auth-Username unbekannt ist (führt zu SMTP-Rejection).
if Rails.env.production?
  if ENV["SMTP_USERNAME"].blank? || ENV["SMTP_PASSWORD"].blank?
    raise "FATAL: SMTP_USERNAME/SMTP_PASSWORD not set. " \
      "Devise mailer cannot authenticate with Gmail SMTP. Aborting startup."
  end
end
```

---

## i18n-Coverage-Analyse

### DE-Locale (devise.de.yml) — VOLLSTÄNDIG [VERIFIED]

Alle relevanten Sections vorhanden:
- `devise.mailer.confirmation_instructions` (subject, greeting, instruction, action) ✓
- `devise.mailer.reset_password_instructions` (subject, greeting, instruction, instruction_2, instruction_3, action) ✓
- `devise.mailer.password_change` (subject, greeting, message) ✓
- `devise.mailer.email_changed` (subject, greeting, message, message_unconfirmed) ✓
- `devise.registrations.new` (sign_up, login_html, submitting, terms_html) ✓
- `devise.registrations.edit` (title, update, current_password, change_password usw.) ✓
- `devise.passwords.new/edit` (forgot_your_password, send_me_reset_password_instructions) ✓

### EN-Locale (devise.en.yml) — VOLLSTÄNDIG [VERIFIED]

Alle gleichen Sections auf Englisch vorhanden und vollständig. Kein i18n-Gap.

### Registrierungs-View: Hartkodierte Strings (GEFUNDEN)

In `app/views/devise/registrations/new.html.erb`:
- `"I accept the Terms of Service"` (Zeile 49) — nicht via `t()`, nur EN-Text
- `"First name"`, `"Last name"` als Label-Text hartkodiert (aber da D-41-D View-Restyling Out-of-Scope ist, ist das Risiko akzeptierbar)

**System-Test betroffen:** `user_authentication_test.rb:14` nutzt `check 'I accept the Terms of Service'` — dieser Selektor funktioniert nur in EN-Locale. DE-Locale würde einen anderen Label-Text erfordern. **Derzeit fixiert auf `:en` im Test** (Zeile 9: `visit new_user_registration_path(locale: :en)`) — korrekt.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Ruby 3.2.1 | Alles | ✓ | 3.2.1 | — |
| PostgreSQL | User-Model, jti-Spalte | ✓ | lokal vorhanden | — |
| Redis | ActionCable (nicht Devise-kritisch) | ✓ | angenommen | — |
| Gmail-SMTP | Production-Mails | Unbekannt in Dev | — | letter_opener_web für Dev |
| letter_opener_web | Dev-Mail-Preview | ✓ (Gem installiert) | 3.0.0 | — aber nicht konfiguriert! |
| Selenium/Chrome | E2E System-Tests | ✓ | headless_chrome | — |
| invisible_captcha | Registration-Spam-Guard | ✓ | 2.0 | Server-Guard fehlt im Controller |

**Fehlend mit Lösung:**
- letter_opener_web nicht in development-carambus.rb konfiguriert → Wave-0-Aufgabe in Plan-01

---

## Validation Architecture (Nyquist)

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Minitest (Rails default) |
| Config | `test/test_helper.rb` |
| Quick run | `bin/rails test test/mailers/ test/controllers/registrations_controller_test.rb` |
| Full suite | `bin/rails test` |

### Phase Requirements → Test Map

| ID | Behavior | Test Type | Automated Command |
|----|----------|-----------|-------------------|
| AUTH-01 | Registrierung sendet confirmation_instructions Mail | Mailer | `bin/rails test test/mailers/devise_mailer_test.rb` |
| AUTH-02 | Confirmation-Token-URL im Mail klickbar → User confirmed | Controller + E2E | `bin/rails test test/controllers/confirmations_controller_test.rb` |
| AUTH-03 | Forgot-Password sendet reset_password_instructions Mail | Mailer | `bin/rails test test/mailers/devise_mailer_test.rb` |
| AUTH-04 | Reset-Token-URL → neues PW setzbar | Controller | `bin/rails test test/controllers/passwords_controller_test.rb` |
| AUTH-05 | JTI rotiert bei PW-Change → alter JWT ungültig | Model | `bin/rails test test/models/user_test.rb` |
| AUTH-06 | JTI rotiert bei PW-Reset → alter JWT ungültig | Model | `bin/rails test test/models/user_test.rb` |
| AUTH-07 | Change-Password sendet password_change Notification | Mailer | `bin/rails test test/mailers/devise_mailer_test.rb` |
| AUTH-08 | Email-Change → confirmation_instructions an neue Adresse | Mailer + Controller | kombiniert |
| AUTH-09 | Gmail-SMTP Fail-Fast wenn ENV fehlt | Model/Init | `bin/rails test test/initializers/smtp_guard_test.rb` |
| AUTH-10 | E2E Registrierung → Mail → Bestätigung → Einloggen | System | `bin/rails test test/system/devise_flows_test.rb` |

### Wave 0 Gaps (vor Implementierung zu erstellen)

- [ ] `test/mailers/devise_mailer_test.rb` — Layer 3, alle 4 Mailer-Typen
- [ ] `test/controllers/passwords_controller_test.rb` — Forgot + Reset-Flow HTTP
- [ ] `test/controllers/confirmations_controller_test.rb` — Resend + Confirm HTTP
- [ ] `test/support/mail_helpers.rb` — `last_email`, `extract_confirmation_url`, `extract_reset_password_url`
- [ ] `test/system/devise_flows_test.rb` — E2E: Registrierung+Confirmation, Forgot+Reset, PW-Change
- [ ] `config/environments/development-carambus.rb` — letter_opener_web aktivieren

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | ja | Devise mit :confirmable, :recoverable |
| V3 Session Management | ja | JTIMatcher-Rotation bei PW-Change; `sign_in_after_change_password = false` |
| V4 Access Control | nein (nicht Scope dieser Phase) | — |
| V5 Input Validation | ja | `invisible_captcha` (Honeypot), `validates :terms_of_service` |
| V6 Cryptography | ja | Devise bcrypt (stretches=12), JWT via devise-jwt mit `secret_key_base` |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Session-Hijacking nach PW-Reset | Spoofing/Elevation | JTI-Rotation (D-41-C) + `sign_in_after_change_password=false` |
| Account-Enumeration via Reset-Mail | Information Disclosure | `send_paranoid_instructions` (Devise-Config vorhanden) |
| Honeypot-Bypass bei Registrierung | Spoofing | `invisible_captcha` Macro im RegistrationsController nachrüsten |
| SMTP-Credential-Leak | Information Disclosure | ENV-Vars (keine Klartext-Creds im Code), Fail-Fast-Guard |
| Token-Reuse nach Reset | Repudiation | Devise löscht Token nach Verwendung (`clear_reset_password_token`) |

---

## Cross-Repo-Risiken

| Risiko | Einschätzung | Mitigierung |
|--------|-------------|-------------|
| JTI-Rotation bricht MCP-JWT (bcw) | **NIEDRIG** — Rotation nur bei PW-Change ausgelöst, nicht bei normalen Requests | Callback auf `saved_change_to_encrypted_password?` — nur explizite PW-Änderungen |
| User-Modell-Schema-Änderungen | **NIEDRIG** — kein Schema-Change nötig, jti-Spalte existiert | keine Migration erforderlich |
| routes.rb (devise_for) Änderung | **NIEDRIG** — PasswordsController-Override ändert Router-Config | `controllers: { passwords: "passwords" }` hinzufügen falls Custom-Controller |
| SMTP-Guard bricht Dev-Start wenn ENV fehlt | **MITTEL** — Guard darf nur in Production aktiv sein | `if Rails.env.production?` Guard (bereits im Beispiel) |

---

## Open Questions für Plan-Phase

1. **Diagnose-Spike zuerst oder direkt Flow-by-Flow?**
   - Befund: Der IST-Zustand ist bereits gut verstanden (kein echter Diagnose-Spike nötig — Research hat alle Gaps gefunden). Plan-01 könnte direkt als "Wave-0: Test-Infrastruktur + Charakterisierungstests schreiben" starten.
   - Empfehlung: Plan-01 = Mailer-Infrastruktur + Layer-3-Charakterisierungstests; Plan-02 = Registrierung+Confirmation fix; Plan-03 = Forgot/Reset + JTI-Rotation; Plan-04 = Change-Password + JTI-Rotation + SMTP-Härtung; Plan-05 = E2E-Tests + letter_opener-Aktivierung.

2. **Model-Callback vs. Controller-Integration für JTI-Rotation?**
   - Empfehlung: Model-Callback (`after_update` auf `saved_change_to_encrypted_password?`) ist bevorzugt — deckt alle Pfade ab (Controller-Update, Admin-Update, direkte API-Calls).

3. **Custom PasswordsController erforderlich?**
   - Wenn JTI-Rotation via Model-Callback: **Nein** — kein Custom PasswordsController nötig.
   - Wenn JTI-Rotation via Controller-Integration: **Ja** — minimaler Custom-Controller wie im Beispiel.

4. **invisible_captcha im RegistrationsController nachrüsten?**
   - D-41-D schreibt Registrierungs-Restoration vor. Honeypot ist im View gerendert, aber nicht server-seitig enforced. Test `"honeypot is filled and user creation fails"` ist geskippt mit explizitem Kommentar. Empfehlung: Nachrüsten als Teil der Registrierungs-Reparatur.

5. **password_change.html.erb und email_changed.html.erb custom erstellen?**
   - Devise-Defaults funktionieren (kein custom Template nötig für Funktionalität). Für Mailer-Tests reicht der Devise-Default. Empfehlung: Nur erstellen, wenn DE/EN-i18n-Kontrolle nötig — die Devise-Defaults nutzen bereits die devise.*.yml Strings.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Dev-Mails werden wegen fehlender delivery_method-Konfiguration nicht angezeigt | Current State | Falls doch konfiguriert in anderem Env-File: letter_opener-Aktivierung unnötig |
| A2 | `sign_in_after_change_password` Default = true (weil auskommentiert in devise.rb) | Pitfalls | Devise-Default könnte false sein → JTI-Revoke-Seiteneffekt geändert |
| A3 | `custom_link_to` funktioniert im Mailer-Context ohne Fehler | Architecture | Falls Request-Kontext nötig: Mailer-View muss angepasst werden |
| A4 | Gmail-SMTP-Auth akzeptiert Divergenz zwischen From und SMTP-Username nicht | Pitfalls | Gmail könnte permissiver sein → kein SMTP-Error, aber SPF/DKIM-Problem |

---

## Sources

### Primary (HIGH confidence — direkt gelesen)

- `app/models/user.rb` — Devise-Module-Deklaration, JTIMatcher-Include, skip_confirmation!
- `app/controllers/registrations_controller.rb` — Update-Flow, bypass_sign_in
- `app/controllers/sessions_controller.rb` — JSON-Support, JWT-Dispatch
- `config/initializers/devise.rb` — Alle Devise-Einstellungen
- `config/environments/production-carambus-de.rb` — SMTP-Konfiguration
- `app/views/devise/registrations/new.html.erb` — Terms-Checkbox, invisible_captcha
- `config/locales/devise.de.yml`, `config/locales/devise.en.yml` — i18n-Vollständigkeit
- `test/` — Coverage-Gap-Analyse (alle Devise-relevanten Test-Dateien)
- `/Users/gullrich/.rbenv/.../devise-jwt-0.13.0/lib/devise/jwt/revocation_strategies/jti_matcher.rb` — JTIMatcher-Quellcode
- `/Users/gullrich/.rbenv/.../devise-4.9.4/lib/devise/models/recoverable.rb` — Password-Reset-Flow
- `/Users/gullrich/.rbenv/.../devise-4.9.4/app/mailers/devise/mailer.rb` — Mailer-Methoden

### Secondary (MEDIUM confidence)

- Gemfile.lock — Versions-Verifikation: devise 4.9.4, devise-jwt 0.13.0, letter_opener_web 3.0.0

---

## Metadata

**Confidence breakdown:**
- Current State Analysis: HIGH — Code direkt gelesen, keine Spekulation
- JTI-Rotation-Mechanismus: HIGH — Quellcode von devise-jwt gelesen
- SMTP-Härtungs-Patterns: MEDIUM — Standard-Rails-Patterns aus Training, nicht via Context7 verifiziert
- letter_opener-Integration: HIGH — Gemfile + Gemfile.lock + Config-Files gelesen

**Research date:** 2026-05-15
**Valid until:** 2026-06-15 (Devise 4.9.4 ist stabil; devise-jwt 0.13.0 war aktuell)
