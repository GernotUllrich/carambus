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
end
