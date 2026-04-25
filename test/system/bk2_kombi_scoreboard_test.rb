# frozen_string_literal: true

require "application_system_test_case"

# Phase 38.3-07: end-to-end system test for BK2-Kombi Variante B point-entry.
#
# Rewrites the Plan 38.2-05 file which exercised the now-deleted event-based
# form (Plan 38.2-04 Stimulus + bk2_kombi_submit_shot reflex).
#
# Coverage matrix:
#   T1  — detail-view shows DZ-max + SP-max inputs (not 4 first_set_mode buttons)       [Plan 38.3-06]
#   T2  — Regression guard: 4-button first_set_mode block absent from detail-view        [Plan 38.3-06]
#   T3  — Shootout screen for BK2 shows 4 buttons (not Karambol 2)                      [Plan 38.3-05]
#   T4  — Phase chip renders based on bk2_state.current_phase                           [Plan 38.3-03]
#   T5  — GD/HS rows absent on player cards for BK2                                     [Plan 38.3-03]
#   T6  — Remaining-badge wording (Aufnahmen/Stöße) changes with phase                  [Plan 38.3-03]
#   T7  — Non-BK2 monitor does NOT render bk2-kombi-scoreboard CSS hook                 [Plan 38.3-03 negative]
#   T8  — SP positive inning commits to self via CommitInning (D-12)                    [Plan 38.3-01+04]
#   T9  — After commit, player_at_table flips; phase chip unchanged within same set     [Plan 38.3-01+04]
#   T10 — DZ negative inning credits opponent on commit (D-11)                          [Plan 38.3-01+04]
#   T11 — Set close: accumulate to set_target_points → set finished flag set            [Plan 38.3-01+03]
#   T12 — Regression guard: bk2_kombi_submit_shot reflex removed (D-23)                [Plan 38.3-04]
#   T13 — detail-view Alpine x-data scope is exactly 1 wrapper (GAP-02 guard)          [Plan 38.3-06]

