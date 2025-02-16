require "application_system_test_case"

class UserProfileTest < ApplicationSystemTestCase
  test "user updates profile" do
    sign_in users(:regular)
    visit edit_profile_path
    
    select "Deutsch", from: "Preferred language"
    select "(UTC+01:00) Berlin", from: "Time zone"
    select "Dark", from: "Theme"
    
    click_button "Update Profile"
    assert_text "Profil erfolgreich aktualisiert"
  end
end 