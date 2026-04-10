# frozen_string_literal: true

require "test_helper"

# Unit tests fuer RegionCc::BranchSyncer.
# Verifiziert: BranchCc-Erstellung aus CC-HTML, Fehlerbehandlung bei unbekannten Branches.
# Alle HTTP-Anfragen werden via Minitest::Mock abgefangen — kein echtes Netzwerk.
class RegionCc::BranchSyncerTest < ActiveSupport::TestCase
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
  end

  teardown do
    @region_cc.destroy if @region_cc.persisted?
  end

  # ---------------------------------------------------------------------------
  # Test 1: Erstellt BranchCc-Datensaetze aus HTML-Optionen
  # ---------------------------------------------------------------------------
  test "creates BranchCc records from HTML branch options" do
    # Karambol muss in der Branch-Tabelle vorhanden sein
    branch = Branch.find_by_name("Karambol") || Branch.create!(name: "Karambol")

    stub_html = <<~HTML
      <html><body>
        <select name="branchId">
          <option value="6">Karambol</option>
        </select>
      </body></html>
    HTML

    @client.expect(:get, [OpenStruct.new(message: "OK"), Nokogiri::HTML(stub_html)],
      ["showClubList", {}, {}])

    result = RegionCc::BranchSyncer.call(region_cc: @region_cc, client: @client)

    assert_kind_of Array, result
    assert_equal 1, result.size
    assert_equal branch, result.first

    branch_cc = BranchCc.find_by_cc_id(6)
    assert_equal 6, branch_cc&.cc_id
    assert_equal @region_cc.id, branch_cc.region_cc_id
    assert_equal "nbv", branch_cc.context

    @client.verify
  end

  # ---------------------------------------------------------------------------
  # Test 2: Wirft ArgumentError wenn Branch-Name nicht in DB
  # ---------------------------------------------------------------------------
  test "raises ArgumentError when branch name not found in Branch table" do
    stub_html = <<~HTML
      <html><body>
        <select name="branchId">
          <option value="99">UnknownDisziplin</option>
        </select>
      </body></html>
    HTML

    @client.expect(:get, [OpenStruct.new(message: "OK"), Nokogiri::HTML(stub_html)],
      ["showClubList", {}, {}])

    assert_raises(ArgumentError) do
      RegionCc::BranchSyncer.call(region_cc: @region_cc, client: @client)
    end

    @client.verify
  end
end
