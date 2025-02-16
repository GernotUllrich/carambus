require 'test_helper'

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:regular)
    sign_in @user
  end

  test 'should update preferences' do
    sign_in @user
    get edit_user_registration_path
    assert_response :success
    
    match = response.body.match(/<meta\s+name="csrf-token"\s+content="([^"]*)"\s*\/?>/)
    assert match, "CSRF token meta tag missing in response. Response body: #{response.body}"
    csrf_token = match[1]
    
    patch user_registration_path, params: {
      authenticity_token: csrf_token,
      user: {
        preferences: {
          theme: 'dark',
          locale: 'de',
          timezone: 'Vienna'
        }
      }
    }
    
    assert_redirected_to edit_user_registration_path(locale: 'de')
    assert_equal 'dark', @user.reload.preferences['theme']
    assert_equal 'de', @user.preferences['locale']
    assert_equal 'Vienna', @user.preferences['timezone']
  end

  test 'should update password with valid current password' do
    @user.update!(preferences: { locale: 'en' }) # Ensure default locale
    get edit_user_registration_path
    csrf_token = response.body.match(/<meta name="csrf-token" content="(.*)"/)[1]
    
    patch user_registration_path, params: {
      authenticity_token: csrf_token,
      user: {
        current_password: 'password',
        password: 'newpassword',
        password_confirmation: 'newpassword'
      }
    }
    
    assert_redirected_to edit_user_registration_path(locale: 'en')
    assert @user.reload.valid_password?('newpassword')
  end
end 