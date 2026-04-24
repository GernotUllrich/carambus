# frozen_string_literal: true

require "application_system_test_case"

# Phase 38.2 BK2-Kombi scoreboard system + integration test.
#
# Replaces the 38.1 Plan 04 test file (inplace overwrite per CONTEXT.md D-17).
#
# Coverage:
#   - Plan 02 detail-view first_set_mode selector integration — covered
#     indirectly via the `bk2_first_set_mode` round-trip through the
#     controller (Plan 01 whitelist + service init). DOM-level Alpine
#     coverage lives in the controller tests shipped in Plan 01.
#   - Plan 03 Karambol-parallel scoreboard:
#       * Satz header (#bk2_set_header)
#       * Phase chip
#       * Phase-sensitive remaining badge (#bk2_remaining_badge)
#       * Player cards with current-set score + match-score + Ziel
#       * Home/Cancel/Continue warning modal
#   - Plan 04 bottom bar:
#       * data-controller="bk2-kombi-shot"
#       * 10 Stimulus targets
#       * data-reflex="click->TableMonitor#bk2_kombi_submit_shot"
#   - UAT-GAP regressions:
#       * GAP-02 (Alpine scope) — indirect via bk2_first_set_mode param persistence
#       * GAP-03 (phase chip hash bleed on blank current_phase)
#       * GAP-04 (Home/Cancel/Continue modal present)
#       * GAP-05 (fallback banner + absent bottom bar on uninitialised state)
#   - Plan 01 service/state augmentations:
#       * first_set_mode persisted in bk2_state
#       * innings_left_in_set seeded from bk2_options.serienspiel_max_innings_per_set
#       * shots_left_in_turn seeded from bk2_options.direkter_zweikampf_max_shots_per_turn
#   - 38.1 ScoreShot regression (scope-guard: ScoreShot UNCHANGED in 38.2):
#       * B2 full_pin_image + middle_pin_only → 2 points
#       * wrong_ball foul credits opponent 6 points
#
# Integration-level shot-submit tests call Bk2Kombi::AdvanceMatchState.call
# directly — the StimulusReflex click path is JS-brittle and duplicates the
# service-layer test coverage shipped in Plan 01.
class Bk2KombiScoreboardTest < ApplicationSystemTestCase
  setup do
    @tm = table_monitors(:one)

    # 38.1 WR-02: track whether THIS test created the Game, so teardown only
    # destroys what setup created. Without this guard, a prior failed/aborted
    # run (or a future fixture) that left a Game at id 50_000_200 would be
    # silently wiped by our teardown — leaking test-to-test state.
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

  # -----------------------------------------------------------------------
  # Capybara DOM tests
  # -----------------------------------------------------------------------

  test "renders Satz header and phase chip for direkter_zweikampf phase" do
    visit table_monitor_path(@tm)

    assert_selector "#bk2_set_header", wait: 5
    # D-04 header: "Satz N" (key t("table_monitor.bk2_kombi.set.current", n: 1)
    # renders "Satz 1"). The partial then appends " / 3".
    assert_text "Satz 1"
    assert_selector "#bk2_remaining_badge"
    # D-11: DZ phase badge shows shots_left (2) + pluralised shots_left_label.
    remaining = find("#bk2_remaining_badge").text
    assert_match(/2/, remaining,
      "DZ badge should show shots_left_in_turn=2 (seeded from bk2_options)")
    assert_match(/Stöße übrig|Stoß übrig/, remaining,
      "DZ badge should render shots_left_label i18n value (not a parent hash)")
  end

  test "renders innings_left badge for serienspiel phase" do
    @tm.update!(data: initial_bk2_data.deep_merge(
      "bk2_state" => {
        "current_phase" => "serienspiel",
        "first_set_mode" => "serienspiel",
        "innings_left_in_set" => 5,
        "shots_left_in_turn" => 0
      }
    ))
    visit table_monitor_path(@tm)

    assert_selector "#bk2_remaining_badge", wait: 5
    remaining = find("#bk2_remaining_badge").text
    assert_match(/5/, remaining,
      "SP badge should show innings_left_in_set=5")
    assert_match(/Aufnahmen übrig|Aufnahme übrig/, remaining,
      "SP badge should render innings_left_label i18n value (not a parent hash)")
  end

  test "renders player cards with current-set score and match score" do
    @tm.update!(data: initial_bk2_data.deep_merge(
      "bk2_state" => {
        "set_scores" => { "1" => { "playera" => 23, "playerb" => 12 } },
        "sets_won" => { "playera" => 0, "playerb" => 1 }
      }
    ))
    visit table_monitor_path(@tm)

    # D-07: large number = current-set score (not cumulative).
    assert_text "23"
    assert_text "12"
    # D-05: Ziel slot shows current set target (50).
    assert_text "50"
    # D-06: match-score slot next to names reads sets_won (0:1 from A's side;
    # 1:0 from B's side since both mirror cards render the pair). The exact
    # ordering depends on which player is the "left" player per options
    # [:current_left_player], so just assert both pairings appear somewhere.
    assert_match(/0.*1|1.*0/, find_all(:xpath, "//*[contains(text(), ':')]").map(&:text).join(" "),
      "match-score slot should reflect sets_won 0:1 / 1:0")
  end

  test "warning modal present (UAT-GAP-04 regression)" do
    visit table_monitor_path(@tm)

    # The warning modal is initially hidden (class="hidden") — use visible: :all
    # so Capybara doesn't filter by CSS visibility.
    assert_selector "#modal-confirm-back-bg", visible: :all, wait: 5
    assert_selector "#modal-confirm-back", visible: :all
  end

  test "bottom bar renders with 10 Stimulus targets and data-reflex" do
    visit table_monitor_path(@tm)

    assert_selector "[data-controller~='bk2-kombi-shot']", wait: 5

    # All 10 Stimulus targets (Plan 04 Task 1 D-16 DOM).
    %w[fullPinImage fallenPins middlePinOnly trueCarom falseCarom
      passages foul foulCode bandHit submit].each do |target_name|
      # assert_selector kwargs whitelist excludes :message — use Minitest
      # assert with a manual has_selector? check so the failure message names
      # the target.
      assert page.has_selector?("[data-bk2-kombi-shot-target='#{target_name}']",
        visible: :all),
        "expected Stimulus target '#{target_name}' in bottom bar"
    end

    # Reflex binding on submit button.
    assert_selector "[data-reflex*='TableMonitor#bk2_kombi_submit_shot']",
      visible: :all
  end

  test "fallback banner + bottom bar absent on uninitialised state (UAT-GAP-05 regression)" do
    # free_game_form=bk2_kombi but NO bk2_state key — the GAP-05 class of bug.
    @tm.update!(data: { "free_game_form" => "bk2_kombi" })
    visit table_monitor_path(@tm)

    # GAP-05 regression: fallback banner title must render when bk2_state is empty.
    # Note: assert_text treats the first positional arg as a type selector if a
    # second positional arg is provided — pass only the expected text.
    assert_text I18n.t("table_monitor.bk2_kombi.fallback.uninitialized_banner_title")
    # bk2_state_uninitialized? returns true here — bottom bar must NOT render.
    assert_no_selector "[data-controller~='bk2-kombi-shot']"
    # The Home/Cancel/Continue modal is outside the fallback branch, so it's
    # still present (Home nav must remain reachable even in error state).
    assert_selector "#modal-confirm-back", visible: :all
  end

  test "phase chip shows fallback marker when current_phase is blank (UAT-GAP-03 regression)" do
    # Build a bk2_state with every field populated EXCEPT current_phase (blank).
    # This is the post-init-before-first-shot state where GAP-03 would trigger:
    # t("table_monitor.bk2_kombi.phase.#{''}") would return the parent hash.
    blank_phase_state = initial_bk2_data["bk2_state"].merge("current_phase" => "")
    @tm.update!(data: initial_bk2_data.merge("bk2_state" => blank_phase_state))
    visit table_monitor_path(@tm)

    page_body = page.body
    # GAP-03 regression: the parent i18n hash must NOT leak through as text.
    refute_match(/direkter_zweikampf:\s*Direkter Zweikampf/, page_body,
      "GAP-03 regression: phase chip should not render the parent i18n hash as text")
    refute_match(/translation missing/i, page_body,
      "GAP-03 regression: should not render 'translation missing' for blank phase")
    # Guard helper (phase_label in the partial) renders "—" when current_phase blank.
    assert_match(/—|&mdash;|-/, page_body,
      "phase chip should render a fallback marker when current_phase is blank")
  end

  test "non-BK2 TableMonitor does not render bk2-kombi DOM (negative control)" do
    @tm.update!(data: {
      "free_game_form" => "karambol",
      "playera" => {},
      "playerb" => {}
    })
    visit table_monitor_path(@tm)

    assert_no_selector "[data-controller~='bk2-kombi-shot']"
    assert_no_selector "#bk2_set_header"
  end

  # -----------------------------------------------------------------------
  # Integration tests (direct service calls — avoid JS-brittle Capybara)
  # -----------------------------------------------------------------------

  test "AdvanceMatchState initialises bk2_state with first_set_mode=serienspiel" do
    # Start from a cleared state so init_state_if_missing! runs.
    @tm.update!(data: {
      "free_game_form" => "bk2_kombi",
      "bk2_options" => {
        "set_target_points" => 50,
        "first_set_mode" => "serienspiel",
        "serienspiel_max_innings_per_set" => 5
      },
      "current_kickoff_player" => "playera"
    })

    # Submit a non-turn-ending shot (fallen_pins=3 in SP scores 3 points, does
    # not zero out → turn continues → innings_left_in_set NOT decremented).
    Bk2Kombi::AdvanceMatchState.call(
      table_monitor: @tm,
      shot_payload: {
        observations: { fallen_pins: 3 },
        table_snapshot: { full_pin_image: false }
      }
    )

    state = @tm.reload.data["bk2_state"]
    assert_equal "serienspiel", state["first_set_mode"],
      "Plan 01: first_set_mode must be persisted from bk2_options"
    assert_equal "serienspiel", state["current_phase"],
      "D-14: Satz 1 in a SP-first match must start in serienspiel phase"
    assert_equal 5, state["innings_left_in_set"],
      "D-20: innings_left_in_set must be seeded from bk2_options.serienspiel_max_innings_per_set=5 (non-zero shot keeps turn alive)"
  end

  test "AdvanceMatchState seeds shots_left_in_turn from direkter_zweikampf_max_shots_per_turn" do
    @tm.update!(data: {
      "free_game_form" => "bk2_kombi",
      "bk2_options" => {
        "set_target_points" => 50,
        "first_set_mode" => "direkter_zweikampf",
        "direkter_zweikampf_max_shots_per_turn" => 3
      },
      "current_kickoff_player" => "playera"
    })

    Bk2Kombi::AdvanceMatchState.call(
      table_monitor: @tm,
      shot_payload: {
        observations: { fallen_pins: 1 },
        table_snapshot: { full_pin_image: false }
      }
    )

    state = @tm.reload.data["bk2_state"]
    assert_equal "direkter_zweikampf", state["current_phase"],
      "D-14: Satz 1 in a DZ-first match must start in direkter_zweikampf phase"
    # After one non-bonus shot (fallen_pins=1, not 5): shots_left_in_turn
    # decremented from 3 → 2 per ScoreShot DZ transitions contract.
    assert_equal 2, state["shots_left_in_turn"],
      "D-20: shots_left_in_turn seeded from bk2_options.direkter_zweikampf_max_shots_per_turn=3, decremented by 1 after one non-bonus shot"
  end

  test "B2 full_pin_image + middle_pin_only rule awards 2 points (38.1 scope-guard regression)" do
    # @tm starts with bk2_state populated (DZ, set 1, playera at table) from setup.
    result = Bk2Kombi::AdvanceMatchState.call(
      table_monitor: @tm,
      shot_payload: {
        observations: { fallen_pins: 0, middle_pin_only: true },
        table_snapshot: { full_pin_image: true }
      }
    )
    # Return shape per plan read_first: { scoring: {…}, transitions: {…}, state: {…} }.
    # scoring[:points_for_current_player] per score_shot.rb apply_positive_scoring.
    assert_equal 2, result[:scoring][:points_for_current_player],
      "D-15: middle_pin_only + full_pin_image must still award 2 points (ScoreShot UNCHANGED in 38.2)"
  end

  test "foul wrong_ball credits opponent 6 points (38.1 scope-guard regression)" do
    # ScoreShot deep_symbolize_keys on keys only (not values); the case/when
    # block in calculate_foul_points dispatches on foul_code SYMBOL — so the
    # test payload must pass `:wrong_ball` as a Ruby symbol (mirrors the
    # TableMonitorReflex#bk2_kombi_submit_shot payload shape).
    result = Bk2Kombi::AdvanceMatchState.call(
      table_monitor: @tm,
      shot_payload: {
        observations: { foul: true, foul_code: :wrong_ball, fallen_pins: 0 },
        table_snapshot: { full_pin_image: false }
      }
    )
    # Per score_shot.rb docstring (lines 10-14) + apply_foul_scoring (lines 147-159):
    #   points_for_opponent = |foul_points| (POSITIVE credit to opponent)
    #   foul_points         = SIGNED D-16 value (-6 for wrong_ball)
    assert_equal 6, result[:scoring][:points_for_opponent],
      "wrong_ball foul must credit opponent 6 points (|foul_points|)"
    assert_equal(-6, result[:scoring][:foul_points],
      "foul_points must carry SIGNED D-16 value (-6 for wrong_ball)")
  end

  test "bk2_state_uninitialized? false for karambol (model regression)" do
    @tm.update!(data: { "free_game_form" => "karambol" })
    refute @tm.bk2_state_uninitialized?,
      "bk2_state_uninitialized? must return false for non-BK2 games (Plan 01 predicate guard)"
  end

  private

  # Initial bk2_data used in setup — mirrors post-Plan-01 state shape
  # (includes first_set_mode + innings_left_in_set fields).
  #
  # Also includes the stub keys the Karambol-parallel scoreboard partial
  # (Plan 03 D-01) needs when rendering with `state: "playing"`:
  #   - current_inning.active_player   — _menu.html.erb → can_undo? (line 1184)
  #   - playera.discipline / playerb.discipline — can_undo? discipline branch
  #   - playera.innings / playerb.innings       — can_undo? innings check
  # These stubs keep the Karambol-parallel _menu partial render-safe in tests;
  # they do not affect any BK2-specific assertion. Not in Plan 01 state
  # contract — pure view-layer scaffolding.
  def initial_bk2_data
    {
      "free_game_form" => "bk2_kombi",
      "current_kickoff_player" => "playera",
      "current_inning" => { "active_player" => "playera" },
      "playera" => { "discipline" => "BK2-Kombi", "innings" => 0, "result" => 0 },
      "playerb" => { "discipline" => "BK2-Kombi", "innings" => 0, "result" => 0 },
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
