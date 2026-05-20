# frozen_string_literal: true

require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:regular)
    sign_in @user
  end

  test "should update preferences" do
    get edit_user_registration_path
    assert_response :success

    patch user_registration_path, params: {
      user: {
        theme: "dark",
        locale: "de",
        timezone: "Vienna"
      }
    }

    assert_redirected_to root_path
    assert_equal "dark", @user.reload.preferences["theme"]
    assert_equal "de", @user.preferences["locale"]
    assert_equal "Vienna", @user.preferences["timezone"]
  end

  test "should update password with valid current password" do
    @user.update!(preferences: {"locale" => "en"})

    patch user_registration_path, params: {
      user: {
        current_password: "password",
        password: "newpassword",
        password_confirmation: "newpassword"
      }
    }

    assert_redirected_to root_path(locale: "en")
    assert @user.reload.valid_password?("newpassword")
  end

  # Plan 41-02 Task 1: Anonyme Tests fuer den Registrierungs-Flow (POST /users).
  # Setup-Block oben ruft sign_in @user auf — fuer Registrierungstests muessen wir
  # uns abmelden (anonym posten), damit Devise den :sign_up-Flow durchlaeuft.
  class AnonymousRegistrationTest < ActionDispatch::IntegrationTest
    # Plan 41-02 Task 1: invisible_captcha 2.3 erzwingt drei Spam-Checks (Timestamp,
    # Spinner-HMAC-Field, Honeypot). Helper liefert valide Captcha-Vorbereitung:
    # GET der Form (setzt Session-Timestamp), Spinner-Extraktion aus Response-Body,
    # Time-Travel ueber den Threshold (Default 4s).
    def prepare_captcha_for_post
      get new_user_registration_path
      assert_response :success
      spinner = response.body[/name="spinner"\s+value="([^"]+)"/, 1]
      refute_nil spinner, "Spinner-Hidden-Field muss im Registrierungs-Form sein"
      travel(InvisibleCaptcha.timestamp_threshold + 1.second)
      spinner
    end

    teardown do
      travel_back
    end

    test "POST /users mit gueltigen Params versendet 1 confirmation_instructions Mail" do
      ActionMailer::Base.deliveries.clear
      email = "neu-#{SecureRandom.hex(4)}@example.test"
      spinner = prepare_captcha_for_post
      assert_difference -> { User.count }, 1 do
        assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
          post user_registration_path, params: {
            user: {
              email: email,
              password: "GueltigesPasswort123!",
              password_confirmation: "GueltigesPasswort123!",
              first_name: "Neu",
              last_name: "User",
              terms_of_service: "1"
            },
            spinner: spinner
          }
        end
      end
      mail = ActionMailer::Base.deliveries.last
      assert_equal [email], mail.to
      assert_match %r{/confirmation\?confirmation_token=}, mail.body.to_s
    end

    test "POST /users mit terms_of_service=0 (explizit abgelehnt) wird abgewiesen" do
      # Hinweis: Rails `acceptance: true`-Validation greift NUR bei explizit falsy-Werten
      # (z.B. "0"). Wenn das Feld komplett fehlt (nil), wird die Validation NICHT erzwungen
      # — das ist Rails-Default-Verhalten. Daher testen wir explizit den abgelehnten Fall.
      ActionMailer::Base.deliveries.clear
      spinner = prepare_captcha_for_post
      assert_no_difference -> { User.count } do
        assert_no_difference -> { ActionMailer::Base.deliveries.size } do
          post user_registration_path, params: {
            user: {
              email: "no-terms-#{SecureRandom.hex(4)}@example.test",
              password: "GueltigesPasswort123!",
              password_confirmation: "GueltigesPasswort123!",
              first_name: "No",
              last_name: "Terms",
              terms_of_service: "0" # explizit abgelehnt
            },
            spinner: spinner
          }
        end
      end
      # Devise rendert :new mit Validation-Error
      assert_response :unprocessable_entity
    end
  end

  # === Plan 41-04 Task 1: D-41-D Flow 3 (Change-Password) + Flow 4 (Email-Change-Reconfirmation) ===
  #
  # Diese Tests pinnen das Verhalten nach D-41-C-Hard-Revoke + sign_in_after_change_password=false.
  # Voraussetzung: Plan 41-03 hat den after_update :rotate_jti_on_password_change!-Callback
  # eingebaut. Plan 41-04 Task 1 setzt zusaetzlich Devise.sign_in_after_change_password = false,
  # damit die User-Session nach PW-Change abgemeldet wird (D-41-C "User muss neu einloggen").
  #
  # Klartext-Password fuer Fixture `valid`: "password" (siehe test/fixtures/users.yml:77 —
  # `Devise::Encryptor.digest(User, 'password')`). Wird in den 3 Tests als current_password
  # verwendet.

  test "PATCH /users mit current_password+password rotiert jti und versendet password_change-Mail" do
    user = users(:valid)
    user.update_column(:jti, SecureRandom.uuid) if user.jti.blank?
    old_jti = user.jti
    old_encrypted = user.encrypted_password
    sign_in user
    ActionMailer::Base.deliveries.clear

    patch user_registration_path, params: {
      user: {
        current_password: "password",
        password: "NeuesPasswort123!",
        password_confirmation: "NeuesPasswort123!"
      }
    }

    user.reload
    assert_not_equal old_encrypted, user.encrypted_password, "PW muss aendern"
    assert_not_equal old_jti, user.jti, "jti muss rotieren (Plan-03 Callback)"

    # send_password_change_notification = true (Devise-Config) → 1 Notification-Mail
    mails = ActionMailer::Base.deliveries
    assert_operator mails.size, :>=, 1, "Mind. 1 Mail (password_change Notification)"
    pw_change_mail = mails.find { |m| m.to == [user.email] && m.subject.match?(/Passwort|Password/) }
    refute_nil pw_change_mail, "password_change-Notification fehlt"
  end

  test "Nach PATCH /users mit PW-Change ist User NICHT mehr eingeloggt (sign_in_after_change_password=false)" do
    user = users(:valid)
    sign_in user

    patch user_registration_path, params: {
      user: {
        current_password: "password",
        password: "NeuesPasswort456!",
        password_confirmation: "NeuesPasswort456!"
      }
    }

    # Verifikation: Folge-Request auf geschuetzte Seite muss zu Login redirecten
    get edit_user_registration_path
    assert_redirected_to new_user_session_path,
      "Nach PW-Change muss User neu einloggen (D-41-C Semantik)"
  end

  test "PATCH /users mit neuer email triggert reconfirmation (Email-Change-Flow D-41-D #4)" do
    user = users(:valid)
    sign_in user
    ActionMailer::Base.deliveries.clear

    new_email = "neue-#{SecureRandom.hex(4)}@example.test"
    patch user_registration_path, params: {
      user: {
        current_password: "password",
        email: new_email
      }
    }

    user.reload
    # reconfirmable=true: neue email landet in unconfirmed_email, alte bleibt
    assert_equal new_email, user.unconfirmed_email,
      "Neue email muss in unconfirmed_email landen (reconfirmable=true)"
    refute_equal new_email, user.email,
      "Alte email muss bestehen bleiben bis Bestaetigung"

    # 1 confirmation_instructions-Mail an NEUE Adresse erwartet
    mails = ActionMailer::Base.deliveries
    confirm_mail = mails.find { |m| m.to == [new_email] }
    refute_nil confirm_mail, "confirmation_instructions muss an neue Adresse versendet werden"
    assert_match %r{/confirmation\?confirmation_token=}, confirm_mail.body.to_s
  end
end
