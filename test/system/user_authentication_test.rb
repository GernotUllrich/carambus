# test/system/user_authentication_test.rb
require 'test_helper'
require 'application_system_test_case'

class UserAuthenticationTest < ApplicationSystemTestCase
  test 'user can register with valid credentials' do
    visit new_user_registration_path(locale: :en)
    fill_in 'Full name', with: 'Test User'
    fill_in 'Email', with: 'test@example.com'
    fill_in 'Password', with: 'password123'
    fill_in 'Password confirmation', with: 'password123'
    check 'I accept the Terms of Service'
    sleep 3 # Simulate the time it takes for a human to fill out the form
    click_button 'Sign up'
    assert_text 'Welcome! You have signed up successfully.'
  end

  test 'user can log in with valid credentials' do
    user = users(:valid)
    visit new_user_session_path(locale: :en)
    fill_in 'Email', with: user.email
    fill_in 'Password', with: 'password'
    click_button 'Log in'
    assert_text 'Signed in successfully.'
  end

  test 'user cannot log in with invalid credentials' do
    visit new_user_session_path(locale: :en)
    assert_selector 'h2', text: 'Log in'  # Verify page load

    fill_in 'Email', with: 'invalid@example.com'
    fill_in 'Password', with: 'wrongpassword'
    click_button 'Log in'
    assert_text 'Invalid Email or password.'
  end

  test 'user roles are properly enforced' do
    player = users(:player)
    club_admin = users(:club_admin)
    system_admin = users(:system_admin)

    # Player can access public pages
    sign_in player
    visit root_path(locale: :en)
    assert_no_text 'Internal Server Error'  # Verify no 500 error
    assert_text 'Welcome to Carambus', wait: 5  # Add wait for async loading

    # Player cannot access admin-only pages
    assert_raises ActionController::RoutingError do
      visit admin_dashboard_path(locale: :en)
    end

    # Club admin can access admin-only pages
    sign_in club_admin
    visit admin_dashboard_path(locale: :en)
    assert_text 'Admin Dashboard'

    # System admin can access all pages
    sign_in system_admin
    visit admin_dashboard_path(locale: :en)
    assert_text 'Admin Dashboard'
  end

  test "system admin is redirected to admin dashboard after login" do
    user = users(:system_admin)
    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password"
    click_button "Log in"
    assert_current_path admin_root_path(locale: :en)
  end

  test "club admin is redirected to admin dashboard after login" do
    user = users(:club_admin)
    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password"
    click_button "Log in"
    assert_current_path admin_root_path(locale: :en)
  end

  test "player is redirected to root path after login" do
    user = users(:player)
    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password"
    click_button "Log in"
    assert_current_path root_path(locale: :en)
    assert_text 'Willkommen zu Carambus'
  end
end
