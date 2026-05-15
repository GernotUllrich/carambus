# frozen_string_literal: true

require "test_helper"

class McpServer::Tools::CheckPlayerDisciplineExperienceTest < ActiveSupport::TestCase
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

  test "validation: missing player_id returns error" do
    response = McpServer::Tools::CheckPlayerDisciplineExperience.call(discipline_id: 1, server_context: {cc_region: "NBV"})
    assert response.error?
    assert_match(/player_id/i, response.content.first[:text])
  end

  test "validation: missing discipline_id returns error" do
    response = McpServer::Tools::CheckPlayerDisciplineExperience.call(player_id: 1, server_context: {cc_region: "NBV"})
    assert response.error?
    assert_match(/discipline_id/i, response.content.first[:text])
  end

  test "validation: unknown player_id returns error" do
    response = McpServer::Tools::CheckPlayerDisciplineExperience.call(
      player_id: 999_999_999,
      discipline_id: 1,
      server_context: {cc_region: "NBV"}
    )
    assert response.error?
    assert_match(/Player not found/i, response.content.first[:text])
  end

  test "validation: unknown discipline_id returns error" do
    sample = Player.first
    skip "No players in fixtures" unless sample

    response = McpServer::Tools::CheckPlayerDisciplineExperience.call(
      player_id: sample.id,
      discipline_id: 999_999_999,
      server_context: {cc_region: "NBV"}
    )
    assert response.error?
    assert_match(/Discipline not found/i, response.content.first[:text])
  end

  # Plan 14-02.2 / B-3: shortname-Override-Logik entfernt. Test reframed.
  test "B-3: shortname-Override wird ignoriert, User-Region greift strict" do
    sample = Player.first
    discipline = Discipline.first
    skip "No fixtures" unless sample && discipline

    response = McpServer::Tools::CheckPlayerDisciplineExperience.call(
      player_id: sample.id,
      discipline_id: discipline.id,
      shortname: "ZZZ-XYZ",
      server_context: {cc_region: "NBV"}
    )
    # shortname-Override wird ignoriert; ggf. experienced:false oder true je nach Daten — kein Error
    refute response.error?, "shortname-Override darf nicht zu Region-not-found-Error führen — strict server_context greift"
  end

  test "D-14-02-G: server_context ohne cc_region → Profile-Edit-Diagnostic-Error" do
    sample = Player.first
    discipline = Discipline.first
    skip "No fixtures" unless sample && discipline

    response = McpServer::Tools::CheckPlayerDisciplineExperience.call(
      player_id: sample.id,
      discipline_id: discipline.id,
      server_context: {}
    )
    assert response.error?
    assert_match(/Scenario-Config-Fehler.*Carambus\.config\.context/i, response.content.first[:text])
  end

  test "experienced:true via PlayerRanking existence" do
    nbv = Region.find_by(shortname: "NBV")
    skip "NBV region fixture missing" unless nbv

    ranking = PlayerRanking.where(region_id: nbv.id).where.not(player_id: nil).where.not(discipline_id: nil).first
    skip "No PlayerRanking in NBV fixtures" unless ranking

    response = McpServer::Tools::CheckPlayerDisciplineExperience.call(
      player_id: ranking.player_id,
      discipline_id: ranking.discipline_id,
      shortname: "NBV",
      server_context: {cc_region: "NBV"}
    )
    refute response.error?, "Expected non-error; got: #{response.content.first[:text]}"

    body = JSON.parse(response.content.first[:text])
    assert_equal true, body["experienced"]
    assert_equal true, body.dig("signals", "has_ranking")
    assert_match(/PlayerRanking/i, body["reason"])
  end

  test "experienced:true via GameParticipation tournament-path" do
    nbv = Region.find_by(shortname: "NBV")
    skip "NBV region fixture missing" unless nbv

    # Spieler mit GameParticipation in Game→Tournament(disciplin) aber OHNE Ranking
    # in derselben (player, discipline, region) Triple
    candidate = GameParticipation
      .joins(game: :tournament)
      .where.not(player_id: nil)
      .where.not(tournaments: {discipline_id: nil})
      .first
    skip "No GameParticipation→Tournament with discipline" unless candidate

    tournament = candidate.game.tournament
    skip "Tournament missing discipline_id" unless tournament&.discipline_id

    response = McpServer::Tools::CheckPlayerDisciplineExperience.call(
      player_id: candidate.player_id,
      discipline_id: tournament.discipline_id,
      shortname: "NBV",
      server_context: {cc_region: "NBV"}
    )
    refute response.error?
    body = JSON.parse(response.content.first[:text])
    assert_equal true, body["experienced"]
    # Mind. EINER der beiden Pfade muss true sein
    assert(body.dig("signals", "has_ranking") || body.dig("signals", "has_game_participation"))
  end

  test "experienced:false when no ranking and no participation" do
    nbv = Region.find_by(shortname: "NBV")
    skip "NBV region fixture missing" unless nbv

    # Spieler + Disziplin-Kombi ohne Ranking, ohne Participation
    sample_player = Player.first
    sample_discipline = Discipline.first
    skip "Missing fixtures" unless sample_player && sample_discipline

    # Sicherstellen, dass diese Kombination NICHT existiert
    has_ranking = PlayerRanking.where(player_id: sample_player.id, discipline_id: sample_discipline.id, region_id: nbv.id).exists?
    has_part_t = GameParticipation.joins(game: :tournament).where(player_id: sample_player.id, tournaments: {discipline_id: sample_discipline.id}).exists?
    has_part_l = GameParticipation.joins(game: {tournament: :league}).where(player_id: sample_player.id, leagues: {discipline_id: sample_discipline.id}).exists?
    skip "Sample combo accidentally has signals" if has_ranking || has_part_t || has_part_l

    response = McpServer::Tools::CheckPlayerDisciplineExperience.call(
      player_id: sample_player.id,
      discipline_id: sample_discipline.id,
      shortname: "NBV",
      server_context: {cc_region: "NBV"}
    )
    refute response.error?
    body = JSON.parse(response.content.first[:text])
    assert_equal false, body["experienced"]
    assert_equal false, body.dig("signals", "has_ranking")
    assert_equal false, body.dig("signals", "has_game_participation")
    assert_match(/Erstantritt/i, body["reason"])
    assert_match(/Plausibilitäts/i, body["reason"])
  end

  test "output includes meta with player_fl_name and discipline_name" do
    sample_player = Player.first
    sample_discipline = Discipline.first
    nbv = Region.find_by(shortname: "NBV")
    skip "Missing fixtures" unless sample_player && sample_discipline && nbv

    response = McpServer::Tools::CheckPlayerDisciplineExperience.call(
      player_id: sample_player.id,
      discipline_id: sample_discipline.id,
      shortname: "NBV",
      server_context: {cc_region: "NBV"}
    )
    refute response.error?
    body = JSON.parse(response.content.first[:text])
    assert_equal sample_player.id, body.dig("meta", "player_id")
    assert_equal sample_player.fl_name, body.dig("meta", "player_fl_name")
    assert_equal sample_discipline.id, body.dig("meta", "discipline_id")
    assert_equal sample_discipline.name, body.dig("meta", "discipline_name")
    assert_equal "NBV", body.dig("meta", "region")
  end

  test "signals expose both participation paths separately" do
    sample_player = Player.first
    sample_discipline = Discipline.first
    nbv = Region.find_by(shortname: "NBV")
    skip "Missing fixtures" unless sample_player && sample_discipline && nbv

    response = McpServer::Tools::CheckPlayerDisciplineExperience.call(
      player_id: sample_player.id,
      discipline_id: sample_discipline.id,
      shortname: "NBV",
      server_context: {cc_region: "NBV"}
    )
    refute response.error?
    body = JSON.parse(response.content.first[:text])
    assert body["signals"].key?("has_participation_via_tournament")
    assert body["signals"].key?("has_participation_via_league")
  end
end
