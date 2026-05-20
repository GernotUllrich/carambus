# frozen_string_literal: true

require "test_helper"

# D-41-A Layer 2: Forgot- und Reset-Password HTTP-Flow charakterisieren.
# Devise-Default-Controller (kein Custom-Override) — Tests pinnen, wie Devise
# heute reagiert. Plan 41-03 erweitert dies um JTI-Rotation-Assertions.
class PasswordsControllerTest < ActionDispatch::IntegrationTest
  setup do
    clear_mail_queue
    @user = users(:valid)
  end

  test "POST /users/password mit gueltiger email versendet Reset-Mail" do
    assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
      post user_password_path, params: {user: {email: @user.email}}
    end
    assert_redirected_to new_user_session_path
  end

  test "GET /users/password/edit mit gueltigem Token rendert Form" do
    raw_token = @user.send_reset_password_instructions
    get edit_user_password_path(reset_password_token: raw_token)
    assert_response :success
    assert_select "input[name='user[password]']"
  end

  test "PUT /users/password mit gueltigem Token aendert encrypted_password" do
    raw_token = @user.send_reset_password_instructions
    old_encrypted = @user.reload.encrypted_password

    put user_password_path, params: {
      user: {
        reset_password_token: raw_token,
        password: "NeuesPasswort123!",
        password_confirmation: "NeuesPasswort123!"
      }
    }
    # IST: redirect (root oder signed_in_root_path) — charakterisieren
    assert_response :redirect
    assert_not_equal old_encrypted, @user.reload.encrypted_password,
      "encrypted_password muss sich nach Reset aendern"
  end

  test "PUT /users/password mit invalidem Token gibt Form-Error zurueck" do
    put user_password_path, params: {
      user: {
        reset_password_token: "absolut-ungueltig-xyz",
        password: "NeuesPasswort123!",
        password_confirmation: "NeuesPasswort123!"
      }
    }
    # Devise rendert Form mit Error (kein redirect)
    assert_response :unprocessable_entity
  end

  # === Plan 41-03 Task 2: D-41-C JTI-Rotation + Token-Replay-Schutz ===

  test "PUT /users/password rotiert User.jti (D-41-C Hard-Revoke)" do
    # Sicherstellen, dass User jti hat (Fixture hat keinen)
    @user.update_column(:jti, SecureRandom.uuid) if @user.jti.blank?
    @user.reload
    old_jti = @user.jti
    refute_nil old_jti, "User-Fixture muss jti haben (ggf. via Backfill)"

    raw_token = @user.send_reset_password_instructions

    put user_password_path, params: {
      user: {
        reset_password_token: raw_token,
        password: "NeuesPasswort123!",
        password_confirmation: "NeuesPasswort123!"
      }
    }

    @user.reload
    assert_not_equal old_jti, @user.jti,
      "Nach PW-Reset muss jti rotieren (D-41-C). Alter JWT wird damit ungueltig."
  end

  test "PUT /users/password: Token-Replay nach Use wird abgewiesen (Devise-Default)" do
    raw_token = @user.send_reset_password_instructions

    # Erster Use: erfolgreich → Devise sign_in_after_reset_password=true loggt
    # User direkt ein (303 redirect zu root, sign_in via bypass_sign_in)
    put user_password_path, params: {
      user: {
        reset_password_token: raw_token,
        password: "ErstesNeuesPasswort123!",
        password_confirmation: "ErstesNeuesPasswort123!"
      }
    }
    assert_response :redirect, "Erster Reset muss erfolgreich sein"
    old_encrypted_after_first = @user.reload.encrypted_password
    refute_nil old_encrypted_after_first

    # Zweiter Use mit IDENTISCHEM Token: zwei Schutz-Schichten greifen:
    # 1. Devise loescht reset_password_token + reset_password_sent_at nach erstem
    #    Use (clear_reset_password_token-Callback in Recoverable#reset_password)
    # 2. PasswordsController hat `prepend_before_action :require_no_authentication`
    #    — der eingeloggte User wird mit "already_authenticated" zur root redirected
    # Beide Schichten verhindern Token-Replay. IST ist Schicht 2 (302 redirect, weil
    # User nach Schicht-1-Sign-In eingeloggt ist).
    put user_password_path, params: {
      user: {
        reset_password_token: raw_token,
        password: "ZweitesPasswort123!",
        password_confirmation: "ZweitesPasswort123!"
      }
    }
    assert_response :redirect,
      "Token-Replay muss abgewiesen werden (Devise require_no_authentication redirect)"
    # KRITISCH: encrypted_password darf sich NICHT geaendert haben durch den 2. PUT
    assert_equal old_encrypted_after_first, @user.reload.encrypted_password,
      "Zweiter PUT mit gleichem Token darf encrypted_password NICHT erneut aendern"
  end

  test "POST /users/password mit unbekannter Email: Devise-Default-Verhalten dokumentieren" do
    # CHARAKTERISIERUNG des Devise paranoid_mode-Settings:
    # - paranoid=false (IST): Devise sendet KEINE Mail an unbekannte Email,
    #   gibt aber Form-Error zurueck (rendert :new)
    # - paranoid=true (alternativ): Identischer Redirect ohne Hinweis (gegen Account-Enumeration)
    # Aktuelles IST in carambus: paranoid=false → keine Mail + Form-Error
    clear_mail_queue
    assert_no_difference -> { ActionMailer::Base.deliveries.size } do
      post user_password_path, params: {user: {email: "unbekannt-#{SecureRandom.hex(4)}@example.test"}}
    end
    # Devise-Default ohne paranoid: rendert :new mit "email not found" — entweder
    # 422 (unprocessable_entity, Devise 4.9 default) oder 200 (success). Test
    # akzeptiert beides via in?-Check; wichtig: KEINE Mail versendet.
    assert_includes [200, 422], response.status,
      "Devise rendert Form (200 oder 422), KEIN redirect (paranoid=false)"
  end
end
