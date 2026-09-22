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

  # Plan 23-01: Der Rundenwechsel gehoert dem Turnierleiter. Bis 23-01 loeste ihn der gruene
  # Knopf am Scoreboard aus — von jedem, der am Tisch stand (NDM-Vorfall 2026-09-20).
  test "23-01: advance_round verlangt das Turnierleiter-Recht" do
    sign_out @club_admin
    sign_in users(:one)

    post advance_round_tournament_monitor_url(@tournament_monitor)

    assert_redirected_to root_path,
      "Ohne Turnierleiter-Recht darf die Runde nicht geschaltet werden koennen"
  end

  # Der Guard sitzt im Modell (round_ready_for_advance?), nicht nur in der View: ein direkter
  # POST auf eine nicht abschlussbereite Runde muss abgelehnt werden, nicht durchlaufen.
  test "23-01: advance_round lehnt eine nicht abschlussbereite Runde ab" do
    post advance_round_tournament_monitor_url(@tournament_monitor)

    assert_redirected_to tournament_monitor_path(@tournament_monitor)
    assert_equal I18n.t("tournament_monitors.round_status.advance_rejected"), flash[:alert]
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

end
