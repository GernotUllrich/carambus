# frozen_string_literal: true

require "application_system_test_case"

# Phase 38.3-07 / Phase 38.4-07: end-to-end system test for all BK-* disciplines.
#
# Renamed from bk2_kombi_scoreboard_test.rb (Phase 38.4-07: single Bk2:: namespace).
# Covers Phase 38.3 T1-T15 (updated for BK-2plus/BK-2 strings and balls_goal key)
# plus Phase 38.4 regressions I8/I9 and all 5 BK-* discipline branches.
#
# Coverage matrix:
#   T1  — detail-view contains DZ-max + SP-max hidden inputs for form payload     [Plan 38.3-06]
#   T2  — Regression guard: 4-button first_set_mode block absent from detail-view [Plan 38.3-06]
#   T3  — Shootout screen for BK2-Kombi shows 4 buttons (not Karambol 2)         [Plan 38.3-05]
#   T4  — Phase chip renders based on bk2_state.current_phase                    [Plan 38.3-03]
#   T5  — GD/HS rows absent on player cards for BK2                              [Plan 38.3-03]
#   T6  — Remaining-badge wording (Aufnahmen/Stöße) changes with phase           [Plan 38.3-03]
#   T7  — Non-BK2 monitor does NOT render bk2-kombi-scoreboard CSS hook          [Plan 38.3-03 neg.]
#   T8  — SP positive inning commits to self via CommitInning (D-12)             [Plan 38.3-01+04]
#   T9  — After commit, player_at_table flips; phase unchanged within same set   [Plan 38.3-01+04]
#   T10 — DZ negative inning credits opponent on commit (D-11)                   [Plan 38.3-01+04]
#   T11 — Set closes when player reaches balls_goal (I9 / D-06 migration)        [Plan 38.4-07]
#   T12 — Regression: bk2_kombi_submit_shot reflex removed (D-23)               [Plan 38.3-04]
#   T13 — detail-view Alpine x-data scope is exactly 1 wrapper (GAP-02)         [Plan 38.3-06]
#   T14 — Shootout click initialises bk2_state before AASM transition (I6)      [Plan 38.3-08]
#   T15 — DZ variant of T14 (I6)                                                 [Plan 38.3-08]
#
#   Phase 38.4 regression guards:
#   I8a — delete button present in _show.html.erb fallback banner                [Plan 38.4-02]
#   I8b — delete_button key in DE/EN locale files                                [Plan 38.4-02]
#   I9a — set closes at balls_goal for BK-2 (service-level)                     [Plan 38.4-04]
#   I9b — set does NOT close below balls_goal for BK-2 (service-level)          [Plan 38.4-04]
#
#   BK-* family dispatch (service-level):
#   T-BK50         — BK50 additive, closes at balls_goal 50                     [Plan 38.4-05]
#   T-BK100        — BK100 additive, closes at balls_goal 100                   [Plan 38.4-05]
#   T-BK2plus-neg  — BK-2plus opponent-credit for negative inning               [Plan 38.4-05]
#   T-BK2plus-pos  — BK-2plus credits positive inning to player                 [Plan 38.4-05]
#   T-BK2-neg      — BK-2 additive, negative stays on player                    [Plan 38.4-05]
#   T-BK2kombi-DZ  — BK-2kombi DZ phase → opponent credit                      [Plan 38.4-05]
#   T-BK2kombi-SP  — BK-2kombi SP phase → additive                             [Plan 38.4-05]
#
#   View-content assertions (fast — read ERB file, no browser):
#   T-DZ-max-visibility   — DZ-max gated by is_bk_dz_configurable              [Plan 38.4-06]
#   T-SP-max-visibility   — SP-max gated by is_bk_sp_configurable              [Plan 38.4-06]
#   T-Ballziel-fixed-bk50 — BK50/BK100 use is_bk_fixed_goal for read-only      [Plan 38.4-06]
#
#   Shootout layout guards (browser):
#   T-shootout-4btn-bk2kombi — 4 buttons for BK-2kombi                         [Plan 38.4-06]
#   T-shootout-2btn-bk2      — generic 2-button for non-BK-2kombi              [Plan 38.4-06]
#   T-i18n-labels  — BK-2plus / BK-2 rename guard                              [Plan 38.4-03]
#   T-deleted-reflex — bk2_kombi_submit_shot endpoint absent                    [Plan 38.3-04]

