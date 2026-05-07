# frozen_string_literal: true
require "test_helper"

class McpServer::Tools::ListClubsByDisciplineTest < ActiveSupport::TestCase
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

  test "DB-first happy path: returns clubs for NBV + Freie Partie klein" do
    nbv = Region.find_by(shortname: "NBV")
    discipline = Discipline.find_by(name: "Freie Partie klein")
    skip "Fixtures missing (NBV / Freie Partie klein)" unless nbv && discipline

    response = McpServer::Tools::ListClubsByDiscipline.call(
      shortname: "NBV",
      discipline: "Freie Partie klein",
      server_context: nil
    )
    refute response.error?, "Expected non-error response, got: #{response.content.first[:text]}"

    body = JSON.parse(response.content.first[:text])
    assert_equal "NBV", body["region"]
    assert_equal "Freie Partie klein", body["discipline"]
    assert_kind_of Integer, body["count"]
    assert_kind_of Array, body["clubs"]
    body["clubs"].each do |club|
      assert club.key?("id"), "club entry missing id: #{club.inspect}"
      assert club.key?("shortname"), "club entry missing shortname: #{club.inspect}"
      assert club.key?("name"), "club entry missing name: #{club.inspect}"
    end
  end

  test "discipline can be passed as numeric ID" do
    nbv = Region.find_by(shortname: "NBV")
    discipline = Discipline.find_by(name: "Freie Partie klein")
    skip "Fixtures missing" unless nbv && discipline

    response = McpServer::Tools::ListClubsByDiscipline.call(
      shortname: "NBV",
      discipline: discipline.id.to_s,
      server_context: nil
    )
    refute response.error?
    body = JSON.parse(response.content.first[:text])
    assert_equal discipline.name, body["discipline"]
  end

  test "missing discipline returns error" do
    response = McpServer::Tools::ListClubsByDiscipline.call(
      shortname: "NBV",
      server_context: nil
    )
    assert response.error?
    assert_match(/discipline/i, response.content.first[:text])
  end

  test "missing region returns error when no default available" do
    response = McpServer::Tools::ListClubsByDiscipline.call(
      discipline: "Freie Partie klein",
      server_context: nil
    )
    assert response.error?
    assert_match(/Region not found/i, response.content.first[:text])
  end

  test "unknown region shortname returns error" do
    response = McpServer::Tools::ListClubsByDiscipline.call(
      shortname: "ZZZ-IMPOSSIBLE-#{SecureRandom.hex(4)}",
      discipline: "Freie Partie klein",
      server_context: nil
    )
    assert response.error?
    assert_match(/Region not found/i, response.content.first[:text])
  end

  test "unknown discipline returns error" do
    nbv = Region.find_by(shortname: "NBV")
    skip "Fixtures missing" unless nbv

    response = McpServer::Tools::ListClubsByDiscipline.call(
      shortname: "NBV",
      discipline: "Nonexistent-Discipline-#{SecureRandom.hex(4)}",
      server_context: nil
    )
    assert response.error?
    assert_match(/Discipline not found/i, response.content.first[:text])
  end

  test "force_refresh: true with sync raising stays defensive (no crash)" do
    nbv = Region.find_by(shortname: "NBV")
    discipline = Discipline.find_by(name: "Freie Partie klein")
    skip "Fixtures missing" unless nbv && discipline

    region_cc = nbv.region_cc
    skip "RegionCc missing for NBV" unless region_cc

    region_cc.stub(:sync_clubs, ->(_) { raise StandardError, "stubbed sync failure" }) do
      response = McpServer::Tools::ListClubsByDiscipline.call(
        shortname: "NBV",
        discipline: "Freie Partie klein",
        force_refresh: true,
        server_context: nil
      )
      refute response.error?, "Tool should be defensive against sync failure; got: #{response.content.first[:text]}"
    end
  end
end
