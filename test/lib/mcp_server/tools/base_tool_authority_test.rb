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
end