class Bk2ScoreboardTest < ApplicationSystemTestCase
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
  # T2 — 4-button first_set_mode block is absent from detail-view (Plan 38.3-06)
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
  # T3 — Shootout screen for BK2-Kombi shows 4 buttons (Plan 38.3-05)
  # ---------------------------------------------------------------------------

  test "T3 38.3-05: shootout screen for BK2-Kombi renders 4 first_set_mode buttons" do
    @tm.update_columns(state: "match_shootout")
    visit table_monitor_path(@tm)

    assert_selector "#bk2_start_a_dz", wait: 5,
      visible: :all
    assert_selector "#bk2_start_a_sp", visible: :all
    assert_selector "#bk2_start_b_dz", visible: :all
    assert_selector "#bk2_start_b_sp", visible: :all

    # Karambol 2-button IDs must NOT be present for BK2-Kombi matches
    assert_no_selector "#start_game", visible: :all
    assert_no_selector "#switch_and_start", visible: :all
  end

  # ---------------------------------------------------------------------------
  # T4 — Phase chip renders based on bk2_state.current_phase (Plan 38.3-03)
  #      Updated for Plan 38.4-03: labels are now "BK-2" / "BK-2plus" (not "Serienspiel" etc.)
  # ---------------------------------------------------------------------------

  test "T4 38.3-03: phase chip renders BK-2 label when current_phase is serienspiel" do
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
    # Plan 38.4-03: serienspiel label is now "BK-2"
    assert_text I18n.t("table_monitor.bk2_kombi.phase_chip.serienspiel")
  end

  test "T4b 38.3-03: phase chip renders BK-2plus label when current_phase is direkter_zweikampf" do
    visit table_monitor_path(@tm)

    assert_selector ".bk2-kombi-scoreboard", wait: 5
    # Plan 38.4-03: direkter_zweikampf label is now "BK-2plus"
    assert_text I18n.t("table_monitor.bk2_kombi.phase_chip.direkter_zweikampf")
  end

  # ---------------------------------------------------------------------------
  # T5 — GD/HS rows absent on player cards for BK2 (Plan 38.3-03 D-08)
  # ---------------------------------------------------------------------------

  test "T5 38.3-03: BK2 player cards do not render GD or HS rows (D-08)" do
    visit table_monitor_path(@tm)

    assert_selector ".bk2-kombi-scoreboard", wait: 5
    page_body = page.body
    refute_match(/\bGD\b.*\bHS\b|\bHS\b.*\bGD\b/, page_body,
      "T5: GD and HS stat labels must be absent for BK2 player cards (D-08 Plan 38.3-03)")
  end

  # ---------------------------------------------------------------------------
  # T6 — Remaining-badge wording changes with phase (Plan 38.3-03)
  # ---------------------------------------------------------------------------

  # Phase 38.4 R5-6: Stöße-übrig-Badge wurde entfernt. Es gibt keine UI um
  # einen Stoß innerhalb der Aufnahme abzuschließen → Counter war ohne Funktion.
  # Test invertiert: prüft jetzt Abwesenheit der Badge in DZ-Phase.
  test "T6a R5-6: DZ phase does NOT show shots_left remaining badge (removed — no UI to advance shots)" do
    visit table_monitor_path(@tm)

    assert_selector ".bk2-kombi-scoreboard", wait: 5
    page_body = page.body
    refute_match(/Stöße übrig|Stoß übrig/, page_body,
      "T6a R5-6: shots_left badge must NOT render in DZ phase (removed in Phase 38.4 R5-6)")
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
  # T7 — Non-BK2 monitor does NOT render bk2-kombi-scoreboard CSS hook (neg.)
  # ---------------------------------------------------------------------------

  test "T7 38.3-03: non-BK2 match does NOT render bk2-kombi-scoreboard CSS class (negative control)" do
    @tm.update!(data: {
      "free_game_form" => "karambol",
      "playera" => {"discipline" => "5-Pin", "innings" => 0, "result" => 0, "innings_redo_list" => [0]},
      "playerb" => {"discipline" => "5-Pin", "innings" => 0, "result" => 0, "innings_redo_list" => [0]},
      "current_inning" => {"active_player" => "playera"}
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
          "1" => {"playera" => 10, "playerb" => 0},
          "2" => {"playera" => 0, "playerb" => 0},
          "3" => {"playera" => 0, "playerb" => 0}
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
  # T9 — After commit, player_at_table flips; phase chip unchanged within same set
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
          "1" => {"playera" => 5, "playerb" => 5},
          "2" => {"playera" => 0, "playerb" => 0},
          "3" => {"playera" => 0, "playerb" => 0}
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
          "1" => {"playera" => 5, "playerb" => 10},
          "2" => {"playera" => 0, "playerb" => 0},
          "3" => {"playera" => 0, "playerb" => 0}
        }
      }
    ))

    # DZ opponent credit: negative inning → abs goes to opponent
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
  # T11 — Set closes when player reaches balls_goal (I9 / D-06 migration)
  #        Updated from T11 38.3-01+03 — now uses balls_goal (not set_target_points)
  # ---------------------------------------------------------------------------

  test "T11 38.4-07 I9: set closes when player reaches balls_goal (D-06 migration)" do
    @tm.update!(data: initial_bk2_data.deep_merge(
      "bk2_state" => {
        "current_set_number" => 1,
        "current_phase" => "serienspiel",
        "first_set_mode" => "serienspiel",
        "player_at_table" => "playera",
        "innings_left_in_set" => 2,
        "shots_left_in_turn" => 0,
        "set_scores" => {
          "1" => {"playera" => 45, "playerb" => 0},
          "2" => {"playera" => 0, "playerb" => 0},
          "3" => {"playera" => 0, "playerb" => 0}
        },
        "sets_won" => {"playera" => 0, "playerb" => 0},
        "balls_goal" => 50
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
    assert(
      state.dig("sets_won", "playera").to_i >= 1 ||
        state["set_finished_1"] == true ||
        state["current_set_number"].to_i >= 2,
      "T11: set must close when player reaches balls_goal. State: #{state.inspect}"
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
    assert_equal 1, contents.scan('x-data="{').count,
      "T13: detail-view x-data scope count drifted — GAP-02 scope-lift may have regressed"
  end

  # ---------------------------------------------------------------------------
  # T14 — Shootout click → playing state with fully initialized bk2_state (I6)
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
    # simulates what clicking "Spieler A — BK-2" (id=bk2_start_a_sp) does:
    # writes bk2_first_set_mode="serienspiel" to dataset, then fires start_game reflex.
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

    # Mirror: simulate "Spieler B — BK-2plus" button click (id=bk2_start_b_dz)
    # which fires switch_players_and_start_game with bk2_first_set_mode=direkter_zweikampf.
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
    assert_equal "playerb", state["player_at_table"],
      "T15 I6: kickoff playerb honored"
  end

  # ===========================================================================
  # Phase 38.4 I8 — delete button on fallback banner
  # ===========================================================================

  test "I8a 38.4-02: delete button is present in bk2_state_uninitialized fallback banner" do
    # Verify the view template directly — fast and deterministic.
    show_erb = File.read(Rails.root.join("app/views/table_monitors/_show.html.erb"))
    assert_match(/button_to.*table_monitor\.bk2_kombi\.fallback\.delete_button/, show_erb,
      "I8a: button_to with delete_button i18n key must be present in the fallback banner block")
    assert_match(/method: :delete/, show_erb,
      "I8a: delete button must use method: :delete")
    assert_match(/turbo_confirm/, show_erb,
      "I8a: delete button must include a Turbo confirm guard")
  end

  test "I8b 38.4-02: delete_button key exists in DE and EN locale files and resolves at runtime" do
    de_yaml = File.read(Rails.root.join("config/locales/de.yml"))
    en_yaml = File.read(Rails.root.join("config/locales/en.yml"))

    assert_match(/delete_button:/, de_yaml,
      "I8b: delete_button key must exist in de.yml under table_monitor.bk2_kombi.fallback")
    assert_match(/delete_button:/, en_yaml,
      "I8b: delete_button key must exist in en.yml under table_monitor.bk2_kombi.fallback")

    # Verify i18n resolves correctly at runtime
    resolved = I18n.t("table_monitor.bk2_kombi.fallback.delete_button")
    assert resolved.present?, "I8b: I18n.t must resolve delete_button without missing key"
    refute_match(/translation missing/, resolved,
      "I8b: delete_button i18n key must not return translation-missing")
  end

  # ===========================================================================
  # Phase 38.4 I9 — set closes at balls_goal (service level)
  # ===========================================================================

  test "I9a 38.4-07: set closes when player reaches balls_goal for BK-2 (I9 regression guard)" do
    tm = create_bk_family_table_monitor(free_game_form: "bk_2", balls_goal: 50, phase: "serienspiel")
    result = Bk2::CommitInning.call(table_monitor: tm, player: "playera", inning_total: 50)
    state = result[:state]
    assert(
      state.dig("sets_won", "playera").to_i >= 1 ||
        state["set_finished_1"] == true ||
        state["current_set_number"].to_i >= 2,
      "I9a: set must close when player reaches balls_goal=50. State: #{state.inspect}"
    )
  end

  test "I9b 38.4-07: set does NOT close below balls_goal for BK-2" do
    tm = create_bk_family_table_monitor(free_game_form: "bk_2", balls_goal: 50, phase: "serienspiel")
    result = Bk2::CommitInning.call(table_monitor: tm, player: "playera", inning_total: 49)
    state = result[:state]
    assert_equal 0, state.dig("sets_won", "playera").to_i,
      "I9b: set must NOT close when player is 1 below balls_goal"
    assert_nil state["set_finished_1"],
      "I9b: set_finished_1 must not be set at 49 when balls_goal is 50"
  end

  # ===========================================================================
  # Phase 38.4 I7 — 5-way scoring dispatch (service level)
  # ===========================================================================

  test "T-BK50 38.4-05: BK50 additive scoring closes at balls_goal 50" do
    tm = create_bk_family_table_monitor(free_game_form: "bk50", balls_goal: 50,
      phase: "serienspiel", initial_score: 44)
    result = Bk2::CommitInning.call(table_monitor: tm, player: "playera", inning_total: 7)
    state = result[:state]
    assert state["set_scores"]["1"]["playera"] >= 50,
      "T-BK50: playera must reach 51 (44+7)"
    assert(
      state["set_finished_1"] == true ||
        state.dig("sets_won", "playera").to_i >= 1 ||
        state["current_set_number"].to_i >= 2,
      "T-BK50: set must close when balls_goal reached"
    )
  end

  test "T-BK100 38.4-05: BK100 additive scoring closes at balls_goal 100" do
    tm = create_bk_family_table_monitor(free_game_form: "bk100", balls_goal: 100,
      phase: "serienspiel", initial_score: 95)
    result = Bk2::CommitInning.call(table_monitor: tm, player: "playera", inning_total: 6)
    state = result[:state]
    assert state["set_scores"]["1"]["playera"] >= 100,
      "T-BK100: playera must reach 101 (95+6)"
    assert(
      state["set_finished_1"] == true ||
        state.dig("sets_won", "playera").to_i >= 1 ||
        state["current_set_number"].to_i >= 2,
      "T-BK100: set must close when balls_goal reached"
    )
  end

  test "T-BK2plus-neg 38.4-05: BK-2plus opponent-credit for negative inning" do
    tm = create_bk_family_table_monitor(free_game_form: "bk_2plus", balls_goal: 50,
      phase: "direkter_zweikampf")
    result = Bk2::CommitInning.call(table_monitor: tm, player: "playera", inning_total: -3)
    state = result[:state]
    assert_equal 0, state["set_scores"]["1"]["playera"],
      "T-BK2plus-neg: playera score must be UNCHANGED (opponent-credit rule)"
    assert_equal 3, state["set_scores"]["1"]["playerb"],
      "T-BK2plus-neg: playerb score must be abs(-3) = 3"
  end

  test "T-BK2plus-pos 38.4-05: BK-2plus credits positive inning to current player" do
    tm = create_bk_family_table_monitor(free_game_form: "bk_2plus", balls_goal: 50,
      phase: "direkter_zweikampf")
    result = Bk2::CommitInning.call(table_monitor: tm, player: "playera", inning_total: 5)
    state = result[:state]
    assert_equal 5, state["set_scores"]["1"]["playera"],
      "T-BK2plus-pos: playera score must be 5"
    assert_equal 0, state["set_scores"]["1"]["playerb"],
      "T-BK2plus-pos: playerb score must be unchanged"
  end

  test "T-BK2-neg 38.4-05: BK-2 additive scoring keeps negative on player (no opponent credit)" do
    tm = create_bk_family_table_monitor(free_game_form: "bk_2", balls_goal: 50, phase: "serienspiel")
    result = Bk2::CommitInning.call(table_monitor: tm, player: "playera", inning_total: -3)
    state = result[:state]
    assert_equal(-3, state["set_scores"]["1"]["playera"],
      "T-BK2-neg: playera score must be -3 (sign-preserving additive)")
    assert_equal 0, state["set_scores"]["1"]["playerb"],
      "T-BK2-neg: playerb score must be unchanged"
  end

  test "T-BK2kombi-DZ 38.4-05: BK-2kombi in DZ phase uses opponent-credit rule" do
    tm = create_bk_family_table_monitor(free_game_form: "bk2_kombi", balls_goal: 50,
      phase: "direkter_zweikampf")
    result = Bk2::CommitInning.call(table_monitor: tm, player: "playera", inning_total: -5)
    state = result[:state]
    assert_equal 0, state["set_scores"]["1"]["playera"],
      "T-BK2kombi-DZ: playera score must be UNCHANGED (opponent-credit in DZ phase)"
    assert_equal 5, state["set_scores"]["1"]["playerb"],
      "T-BK2kombi-DZ: playerb score must be abs(-5) = 5"
  end

  test "T-BK2kombi-SP 38.4-05: BK-2kombi in SP phase uses additive rule" do
    tm = create_bk_family_table_monitor(free_game_form: "bk2_kombi", balls_goal: 50,
      phase: "serienspiel")
    result = Bk2::CommitInning.call(table_monitor: tm, player: "playera", inning_total: -5)
    state = result[:state]
    assert_equal(-5, state["set_scores"]["1"]["playera"],
      "T-BK2kombi-SP: playera score must be -5 (additive in SP phase)")
    assert_equal 0, state["set_scores"]["1"]["playerb"],
      "T-BK2kombi-SP: playerb score must be unchanged"
  end

  # ===========================================================================
  # Phase 38.4 D-16 — conditional DZ-max / SP-max visibility (view-content)
  # ===========================================================================

  test "T-DZ-max-visibility 38.4-06: DZ-max input gated on is_bk_dz_configurable Alpine getter" do
    contents = File.read(Rails.root.join(
      "app/views/locations/scoreboard_free_game_karambol_new.html.erb"
    ))
    # is_bk_dz_configurable must be defined and reference bk_2plus + bk2_kombi only (D-16)
    assert_match(/is_bk_dz_configurable/, contents,
      "T-DZ-max-visibility: is_bk_dz_configurable getter must be defined in the view")
    # The getter must contain both bk_2plus and bk2_kombi
    assert_match(/'bk_2plus'.*'bk2_kombi'|bk_2plus.*bk2_kombi/, contents,
      "T-DZ-max-visibility: is_bk_dz_configurable must reference bk_2plus and bk2_kombi")
    # The getter must NOT include plain bk_2 as a condition
    dz_getter_line = contents.match(/is_bk_dz_configurable.*?[;\n]/)&.to_s || ""
    refute_match(/=== 'bk_2'[^p]|=== "bk_2"[^p]/, dz_getter_line,
      "T-DZ-max-visibility: is_bk_dz_configurable must NOT include plain bk_2")
  end

  test "T-SP-max-visibility 38.4-06: SP-max input gated on is_bk_sp_configurable Alpine getter" do
    contents = File.read(Rails.root.join(
      "app/views/locations/scoreboard_free_game_karambol_new.html.erb"
    ))
    # is_bk_sp_configurable must be defined and reference bk_2 + bk2_kombi only (D-16)
    assert_match(/is_bk_sp_configurable/, contents,
      "T-SP-max-visibility: is_bk_sp_configurable getter must be defined in the view")
    assert_match(/'bk_2'.*'bk2_kombi'|bk_2.*bk2_kombi/, contents,
      "T-SP-max-visibility: is_bk_sp_configurable must reference bk_2 and bk2_kombi")
    # The getter must NOT include bk_2plus as a condition
    sp_getter_line = contents.match(/is_bk_sp_configurable.*?[;\n]/)&.to_s || ""
    refute_match(/bk_2plus/, sp_getter_line,
      "T-SP-max-visibility: is_bk_sp_configurable must NOT include bk_2plus")
  end

  test "T-Ballziel-fixed-bk50 38.4-06: BK50 and BK100 use is_bk_fixed_goal for read-only Ballziel" do
    contents = File.read(Rails.root.join(
      "app/views/locations/scoreboard_free_game_karambol_new.html.erb"
    ))
    assert_match(/is_bk_fixed_goal/, contents,
      "T-Ballziel-fixed-bk50: is_bk_fixed_goal getter must be defined for BK50/BK100 read-only display")
    assert_match(/'bk50'.*'bk100'|bk50.*bk100/, contents,
      "T-Ballziel-fixed-bk50: is_bk_fixed_goal must reference bk50 and bk100")
  end

  test "T-Punktziel-row-introduced 38.4-09: dedicated Punkt-Ziel row exists for all BK-* variants" do
    contents = File.read(Rails.root.join(
      "app/views/locations/scoreboard_free_game_karambol_new.html.erb"
    ))
    # Plan 38.4-09 introduced a dedicated touch-button row for Punkt-Ziel (the "missing
    # row" the user explicitly mentioned). It is gated on is_bk_family (visible for all
    # 5 BK-* variants) and uses bk_ballziel_choices to drive the button list.
    assert_match(/data-test-id="bk-punktziel-row"/, contents,
      "T-Punktziel-row-introduced: data-test-id='bk-punktziel-row' must mark the new row")
    assert_match(/x-show="[^"]*is_bk_family/, contents,
      "T-Punktziel-row-introduced: Punkt-Ziel row must be gated on is_bk_family for all 5 variants")
    assert_match(/x-for=.\(?choice.*in bk_ballziel_choices/, contents,
      "T-Punktziel-row-introduced: row must iterate bk_ballziel_choices reactively")
    assert_match(/x-model\.number="bk_balls_goal"/, contents,
      "T-Punktziel-row-introduced: row must bind selection to bk_balls_goal")
    # Touch-button affordance — large labelled <label> with hidden radio (sr-only)
    assert_match(/class="sr-only"[^>]*x-model\.number="bk_balls_goal"|x-model\.number="bk_balls_goal"[^>]*class="sr-only"/, contents,
      "T-Punktziel-row-introduced: hidden radio (sr-only) inside labelled wrapper — touch-button pattern")
  end

  test "T-DZ-max-touchbutton 38.4-09→10: standalone DZ-max row removed by Plan 38.4-10 (dz_max=2 hardcoded server-side)" do
    contents = File.read(Rails.root.join(
      "app/views/locations/scoreboard_free_game_karambol_new.html.erb"
    ))
    # Plan 38.4-10 O8 removed the standalone DZ-max ± row that Plan 38.4-09 introduced.
    # dz_max=2 is now hardcoded server-side in clamp_bk_family_params! (authoritative).
    # The visible ± row and its display <input> must be GONE from the view.
    refute_match(/BK-2plus — max\. Stöße \/ Aufnahme/, contents,
      "T-DZ-max-touchbutton: standalone DZ-max row label must be removed by Plan 38.4-10")
    refute_match(/name="bk2_dz_max_shots_display"/, contents,
      "T-DZ-max-touchbutton: bk2_dz_max_shots_display visible input must be removed by Plan 38.4-10")
    # The hidden input bk2_options[direkter_zweikampf_max_shots_per_turn] must still be present (shape consistency)
    assert_equal 1, contents.scan(/name='bk2_options\[direkter_zweikampf_max_shots_per_turn\]'/).size,
      "T-DZ-max-touchbutton: hidden bk2_options[direkter_zweikampf_max_shots_per_turn] input must still emit exactly once"
  end

  test "T-SP-max-touchbutton 38.4-09→10: standalone SP-max row removed by Plan 38.4-10 (merged into Aufnahmebegrenzung)" do
    contents = File.read(Rails.root.join(
      "app/views/locations/scoreboard_free_game_karambol_new.html.erb"
    ))
    # Plan 38.4-10 O7 removed the standalone SP-max ± row that Plan 38.4-09 introduced.
    # SP innings are now controlled via the merged Aufnahmebegrenzung row (BK-* gets [5, 7] buttons).
    # The visible ± row and its display <input> must be GONE from the view.
    refute_match(/BK-2 — max\. Aufnahmen \/ Satz/, contents,
      "T-SP-max-touchbutton: standalone SP-max row label must be removed by Plan 38.4-10")
    refute_match(/name="bk2_sp_max_innings_display"/, contents,
      "T-SP-max-touchbutton: bk2_sp_max_innings_display visible input must be removed by Plan 38.4-10")
    # Merged Aufnahmebegrenzung BK-* partial must offer [5, 7] as replacement
    assert_match(/show: "is_bk_family && !is_bk_fixed_goal"[^%]+values: %w\{0 5 7\}/m, contents,
      "T-SP-max-touchbutton: merged BK-* Aufnahmebegrenzung partial with [5, 7] must exist")
  end

  test "T-hidden-inputs-not-duplicated 38.4-09: hidden form inputs appear exactly once" do
    contents = File.read(Rails.root.join(
      "app/views/locations/scoreboard_free_game_karambol_new.html.erb"
    ))
    # Plan 38.4-09 must NOT re-emit hidden inputs (they are at lines 241-253, outside
    # the 317-390 replacement range). Guard against an executor accidentally
    # duplicating them.
    %w[free_game_form balls_goal discipline_a discipline_b sets_to_win sets_to_play].each do |name|
      count = contents.scan(/name=['"]#{name}['"]/).size
      assert_equal 1, count,
        "T-hidden-inputs-not-duplicated: name='#{name}' must appear exactly once (found #{count})"
    end
    %w[direkter_zweikampf_max_shots_per_turn serienspiel_max_innings_per_set].each do |key|
      count = contents.scan(/name=['"]bk2_options\[#{key}\]['"]/).size
      assert_equal 1, count,
        "T-hidden-inputs-not-duplicated: name='bk2_options[#{key}]' must appear exactly once (found #{count})"
    end
  end

  # ===========================================================================
  # Phase 38.4-10 — layout/form integrity (O1, O3, O6, O7, O8)
  # ===========================================================================

  test "T-O1-balls-goal-honored 38.4-10: clamp_bk_family_params! reads :balls_goal from sliced params and intersects with discipline.ballziel_choices" do
    contents = File.read(Rails.root.join(
      "app/controllers/table_monitors_controller.rb"
    ))
    # Plan 38.4-10 must preserve clamp_bk_family_params!'s contract: read :balls_goal
    # from p (sliced params), intersect with allowed list, default to first allowed.
    # This is the controller-side guarantee that O1 doesn't regress (regardless of
    # which form row drives the hidden input — the controller is final arbiter).
    # Phase 38.4-13 P1 widened the read pattern to fall back to :balls_goal_a /
    # :balls_goal_b — `p.delete(:balls_goal).presence` replaces the bare `.to_i`.
    # Updated regex tolerates both single-line and multi-line forms.
    assert_match(/requested = \(?p\.delete\(:balls_goal\)\.presence/, contents,
      "T-O1: clamp_bk_family_params! must read :balls_goal from p (with .presence guard for 38.4-13 fallback chain)")
    assert_match(/allowed\.include\?\(requested\) \? requested : allowed\.first/, contents,
      "T-O1: clamped_goal must intersect requested with allowed list")
    assert_match(/p\[:balls_goal\] = clamped_goal/, contents,
      "T-O1: clamped balls_goal must be written back to p[:balls_goal]")
  end

  test "T-O3-no-double-punktziel-row 38.4-10: pre-existing generic Punktziel row hidden when BK-* selected" do
    contents = File.read(Rails.root.join(
      "app/views/locations/scoreboard_free_game_karambol_new.html.erb"
    ))
    # The generic Karambol Punktziel row (header: 'Punktziel', varname: 'balls_goal')
    # must be gated on `parameters == 0 && !is_bk_family` so it disappears when a
    # BK-* discipline is selected — closes O3 (two rows simultaneously) and the
    # secondary leak path of O1 (default 50 from generic row overriding selection).
    assert_match(/show: "parameters == 0 && !is_bk_family"/, contents,
      "T-O3: generic Punktziel row must be gated on parameters == 0 && !is_bk_family")
    # Sanity: only one render call uses header: 'Punktziel'
    header_count = contents.scan(/header: "Punktziel"/).size
    assert_equal 1, header_count,
      "T-O3: exactly one generic Punktziel row must exist (found #{header_count})"
  end

  # 2026-04-27: Two tests removed here that asserted the standalone BK-Variante row
  # markup (>BK-Variante<, name="bk_form_choice", grid-cols-5). The Kegel-Toggle
  # restructure collapsed that row into the new 6-button Kegel-Familien-Zeile (uses
  # name="kegel_choice", grid-cols-6, label "Kegel-Variante"). The replacement
  # invariants are pinned by T-Kegel-* tests near the bottom of this file:
  #   T-Kegel-discipline-row-uses-kegel-label    (parameters==0 displays array uses 'Kegel')
  #   T-Kegel-row-eurok-button-present           (kegel_choice radio + EUROK + is_kegel getter + x-effect reset)
  #   T-Kegel-old-bk-variante-block-removed      (negative guard: bk_form_choice / >BK-Variante< absent)
  #   T-Kegel-erb-compiles                       (Alpine getters survive ERB compilation)
  # Removed: T-O6-bk-variante-row-alignment-v2 (38.4-15) and T-P2-bk-variante-fixed-width-buttons (38.4-15).

  # Phase 38.4-15 P2: visible vertical spacer (col-span-6 h-4) inserted above MEHRSATZ
  # partial call so MEHRSATZ doesn't crowd against the merged Aufnahmebegrenzung row.
  # Also asserts BK-* Aufnahmebegrenzung uses cols=4 and non-BK keeps cols=5.
  test "T-P2-mehrsatz-row-spacing 38.4-15: MEHRSATZ row has visible vertical spacer above" do
    contents = File.read(Rails.root.join(
      "app/views/locations/scoreboard_free_game_karambol_new.html.erb"
    ))

    mehrsatz_block = contents.match(/col-span-6 h-4.{0,500}header: "Mehrsatzspiel"/m)&.to_s || ""
    refute_empty mehrsatz_block,
      "T-P2: spacer (col-span-6 h-4) must precede MEHRSATZ partial call (closes P2.3)"

    # Aufnahmebegrenzung BK-* partial uses cols=4 (3 buttons + 1 counter)
    bk_aufnahme_block = contents.match(/show: "is_bk_family && !is_bk_fixed_goal".{0,500}cols: 4/m)&.to_s || ""
    refute_empty bk_aufnahme_block,
      "T-P2: BK-* Aufnahmebegrenzung partial must use cols=4 (closes P2.2)"

    # Non-BK Aufnahmebegrenzung partial unchanged (cols=5)
    non_bk_aufnahme_block = contents.match(/show: "!is_bk_family".{0,500}cols: 5/m)&.to_s || ""
    refute_empty non_bk_aufnahme_block,
      "T-P2: non-BK Aufnahmebegrenzung partial keeps cols=5 (no regression)"
  end

  # 2026-04-27: Removed T-P2-bk-variante-row-cols-5-rendered (38.4-15 / I-15-01) —
  # asserted grid-cols-5 + absence of grid-cols-8 in the compiled ERB for the now-
  # gone BK-Variante row. Replaced by T-Kegel-erb-compiles which compiles the
  # template post-restructure and asserts the new Kegel-Variante markers survive.

  test "T-O7-merged-aufnahmebegrenzung-row 38.4-10: standalone SP-max row removed; Aufnahmebegrenzung swaps button set per discipline" do
    contents = File.read(Rails.root.join(
      "app/views/locations/scoreboard_free_game_karambol_new.html.erb"
    ))
    # Standalone SP-max row from Plan 09 must be GONE (no header text, no bk2_sp_max_innings ± row visible).
    refute_match(/BK-2 — max\. Aufnahmen \/ Satz/, contents,
      "T-O7: standalone SP-max row label must be removed")
    # Merged Aufnahmebegrenzung row must have BK-* partial call with [5, 7] values
    assert_match(/show: "is_bk_family && !is_bk_fixed_goal"[^%]+values: %w\{0 5 7\}/m, contents,
      "T-O7: merged BK-* Aufnahmebegrenzung partial must offer [5, 7] buttons")
    # Non-BK partial call preserved with classic [20, 25, 30] values
    assert_match(/show: "!is_bk_family"[^%]+values: %w\{0 20 25 30\}/m, contents,
      "T-O7: non-BK Aufnahmebegrenzung partial must preserve [20, 25, 30] buttons")
    # x-effect mirroring innings → bk2_sp_max_innings present
    assert_match(/x-effect=.*bk2_sp_max_innings.*=.*parseInt\(innings\)/, contents,
      "T-O7: x-effect must mirror innings to bk2_sp_max_innings for BK-* configurable")
  end

  test "T-O8-no-dz-row 38.4-10: standalone DZ-max row removed; controller hardcodes dz_max=2 for BK-2plus and BK2-Kombi" do
    view = File.read(Rails.root.join(
      "app/views/locations/scoreboard_free_game_karambol_new.html.erb"
    ))
    controller = File.read(Rails.root.join(
      "app/controllers/table_monitors_controller.rb"
    ))
    # View: standalone DZ-max ± row from Plan 09 must be GONE
    refute_match(/BK-2plus — max\. Stöße \/ Aufnahme/, view,
      "T-O8: standalone DZ-max row label must be removed")
    # The bk2_dz_max_shots_display visible <input> from Plan 09 must be GONE
    refute_match(/name="bk2_dz_max_shots_display"/, view,
      "T-O8: bk2_dz_max_shots_display visible input must be removed")
    # Hidden input bk2_options[direkter_zweikampf_max_shots_per_turn] still present (line 252)
    assert_equal 1, view.scan(/name='bk2_options\[direkter_zweikampf_max_shots_per_turn\]'/).size,
      "T-O8: hidden bk2_options[direkter_zweikampf_max_shots_per_turn] input still emits exactly once"
    # Controller: dz_max hardcode for BK-2plus and BK2-Kombi
    assert_match(/dz_max = 2 if %w\[BK-2plus BK2-Kombi\]\.include\?\(p\[:discipline_a\]\.to_s\)/, controller,
      "T-O8: clamp_bk_family_params! must hardcode dz_max=2 for BK-2plus and BK2-Kombi")
  end

  # ===========================================================================
  # Phase 38.4 D-17 — shootout 4-button BK-2kombi only (DOM assertions)
  # ===========================================================================

  test "T-shootout-4btn-bk2kombi 38.4-06 D-17: 4 shootout buttons present for BK-2kombi" do
    # @tm uses initial_bk2_data → free_game_form = "bk2_kombi"
    @tm.update_columns(state: "match_shootout")
    visit table_monitor_path(@tm)

    assert_selector "#bk2_start_a_dz", wait: 5, visible: :all
    assert_selector "#bk2_start_a_sp", visible: :all
    assert_selector "#bk2_start_b_dz", visible: :all
    assert_selector "#bk2_start_b_sp", visible: :all
  end

  test "T-shootout-2btn-bk2 38.4-06 D-17: generic 2-button shootout for non-BK-2kombi BK family" do
    # Use a non-BK-2kombi BK-* discipline (bk_2) — no 4-button mode selector
    @tm.update!(data: {
      "free_game_form" => "bk_2",
      "current_kickoff_player" => "playera",
      "current_inning" => {"active_player" => "playera"},
      "playera" => {"discipline" => "BK-2", "innings" => 0, "result" => 0, "innings_redo_list" => [0]},
      "playerb" => {"discipline" => "BK-2", "innings" => 0, "result" => 0, "innings_redo_list" => [0]}
    })
    @tm.update_columns(state: "match_shootout")
    visit table_monitor_path(@tm)

    # 4-button BK-2kombi IDs must NOT be present for non-bk2_kombi disciplines
    assert_no_selector "#bk2_start_a_dz", wait: 3, visible: :all
    assert_no_selector "#bk2_start_a_sp", visible: :all
    # Generic 2-button IDs must be present
    assert_selector "#start_game", wait: 5, visible: :all
    assert_selector "#switch_and_start", visible: :all
  end

  # ===========================================================================
  # Phase 38.4 I2 — i18n rename guard (Plan 38.4-03)
  # ===========================================================================

  test "T-i18n-labels 38.4-03: phase labels renamed to BK-2plus and BK-2 (I2 closure)" do
    dz_label = I18n.t("table_monitor.bk2_kombi.phase.direkter_zweikampf")
    sp_label = I18n.t("table_monitor.bk2_kombi.phase.serienspiel")

    assert_equal "BK-2plus", dz_label,
      "T-i18n-labels: direkter_zweikampf label must be 'BK-2plus' (Plan 38.4-03 I2 rename)"
    assert_equal "BK-2", sp_label,
      "T-i18n-labels: serienspiel label must be 'BK-2' (Plan 38.4-03 I2 rename)"

    refute_equal "Direkter Zweikampf", dz_label, "T-i18n-labels: 'Direkter Zweikampf' must be retired"
    refute_equal "Serienspiel", sp_label, "T-i18n-labels: 'Serienspiel' string must be retired"
  end

  # ===========================================================================
  # Phase 38.3 regression guards (namespace + deleted endpoints)
  # ===========================================================================

  test "T-deleted-reflex 38.3-04: bk2_kombi_submit_shot endpoint no longer exists" do
    refute TableMonitorReflex.instance_methods.include?(:bk2_kombi_submit_shot),
      "T-deleted-reflex: bk2_kombi_submit_shot should have been deleted in Plan 38.3-04"
  end

  # ===========================================================================
  # Phase 38.4-11 O4 — Nachstoß source code guard (file-grep test)
  # ===========================================================================

  test "T-O4-protokoll-editor-accepts-equal 38.4-11: close_set_if_reached! has Nachstoß-aware branch" do
    contents = File.read(Rails.root.join("app/services/bk2/advance_match_state.rb"))
    assert_match(/nachstoss_pending/, contents,
      "T-O4: close_set_if_reached! must reference nachstoss_pending state slot")
    assert_match(/discipline_nachstoss_allowed\?/, contents,
      "T-O4: close_set_if_reached! must call discipline_nachstoss_allowed? helper")
    # Nachstoß resolution path must allow score >= original_target (no off-by-one cap)
    assert_match(/nachstoss_score >= target/, contents,
      "T-O4: Nachstoß resolution must accept score == balls_goal (no off-by-one)")
  end

  # ===========================================================================
  # Phase 38.4-12 O5 — BK-2kombi quick-game canonical shortcut
  # ===========================================================================

  test "T-O5-quick-game-shortcut-renders 38.4-12: BK-2kombi canonical shortcut is at index 0 of BK2-Kombi quick-game buttons" do
    # Plan 38.4-12 O5: user requested a labelled BK-2kombi default at the first position
    # of the Schnellauswahl page. Test reads the YAML directly (config-driven path) and
    # asserts:
    #   1. The category "BK2-Kombi" exists with at least 4 buttons.
    #   2. The first button has the canonical "BK-2kombi 2/5/70+NS" label.
    #   3. The first button carries balls_goal=70, sets_to_win=2, sets_to_play=3.
    yaml_text = File.read(Rails.root.join("config/carambus.yml.erb"))
    assert_match(/label: "BK-2kombi 2\/5\/70\+NS"/, yaml_text,
      "T-O5: canonical 'BK-2kombi 2/5/70+NS' label must appear in YAML")

    # Programmatic config check — guards against typos that pass file grep but
    # break Carambus.config parsing.
    buttons = Carambus.config.quick_game_presets.dig("small_billard")
      .find { |c| c["category"] == "BK2-Kombi" }["buttons"]
    assert_operator buttons.length, :>=, 4,
      "T-O5: BK2-Kombi category must have at least 4 buttons after Plan 12 insertion"

    first = buttons.first
    assert_equal "BK-2kombi 2/5/70+NS", first["label"],
      "T-O5: first BK2-Kombi button must be the canonical 'BK-2kombi 2/5/70+NS'"
    assert_equal 70, first["balls_goal"],
      "T-O5: first button balls_goal must be 70"
    assert_equal 2, first["sets_to_win"],
      "T-O5: first button sets_to_win must be 2 (best-of-3)"
    assert_equal 3, first["sets_to_play"],
      "T-O5: first button sets_to_play must be 3 (best-of-3)"
    assert_equal "BK2-Kombi", first["discipline"],
      "T-O5: first button discipline must be 'BK2-Kombi'"
  end

  test "T-O5-button-id-uniqueness 38.4-12: button_id derivation disambiguates same-discipline-same-balls_goal entries via label suffix" do
    contents = File.read(Rails.root.join("app/views/locations/_quick_game_buttons.html.erb"))
    # Plan 38.4-12 added label_suffix to the BK-family button_id branch to prevent
    # the new "BK-2kombi 2/5/70+NS" entry colliding with the existing "70/Best of 3"
    # (both have discipline=BK2-Kombi + balls_goal=70).
    assert_match(/label_suffix = button\['label'\] \? "_#\{button\['label'\]\.gsub/, contents,
      "T-O5: _quick_game_buttons.html.erb must derive label_suffix for unique button_id")
    assert_match(/button_id = "#\{button\['discipline'\]\.gsub.+#\{button\['balls_goal'\]\}#\{label_suffix\}"/, contents,
      "T-O5: button_id must concatenate discipline + balls_goal + label_suffix")
  end

  test "T-P1-clamp-fallback-constant 38.4-13: BK_FAMILY_BALLZIEL_FALLBACK constant present and clamp reads balls_goal_a/b fallback" do
    contents = File.read(Rails.root.join("app/controllers/table_monitors_controller.rb"))

    # Phase 38.4-13 P1/P3: BK_FAMILY_BALLZIEL_FALLBACK is the discipline-specific
    # safety net used when Discipline.find_by returns nil OR ballziel_choices is empty.
    # Mirrors script/seed_bk2_disciplines.rb. This guard ensures the constant survives
    # future refactors.
    assert_match(/BK_FAMILY_BALLZIEL_FALLBACK\s*=\s*\{/, contents,
      "T-P1: BK_FAMILY_BALLZIEL_FALLBACK constant must be defined")

    # All 5 BK-* disciplines present in the constant
    %w[BK50 BK100 BK-2 BK-2plus BK2-Kombi].each do |name|
      assert_match(/"#{Regexp.escape(name)}"\s*=>\s*\[/, contents,
        "T-P1: BK_FAMILY_BALLZIEL_FALLBACK must contain entry for #{name}")
    end

    # The fallback values match the seed script (the constants must stay in sync)
    assert_match(/"BK50"\s*=>\s*\[50\]/, contents,
      "T-P1: BK50 fallback must be [50]")
    assert_match(/"BK100"\s*=>\s*\[100\]/, contents,
      "T-P1: BK100 fallback must be [100]")
    assert_match(/"BK-2"\s*=>\s*\[50, 60, 70, 80, 90, 100\]/, contents,
      "T-P1: BK-2 fallback must be [50, 60, 70, 80, 90, 100]")
    assert_match(/"BK-2plus"\s*=>\s*\[50, 60, 70, 80, 90, 100\]/, contents,
      "T-P1: BK-2plus fallback must be [50, 60, 70, 80, 90, 100]")
    assert_match(/"BK2-Kombi"\s*=>\s*\[50, 60, 70\]/, contents,
      "T-P1: BK2-Kombi fallback must be [50, 60, 70]")

    # clamp_bk_family_params! uses the fallback constant
    assert_match(/BK_FAMILY_BALLZIEL_FALLBACK\[discipline_name\]/, contents,
      "T-P1: clamp_bk_family_params! must read BK_FAMILY_BALLZIEL_FALLBACK[discipline_name]")

    # clamp_bk_family_params! reads balls_goal with balls_goal_a/balls_goal_b fallback
    assert_match(/p\[:balls_goal_a\]\.presence/, contents,
      "T-P1: clamp_bk_family_params! must read :balls_goal_a as fallback for :balls_goal")
    assert_match(/p\[:balls_goal_b\]\.presence/, contents,
      "T-P1: clamp_bk_family_params! must read :balls_goal_b as fallback")

    # Slice-list precondition (I-13-01): :balls_goal_a + :balls_goal_b in permit/slice list
    assert_match(/:balls_goal_a/, contents,
      "T-P1 slice-list precondition (I-13-01): :balls_goal_a must be in permit/slice list")
    assert_match(/:balls_goal_b/, contents,
      "T-P1 slice-list precondition (I-13-01): :balls_goal_b must be in permit/slice list")
  end

  test "T-P1-fallback-mirrors-seed 38.4-13: BK_FAMILY_BALLZIEL_FALLBACK values match script/seed_bk2_disciplines.rb (all 5 BK-* entries)" do
    controller = File.read(Rails.root.join("app/controllers/table_monitors_controller.rb"))
    seed       = File.read(Rails.root.join("script/seed_bk2_disciplines.rb"))

    # Phase 38.4-13 P1/P3: cross-file invariant — the controller fallback values
    # MUST mirror the seed script. If either file changes its values, this test
    # surfaces the drift before production deploy. I-13-02: check ALL 5 BK-* entries
    # (not just BK50/BK100) so a drift on BK-2 / BK-2plus / BK2-Kombi is also caught.

    # Map of expected fallback values (must mirror BK_FAMILY_BALLZIEL_FALLBACK constant)
    bk_family_expectations = {
      "BK50" => "[50]",
      "BK100" => "[100]",
      "BK-2" => "[50, 60, 70, 80, 90, 100]",
      "BK-2plus" => "[50, 60, 70, 80, 90, 100]",
      "BK2-Kombi" => "[50, 60, 70]"
    }

    bk_family_expectations.each do |name, expected_values|
      # Controller side: BK_FAMILY_BALLZIEL_FALLBACK entry
      assert_match(/"#{Regexp.escape(name)}"\s*=>\s*#{Regexp.escape(expected_values)}/, controller,
        "T-P1-mirror: controller BK_FAMILY_BALLZIEL_FALLBACK[#{name}] must equal #{expected_values}")
    end

    # Seed side: each non-BK-2kombi entry has matching ballziel_choices
    # (BK-2kombi is in a separate backfill block — checked separately below)
    %w[BK50 BK100 BK-2 BK-2plus].each do |name|
      expected = bk_family_expectations[name]
      # Seed file uses ballziel_choices: [...] (Ruby symbol-key hash literal)
      assert_match(/"#{Regexp.escape(name)}"[^}]*ballziel_choices:\s*#{Regexp.escape(expected)}/m, seed,
        "T-P1-mirror: seed_bk2_disciplines.rb #{name} ballziel_choices must equal #{expected}")
    end

    # BK-2kombi backfill: the seed sets current["ballziel_choices"] = [50, 60, 70]
    assert_match(/current\["ballziel_choices"\]\s*=\s*\[50, 60, 70\]/, seed,
      "T-P1-mirror: seed_bk2_disciplines.rb BK2-Kombi backfill must set ballziel_choices to [50, 60, 70]")
  end

  test "T-P5-seed-flag-narrowed 38.4-16: nachstoss_allowed: true scope narrowed to BK-2kombi only" do
    seed = File.read(Rails.root.join("script/seed_bk2_disciplines.rb"))

    # Phase 38.4-16 P5: the discs array (lines ~23-28) has FOUR entries for
    # BK50/BK100/BK-2/BK-2plus, NONE of which carry nachstoss_allowed.
    # Symbol-style flag literal must be ABSENT from the discs array.
    assert_no_match(/nachstoss_allowed:\s*true/, seed,
      "T-P5: symbol-style 'nachstoss_allowed: true' literal MUST be absent from seed (P5 narrowing)")

    # The BK-2kombi backfill block uses string-bracket assignment style:
    #   current["nachstoss_allowed"] = true
    # This is the SOLE remaining write of the flag. Lock it in place.
    assert_match(/current\["nachstoss_allowed"\]\s*=\s*true/, seed,
      "T-P5: BK2-Kombi backfill MUST keep current[\"nachstoss_allowed\"] = true (sole keeper)")

    # The needs_update guard at line ~55 still tests for stale flag absence —
    # idempotent re-run friendly. Lock it in place.
    assert_match(/current\["nachstoss_allowed"\]\s*!=\s*true/, seed,
      "T-P5: BK2-Kombi backfill MUST keep idempotent guard current[\"nachstoss_allowed\"] != true")

    # All 4 non-BK-2kombi disciplines still have entries — narrowing the flag
    # does NOT mean removing the records. (Interpretation (b) — flag-only narrowing.)
    %w[BK50 BK100 BK-2 BK-2plus].each do |name|
      assert_match(/name:\s*"#{Regexp.escape(name)}"/, seed,
        "T-P5: discipline #{name} entry MUST still exist in discs array (interpretation b — flag-only narrowing)")
    end

    # The BK2-Kombi find(107) backfill block still exists.
    assert_match(/Discipline\.find\(107\)/, seed,
      "T-P5: BK2-Kombi (id 107) backfill block MUST still exist")
  end

  test "T-P5-clear-nachstoss-migration-present 38.4-16: catch-up migration removes flag with EXPLICIT pre-check (per round-4 iteration-2 BLOCKER 2 fix) + documents sync-race (per I-16-02)" do
    migration_path = Rails.root.join("db/migrate/20260425090000_clear_nachstoss_allowed_for_non_bk2_kombi.rb")
    assert File.exist?(migration_path),
      "T-P5: migration file MUST exist at db/migrate/20260425090000_clear_nachstoss_allowed_for_non_bk2_kombi.rb"

    contents = File.read(migration_path)

    assert_match(/class ClearNachstossAllowedForNonBk2Kombi < ActiveRecord::Migration/, contents,
      "T-P5: migration class declared with correct name + ActiveRecord::Migration parent")

    # Targets the 4 non-BK-2kombi disciplines explicitly.
    assert_match(/TARGET_NAMES\s*=\s*%w\[BK50 BK100 BK-2 BK-2plus\]/, contents,
      "T-P5: migration TARGET_NAMES MUST be exactly [BK50, BK100, BK-2, BK-2plus] (excludes BK2-Kombi)")

    # Performs the key deletion.
    assert_match(/parsed\.delete\("nachstoss_allowed"\)/, contents,
      "T-P5: migration MUST delete the nachstoss_allowed key from parsed data hash")

    # Idempotent guard — skip when key already absent.
    assert_match(/parsed\.key\?\("nachstoss_allowed"\)/, contents,
      "T-P5: migration MUST guard against re-running on already-cleared records (idempotency)")

    # ROUND-4 ITERATION-2 BLOCKER 2 FIX:
    # Migration MUST use the EXPLICIT pre-check pattern `if !ApplicationRecord.local_server?`
    # then `rec.update!`. The previous `rescue ActiveRecord::RecordInvalid` pattern was
    # unreachable because LocalProtector raises ActiveRecord::Rollback (silently swallowed
    # by transactions), so update! returned true while data was rolled back. The pre-check
    # eliminates the silent no-op.
    assert_match(/if\s+!ApplicationRecord\.local_server\?/, contents,
      "T-P5/round-4-iteration-2-BLOCKER-2: migration MUST use the explicit pre-check `if !ApplicationRecord.local_server?` (replaces the unreachable rescue ActiveRecord::RecordInvalid pattern)")
    assert_match(/rec\.update!\(data:/, contents,
      "T-P5/round-4-iteration-2-BLOCKER-2: migration MUST use rec.update!(data:) inside the pre-check guard (preserves PaperTrail versioning when permitted)")

    # The unreachable rescue MUST be removed.
    assert_no_match(/rescue\s+ActiveRecord::RecordInvalid/, contents,
      "T-P5/round-4-iteration-2-BLOCKER-2: the unreachable `rescue ActiveRecord::RecordInvalid` block MUST be removed — LocalProtector raises Rollback (transaction control flow), not RecordInvalid; that rescue NEVER fired and silently masked failures")

    # update_columns is also NOT used (would bypass PaperTrail entirely).
    assert_no_match(/update_columns/, contents,
      "T-P5: migration MUST NOT use update_columns (bypasses PaperTrail)")

    # Skip-local counter present (proves the explicit-skip branch is implemented).
    assert_match(/skipped_local/, contents,
      "T-P5/round-4-iteration-2-BLOCKER-2: migration MUST track skipped_local counter for the explicit-skip branch (global record on local server)")

    # I-16-02: residual sync-race risk documented in source comments.
    assert_match(/sync-race/i, contents,
      "T-P5/I-16-02: migration MUST document the residual sync-race risk in source comments")

    # Down is a no-op (we don't want to re-introduce the flag on a rollback).
    assert_match(/def down/, contents, "T-P5: migration MUST define down method")
    assert_match(/No-op: ClearNachstossAllowedForNonBk2Kombi is not reversible/, contents,
      "T-P5: migration down MUST be a no-op with explanatory message")
  end

  test "T-P4-add-n-balls-bk-family-routes-through-bk2-commitinning 38.4-14: TableMonitor#add_n_balls + #set_n_balls dispatch BK-family-with-nachstoss through Bk2::CommitInning" do
    contents = File.read(Rails.root.join("app/models/table_monitor.rb"))
    lines = contents.lines

    # Phase 38.4-14 P4 (round-4 iteration-2): BK-family with nachstoss_allowed routes
    # through Bk2::CommitInning. Plan 11's deferred-close machinery is engaged via
    # this dispatch; without it, the legacy karambol terminate_current_inning fires
    # evaluate_result → AASM set_over, freezing the trailing player's ProtokollEditor
    # and +1 button paths.
    #
    # W-5 fix: line-range scan instead of regex with lazy `.*?^  end$` match (which
    # could match the rescue-clause end instead of the method end).

    # Helper predicate present
    assert_match(/def bk_family_with_nachstoss\?/, contents,
      "T-P4: TableMonitor#bk_family_with_nachstoss? helper must be defined")

    # Dispatch helper present
    assert_match(/def route_goal_reached_through_bk2_commit_inning/, contents,
      "T-P4: TableMonitor#route_goal_reached_through_bk2_commit_inning helper must be defined")

    # Helper uses Option B name-based lookup (not self.discipline)
    assert_match(/Discipline\.find_by\(name:/, contents,
      "T-P4 (Option B): bk_family_with_nachstoss? must look up Discipline by name (round-4 iteration-2 — preserves TableMonitor#discipline String contract for 15+ legacy callers)")
    assert_match(/data\.dig\("playera",\s*"discipline"\)/, contents,
      "T-P4 (Option B): bk_family_with_nachstoss? must read name from data['playera']['discipline'] (production String contract)")

    # add_n_balls dispatches via the helper — line-range scan (W-5 fix)
    add_idx = lines.index { |l| l =~ /^\s*def add_n_balls\b/ }
    refute_nil add_idx, "T-P4: def add_n_balls line not found in app/models/table_monitor.rb"
    add_window = lines[add_idx, 30].join
    assert_match(/bk_family_with_nachstoss\?/, add_window,
      "T-P4: add_n_balls (within 30 lines of def) must check bk_family_with_nachstoss?")
    assert_match(/route_goal_reached_through_bk2_commit_inning/, add_window,
      "T-P4: add_n_balls (within 30 lines of def) must dispatch to route_goal_reached_through_bk2_commit_inning")
    assert_match(/terminate_current_inning\(player\)/, add_window,
      "T-P4: add_n_balls (within 30 lines of def) must keep legacy terminate_current_inning(player) for non-BK-family fallback")

    # set_n_balls (ProtokollEditor write path) dispatches via the helper — line-range scan
    set_idx = lines.index { |l| l =~ /^\s*def set_n_balls\b/ }
    refute_nil set_idx, "T-P4: def set_n_balls line not found in app/models/table_monitor.rb"
    set_window = lines[set_idx, 30].join
    assert_match(/bk_family_with_nachstoss\?/, set_window,
      "T-P4-protokoll: set_n_balls (within 30 lines of def) must check bk_family_with_nachstoss?")
    assert_match(/route_goal_reached_through_bk2_commit_inning/, set_window,
      "T-P4-protokoll: set_n_balls (within 30 lines of def) must dispatch to route_goal_reached_through_bk2_commit_inning")

    # Bk2::CommitInning is referenced in the new private helper
    assert_match(/Bk2::CommitInning\.call/, contents,
      "T-P4: TableMonitor must call Bk2::CommitInning.call from the dispatch helper")

    # TableMonitor#discipline String contract preserved (Option B per round-4 iteration-2).
    # If a future refactor changes this method's return type, this test surfaces it
    # so the deferred T8-T11 caller-migration phase can be planned deliberately.
    disc_idx = lines.index { |l| l =~ /^\s*def discipline\s*$/ }
    refute_nil disc_idx, "T-P4: def discipline line not found"
    disc_window = lines[disc_idx, 4].join
    assert_match(/data\["playera"\]\.andand\["discipline"\]/, disc_window,
      "T-P4 (Option B preservation): TableMonitor#discipline must still return data['playera']['discipline'] (String) — 15+ legacy callers depend on the String contract; round-4 iteration-2 explicitly defers the AR-record migration to a future phase")
  end

  # ---------------------------------------------------------------------------
  # 2026-04-27 Kegel-Toggle: discipline index 5 ("Kegel") opens a sub-row with
  # [EUROK, BK50, BK100, BK-2, BK-2plus, BK-2kombi]. EUROK is default, BK-Variante
  # row is collapsed into the new Kegel-Familien-Zeile. File-grep + ERB-compile
  # tests guard the markup; Alpine reactivity itself is verified manually in the
  # browser (per UAT pattern).
  # ---------------------------------------------------------------------------

  test "T-Kegel-discipline-row-uses-kegel-label 2026-04-27: discipline radio displays array contains 'Kegel' (not 'Eurok') for index 5" do
    view_path = Rails.root.join("app/views/locations/scoreboard_free_game_karambol_new.html.erb")
    contents = File.read(view_path)

    # Locate the parameters==0 discipline radio block (Small Billard, both players)
    # and assert its displays array uses "Kegel" at the last slot. Block is uniquely
    # identified by the show: clause for parameters==0 + Small Billard.
    assert_match(/show:\s*"table_kind == 'Small Billard' && parameters == 0",\s*\n\s*header:\s*"Disziplin",[\s\S]*?displays:\s*\[.*?"Kegel"\s*\]/,
      contents,
      "T-Kegel: parameters==0 Small Billard discipline row must end displays array with \"Kegel\" (renamed from \"Eurok\")")
  end

  test "T-Kegel-row-eurok-button-present 2026-04-27: Kegel-Familien-Zeile contains EUROK button as first option" do
    view_path = Rails.root.join("app/views/locations/scoreboard_free_game_karambol_new.html.erb")
    contents = File.read(view_path)

    # The new Kegel-Familien-Zeile uses kegel_choice radio and EUROK as the first
    # ([0]) entry; this enables it to be the default selection when discipline=5.
    assert_match(/\["eurok",\s*"EUROK"\]/, contents,
      "T-Kegel: Kegel-Familien-Zeile must contain ['eurok', 'EUROK'] as first option (default sub-discipline)")
    assert_match(/name="kegel_choice"/, contents,
      "T-Kegel: hidden radio input must use name='kegel_choice' for the new Kegel-Familien-Zeile")
    # is_kegel getter ties row visibility to discipline == 5
    assert_match(/get is_kegel\(\)\s*\{\s*return this\.discipline == 5/, contents,
      "T-Kegel: Alpine getter is_kegel() must check discipline == 5")
    # x-effect clears bk_selected_form when leaving discipline 5
    assert_match(/if \(discipline != 5 && bk_selected_form\) \{ bk_selected_form = null \}/, contents,
      "T-Kegel: x-effect must reset bk_selected_form when user navigates away from discipline 5")
  end

  test "T-Kegel-old-bk-variante-block-removed 2026-04-27: standalone BK-Variante row (5 buttons, always-visible) is removed" do
    view_path = Rails.root.join("app/views/locations/scoreboard_free_game_karambol_new.html.erb")
    contents = File.read(view_path)

    # The pre-2026-04-27 BK-Variante row used name="bk_form_choice" for its 5-button
    # radio set. After the Kegel-toggle restructure, that row is gone (collapsed
    # into the kegel_choice row). The new row uses name="kegel_choice" — the
    # bk_form_choice name must NOT appear anywhere in the template.
    refute_match(/name="bk_form_choice"/, contents,
      "T-Kegel: legacy BK-Variante row (name='bk_form_choice') must be removed — its 5 BK buttons now live in the Kegel-Familien-Zeile under name='kegel_choice'")
    # Also: the standalone "BK-Variante" label is gone (replaced by "Kegel-Variante" in the new row)
    refute_match(/>BK-Variante</, contents,
      "T-Kegel: literal label 'BK-Variante' must be replaced by 'Kegel-Variante' in the new row")
    assert_match(/>Kegel-Variante</, contents,
      "T-Kegel: new row must use 'Kegel-Variante' as its label")
  end

  test "T-Kegel-erb-compiles 2026-04-27: template still compiles after Kegel-toggle restructure" do
    view_path = Rails.root.join("app/views/locations/scoreboard_free_game_karambol_new.html.erb")
    raw_erb = File.read(view_path)

    # Asserting compilation catches syntax errors introduced by the new Alpine
    # getters (is_kegel, kegel_choice) and the modified x-effect.
    compiled = ActionView::Template::Handlers::ERB.new.call(
      ActionView::Template.new(
        raw_erb,
        view_path.to_s,
        ActionView::Template.handler_for_extension("erb"),
        format: :html,
        locals: []
      ),
      raw_erb
    )

    # Compiled output must contain literal markers from the new row (not stripped
    # as ERB comments) and the new Alpine getter signatures.
    assert_match(/Kegel-Variante/, compiled,
      "T-Kegel-erb-compiles: 'Kegel-Variante' label must survive ERB compilation")
    assert_match(/get is_kegel\(\)/, compiled,
      "T-Kegel-erb-compiles: is_kegel() getter must survive compilation")
    assert_match(/get kegel_choice\(\)/, compiled,
      "T-Kegel-erb-compiles: kegel_choice() getter must survive compilation")
  end

  private

  # ---------------------------------------------------------------------------
  # Helper — initial BK2-Kombi TableMonitor data for DZ phase (mirrors Phase 38.3 shape)
  # ---------------------------------------------------------------------------
  def initial_bk2_data
    {
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
          "1" => {"playera" => 0, "playerb" => 0},
          "2" => {"playera" => 0, "playerb" => 0},
          "3" => {"playera" => 0, "playerb" => 0}
        },
        "sets_won" => {"playera" => 0, "playerb" => 0},
        "balls_goal" => 50,
        "set_target_points" => 50
      }
    }
  end

  # Helper — creates a fresh persisted TableMonitor with the given BK-* free_game_form,
  # balls_goal, phase, and an optional initial score for playera.
  #
  # Used for service-level dispatch tests (I7/I9) that do not require a browser.
  # Uses dynamic create! (not fixtures) because BK-family fixtures reference
  # TournamentMonitor associations that are not wired in the fixture file.
  #
  # Phase 38.4-07 D-06: bk2_state["balls_goal"] and transitional "set_target_points"
  # are both written so that both close_set_if_reached! paths work regardless of
  # whether the run is on an in-flight game (legacy key) or a fresh one.
  def create_bk_family_table_monitor(free_game_form:, balls_goal: 50, phase: "serienspiel",
    initial_score: 0)
    max_shots = (phase == "direkter_zweikampf") ? 2 : 0
    max_innings = (phase == "serienspiel") ? 5 : 0

    TableMonitor.create!(
      state: "playing",
      data: {
        "free_game_form" => free_game_form,
        "bk2_options" => {
          "direkter_zweikampf_max_shots_per_turn" => max_shots,
          "serienspiel_max_innings_per_set" => max_innings,
          "first_set_mode" => phase
        },
        "bk2_state" => {
          "current_set_number" => 1,
          "current_phase" => phase,
          "first_set_mode" => phase,
          "player_at_table" => "playera",
          "shots_left_in_turn" => (phase == "direkter_zweikampf") ? 2 : 0,
          "innings_left_in_set" => (phase == "serienspiel") ? 5 : 0,
          "set_scores" => {
            "1" => {"playera" => initial_score, "playerb" => 0},
            "2" => {"playera" => 0, "playerb" => 0},
            "3" => {"playera" => 0, "playerb" => 0}
          },
          "sets_won" => {"playera" => 0, "playerb" => 0},
          "balls_goal" => balls_goal,
          "set_target_points" => balls_goal
        }
      }
    )
  end
end
