# frozen_string_literal: true

require "test_helper"

class McpServer::Tools::ListPlayersByClubAndDisciplineTest < ActiveSupport::TestCase
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

  test "DB-first happy path: returns players for a NBV-Club + Discipline" do
    nbv = Region.find_by(shortname: "NBV")
    discipline = Discipline.find_by(name: "Freie Partie klein")
    skip "Fixtures missing" unless nbv && discipline

    sample_club = Club.joins(players: :player_rankings)
      .where(region_id: nbv.id)
      .where(player_rankings: {discipline_id: discipline.id, region_id: nbv.id})
      .distinct
      .first
    skip "No NBV club has rankings in 'Freie Partie klein'" unless sample_club

    response = McpServer::Tools::ListPlayersByClubAndDiscipline.call(
      club: sample_club.shortname,
      discipline: "Freie Partie klein",
      server_context: nil
    )
    refute response.error?, "Expected non-error; got: #{response.content.first[:text]}"

    body = JSON.parse(response.content.first[:text])
    assert_equal sample_club.shortname, body["club"]
    assert_equal "Freie Partie klein", body["discipline"]
    assert_kind_of Integer, body["count"]
    assert_kind_of Array, body["players"]
    body["players"].each do |player|
      assert player.key?("id")
      assert player.key?("fl_name")
    end
  end

  test "missing club returns error" do
    response = McpServer::Tools::ListPlayersByClubAndDiscipline.call(
      discipline: "Freie Partie klein",
      server_context: nil
    )
    assert response.error?
    assert_match(/club/i, response.content.first[:text])
  end

  test "missing discipline returns error" do
    response = McpServer::Tools::ListPlayersByClubAndDiscipline.call(
      club: "1. BC Schwerin",
      server_context: nil
    )
    assert response.error?
    assert_match(/discipline/i, response.content.first[:text])
  end

  test "unknown club returns error" do
    response = McpServer::Tools::ListPlayersByClubAndDiscipline.call(
      club: "ZZZ-#{SecureRandom.hex(4)}",
      discipline: "Freie Partie klein",
      server_context: nil
    )
    assert response.error?
    assert_match(/Club not found/i, response.content.first[:text])
  end

  test "unknown discipline returns error" do
    sample_club = Club.first
    skip "No clubs in fixtures" unless sample_club

    response = McpServer::Tools::ListPlayersByClubAndDiscipline.call(
      club: sample_club.shortname,
      discipline: "Nonexistent-#{SecureRandom.hex(4)}",
      server_context: nil
    )
    assert response.error?
    assert_match(/Discipline not found/i, response.content.first[:text])
  end

  test "explicit season: param resolves season by name" do
    season = Season.first
    skip "No seasons in fixtures" unless season

    sample_club = Club.first
    discipline = Discipline.first
    skip "No clubs/disciplines" unless sample_club && discipline

    response = McpServer::Tools::ListPlayersByClubAndDiscipline.call(
      club: sample_club.shortname,
      discipline: discipline.name,
      season: season.name,
      server_context: nil
    )
    refute response.error?, "Expected non-error; got: #{response.content.first[:text]}"
    body = JSON.parse(response.content.first[:text])
    assert_equal season.name, body["season"]
  end

  test "shortname mismatch with club's region returns error" do
    nbv_club = Club.where.not(region_id: nil).first
    other_region_shortname = Region.where.not(id: nbv_club&.region_id).first&.shortname
    skip "Need a club with region + a different region" unless nbv_club && other_region_shortname

    response = McpServer::Tools::ListPlayersByClubAndDiscipline.call(
      club: nbv_club.shortname,
      discipline: "Freie Partie klein",
      shortname: other_region_shortname,
      server_context: nil
    )
    assert response.error?
    assert_match(/belongs to region_id/i, response.content.first[:text])
  end
end