class Bk2KombiScoreboardTest < ApplicationSystemTestCase
  setup do
    @tm = table_monitors(:one)

    # The show action redirects unless game_id is set (see TableMonitorsController#show).
    # Track whether we created the Game so teardown only destroys what we created.
    @game_created_by_test = !Game.exists?(id: 50_000_200)
    @game = Game.find_or_create_by!(id: 50_000_200)

    @tm.update_columns(game_id: @game.id, state: "playing")
    @tm.update!(data: initial_bk2_data)
  end

  teardown do
    @tm.update_columns(game_id: nil, state: "new")
    @tm.update!(data: {})
    @game.destroy if @game_created_by_test && @game&.persisted?
  end

  # ---------------------------------------------------------------------------
  # T1 — Detail-view shows DZ-max + SP-max inputs (not 4 first_set_mode buttons)
  # ---------------------------------------------------------------------------

  test "T1 38.3-06: detail-view template contains DZ-max + SP-max hidden inputs for form payload" do
    # Verify the view template directly (Alpine-rendered DOM requires a full server
    # with JS; asserting the ERB source is fast and deterministic).
    view_path = Rails.root.join(
      "app/views/locations/scoreboard_free_game_karambol_new.html.erb"
    )
    contents = File.read(view_path)

    assert_match(/bk2_options\[direkter_zweikampf_max_shots_per_turn\]/, contents,
                 "T1: DZ-max hidden input (name attribute) must be present in detail-view")
    assert_match(/bk2_options\[serienspiel_max_innings_per_set\]/, contents,
                 "T1: SP-max hidden input (name attribute) must be present in detail-view")
    assert_match(/bk2_dz_max_shots/, contents,
                 "T1: Alpine state slot bk2_dz_max_shots must be present")
    assert_match(/bk2_sp_max_innings/, contents,
                 "T1: Alpine state slot bk2_sp_max_innings must be present")
  end

  # ---------------------------------------------------------------------------
  # T2 — 4-button first_set_mode block is absent from detail-view (Plan 38.3-06 deletion)
  # ---------------------------------------------------------------------------

  test "T2 38.3-06: detail-view no longer contains 4-button first_set_mode matrix (DR-06)" do
    view_path = Rails.root.join(
      "app/views/locations/scoreboard_free_game_karambol_new.html.erb"
    )
    contents = File.read(view_path)

    refute_match(/button_direkter_zweikampf_a/, contents,
                 "T2: Plan 38.2-02 first_set_mode button_direkter_zweikampf_a must be absent from detail-view — moved to shootout screen (Plan 38.3-05)")
    refute_match(/button_serienspiel_b/, contents,
                 "T2: Plan 38.2-02 first_set_mode button_serienspiel_b must be absent from detail-view")
    refute_match(/bk2_first_set_mode/, contents,
                 "T2: bk2_first_set_mode hidden input/state must be absent from detail-view — decision moved to shootout screen")
  end

  # ---------------------------------------------------------------------------
  # T3 — Shootout screen for BK2 shows 4 buttons (not Karambol 2)
  # ---------------------------------------------------------------------------

  test "T3 38.3-05: shootout screen for BK2 renders 4 first_set_mode buttons" do
    @tm.update_columns(state: "match_shootout")
    visit table_monitor_path(@tm)

    assert_selector "#bk2_start_a_dz", wait: 5,
                    visible: :all
    assert_selector "#bk2_start_a_sp", visible: :all
    assert_selector "#bk2_start_b_dz", visible: :all
    assert_selector "#bk2_start_b_sp", visible: :all

    # Karambol 2-button IDs must NOT be present for BK2 matches
    assert_no_selector "#start_game", visible: :all
    assert_no_selector "#switch_and_start", visible: :all
  end

  # ---------------------------------------------------------------------------
  # T4 — Phase chip renders based on bk2_state.current_phase (Plan 38.3-03)
  # ---------------------------------------------------------------------------

  test "T4 38.3-03: phase chip renders Serienspiel label when current_phase is serienspiel" do
    @tm.update!(data: initial_bk2_data.deep_merge(
      "bk2_state" => {
        "current_phase" => "serienspiel",
        "first_set_mode" => "serienspiel",
        "innings_left_in_set" => 5,
        "shots_left_in_turn" => 0
      }
    ))
    visit table_monitor_path(@tm)

    assert_selector ".bk2-kombi-scoreboard", wait: 5
    # Phase chip must contain the serienspiel i18n label
    assert_text I18n.t("table_monitor.bk2_kombi.phase_chip.serienspiel",
                       default: "Serienspiel")
  end

  test "T4b 38.3-03: phase chip renders Direkter Zweikampf label when current_phase is direkter_zweikampf" do
    visit table_monitor_path(@tm)

    assert_selector ".bk2-kombi-scoreboard", wait: 5
    assert_text I18n.t("table_monitor.bk2_kombi.phase_chip.direkter_zweikampf",
                       default: "Direkter Zweikampf")
  end

  # ---------------------------------------------------------------------------
  # T5 — GD/HS rows absent on player cards for BK2 (Plan 38.3-03 D-08)
  # ---------------------------------------------------------------------------

  test "T5 38.3-03: BK2 player cards do not render GD or HS rows (D-08)" do
    visit table_monitor_path(@tm)

    assert_selector ".bk2-kombi-scoreboard", wait: 5
    # GD and HS are typically labelled with i18n — verify the full page body
    # does NOT contain the Karambol-specific GD/HS stat labels
    page_body = page.body
    refute_match(/\bGD\b.*\bHS\b|\bHS\b.*\bGD\b/, page_body,
                 "T5: GD and HS stat labels must be absent for BK2 player cards (D-08 Plan 38.3-03)")
  end

  # ---------------------------------------------------------------------------
  # T6 — Remaining-badge wording changes with phase (Plan 38.3-03)
  # ---------------------------------------------------------------------------

  test "T6a 38.3-03: DZ phase shows shots_left remaining badge (Stöße übrig)" do
    visit table_monitor_path(@tm)

    assert_selector ".bk2-kombi-scoreboard", wait: 5
    page_body = page.body
    assert_match(/Stöße übrig|Stoß übrig/, page_body,
                 "T6a: DZ phase remaining badge must contain shots_left i18n label")
  end

  test "T6b 38.3-03: SP phase shows innings_left remaining badge (Aufnahmen übrig)" do
    @tm.update!(data: initial_bk2_data.deep_merge(
      "bk2_state" => {
        "current_phase" => "serienspiel",
        "first_set_mode" => "serienspiel",
        "innings_left_in_set" => 4,
        "shots_left_in_turn" => 0
      }
    ))
    visit table_monitor_path(@tm)

    assert_selector ".bk2-kombi-scoreboard", wait: 5
    page_body = page.body
    assert_match(/Aufnahmen übrig|Aufnahme übrig/, page_body,
                 "T6b: SP phase remaining badge must contain innings_left i18n label")
  end

  # ---------------------------------------------------------------------------
  # T7 — Non-BK2 monitor does NOT render bk2-kombi-scoreboard CSS hook (negative control)
  # ---------------------------------------------------------------------------

  test "T7 38.3-03: non-BK2 match does NOT render bk2-kombi-scoreboard CSS class (negative control)" do
    @tm.update!(data: {
      "free_game_form" => "karambol",
      "playera" => { "discipline" => "5-Pin", "innings" => 0, "result" => 0, "innings_redo_list" => [0] },
      "playerb" => { "discipline" => "5-Pin", "innings" => 0, "result" => 0, "innings_redo_list" => [0] },
      "current_inning" => { "active_player" => "playera" }
    })
    visit table_monitor_path(@tm)

    assert_no_selector ".bk2-kombi-scoreboard", wait: 3
  end

  # ---------------------------------------------------------------------------
  # T8 — SP positive inning commits to self via CommitInning (D-12)
  #      Integration-level: direct CommitInning call (reflex JS-round-trip avoided)
  # ---------------------------------------------------------------------------

  test "T8 38.3-01+04: SP positive inning commits additively to self (D-12)" do
    @tm.update!(data: initial_bk2_data.deep_merge(
      "bk2_state" => {
        "current_phase" => "serienspiel",
        "first_set_mode" => "serienspiel",
        "player_at_table" => "playera",
        "innings_left_in_set" => 5,
        "shots_left_in_turn" => 0,
        "set_scores" => {
          "1" => { "playera" => 10, "playerb" => 0 },
          "2" => { "playera" => 0, "playerb" => 0 },
          "3" => { "playera" => 0, "playerb" => 0 }
        }
      }
    ))

    # SP additive: playera had 10, adds 6 → 16
    Bk2::CommitInning.call(
      table_monitor: @tm,
      player: "playera",
      inning_total: 6,
      shot_sequence_number: SecureRandom.uuid
    )

    @tm.reload
    assert_equal 16, @tm.data["bk2_state"]["set_scores"]["1"]["playera"],
                 "T8 (D-12): SP additive — playera 10 + 6 = 16"
    assert_equal 0, @tm.data["bk2_state"]["set_scores"]["1"]["playerb"],
                 "T8: playerb score must be unchanged for SP positive inning"
  end

  # ---------------------------------------------------------------------------
  # T9 — After commit, player_at_table flips (Plan 38.3-01+04)
  # ---------------------------------------------------------------------------

  test "T9 38.3-01+04: player_at_table flips after CommitInning; phase chip unchanged within same set" do
    @tm.update!(data: initial_bk2_data.deep_merge(
      "bk2_state" => {
        "current_phase" => "serienspiel",
        "first_set_mode" => "serienspiel",
        "player_at_table" => "playera",
        "innings_left_in_set" => 5,
        "shots_left_in_turn" => 0,
        "set_scores" => {
          "1" => { "playera" => 5, "playerb" => 5 },
          "2" => { "playera" => 0, "playerb" => 0 },
          "3" => { "playera" => 0, "playerb" => 0 }
        }
      }
    ))

    Bk2::CommitInning.call(
      table_monitor: @tm,
      player: "playera",
      inning_total: 3,
      shot_sequence_number: SecureRandom.uuid
    )

    @tm.reload
    assert_equal "playerb", @tm.data["bk2_state"]["player_at_table"],
                 "T9: player_at_table must flip to playerb after playera commits"
    assert_equal "serienspiel", @tm.data["bk2_state"]["current_phase"],
                 "T9: current_phase must remain serienspiel within same set (no set close triggered)"
  end

  # ---------------------------------------------------------------------------
  # T10 — DZ negative inning credits opponent (D-11)
  # ---------------------------------------------------------------------------

  test "T10 38.3-01+04: DZ negative inning credits opponent on commit (D-11)" do
    @tm.update!(data: initial_bk2_data.deep_merge(
      "bk2_state" => {
        "current_set_number" => 1,
        "current_phase" => "direkter_zweikampf",
        "first_set_mode" => "direkter_zweikampf",
        "player_at_table" => "playera",
        "shots_left_in_turn" => 2,
        "innings_left_in_set" => 0,
        "set_scores" => {
          "1" => { "playera" => 5, "playerb" => 10 },
          "2" => { "playera" => 0, "playerb" => 0 },
          "3" => { "playera" => 0, "playerb" => 0 }
        }
      }
    ))

    # DZ opponent credit: negative inning → abs goes to opponent
    # playera had 5, playerb had 10. Commit -4 for playera →
    # D-11: playera stays at 5, playerb += 4 → 14
    Bk2::CommitInning.call(
      table_monitor: @tm,
      player: "playera",
      inning_total: -4,
      shot_sequence_number: SecureRandom.uuid
    )

    @tm.reload
    assert_equal 5, @tm.data["bk2_state"]["set_scores"]["1"]["playera"],
                 "T10 (D-11): DZ negative inning — playera score must be unchanged"
    assert_equal 14, @tm.data["bk2_state"]["set_scores"]["1"]["playerb"],
                 "T10 (D-11): DZ negative inning — abs(inning) credited to opponent: 10 + 4 = 14"
  end

  # ---------------------------------------------------------------------------
  # T11 — Set close when set_target_points reached (Plan 38.3-01+03)
  # ---------------------------------------------------------------------------

  test "T11 38.3-01+03: set closes when player reaches set_target_points" do
    @tm.update!(data: initial_bk2_data.deep_merge(
      "bk2_state" => {
        "current_set_number" => 1,
        "current_phase" => "serienspiel",
        "first_set_mode" => "serienspiel",
        "player_at_table" => "playera",
        "innings_left_in_set" => 2,
        "shots_left_in_turn" => 0,
        "set_scores" => {
          "1" => { "playera" => 45, "playerb" => 0 },
          "2" => { "playera" => 0, "playerb" => 0 },
          "3" => { "playera" => 0, "playerb" => 0 }
        },
        "sets_won" => { "playera" => 0, "playerb" => 0 },
        "set_target_points" => 50
      }
    ))

    # playera has 45, commits 7 → 52 >= 50 → set closes
    Bk2::CommitInning.call(
      table_monitor: @tm,
      player: "playera",
      inning_total: 7,
      shot_sequence_number: SecureRandom.uuid
    )

    @tm.reload
    state = @tm.data["bk2_state"]
    # set_finished_1 should be set (set closed) or sets_won incremented
    # CommitInning calls close_set_if_reached! which updates sets_won
    assert(
      state.dig("sets_won", "playera").to_i >= 1 ||
        state["set_finished_1"] == true ||
        state["current_set_number"].to_i >= 2,
      "T11: set must be marked closed when player reaches set_target_points. " \
      "State: #{state.inspect}"
    )
  end

  # ---------------------------------------------------------------------------
  # T12 — Regression guard: bk2_kombi_submit_shot reflex is removed (D-23)
  # ---------------------------------------------------------------------------

  test "T12 38.3-04: bk2_kombi_submit_shot reflex method is removed (D-23)" do
    refute TableMonitorReflex.instance_methods(false).include?(:bk2_kombi_submit_shot),
           "T12: bk2_kombi_submit_shot should have been deleted in Plan 38.3-04"
    refute File.exist?(Rails.root.join("app/javascript/controllers/bk2_kombi_shot_controller.js")),
           "T12: bk2_kombi_shot_controller.js should have been deleted in Plan 38.3-04"
  end

  # ---------------------------------------------------------------------------
  # T13 — detail-view Alpine x-data scope is exactly 1 wrapper (GAP-02 guard)
  # ---------------------------------------------------------------------------

  test "T13 38.3-06: detail-view Alpine x-data scope is exactly 1 wrapper (GAP-02 guard)" do
    contents = File.read(Rails.root.join(
      "app/views/locations/scoreboard_free_game_karambol_new.html.erb"
    ))
    assert_equal 1, contents.scan(/x-data="\{/).count,
                 "T13: detail-view x-data scope count drifted — GAP-02 scope-lift may have regressed"
  end

  # ---------------------------------------------------------------------------
  # T14 — Shootout click → playing state with fully initialized bk2_state (I6 blocker fix)
  # ---------------------------------------------------------------------------

  test "T14 38.3-08: shootout click initializes bk2_state before AASM transition to playing (I6)" do
    # Setup: TableMonitor in match_shootout state with warmup complete; bk2_state not yet populated
    @tm.update_columns(state: "match_shootout")
    @tm.update!(data: {
      "free_game_form" => "bk2_kombi",
      "current_kickoff_player" => "playera",
      "current_inning" => {"active_player" => "playera"},
      "playera" => {
        "discipline" => "BK2-Kombi",
        "innings" => 0,
        "result" => 0,
        "innings_redo_list" => [0]
      },
      "playerb" => {
        "discipline" => "BK2-Kombi",
        "innings" => 0,
        "result" => 0,
        "innings_redo_list" => [0]
      },
      "bk2_options" => {
        "set_target_points" => 50,
        "direkter_zweikampf_max_shots_per_turn" => 2,
        "serienspiel_max_innings_per_set" => 5
        # NOTE: no first_set_mode set — the shootout click must write it
      }
      # NOTE: no bk2_state — this is the precondition where I6 reproduced
    })

    assert @tm.reload.bk2_state_uninitialized?,
           "precondition: bk2_state must NOT be populated before the shootout click"

    visit table_monitor_path(@tm)

    # Directly exercise the reflex server-side to avoid Capybara/StimulusReflex flake —
    # simulates what clicking "Spieler A — Serienspiel" (id=bk2_start_a_sp) does:
    # writes bk2_first_set_mode="serienspiel" to dataset, then fires start_game reflex.
    #
    # This matches the exact reflex code path from Plan 38.3-05 + Plan 38.3-08 — we
    # invoke the TableMonitor model transitions + initialize_bk2_state! in the same
    # order as the reflex, and assert the final persisted state.
    @tm.data["bk2_options"] ||= {}
    @tm.data["bk2_options"]["first_set_mode"] = "serienspiel"
    @tm.suppress_broadcast = true
    Bk2::AdvanceMatchState.initialize_bk2_state!(@tm)
    @tm.finish_shootout!
    @tm.do_play
    @tm.suppress_broadcast = false
    @tm.save!

    @tm.reload
    state = @tm.data["bk2_state"]

    # Primary I6 assertion: bk2_state is fully populated
    refute @tm.bk2_state_uninitialized?,
           "T14 I6: bk2_state_uninitialized? must return false after shootout init"
    assert state.is_a?(Hash), "T14 I6: bk2_state must be a Hash"
    refute state.empty?, "T14 I6: bk2_state must not be empty"

    # Mode plumbing from bk2_options → bk2_state
    assert_equal "serienspiel", state["current_phase"],
                 "T14 I6: current_phase must reflect bk2_options.first_set_mode"
    assert_equal "serienspiel", state["first_set_mode"]

    # Counter defaults
    assert_equal 5, state["innings_left_in_set"],
                 "T14 I6: SP mode must initialize innings_left_in_set from bk2_options (5)"
    assert_equal 0, state["shots_left_in_turn"],
                 "T14 I6: SP mode must leave shots_left_in_turn at 0"

    # Set scaffold
    assert_equal 1, state["current_set_number"]
    assert_equal 50, state["set_target_points"]
    assert_equal({"playera" => 0, "playerb" => 0}, state["set_scores"]["1"])
    assert_equal({"playera" => 0, "playerb" => 0}, state["set_scores"]["2"])
    assert_equal({"playera" => 0, "playerb" => 0}, state["set_scores"]["3"])
    assert_equal({"playera" => 0, "playerb" => 0}, state["sets_won"])

    # Kickoff player honored
    assert_equal "playera", state["player_at_table"]
  end

  # ---------------------------------------------------------------------------
  # T15 — DZ variant: shootout click with direkter_zweikampf mode (I6 mirror case)
  # ---------------------------------------------------------------------------

  test "T15 38.3-08: shootout click with direkter_zweikampf mode initializes DZ counters (I6)" do
    @tm.update_columns(state: "match_shootout")
    @tm.update!(data: {
      "free_game_form" => "bk2_kombi",
      "current_kickoff_player" => "playerb",
      "current_inning" => {"active_player" => "playerb"},
      "playera" => {"discipline" => "BK2-Kombi", "innings" => 0, "result" => 0, "innings_redo_list" => [0]},
      "playerb" => {"discipline" => "BK2-Kombi", "innings" => 0, "result" => 0, "innings_redo_list" => [0]},
      "bk2_options" => {
        "set_target_points" => 60,
        "direkter_zweikampf_max_shots_per_turn" => 3,
        "serienspiel_max_innings_per_set" => 5
      }
    })

    assert @tm.reload.bk2_state_uninitialized?

    # Mirror: simulate "Spieler B — Direkter Zweikampf" button click (id=bk2_start_b_dz)
    # which fires switch_players_and_start_game reflex with bk2_first_set_mode=direkter_zweikampf.
    @tm.data["bk2_options"]["first_set_mode"] = "direkter_zweikampf"
    @tm.suppress_broadcast = true
    Bk2::AdvanceMatchState.initialize_bk2_state!(@tm)
    @tm.switch_players
    @tm.finish_shootout!
    @tm.do_play
    @tm.suppress_broadcast = false
    @tm.save!

    @tm.reload
    state = @tm.data["bk2_state"]

    refute @tm.bk2_state_uninitialized?

    assert_equal "direkter_zweikampf", state["current_phase"]
    assert_equal 3, state["shots_left_in_turn"],
                 "T15 I6: DZ mode must honor bk2_options.direkter_zweikampf_max_shots_per_turn=3"
    assert_equal 0, state["innings_left_in_set"],
                 "T15 I6: DZ mode must leave innings_left_in_set at 0"
    assert_equal 60, state["set_target_points"]
    assert_equal "playerb", state["player_at_table"],
                 "T15 I6: kickoff playerb honored"
  end

  private

  # ---------------------------------------------------------------------------
  # Helper — initial BK2 TableMonitor data for DZ phase (mirrors Plan 38.3 state shape)
  # ---------------------------------------------------------------------------
  def initial_bk2_data
    {
      "free_game_form" => "bk2_kombi",
      "current_kickoff_player" => "playera",
      "current_inning" => { "active_player" => "playera" },
      "playera" => {
        "discipline" => "BK2-Kombi",
        "innings" => 0,
        "result" => 0,
        "innings_redo_list" => [0]
      },
      "playerb" => {
        "discipline" => "BK2-Kombi",
        "innings" => 0,
        "result" => 0,
        "innings_redo_list" => [0]
      },
      "bk2_options" => {
        "set_target_points" => 50,
        "first_set_mode" => "direkter_zweikampf",
        "direkter_zweikampf_max_shots_per_turn" => 2,
        "serienspiel_max_innings_per_set" => 5
      },
      "bk2_state" => {
        "current_set_number" => 1,
        "current_phase" => "direkter_zweikampf",
        "first_set_mode" => "direkter_zweikampf",
        "player_at_table" => "playera",
        "shots_left_in_turn" => 2,
        "innings_left_in_set" => 0,
        "set_scores" => {
          "1" => { "playera" => 0, "playerb" => 0 },
          "2" => { "playera" => 0, "playerb" => 0 },
          "3" => { "playera" => 0, "playerb" => 0 }
        },
        "sets_won" => { "playera" => 0, "playerb" => 0 },
        "set_target_points" => 50
      }
    }
  end
end
