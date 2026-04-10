# frozen_string_literal: true

require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:regular)
    sign_in @user
  end

  test "should update preferences" do
    sign_in @user
    get edit_user_registration_path
    assert_response :success

    # In test env, forgery protection is disabled (allow_forgery_protection = false),
    # so CSRF tokens are not rendered or required. Test the functional behavior directly.
    # theme/locale/timezone are top-level user params; update_resource moves them into preferences
    patch user_registration_path, params: {
      user: {
        theme: "dark",
        locale: "de",
        timezone: "Vienna"
      }
    }

    # Controller redirects to root_path after successful update (see RegistrationsController#update)
    assert_redirected_to root_path
    assert_equal "dark", @user.reload.preferences["theme"]
    assert_equal "de", @user.preferences["locale"]
    assert_equal "Vienna", @user.preferences["timezone"]
  end

  test "should update password with valid current password" do
    get edit_user_registration_path
    assert_response :success

    patch user_registration_path, params: {
      user: {
        current_password: "password",
        password: "newpassword",
        password_confirmation: "newpassword"
      }
    }

    assert_redirected_to root_path
    assert @user.reload.valid_password?("newpassword")
  end
end
