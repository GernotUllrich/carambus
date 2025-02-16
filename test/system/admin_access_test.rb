test "club_admin cannot edit imported tournaments" do
  login_as users(:club_admin)
  visit edit_admin_tournament_path(tournaments(:imported))
  assert_text "Bearbeitung eingeschränkt"
  assert_field "source_url", disabled: true
end

test "only system admins can manage users" do
  sign_in users(:club_admin)
  visit admin_users_path
  assert_text "Zugriff verweigert"
end 