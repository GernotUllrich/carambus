# frozen_string_literal: true

require "test_helper"

class ClubsHelperTest < ActionView::TestCase
  include ClubsHelper

  test "Vereinslink ist ein POST-Formular auf cbdet.php mit den Feldern des Scrape-Clients" do
    html = cc_club_page_button("1010", base_url: "https://ndbv.de", fed_id: 20, cc_id: 1010)
    doc = Nokogiri::HTML.fragment(html)
    form = doc.at("form")

    assert_equal "https://ndbv.de/cbdet.php", form["action"]
    assert_equal "post", form["method"]
    assert_equal "_blank", form["target"]
    fields = form.css("input[type=hidden]").to_h { |i| [i["name"], i["value"]] }
    assert_equal ClubCloudPublicClient.form_fields(20, a: 1010).transform_keys(&:to_s).transform_values(&:to_s), fields
    assert_equal "1010", form.at("button[type=submit]").text
  end

  test "kein CSRF-Token an die fremde Domain" do
    html = cc_club_page_button("x", base_url: "https://ndbv.de/", fed_id: 20, cc_id: 1)

    refute_includes html, "authenticity_token"
  end

  test "ohne Verbands- oder Vereins-ID kein Knopf" do
    assert_nil cc_club_page_button("x", base_url: "https://ndbv.de/", fed_id: nil, cc_id: 1)
    assert_nil cc_club_page_button("x", base_url: "https://ndbv.de/", fed_id: 20, cc_id: nil)
    assert_nil cc_club_page_button("x", base_url: nil, fed_id: 20, cc_id: 1)
  end
end
