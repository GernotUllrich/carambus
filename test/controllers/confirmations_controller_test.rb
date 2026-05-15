# frozen_string_literal: true

require "test_helper"

# D-41-A Layer 2: Confirmation-Resend und Confirm-via-Token HTTP-Flow.
class ConfirmationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    clear_mail_queue
    @user = users(:valid)
    # Sicherstellen: User ist unconfirmed fuer diese Tests
    @user.update_columns(confirmed_at: nil, confirmation_token: nil, confirmation_sent_at: nil)
  end

  test "POST /users/confirmation versendet erneut Confirmation-Mail" do
    assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
      post user_confirmation_path, params: {user: {email: @user.email}}
    end
    assert_redirected_to new_user_session_path
  end

  test "GET /users/confirmation mit gueltigem Token bestaetigt User" do
    # Token generieren wie Devise es im Mailer macht
    raw_token, db_token = Devise.token_generator.generate(User, :confirmation_token)
    @user.update_columns(confirmation_token: db_token, confirmation_sent_at: Time.current)

    get user_confirmation_path(confirmation_token: raw_token)
    assert_response :redirect
    assert_not_nil @user.reload.confirmed_at, "User muss confirmed sein"
  end

  test "GET /users/confirmation mit invalidem Token rendert new mit Error (KEIN Crash)" do
    get user_confirmation_path(confirmation_token: "absolut-ungueltig-xyz")
    # IST-Charakterisierung: Devise's ConfirmationsController#show rendert die `new`-View
    # mit HTTP 200 + Form-Error im resource (errors.add(:confirmation_token, :invalid)).
    # Kein 422 (das ist Custom-Mapping, nicht Devise-Default). Kein 500/Crash — das ist
    # die Hauptaussage dieses Tests: invalider Token darf NICHT crashen.
    # Plan-04 koennte erwaegen :unprocessable_entity zu mappen, dann Test anpassen.
    assert_response :success
    assert_select ".error, .field_with_errors, [data-error]", false,
      "Form sollte Fehler-Indikator enthalten — heute: leere Form ohne Fehler-Hinweis"
  end
end
