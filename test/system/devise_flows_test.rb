# frozen_string_literal: true

require "application_system_test_case"

# D-41-A Layer 4: E2E Browser-Tests fuer alle 4 Devise-Flows (Plan 41-05).
#
# Diese Tests simulieren echte Browser-Flows (Capybara + Selenium) inklusive
# Mail-Token-Click-Through. Mail-Empfang erfolgt im Test-Adapter
# (ActionMailer::Base.deliveries) — keine echte SMTP-Verbindung. Token werden aus
# dem Mail-Body via MailHelpers (Plan 41-01) extrahiert; Capybara navigiert dann
# zur extrahierten URL.
#
# MailHelpers (`last_email`, `clear_mail_queue`, `extract_confirmation_url`,
# `extract_reset_password_url`) ist via `test/test_helper.rb` (Plan 41-01) in
# ApplicationSystemTestCase included — direkt aufrufbar, kein extend-im-setup-
# Workaround.
#
# Locale-Konvention: Tests pinnen sich auf :en — die i18n-Strings ("Sign up",
# "Send me reset password instructions", "Change my password", "Update",
# "I accept the Terms of Service") sind in `config/locales/devise.en.yml` exakt
# so hinterlegt und werden via Capybara `click_button`/`check` exakt gemacht.
#
# Plan-04-Hinweis: User#send_devise_notification queued via DeviseMailJob
# (deliver_later). In IntegrationTest + ActionMailer::TestCase wird via
# test_helper.rb `queue_adapter = :inline` umgeschaltet — ApplicationSystemTestCase
# erbt aber von ActionDispatch::SystemTestCase, NICHT von IntegrationTest, daher
# muss hier explizit ebenfalls auf :inline geschaltet werden, damit Mail-Versand
# synchron geschieht und deliveries.size pruefbar bleibt.
class DeviseFlowsTest < ApplicationSystemTestCase
  # Plan-01 BLOCKER-3-Fix hat `include MailHelpers` in test_helper.rb fuer
  # ApplicationSystemTestCase versucht; durch zirkuläres require_relative greift
  # der Patch jedoch nicht zuverlässig (ASTC ist beim include-Aufruf zwar
  # konstant-definiert, aber include MailHelpers wirkt erst nach dem Body-Eval).
  # Defensive Wiederholung hier — idempotent dank Ruby's Module-Include-Tracking.
  include MailHelpers

  setup do
    @_orig_queue_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :inline
    # Plan 41-02 / invisible_captcha 2.3 Timestamp-Threshold: Default 4s. In
    # Layer-2-IntegrationTests greift `travel(InvisibleCaptcha.timestamp_threshold + 1.second)`
    # weil Test-Prozess + Server-Request im gleichen Thread ablaufen. In System-Tests
    # laeuft der Capybara-Puma-Server in einem separaten Thread/Prozess — Time-Stubbing
    # via `travel` wirkt nicht zuverlaessig auf die Server-Seite. Da InvisibleCaptcha
    # die Threshold per Class-Attribute speichert (thread-shared), schalten wir sie
    # fuer die Dauer der System-Tests auf 0 — Form kann sofort submitted werden.
    @_orig_invisible_captcha_threshold = InvisibleCaptcha.timestamp_threshold
    InvisibleCaptcha.timestamp_threshold = 0
    clear_mail_queue
  end

  teardown do
    ActiveJob::Base.queue_adapter = @_orig_queue_adapter if @_orig_queue_adapter
    InvisibleCaptcha.timestamp_threshold = @_orig_invisible_captcha_threshold if @_orig_invisible_captcha_threshold
  end

  # ============================================================
  # Flow 1: Sign-up + Confirmation
  # ============================================================
  # D-41-D Flow 1: User registriert sich via Browser-Form -> Devise schickt
  # confirmation_instructions Mail -> User klickt Link -> User.confirmed_at gesetzt.
  test "user registers and confirms via email link" do
    email = "e2e-signup-#{SecureRandom.hex(4)}@example.test"
    password = "E2EPasswort123!"

    visit new_user_registration_path(locale: :en)
    fill_in "First name", with: "E2E"
    fill_in "Last name", with: "User"
    fill_in "Email", with: email
    fill_in "Password", with: password
    fill_in "Password confirmation", with: password
    check "I accept the Terms of Service"
    # invisible_captcha-Timestamp-Threshold ist via setup auf 0 gesetzt — Form
    # kann sofort submitted werden (siehe Setup-Kommentar).
    click_button "Sign up"

    # Auf serverseitiges Verarbeiten warten: Capybara wartet asynchron auf naechste
    # Page — User-Eintrag muss in DB sein. Polling-Loop, da Mail-Versand via :inline
    # Job-Adapter direkt nach DB-Save erfolgt.
    user_in_db = nil
    Timeout.timeout(10) do
      loop do
        user_in_db = User.find_by(email: email)
        break if user_in_db
        sleep 0.1
      end
    end
    refute_nil user_in_db, "User muss durch Submit erstellt werden — Form-Submit-Pfad failed"

    # Devise schickt confirmation_instructions an die neue Email-Adresse.
    mail = last_email
    refute_nil mail, "Confirmation-Mail muss versendet werden (deliveries.size == #{ActionMailer::Base.deliveries.size})"
    assert_equal [email], mail.to
    assert_match(/confirm/i, mail.subject.to_s)

    confirmation_url = extract_confirmation_url(mail)
    refute_nil confirmation_url, "Confirmation-URL muss aus Mail-Body extrahierbar sein"

    # URL hat den vollen host:port aus default_url_options; Capybara akzeptiert
    # sowohl absolute als auch relative URLs — wir extrahieren path+query, damit
    # der Test gegen den Capybara-Server-Port faehrt, nicht gegen einen anderen.
    uri = URI(confirmation_url)
    visit "#{uri.path}?#{uri.query}"

    # Devise-Default: nach Confirmation-Click -> redirect zu Login mit Flash
    # "Your email address has been successfully confirmed." (devise.en.yml: 4)
    # bzw. "Ihre E-Mail-Adresse wurde erfolgreich bestätigt" (DE) — Mail-URL hat
    # keinen Locale-Param, daher faellt Devise auf den Default zurueck (:de).
    # Beide Sprachen akzeptieren, Hauptaussage: Confirmation hat geklappt.
    assert_text(/confirmed|bestätigt/i, wait: 5)

    # Sanity: User existiert + ist confirmed in der DB.
    user = User.find_by(email: email)
    refute_nil user, "User muss durch Registrierung erstellt worden sein"
    refute_nil user.confirmed_at, "User.confirmed_at muss nach Confirm-Click gesetzt sein"
  end

  # ============================================================
  # Flow 2: Forgot-Password + Reset + JTI-Rotation
  # ============================================================
  # D-41-D Flow 2: User vergisst Passwort -> /password/new -> Mail mit Reset-Link
  # -> Click -> /password/edit -> neues PW -> Devise rotiert encrypted_password
  # -> Plan-03-Callback rotiert User.jti (Hard-Revoke alter JWT-Tokens, D-41-C).
  test "user resets password via forgot-password email link" do
    user = users(:valid)
    # Plan 41-03 Backfill-Pattern: Fixture hat kein jti gesetzt; Production-Backfill
    # liefert UUID. Damit das after_update-JTI-Rotation-Verhalten testbar ist,
    # muss ein Startwert vorhanden sein (sonst ist nil != "neue UUID" ohnehin true).
    user.update_column(:jti, SecureRandom.uuid) if user.jti.blank?
    old_jti = user.jti

    visit new_user_password_path(locale: :en)
    fill_in "Email", with: user.email
    click_button "Send me reset password instructions"

    # Server-Side Mail-Versand erfolgt asynchron zum Capybara-Browser-Klick —
    # auf Mail-Eintreffen polling-warten (Capybara-typisches Pattern via
    # wait_for_mail-Helper, siehe File-Ende).
    mail = wait_for_mail(to: user.email)
    refute_nil mail, "Reset-Password-Mail muss versendet werden"
    assert_equal [user.email], mail.to
    assert_match(/reset password/i, mail.subject.to_s)

    reset_url = extract_reset_password_url(mail)
    refute_nil reset_url, "Reset-Password-URL muss aus Mail-Body extrahierbar sein"
    uri = URI(reset_url)
    # Mail-URL hat keinen locale-Param — Devise-Form rendert dann mit Default-Locale (:de).
    # Wir pinnen locale=en damit die Capybara-Selektoren auf den EN-i18n-Strings matchen.
    visit "#{uri.path}?#{uri.query}&locale=en"

    new_password = "NeuesE2EPasswort123!"
    fill_in "New password", with: new_password
    fill_in "Confirm new password", with: new_password
    click_button "Change my password"

    # Plan 41-03 D-41-C Hard-Revoke verifizieren: after_update-Callback im User-Modell
    # rotiert jti, sobald encrypted_password sich aendert. Das beweist E2E,
    # dass der Layer-1-Callback (user_test.rb) auch ueber den HTTP- + Browser-Pfad
    # bis ins Modell durchschlaegt — Regression-Garantie fuer kommende Refactorings.
    # Polling-Wait noetig: Server-Save passiert asynchron zum Capybara-Click.
    new_jti = wait_until { user.reload.jti != old_jti && user.jti }
    assert_not_equal old_jti, new_jti,
      "Plan-03 JTI-Rotation muss nach Browser-Pfad-Reset gegriffen haben (alter JWT revoked)"
  end

  # ============================================================
  # Flow 3: Change-Password eingeloggt + Re-Login-Pflicht (D-41-C / Plan 41-04)
  # ============================================================
  # D-41-D Flow 3: User eingeloggt -> /users/edit -> PW-Change ueber Form
  # -> Devise verarbeitet PATCH /users -> sign_in_after_change_password=false greift
  # -> User wird abgemeldet -> Folge-Request auf geschuetzte Seite -> Redirect zu Login.
  test "user changes password and is forced to re-login" do
    user = users(:valid)
    user.update_column(:jti, SecureRandom.uuid) if user.jti.blank?
    old_jti = user.jti

    # Devise-Test-Integration-Helper (in ApplicationSystemTestCase included via
    # Devise::Test::IntegrationHelpers). Setzt Warden-Session deterministisch —
    # vermeidet invisible_captcha + Timestamp-Race der echten Login-Form.
    sign_in user

    visit edit_user_registration_path(locale: :en)
    # Locale-Hinweis: Die Custom-Edit-View nutzt locale-Pfad-Param NICHT konsistent
    # (User-Preferences-Locale ueberschreibt). Daher Felder ueber input-name-Attribut
    # ansprechen statt Label-Text — sprachunabhaengig + stabil ueber locale-Wechsel.
    fill_in "user[current_password]", with: "password" # Klartext aus test/fixtures/users.yml
    fill_in "user[password]", with: "ChangedE2EPasswort123!"
    fill_in "user[password_confirmation]", with: "ChangedE2EPasswort123!"
    click_button "Update"

    # Plan 41-04 D-41-C: sign_in_after_change_password=false -> Devise meldet
    # die aktuelle Session ab. Folge-Request auf eine eingeloggte Seite (=Edit)
    # landet via Devise-before_action auf der Login-Seite. Wichtig: edit_user_registration_path
    # ist eine Devise-authenticated Route — nicht / (das ist potentiell public).
    # Wait fuer asynchrone Server-PW-Save + Session-Cleanup.
    wait_until(timeout: 5) do
      visit edit_user_registration_path(locale: :en)
      current_path.match?(%r{/login})
    end
    assert_current_path %r{/login}, wait: 5

    # Plan-03-Callback feuert auch hier (gleicher encrypted_password-Change-Pfad).
    user.reload
    assert_not_equal old_jti, user.jti,
      "JTI-Rotation muss auch fuer Change-Password-Pfad greifen (kein Drift Plan-03 <-> Plan-04)"

    # Plan-04: password_change Notification-Mail wird via Devise's automatic
    # password_change-Hook versendet — Hauptaussage: mindestens 1 Mail an User
    # mit Password-bezogenem Subject in deliveries.
    change_mail = ActionMailer::Base.deliveries.find do |m|
      m.to == [user.email] && m.subject.to_s.match?(/password/i)
    end
    refute_nil change_mail, "password_change-Notification-Mail muss vorhanden sein"
  end

  # ============================================================
  # Flow 4: Email-Change + Reconfirmation (D-41-D Flow 4 / Plan 41-04)
  # ============================================================
  # D-41-D Flow 4: User aendert Email -> Devise reconfirmable=true setzt
  # unconfirmed_email (NICHT email), versendet confirmation_instructions an NEUE
  # Adresse -> Click bestaetigt -> email springt auf neuen Wert.
  test "user changes email and confirms via reconfirmation link" do
    user = users(:valid)
    original_email = user.email
    new_email = "e2e-newemail-#{SecureRandom.hex(4)}@example.test"

    sign_in user

    visit edit_user_registration_path(locale: :en)
    # Felder ueber name-Attribut (sprachunabhaengig), siehe Test 3 fuer Begruendung.
    fill_in "user[email]", with: new_email
    fill_in "user[current_password]", with: "password"
    click_button "Update"

    # reconfirmable=true: alte email bleibt erhalten, neue landet in unconfirmed_email.
    # Polling-Wait fuer Server-Save (Capybara-Click ist asynchron zum DB-Write).
    wait_until { user.reload.unconfirmed_email == new_email }
    assert_equal original_email, user.email,
      "Vor Reconfirmation muss alte email weiterhin in user.email stehen"
    assert_equal new_email, user.unconfirmed_email,
      "Nach PATCH muss neue email in user.unconfirmed_email gehen"

    # confirmation_instructions an NEUE Adresse — devise reconfirmable verschickt
    # ueber DeviseMailer.confirmation_instructions(record, token, opts).
    confirm_mail = wait_for_mail(to: new_email)
    refute_nil confirm_mail, "Reconfirmation-Mail an neue Adresse muss vorhanden sein"

    confirm_url = extract_confirmation_url(confirm_mail)
    refute_nil confirm_url, "Reconfirmation-URL muss aus Mail-Body extrahierbar sein"
    uri = URI(confirm_url)
    visit "#{uri.path}?#{uri.query}"

    # Nach Confirm-Click: Devise-Default schaltet email := unconfirmed_email
    # und setzt unconfirmed_email auf NULL.
    wait_until { user.reload.email == new_email }
    assert_equal new_email, user.email,
      "Nach Reconfirmation-Click muss email auf neuen Wert gesetzt sein"
    assert_nil user.unconfirmed_email,
      "Nach Reconfirmation-Click muss unconfirmed_email zurueckgesetzt sein"
  end

  private

  # Server-Side Mail-Versand erfolgt asynchron zum Capybara-Browser-Klick.
  # Auch mit :inline-Adapter ist Devise's send_devise_notification noch
  # eine Race-Strecke zwischen DB-Save + Job-perform + ActionMailer.delivery.
  # Polling-Helper wartet, bis eine Mail (optional an `to:`) in
  # ActionMailer::Base.deliveries auftaucht. Default-Timeout 10s analog zu
  # Capybara.default_max_wait_time.
  def wait_for_mail(to: nil, timeout: 10)
    Timeout.timeout(timeout) do
      loop do
        mail = if to
          ActionMailer::Base.deliveries.find { |m| m.to == [to] }
        else
          ActionMailer::Base.deliveries.last
        end
        return mail if mail
        sleep 0.1
      end
    end
  rescue Timeout::Error
    nil
  end

  # Polling-Helper, wartet bis Block einen truthy Wert zurueckliefert oder
  # Timeout erreicht ist. Liefert den letzten Block-Returnwert (nil bei Timeout).
  # Verwendet fuer DB-State-Checks nach Capybara-Submits (async Server-Save).
  def wait_until(timeout: 10)
    Timeout.timeout(timeout) do
      loop do
        result = yield
        return result if result
        sleep 0.1
      end
    end
  rescue Timeout::Error
    nil
  end
end
