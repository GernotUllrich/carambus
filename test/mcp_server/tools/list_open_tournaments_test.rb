# frozen_string_literal: true

require "test_helper"

class McpServer::Tools::ListOpenTournamentsTest < ActiveSupport::TestCase
  setup do
    ENV["CARAMBUS_MCP_MOCK"] = "1"
    ENV["CC_FED_ID"] = nil
    ENV["CC_REGION"] = nil
    McpServer::CcSession.reset!
  end

  teardown do
    ENV["CARAMBUS_MCP_MOCK"] = nil
    ENV["CC_FED_ID"] = nil
    ENV["CC_REGION"] = nil
  end

  test "DB-first happy path NBV: returns data + meta with last_sync_age_hours" do
    nbv = Region.find_by(shortname: "NBV")
    skip "NBV fixtures missing" unless nbv

    response = McpServer::Tools::ListOpenTournaments.call(
      shortname: "NBV",
      server_context: nil
    )
    refute response.error?, "Expected non-error; got: #{response.content.first[:text]}"

    body = JSON.parse(response.content.first[:text])
    assert_kind_of Array, body["data"]
    assert_kind_of Hash, body["meta"]
    assert_equal "NBV", body["meta"]["region"]
    assert_equal body["data"].length, body["meta"]["count"]
    assert_kind_of Numeric, body["meta"]["last_sync_age_hours"] unless body["meta"]["last_sync_age_hours"].nil?
    assert_match(/accredation_end >=.*AND date >=/, body["meta"]["filter_basis"])
  end

  test "filter is purely temporal — KEIN state-Filter angewendet" do
    nbv = Region.find_by(shortname: "NBV")
    skip "NBV fixtures missing" unless nbv

    today = Date.today
    expected_count = Tournament.where(region_id: nbv.id)
      .where("accredation_end >= ? AND date >= ?", today, today)
      .count
    skip "No open tournaments in NBV" if expected_count.zero?

    response = McpServer::Tools::ListOpenTournaments.call(
      shortname: "NBV",
      server_context: nil
    )
    refute response.error?
    body = JSON.parse(response.content.first[:text])

    assert_equal expected_count, body["data"].length,
      "Expected #{expected_count} tournaments matching pure temporal filter; " \
      "got #{body["data"].length}. State-Filter would be wrong (User-Korrektur 2026-05-08)."
  end

  test "discipline filter narrows results" do
    nbv = Region.find_by(shortname: "NBV")
    discipline = Discipline.find_by(name: "Freie Partie klein")
    skip "Fixtures missing" unless nbv && discipline

    response_all = McpServer::Tools::ListOpenTournaments.call(shortname: "NBV", server_context: nil)
    refute response_all.error?
    all_count = JSON.parse(response_all.content.first[:text])["data"].length

    response_filtered = McpServer::Tools::ListOpenTournaments.call(
      shortname: "NBV",
      discipline: "Freie Partie klein",
      server_context: nil
    )
    refute response_filtered.error?
    filtered_body = JSON.parse(response_filtered.content.first[:text])
    assert_operator filtered_body["data"].length, :<=, all_count
    assert_equal "Freie Partie klein", filtered_body["meta"]["discipline"]
    filtered_body["data"].each do |t|
      assert_equal discipline.id, t["discipline_id"]
    end
  end

  test "include_no_date toggles NULL accredation_end" do
    nbv = Region.find_by(shortname: "NBV")
    skip "NBV fixtures missing" unless nbv

    r1 = McpServer::Tools::ListOpenTournaments.call(shortname: "NBV", include_no_date: false, server_context: nil)
    r2 = McpServer::Tools::ListOpenTournaments.call(shortname: "NBV", include_no_date: true, server_context: nil)
    refute r1.error?
    refute r2.error?
    body1 = JSON.parse(r1.content.first[:text])
    body2 = JSON.parse(r2.content.first[:text])
    assert_operator body2["data"].length, :>=, body1["data"].length
    assert_equal false, body1["meta"]["include_no_date"]
    assert_equal true, body2["meta"]["include_no_date"]
  end

  test "missing region returns error when no default available" do
    response = McpServer::Tools::ListOpenTournaments.call(server_context: nil)
    assert response.error?
    assert_match(/Region not found/i, response.content.first[:text])
  end

  test "unknown discipline returns error" do
    nbv = Region.find_by(shortname: "NBV")
    skip "NBV fixtures missing" unless nbv

    response = McpServer::Tools::ListOpenTournaments.call(
      shortname: "NBV",
      discipline: "Nonexistent-#{SecureRandom.hex(4)}",
      server_context: nil
    )
    assert response.error?
    assert_match(/Discipline not found/i, response.content.first[:text])
  end

  test "invalid open_after returns error" do
    nbv = Region.find_by(shortname: "NBV")
    skip "NBV fixtures missing" unless nbv

    response = McpServer::Tools::ListOpenTournaments.call(
      shortname: "NBV",
      open_after: "not-a-date",
      server_context: nil
    )
    assert response.error?
    assert_match(/Invalid open_after/i, response.content.first[:text])
  end

  test "force_refresh: true with sync raising stays defensive (no crash)" do
    nbv = Region.find_by(shortname: "NBV")
    skip "NBV fixtures missing" unless nbv
    region_cc = nbv.region_cc
    skip "RegionCc missing for NBV" unless region_cc

    region_cc.stub(:sync_tournaments, ->(_) { raise StandardError, "stubbed sync failure" }) do
      response = McpServer::Tools::ListOpenTournaments.call(
        shortname: "NBV",
        force_refresh: true,
        server_context: nil
      )
      refute response.error?, "Tool should be defensive against sync failure"
    end
  end
end
