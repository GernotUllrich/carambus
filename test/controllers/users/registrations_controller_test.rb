# frozen_string_literal: true

require "test_helper"

class Users::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user_params = {user: {
      name: "Test User",
      email: "user@test.com",
      password: "TestPassword",
      terms_of_service: "1"
    }}
  end

  # Plan 41-02 Task 1: invisible_captcha 2.3 (Macro im RegistrationsController#create
  # ab Plan 41-02) erzwingt drei Spam-Checks:
  #   1) Session-Timestamp (gesetzt beim GET /users/sign_up) + mind. timestamp_threshold
  #      (Default 4s) Verzoegerung
  #   2) Spinner-Hidden-Field (per-Request HMAC-Wert) muss im POST mitgeschickt werden
  #   3) Honeypot-Feld (z.B. :subtitle) darf NICHT gefuellt sein
  # Helper liefert valide Captcha-Vorbereitung in Integration-Tests: GET der Form,
  # Spinner-Extraktion aus dem Response-Body, Time-Travel ueber den Threshold.
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

  class BasicRegistrationTest < Users::RegistrationsControllerTest
    test "successfully registration form render" do
      get new_user_registration_path
      assert_response :success
      # Form uses first_name/last_name fields (not name), plus email and password
      assert_includes response.body, "user[email]"
      assert_includes response.body, "user[password]"
    end

    test "successful user registration" do
      spinner = prepare_captcha_for_post
      assert_difference "User.count" do
        post user_registration_url, params: @user_params.merge(spinner: spinner)
      end
    end

    test "failed user registration" do
      # Leerer User-Hash mit gueltiger Captcha-Vorbereitung -> Devise wirft Validation-Error
      # (kein User erstellt). Pinnt die Devise-Validation, nicht den Captcha-Check.
      spinner = prepare_captcha_for_post
      assert_no_difference "User.count" do
        post user_registration_url, params: {spinner: spinner}
      end
    end
  end

  class InvisibleCaptchaTest < Users::RegistrationsControllerTest
    # Valider Submit (Captcha vollstaendig erfuellt) erzeugt einen User.
    test "honeypot is not filled and user creation succeeds" do
      spinner = prepare_captcha_for_post
      assert_difference "User.count" do
        post user_registration_url, params: @user_params.merge(spinner: spinner)
      end
    end

    # Plan 41-02 Task 1: invisible_captcha-Macro im RegistrationsController#create aktiv.
    # Honeypot-Feld :subtitle gefuellt -> kein User-Insert, keine Mail. Default on_spam-Antwort
    # der invisible_captcha-Gem: head(200) (verschleiert Erfolg/Fehler vor Bots).
    # Mitigation T-41-02-01 (Spoofing via Honeypot-Bypass).
    test "POST /users mit gefuelltem honeypot wird abgewiesen (kein User, keine Mail)" do
      ActionMailer::Base.deliveries.clear
      spinner = prepare_captcha_for_post
      assert_no_difference -> { User.count } do
        assert_no_difference -> { ActionMailer::Base.deliveries.size } do
          post user_registration_url, params: {
            user: {
              email: "bot-#{SecureRandom.hex(4)}@example.test",
              password: "BotPasswort123!",
              password_confirmation: "BotPasswort123!",
              first_name: "Bot",
              last_name: "Spam",
              terms_of_service: "1"
            },
            spinner: spinner,
            subtitle: "filled-by-bot" # Honeypot getriggert
          }
        end
      end
      # invisible_captcha-Default-on_spam: head(200) (verschleiert Erfolg/Fehler vor Bots)
      assert_response :success
      assert_empty response.body
    end
  end

  class RegisterWithAccountTest < Users::RegistrationsControllerTest
    # register_with_account? is a config option that controls whether
    # an account details section appears on the signup form.
    # Tested via Carambus.config attribute access (OpenStruct allows any key).
    test "registration form renders without errors" do
      get new_user_registration_path
      assert_response :success
    end

    test "Carambus config is accessible" do
      # Carambus.config is an OpenStruct — any key can be read
      assert_not_nil Carambus.config
    end
  end
end
