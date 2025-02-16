require 'test_helper'

class ApplicationControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:regular)
    I18n.locale = :en
  end

  test 'should set user preferences' do
    @user.update!(preferences: {
      'theme' => 'dark',
      'locale' => 'de',
      'timezone' => 'Vienna'
    })

    sign_in @user
    get root_path

    assert_select 'h1', text: I18n.t('welcome_to_carambus', locale: 'de')
    assert_equal 'Vienna', Time.zone.name
    assert_equal true, @controller.view_context.dark_mode?
  end

  test 'should fallback to default preferences' do
    @user.update!(preferences: {})
    sign_in @user
    get root_path

    assert_select 'h1', text: I18n.t('welcome_to_carambus', locale: 'de')
    assert_equal 'Berlin', Time.zone.name
    assert_nil @controller.view_context.dark_mode?
  end
end
