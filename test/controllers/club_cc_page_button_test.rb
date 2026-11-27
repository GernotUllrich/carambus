# frozen_string_literal: true

require "test_helper"

# Vereinsseite verlinkt die CC per POST-Formular — die alte GET-Seite verein-details.php liefert HTTP 410.
class ClubCcPageButtonTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:club_admin)
    @club = clubs(:club_bochum)
    @club.region.update_columns(public_cc_url_base: "https://ndbv.de/", cc_id: 20)
    @club.update_columns(cc_id: 1010, dbu_nr: 2191)
  end

  test "Vereinsseite zeigt die Quelle als POST-Formular auf cbdet.php" do
    get club_url(@club)
    assert_response :success

    assert_select "form[action=?][method=post] input[name=a][value=?]", "https://ndbv.de/cbdet.php", "1010"
    assert_select "a[href*=?]", "verein-details", 0
  end
end
