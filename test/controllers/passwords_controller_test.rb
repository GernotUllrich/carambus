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
end
