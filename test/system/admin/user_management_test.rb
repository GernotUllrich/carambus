test "system admin can change roles" do
  sign_in users(:system_admin)
  visit edit_admin_user_path(users(:player))
  
  select "club_admin", from: "Role"
  click_button "Update User"
  
  assert_text "User was successfully updated"
  assert users(:player).reload.club_admin?
end

test "club admin cannot change roles" do
  sign_in users(:club_admin)
  visit admin_users_path
  assert_text "Zugriff verweigert"
end 