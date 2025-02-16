require 'application_system_test_case'

class PreferencesTest < ApplicationSystemTestCase
  setup do
    @user = users(:regular)
    sign_in @user
  end

  test 'updating preferences' do
    visit edit_user_registration_path
    
    select I18n.t('preferences.dark_theme'), from: I18n.t('activerecord.attributes.user.theme')
    select I18n.t('locales.de'), from: I18n.t('activerecord.attributes.user.locale')
    select 'Vienna', from: I18n.t('activerecord.attributes.user.timezone')
    
    click_button 'Update'
    
    assert_text 'Your account has been updated successfully'
    assert_equal 'dark', @user.reload.preferences['theme']
    assert_equal 'de', @user.preferences['locale']
    assert_equal 'Vienna', @user.preferences['timezone']
  end

  test 'showing validation errors' do
    visit edit_user_registration_path
    
    fill_in I18n.t('activerecord.attributes.user.timezone'), with: 'Invalid/Timezone'
    click_button 'Update'
    
    assert_text 'Invalid timezone'
  end
end 