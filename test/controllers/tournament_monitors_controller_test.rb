# frozen_string_literal: true

require "test_helper"

class TournamentMonitorsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @original_api_url = Carambus.config.carambus_api_url
    Carambus.config.carambus_api_url = "http://local.test"
    @club_admin = users(:club_admin)
    @tournament = tournaments(:local)
    sign_in @club_admin
    # Create a TournamentMonitor for tests that need one
    @tournament_monitor = TournamentMonitor.create!(
      tournament: @tournament,
      state: "new_tournament_monitor",
      balls_goal: 30,
      innings_goal: 25,
      timeout: 0,
      timeouts: 2
    )
  end

  teardown do
    Carambus.config.carambus_api_url = @original_api_url
    @tournament_monitor&.destroy rescue nil
  end

  # ---------------------------------------------------------------------------
  # Auth guard: ensure_tournament_director
  # ---------------------------------------------------------------------------

  test "ensure_tournament_director redirects basic user to root" do
    sign_out @club_admin
    sign_in users(:one)
    get tournament_monitor_url(@tournament_monitor)
    assert_redirected_to root_path
  end

  # ---------------------------------------------------------------------------
  # Auth guard: ensure_local_server
  # ---------------------------------------------------------------------------

  test "ensure_local_server redirects to tournaments when no carambus_api_url" do
    Carambus.config.carambus_api_url = nil
    get tournament_monitor_url(@tournament_monitor)
    assert_redirected_to tournaments_path
  end

  # ---------------------------------------------------------------------------
  # Index — only requires sign-in, no local_server or director guard
  # ---------------------------------------------------------------------------

  test "should get index" do
    get tournament_monitors_url
    assert_response :success
  end

  # ---------------------------------------------------------------------------
  # CRUD actions (local server + club_admin signed in)
  # ---------------------------------------------------------------------------

  test "should show tournament_monitor" do
    get tournament_monitor_url(@tournament_monitor)
    assert_response :success
  end

  test "should get edit" do
    get edit_tournament_monitor_url(@tournament_monitor)
    assert_response :success
  end

  test "should update tournament_monitor" do
    patch tournament_monitor_url(@tournament_monitor), params: {
      tournament_monitor: {
        balls_goal: 35,
        innings_goal: 30,
        timeout: 0,
        timeouts: 2
      }
    }
    assert_redirected_to tournament_monitor_url(@tournament_monitor)
  end

  test "should destroy tournament_monitor" do
    assert_difference("TournamentMonitor.count", -1) do
      delete tournament_monitor_url(@tournament_monitor)
    end
    assert_redirected_to tournament_monitors_url
    @tournament_monitor = nil # already destroyed, skip teardown destroy
  end

  # ---------------------------------------------------------------------------
  # Game pipeline actions — no games/table_monitors exist, so these redirect
  # ---------------------------------------------------------------------------

  test "switch_players redirects when no game_id given" do
    post switch_players_tournament_monitor_url(@tournament_monitor)
    assert_redirected_to tournament_monitor_path(@tournament_monitor)
  end

  test "start_round_games redirects after processing (no table_monitors to transition)" do
    post start_round_games_tournament_monitor_url(@tournament_monitor)
    assert_redirected_to tournament_monitor_path(@tournament_monitor)
  end

  test "update_games redirects when no game_id params" do
    post update_games_tournament_monitor_url(@tournament_monitor)
    assert_redirected_to tournament_monitor_path(@tournament_monitor)
  end

  # ----------------------------------------------------------------
  # Phase 38.7 Plan 12 — Gap-04: TournamentMonitor startup form tiebreak override.
  # The form ships a checkbox; submission persists onto Tournament.data
  # (resolver Level 1, NOT TournamentMonitor.data). Plan 04's resolver picks
  # it up at every Game's start_game.
  #
  # AUTH NOTE: Persistence is gated to the :update action only. The :create
  # action is NOT covered by ensure_tournament_director (verified at
  # tournament_monitors_controller.rb lines 1-4). The checkbox renders in
  # `new` for UX continuity but its value is intentionally ignored on create.
  # G4 is the regression test that locks this contract.
  # ----------------------------------------------------------------

  test "G1 (Gap-04): PATCH update with tournament_tiebreak_on_draw=1 persists Tournament.data['tiebreak_on_draw']=true" do
    # Ensure clean baseline (setup uses tournaments(:local) which has no data["tiebreak_on_draw"])
    @tournament.update!(data: (@tournament.data.is_a?(Hash) ? @tournament.data : {}).reject { |k, _| k == "tiebreak_on_draw" })

    patch tournament_monitor_url(@tournament_monitor), params: {
      tournament_monitor: { balls_goal: @tournament_monitor.balls_goal },
      tournament_tiebreak_on_draw: "1"
    }

    @tournament.reload
    data = @tournament.data.is_a?(Hash) ? @tournament.data : JSON.parse(@tournament.data.to_s)
    assert_equal true, data["tiebreak_on_draw"],
      "Gap-04: form tournament_tiebreak_on_draw=1 must persist Tournament.data['tiebreak_on_draw']=true"

    # Resolver wires it to Level 1
    assert_equal true,
      Game.derive_tiebreak_required(tournament: @tournament, tournament_plan: nil, group_no: nil),
      "Gap-04: resolver Level 1 must read Tournament.data['tiebreak_on_draw']=true"
  end

  test "G2 (Gap-04): PATCH update with tournament_tiebreak_on_draw=0 overrides plan default true" do
    @tournament.update!(data: {})

    patch tournament_monitor_url(@tournament_monitor), params: {
      tournament_monitor: { balls_goal: @tournament_monitor.balls_goal },
      tournament_tiebreak_on_draw: "0"
    }

    @tournament.reload
    data = @tournament.data.is_a?(Hash) ? @tournament.data : JSON.parse(@tournament.data.to_s)
    assert_equal false, data["tiebreak_on_draw"],
      "Gap-04: form tournament_tiebreak_on_draw=0 must persist Tournament.data['tiebreak_on_draw']=false (explicit override)"

    assert_equal false,
      Game.derive_tiebreak_required(tournament: @tournament, tournament_plan: nil, group_no: nil),
      "Gap-04: resolver Level 1 must read explicit false"
  end

  test "G3 (Gap-04): PATCH update without tournament_tiebreak_on_draw param leaves Tournament.data['tiebreak_on_draw'] untouched" do
    # Pre-existing value: true
    existing_data = (@tournament.data.is_a?(Hash) ? @tournament.data : {}).merge("tiebreak_on_draw" => true)
    @tournament.update!(data: existing_data)

    patch tournament_monitor_url(@tournament_monitor), params: {
      tournament_monitor: { balls_goal: @tournament_monitor.balls_goal }
      # no tournament_tiebreak_on_draw key
    }

    @tournament.reload
    data = @tournament.data.is_a?(Hash) ? @tournament.data : JSON.parse(@tournament.data.to_s)
    assert_equal true, data["tiebreak_on_draw"],
      "Gap-04: missing form param must NOT overwrite existing Tournament.data['tiebreak_on_draw']"
  end

  test "G4 (Gap-04): POST create with tournament_tiebreak_on_draw=1 does NOT touch Tournament.data (auth gate — :create is not director-gated)" do
    # Clean baseline — Tournament.data has no key.
    @tournament.update!(data: (@tournament.data.is_a?(Hash) ? @tournament.data : {}).reject { |k, _| k == "tiebreak_on_draw" })

    # Create path: param value is intentionally ignored server-side because
    # :create is not protected by ensure_tournament_director (see controller
    # lines 1-4). Operator must edit the monitor afterward to persist the value.
    assert_difference("TournamentMonitor.count", 1) do
      post tournament_monitors_url, params: {
        tournament_monitor: { tournament_id: @tournament.id, balls_goal: 30, innings_goal: 25, timeout: 0, timeouts: 2 },
        tournament_tiebreak_on_draw: "1"
      }
    end

    @tournament.reload
    data = @tournament.data.is_a?(Hash) ? @tournament.data : JSON.parse(@tournament.data.to_s)
    assert_nil data["tiebreak_on_draw"],
      "Gap-04: :create must NOT persist Tournament.data['tiebreak_on_draw'] (auth surface unchanged — only :update is director-gated)"
  end
end
