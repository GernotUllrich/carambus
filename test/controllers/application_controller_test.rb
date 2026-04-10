# frozen_string_literal: true

require "test_helper"

class ApplicationControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:regular)
    I18n.locale = :en
  end

  test "should render root page when user has preferences" do
    @user.update!(preferences: {
      "theme" => "dark",
      "locale" => "de",
      "timezone" => "Vienna"
    })

    sign_in @user
    get root_path

    assert_response :success
    assert_select "h1"
  end

  test "should render root page when user has no preferences" do
    @user.update!(preferences: {})
    sign_in @user
    get root_path

    assert_response :success
    assert_select "h1"
  end
end
