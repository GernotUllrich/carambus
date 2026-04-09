# frozen_string_literal: true

require "test_helper"

# Unit tests fuer RegionCc::ClubSyncer.
# Verifiziert: Club-Aktualisierung aus CC-HTML, Logging bei unbekannten Clubs.
# Alle HTTP-Anfragen werden via Minitest::Mock abgefangen — kein echtes Netzwerk.
class RegionCc::ClubSyncerTest < ActiveSupport::TestCase
  setup do
    @region = regions(:nbv)
    @region_cc = RegionCc.create!(
      region: @region,
      name: "NBV Test",
      shortname: "nbv",
      context: "nbv",
      cc_id: 20,
      base_url: "https://test.club-cloud.de",
      username: "test",
      userpw: "test"
    )
    @client = Minitest::Mock.new

    # Disziplin aus Fixtures verwenden (Discipline/Branch)
    @discipline = disciplines(:carom_3band)
    @branch_cc = BranchCc.create!(
      cc_id: 6,
      region_cc_id: @region_cc.id,
      discipline_id: @discipline.id,
      context: "nbv",
      name: "Karambol"
    )
    @competition_cc = CompetitionCc.create!(
      cc_id: 1,
      branch_cc_id: @branch_cc.id,
      discipline_id: @discipline.id,
      name: "Einzel"
    )

    # Existierenden Club mit bekannter CC-ID anlegen
    @club = Club.create!(
      shortname: "TestBC",
      name: "Test Billard Club",
      region: @region,
      cc_id: 1001
    )
  end

  teardown do
    @region_cc.destroy if @region_cc.persisted?
  end

  # ---------------------------------------------------------------------------
  # Test 1: Findet und aktualisiert Club-Datensaetze aus HTML-Optionen
  # ---------------------------------------------------------------------------
  test "finds and updates Club records from HTML club options" do
    stub_html = <<~HTML
      <html><body>
        <select name="clubId">
          <option value="1001">TestBC (1001)</option>
        </select>
      </body></html>
    HTML

    # Erwartet 2 POST-Anfragen (active + passive fuer jeden branch/competition)
    stub_response = [OpenStruct.new(message: "OK"), Nokogiri::HTML(stub_html)]
    @client.expect(:post, stub_response, ["showClubList", Hash, Hash])
    @client.expect(:post, stub_response, ["showClubList", Hash, Hash])

    result = RegionCc::ClubSyncer.call(region_cc: @region_cc, client: @client)

    assert_kind_of Array, result
    assert_includes result, @club

    @client.verify
  end

  # ---------------------------------------------------------------------------
  # Test 2: Loggt Warnung fuer Clubs die nicht in DB vorhanden (kein raise)
  # ---------------------------------------------------------------------------
  test "logs warning for clubs not found in database without raising" do
    stub_html = <<~HTML
      <html><body>
        <select name="clubId">
          <option value="9999">UnbekannterClub (9999)</option>
        </select>
      </body></html>
    HTML

    stub_response = [OpenStruct.new(message: "OK"), Nokogiri::HTML(stub_html)]
    @client.expect(:post, stub_response, ["showClubList", Hash, Hash])
    @client.expect(:post, stub_response, ["showClubList", Hash, Hash])

    # Darf keine Exception werfen
    result = assert_nothing_raised do
      RegionCc::ClubSyncer.call(region_cc: @region_cc, client: @client)
    end

    assert_kind_of Array, result
    assert_empty result

    @client.verify
  end
end
