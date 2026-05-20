# frozen_string_literal: true

require "test_helper"

# Plan 14-G.4 / F5-C: Authority-Denial-Tests für 6 Write-Tools.
# Verifiziert dass authorize!-Check in jedem Tool Random-User blockt + Sportwart durchlässt.
#
# Setup: Tournament + RegistrationListCc (validate: false — umgeht belongs_to-Pflichten) +
# TournamentCc, sodass resolve_tournament den Tournament-Record findet.
# Sportwart hat sportwart_locations + sportwart_disciplines passend.
# Random-User hat keinen Wirkbereich → wird via Pundit-TournamentPolicy denied.
class WriteToolsAuthorityTest < ActiveSupport::TestCase
  setup do
    @location = locations(:one)
    @discipline = disciplines(:carom_3band)
    @tournament = Tournament.create!(
      title: "WriteAuth-Test",
      season_id: 50_000_001,
      organizer_id: 50_000_001,
      organizer_type: "Region",
      discipline_id: @discipline.id,
      tournament_plan_id: 50_000_100,
      location_id: @location.id,
      state: "tournament_mode_defined",
      date: 1.week.from_now
    )
    @rlc = RegistrationListCc.new(cc_id: 90_001, context: "nbv")
    @rlc.save(validate: false)
    @tournament_cc = TournamentCc.create!(
      cc_id: 80_001, context: "nbv",
      tournament: @tournament, registration_list_cc: @rlc
    )
    @sportwart = User.create!(email: "wta_sw@test.de", password: "password123")
    @sportwart.sportwart_locations << @location
    @sportwart.sportwart_disciplines << @discipline
    @random_user = User.create!(email: "wta_random@test.de", password: "password123")
    @sw_ctx = {user_id: @sportwart.id, cc_region: "NBV"}
    @random_ctx = {user_id: @random_user.id, cc_region: "NBV"}
  end

  # --- cc_register_for_tournament — :manage_teilnehmerliste? ---

  test "cc_register_for_tournament: Random-User → Authority-Denied" do
    result = McpServer::Tools::RegisterForTournament.call(
      fed_id: 1, branch_cc_id: 50, season: "2025/2026",
      meldeliste_cc_id: @rlc.cc_id,
      player_cc_id: 100, club_cc_id: 200, armed: false,
      server_context: @random_ctx
    )
    assert result.error?
    assert_match(/Authority-Denied/, result.content.first[:text])
  end

  test "cc_register_for_tournament: Sportwart-im-Wirkbereich → kein Authority-Block" do
    result = McpServer::Tools::RegisterForTournament.call(
      fed_id: 1, branch_cc_id: 50, season: "2025/2026",
      meldeliste_cc_id: @rlc.cc_id,
      player_cc_id: 100, club_cc_id: 200, armed: false,
      server_context: @sw_ctx
    )
    refute_match(/Authority-Denied/, result.content.first[:text]) if result.error?
  end

  # --- cc_unregister_for_tournament — :manage_teilnehmerliste? ---

  test "cc_unregister_for_tournament: Random-User → Authority-Denied" do
    result = McpServer::Tools::UnregisterForTournament.call(
      fed_id: 1, branch_cc_id: 50, season: "2025/2026",
      meldeliste_cc_id: @rlc.cc_id,
      player_cc_id: 100, club_cc_id: 200, armed: false,
      server_context: @random_ctx
    )
    assert result.error?
    assert_match(/Authority-Denied/, result.content.first[:text])
  end

  test "cc_unregister_for_tournament: Sportwart-im-Wirkbereich → kein Authority-Block" do
    result = McpServer::Tools::UnregisterForTournament.call(
      fed_id: 1, branch_cc_id: 50, season: "2025/2026",
      meldeliste_cc_id: @rlc.cc_id,
      player_cc_id: 100, club_cc_id: 200, armed: false,
      server_context: @sw_ctx
    )
    refute_match(/Authority-Denied/, result.content.first[:text]) if result.error?
  end

  # --- cc_assign_player_to_teilnehmerliste — :manage_teilnehmerliste? ---

  test "cc_assign_player_to_teilnehmerliste: Random-User → Authority-Denied" do
    result = McpServer::Tools::AssignPlayerToTeilnehmerliste.call(
      tournament_cc_id: @tournament_cc.cc_id,
      player_cc_ids: [100], armed: false,
      server_context: @random_ctx
    )
    assert result.error?
    assert_match(/Authority-Denied/, result.content.first[:text])
  end

  test "cc_assign_player_to_teilnehmerliste: Sportwart → kein Authority-Block" do
    result = McpServer::Tools::AssignPlayerToTeilnehmerliste.call(
      tournament_cc_id: @tournament_cc.cc_id,
      player_cc_ids: [100], armed: false,
      server_context: @sw_ctx
    )
    refute_match(/Authority-Denied/, result.content.first[:text]) if result.error?
  end

  # --- cc_remove_from_teilnehmerliste — :manage_teilnehmerliste? ---

  test "cc_remove_from_teilnehmerliste: Random-User → Authority-Denied" do
    result = McpServer::Tools::RemoveFromTeilnehmerliste.call(
      tournament_cc_id: @tournament_cc.cc_id,
      player_cc_id: 100, armed: false,
      server_context: @random_ctx
    )
    assert result.error?
    assert_match(/Authority-Denied/, result.content.first[:text])
  end

  test "cc_remove_from_teilnehmerliste: Sportwart → kein Authority-Block" do
    result = McpServer::Tools::RemoveFromTeilnehmerliste.call(
      tournament_cc_id: @tournament_cc.cc_id,
      player_cc_id: 100, armed: false,
      server_context: @sw_ctx
    )
    refute_match(/Authority-Denied/, result.content.first[:text]) if result.error?
  end

  # --- cc_finalize_teilnehmerliste — :manage_teilnehmerliste? ---

  test "cc_finalize_teilnehmerliste: Random-User → Authority-Denied" do
    result = McpServer::Tools::FinalizeTeilnehmerliste.call(
      fed_id: 1, branch_id: 50, season: "2025/2026",
      meldeliste_id: @rlc.cc_id, armed: false,
      server_context: @random_ctx
    )
    assert result.error?
    assert_match(/Authority-Denied/, result.content.first[:text])
  end

  test "cc_finalize_teilnehmerliste: Sportwart → kein Authority-Block" do
    result = McpServer::Tools::FinalizeTeilnehmerliste.call(
      fed_id: 1, branch_id: 50, season: "2025/2026",
      meldeliste_id: @rlc.cc_id, armed: false,
      server_context: @sw_ctx
    )
    refute_match(/Authority-Denied/, result.content.first[:text]) if result.error?
  end

  # --- cc_update_tournament_deadline — :update_deadline? ---

  test "cc_update_tournament_deadline: Random-User → Authority-Denied" do
    result = McpServer::Tools::UpdateTournamentDeadline.call(
      meldeliste_cc_id: @rlc.cc_id,
      new_deadline: "2026-12-31", armed: false,
      server_context: @random_ctx
    )
    assert result.error?
    assert_match(/Authority-Denied/, result.content.first[:text])
  end

  test "cc_update_tournament_deadline: Sportwart → kein Authority-Block" do
    result = McpServer::Tools::UpdateTournamentDeadline.call(
      meldeliste_cc_id: @rlc.cc_id,
      new_deadline: "2026-12-31", armed: false,
      server_context: @sw_ctx
    )
    refute_match(/Authority-Denied/, result.content.first[:text]) if result.error?
  end
end
