# frozen_string_literal: true

require "test_helper"

# Plan 14-G.2 / D-14-G4 + D-14-G5: Tests für BaseTool.authorize!-Helper.
# Konsumiert Pundit-TournamentPolicy (4 Methoden aus 14-G.1).
class BaseToolAuthorityTest < ActiveSupport::TestCase
  setup do
    @location = locations(:one)
    @discipline = disciplines(:carom_3band)
    @tournament = Tournament.create!(
      title: "Authority-Test-Tournament",
      season_id: 50_000_001,
      organizer_id: 50_000_001,
      organizer_type: "Region",
      discipline_id: @discipline.id,
      tournament_plan_id: 50_000_100,
      location_id: @location.id,
      state: "tournament_mode_defined",
      date: 1.week.from_now
    )
    @sportwart = User.create!(email: "authority_sportwart@test.de", password: "password123")
    @tl_user = User.create!(email: "authority_tl@test.de", password: "password123")
    @random_user = User.create!(email: "authority_random@test.de", password: "password123")

    # Sportwart-Wirkbereich (Location + Disziplin)
    @sportwart.sportwart_locations << @location
    @sportwart.sportwart_disciplines << @discipline

    # TL-Zuordnung
    @tournament.update!(turnier_leiter_user_id: @tl_user.id)
  end

  # --- Eingabe-Validation ---

  test "authorize! mit unbekannter action → error" do
    result = McpServer::Tools::BaseTool.authorize!(
      action: :unknown,
      tournament: @tournament,
      server_context: {user_id: @sportwart.id}
    )
    assert result.error?
    assert_match(/unbekannt/, result.content.first[:text])
  end

  test "authorize! mit tournament=nil → error" do
    result = McpServer::Tools::BaseTool.authorize!(
      action: :assign_leiter,
      tournament: nil,
      server_context: {user_id: @sportwart.id}
    )
    assert result.error?
    assert_match(/tournament-Argument fehlt/, result.content.first[:text])
  end

  test "authorize! mit fehlendem server_context[:user_id] → error" do
    result = McpServer::Tools::BaseTool.authorize!(
      action: :assign_leiter,
      tournament: @tournament,
      server_context: {}
    )
    assert result.error?
    assert_match(/nicht authentifiziert/, result.content.first[:text])
  end

  test "authorize! mit nil-server_context → error" do
    result = McpServer::Tools::BaseTool.authorize!(
      action: :assign_leiter,
      tournament: @tournament,
      server_context: nil
    )
    assert result.error?
    assert_match(/nicht authentifiziert/, result.content.first[:text])
  end

  test "authorize! mit unbekanntem user_id → error" do
    result = McpServer::Tools::BaseTool.authorize!(
      action: :assign_leiter,
      tournament: @tournament,
      server_context: {user_id: 999_999_999}
    )
    assert result.error?
    assert_match(/nicht gefunden/, result.content.first[:text])
  end

  # --- :assign_leiter (nur Sportwart im Wirkbereich) ---

  test "authorize! :assign_leiter — Sportwart im Wirkbereich → nil (allow)" do
    result = McpServer::Tools::BaseTool.authorize!(
      action: :assign_leiter,
      tournament: @tournament,
      server_context: {user_id: @sportwart.id}
    )
    assert_nil result
  end

  test "authorize! :assign_leiter — Random-User → error (denial mit Reasons)" do
    result = McpServer::Tools::BaseTool.authorize!(
      action: :assign_leiter,
      tournament: @tournament,
      server_context: {user_id: @random_user.id}
    )
    assert result.error?
    assert_match(/Authority-Denied/, result.content.first[:text])
    assert_match(/Sportwart-Wirkbereich=nein/, result.content.first[:text])
  end

  test "authorize! :assign_leiter — TL (nicht Sportwart) → error (TL darf nicht TL benennen)" do
    result = McpServer::Tools::BaseTool.authorize!(
      action: :assign_leiter,
      tournament: @tournament,
      server_context: {user_id: @tl_user.id}
    )
    assert result.error?
    assert_match(/Authority-Denied/, result.content.first[:text])
  end

  # --- :enter_results (nur TL) ---

  test "authorize! :enter_results — TL → nil (allow)" do
    result = McpServer::Tools::BaseTool.authorize!(
      action: :enter_results,
      tournament: @tournament,
      server_context: {user_id: @tl_user.id}
    )
    assert_nil result
  end

  test "authorize! :enter_results — Sportwart-not-TL → error (denial)" do
    result = McpServer::Tools::BaseTool.authorize!(
      action: :enter_results,
      tournament: @tournament,
      server_context: {user_id: @sportwart.id}
    )
    assert result.error?
    assert_match(/TL-Status=nein/, result.content.first[:text])
  end

  # --- :update_deadline (TL ODER Sportwart) ---

  test "authorize! :update_deadline — TL → nil (allow)" do
    result = McpServer::Tools::BaseTool.authorize!(
      action: :update_deadline,
      tournament: @tournament,
      server_context: {user_id: @tl_user.id}
    )
    assert_nil result
  end

  test "authorize! :update_deadline — Sportwart im Wirkbereich → nil (allow)" do
    result = McpServer::Tools::BaseTool.authorize!(
      action: :update_deadline,
      tournament: @tournament,
      server_context: {user_id: @sportwart.id}
    )
    assert_nil result
  end

  # --- :manage_teilnehmerliste (TL ODER Sportwart) — Random-User denied mit beiden Reasons ---

  test "authorize! :manage_teilnehmerliste — Random-User → error (denial mit beiden Reasons)" do
    result = McpServer::Tools::BaseTool.authorize!(
      action: :manage_teilnehmerliste,
      tournament: @tournament,
      server_context: {user_id: @random_user.id}
    )
    assert result.error?
    assert_match(/TL-Status=nein/, result.content.first[:text])
    assert_match(/Sportwart-Wirkbereich=nein/, result.content.first[:text])
  end

  # --- Plan 14-G.4 / F5-A: Tournament-Resolver-Specs ---

  test "resolve_tournament: beide cc_ids nil → nil" do
    result = McpServer::Tools::BaseTool.resolve_tournament(
      meldeliste_cc_id: nil, tournament_cc_id: nil, server_context: {cc_region: "NBV"}
    )
    assert_nil result
  end

  test "resolve_tournament: blanker server_context → nil (kein Region-Lookup möglich)" do
    result = McpServer::Tools::BaseTool.resolve_tournament(
      meldeliste_cc_id: 12_345, tournament_cc_id: nil, server_context: {}
    )
    assert_nil result
  end

  test "resolve_tournament: unknown meldeliste_cc_id → nil (defensiv, kein Crash)" do
    result = McpServer::Tools::BaseTool.resolve_tournament(
      meldeliste_cc_id: 99_999_999, tournament_cc_id: nil, server_context: {cc_region: "NBV"}
    )
    assert_nil result
  end

  test "resolve_tournament: meldeliste_cc_id mit gültiger RegistrationListCc→TournamentCc→Tournament-Kette → Tournament" do
    # save(validate: false) — Test-Setup umgeht RegistrationListCc-belongs_to-Validations
    # (branch_cc/season/discipline/category_cc); für Authority-Resolver ist nur die
    # cc_id+context-Such-Kette relevant.
    rlc = RegistrationListCc.new(cc_id: 90_001, context: "nbv")
    rlc.save(validate: false)
    TournamentCc.create!(cc_id: 80_001, context: "nbv", tournament: @tournament, registration_list_cc: rlc)
    result = McpServer::Tools::BaseTool.resolve_tournament(
      meldeliste_cc_id: 90_001, tournament_cc_id: nil, server_context: {cc_region: "NBV"}
    )
    assert_equal @tournament.id, result&.id
  end

  test "resolve_tournament: tournament_cc_id mit gültiger TournamentCc→Tournament-Kette → Tournament" do
    TournamentCc.create!(cc_id: 80_002, context: "nbv", tournament: @tournament)
    result = McpServer::Tools::BaseTool.resolve_tournament(
      meldeliste_cc_id: nil, tournament_cc_id: 80_002, server_context: {cc_region: "NBV"}
    )
    assert_equal @tournament.id, result&.id
  end
end
