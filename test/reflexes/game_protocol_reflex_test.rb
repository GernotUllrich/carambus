# frozen_string_literal: true

require "test_helper"

# Phase 38.7 Plan 06 Task 4 (revision) — GameProtocolReflex#confirm_result
# tiebreak-validation functional tests.
#
# Pattern: same as test/reflexes/party_monitor_reflex_test.rb — reflex methods
# are not driven over the WebSocket/StimulusReflex stack. Instead we instantiate
# the reflex class via .allocate (skipping the StimulusReflex base initializer
# that expects a real WebSocket session), set the @table_monitor ivar and a
# synthesized params hash directly, invoke confirm_result, and assert on the
# persisted side-effects: game.data['tiebreak_winner'], @table_monitor state.
#
# Coverage:
#   - T1: invalid tiebreak_winner ('playerc') -> modal stays open, no game.data write
#   - T2: missing tiebreak_winner (empty params) -> modal stays open, no game.data write
#   - T3: valid tiebreak_winner='playera' -> game.data['tiebreak_winner']='playera'
#   - T4: valid tiebreak_winner='playerb' -> game.data['tiebreak_winner']='playerb'
#   - T5: confirm_result on non-tiebreak path (current_element != 'tiebreak_winner_choice')
#         -> no tiebreak_winner read, no game.data write (regression guard)
#
# T1+T2 mitigate T-38.7-06-01 (forged param). T5 is the regression guard for the
# legacy non-tiebreak path. Plan 08 E2E probe still runs as defense-in-depth.
class GameProtocolReflexTest < ActiveSupport::TestCase
  setup do
    @tm = table_monitors(:one)
    @game = Game.create!(data: {"tiebreak_required" => true}, group_no: 1, seqno: 1, table_no: 1)
    # Tied karambol scores so tiebreak_pending_block? would normally hold (defense-in-depth alignment).
    @tm.update!(
      data: {
        "free_game_form" => "karambol",
        "playera" => {"result" => 80, "innings" => 30, "balls_goal" => 80},
        "playerb" => {"result" => 80, "innings" => 30, "balls_goal" => 80},
        "innings_goal" => 30,
        "allow_follow_up" => false
      }
    )
    @tm.update_columns(
      game_id: @game.id,
      panel_state: "protocol_final",
      current_element: "tiebreak_winner_choice"
    )
    @tm.reload

    @reflex = GameProtocolReflex.allocate
    @reflex.instance_variable_set(:@table_monitor, @tm)
    # Stub the broadcast helpers to avoid touching the real ActionCable / Sidekiq.
    @reflex.define_singleton_method(:send_modal_update) { |_html| nil }
    @reflex.define_singleton_method(:morph) { |_target| nil }
    @reflex.define_singleton_method(:render_protocol_modal) { "<div>modal</div>" }
  end

  test "T1: invalid tiebreak_winner ('playerc') is rejected — game.data not written, state unchanged" do
    @reflex.define_singleton_method(:params) {
      ActionController::Parameters.new(tiebreak_winner: "playerc")
    }
    # evaluate_result must NOT be called when validation fails.
    @tm.define_singleton_method(:evaluate_result) {
      raise "evaluate_result must not be invoked when tiebreak_winner is invalid"
    }
    assert_nothing_raised { @reflex.confirm_result }
    @game.reload
    assert_nil @game.data["tiebreak_winner"], "Invalid tiebreak_winner must not persist"
    assert_equal "tiebreak_winner_choice", @tm.reload.current_element,
      "Modal must stay open (current_element unchanged) on rejection"
  end

  test "T2: missing tiebreak_winner is rejected — game.data not written" do
    @reflex.define_singleton_method(:params) { ActionController::Parameters.new({}) }
    @tm.define_singleton_method(:evaluate_result) {
      raise "evaluate_result must not be invoked when tiebreak_winner is missing"
    }
    assert_nothing_raised { @reflex.confirm_result }
    @game.reload
    assert_nil @game.data["tiebreak_winner"]
    assert_equal "tiebreak_winner_choice", @tm.reload.current_element
  end

  test "T3: valid tiebreak_winner='playera' is persisted to game.data" do
    @reflex.define_singleton_method(:params) {
      ActionController::Parameters.new(tiebreak_winner: "playera")
    }
    # Stub evaluate_result + Job — they're tested in their own files.
    @tm.define_singleton_method(:evaluate_result) { nil }
    TableMonitorJob.stub :perform_later, ->(_a, _b) {} do
      assert_nothing_raised { @reflex.confirm_result }
    end
    @game.reload
    assert_equal "playera", @game.data["tiebreak_winner"],
      "Valid pick must persist to game.data['tiebreak_winner']"
  end

  test "T4: valid tiebreak_winner='playerb' is persisted to game.data" do
    @reflex.define_singleton_method(:params) {
      ActionController::Parameters.new(tiebreak_winner: "playerb")
    }
    @tm.define_singleton_method(:evaluate_result) { nil }
    TableMonitorJob.stub :perform_later, ->(_a, _b) {} do
      assert_nothing_raised { @reflex.confirm_result }
    end
    @game.reload
    assert_equal "playerb", @game.data["tiebreak_winner"]
  end

  test "T5: non-tiebreak confirm_result does NOT read tiebreak_winner (regression guard)" do
    # Switch the marker to the legacy 'confirm_result' value — the validation branch
    # must NOT fire, even if a forged tiebreak_winner param is present.
    @tm.update_columns(current_element: "confirm_result")
    @tm.reload
    @reflex.define_singleton_method(:params) {
      ActionController::Parameters.new(tiebreak_winner: "playerc") # forged value MUST be ignored
    }
    @tm.define_singleton_method(:evaluate_result) { nil }
    TableMonitorJob.stub :perform_later, ->(_a, _b) {} do
      assert_nothing_raised { @reflex.confirm_result }
    end
    @game.reload
    assert_nil @game.data["tiebreak_winner"],
      "Non-tiebreak path must not touch game.data['tiebreak_winner'], even with forged param"
  end

  # Phase quick-260503-mor — panel_state race guard regression suite.
  #
  # Race observed at the BCW Grand Prix on 2026-05-02: when a set ends in a draw,
  # TableMonitor#set_game_over (AASM after-callback) sets panel_state='protocol_final'
  # and current_element='confirm_result' / 'tiebreak_winner_choice'. The CableReady
  # push to the scoreboard can arrive late; the operator clicks the still-visible
  # Spielprotokoll-Button on the stale DOM and GameProtocolReflex#open_protocol (or
  # #switch_to_edit_mode / #switch_to_view_mode) unconditionally overwrites
  # panel_state, downgrading 'protocol_final' → 'protocol' / 'protocol_edit' and
  # losing the tiebreak fieldset wiring.
  #
  # SKILL extend-before-build: protect the existing reflex methods with a small
  # early-return guard rather than building a new state machine. R1/R2/R3 lock the
  # no-downgrade contract for each of the three vulnerable reflex entry points.
  test "R1: open_protocol on protocol_final must NOT downgrade panel_state (race guard)" do
    # Setup already seeds panel_state='protocol_final', current_element='tiebreak_winner_choice'.
    modal_update_calls = 0
    @reflex.define_singleton_method(:send_modal_update) { |_html| modal_update_calls += 1 }
    assert_nothing_raised { @reflex.open_protocol }
    @tm.reload
    assert_equal "protocol_final", @tm.panel_state,
      "open_protocol on a protocol_final TM must NOT downgrade to 'protocol' (BCW Grand Prix race)"
    assert_equal "tiebreak_winner_choice", @tm.current_element,
      "current_element marker must be preserved on stale-DOM open_protocol click"
    assert_equal 1, modal_update_calls,
      "open_protocol on protocol_final must re-render the modal so the operator's click is not silently discarded"
  end

  test "R2: switch_to_edit_mode on protocol_final must NOT downgrade panel_state (race guard)" do
    modal_update_calls = 0
    @reflex.define_singleton_method(:send_modal_update) { |_html| modal_update_calls += 1 }
    assert_nothing_raised { @reflex.switch_to_edit_mode }
    @tm.reload
    assert_equal "protocol_final", @tm.panel_state,
      "switch_to_edit_mode on a protocol_final TM must NOT downgrade to 'protocol_edit'"
    assert_equal "tiebreak_winner_choice", @tm.current_element,
      "current_element marker must be preserved on stale-DOM switch_to_edit_mode click"
    assert_equal 1, modal_update_calls,
      "switch_to_edit_mode on protocol_final must re-render the modal"
  end

  test "R3: switch_to_view_mode on protocol_final must NOT downgrade panel_state (race guard)" do
    # Cover the second valid protocol_final marker — 'confirm_result' (set by set_game_over
    # before ResultRecorder detects a pending tiebreak).
    @tm.update_columns(current_element: "confirm_result")
    @tm.reload
    modal_update_calls = 0
    @reflex.define_singleton_method(:send_modal_update) { |_html| modal_update_calls += 1 }
    assert_nothing_raised { @reflex.switch_to_view_mode }
    @tm.reload
    assert_equal "protocol_final", @tm.panel_state,
      "switch_to_view_mode on a protocol_final TM must NOT downgrade to 'protocol'"
    assert_equal "confirm_result", @tm.current_element,
      "current_element='confirm_result' marker must be preserved on stale-DOM switch_to_view_mode click"
    assert_equal 1, modal_update_calls,
      "switch_to_view_mode on protocol_final must re-render the modal"
  end

  # ---------------------------------------------------------------------------
  # Plan 31-01: Rueckweg ins Spiel bei Satzspielen (Pool/Snooker). Der Matchball wird ueber
  # den ECHTEN Eingabeweg gespielt (add_n_balls -> terminate_current_inning -> evaluate_result),
  # nicht von Hand in den Endzustand gesetzt — gemessen wird, was der Knopf dann zuruecknimmt.
  # ---------------------------------------------------------------------------

  FRAME1_31 = {"Ergebnis1" => 5, "Ergebnis2" => 2, "Aufnahmen1" => 4, "Aufnahmen2" => 3,
               "Höchstserie1" => 3, "Höchstserie2" => 2, "Innings1" => [1, 1, 3, 0], "Innings2" => [1, 1, 0]}.freeze

  def player_31(id, first)
    Player.find_by(id: id) || Player.create!(id: id, firstname: first, lastname: "Satz", dbu_nr: id - 50_000_000, ba_id: id - 50_000_000)
  end

  def side_31(result:, innings_list:, current:, hs:, goal:)
    {"discipline" => "8-Ball", "result" => result, "innings" => innings_list.size, "innings_list" => innings_list,
     "innings_redo_list" => [current], "innings_foul_list" => [0] * innings_list.size, "innings_foul_redo_list" => [0],
     "hs" => hs, "gd" => "0.00", "balls_goal" => goal}
  end

  # Pool, 2 Gewinnsaetze, Frame 1 gewonnen (1:0); Frame 2: A steht bei 4 von 5 in seiner Aufnahme.
  def prepare_pool_31
    game = Game.create!(data: {}, group_no: 1, seqno: 31, table_no: 1)
    GameParticipation.create!(game: game, player: player_31(50_131_001, "PoolA"), role: "playera")
    GameParticipation.create!(game: game, player: player_31(50_131_002, "PoolB"), role: "playerb")
    ba = {"Gruppe" => 1, "Partie" => 31, "Spieler1" => 131_001, "Spieler2" => 131_002, "Sets1" => 1, "Sets2" => 0,
          "Ergebnis1" => 5, "Ergebnis2" => 2, "Aufnahmen1" => 4, "Aufnahmen2" => 3,
          "Höchstserie1" => 3, "Höchstserie2" => 2, "Tischnummer" => 1}
    @tm.update!(data: {
      "free_game_form" => "pool", "sets_to_win" => 2, "sets_to_play" => 3, "allow_follow_up" => false,
      "kickoff_switches_with" => "set", "current_kickoff_player" => "playera",
      "balls_on_table" => 15, "balls_counter" => 15, "balls_counter_stack" => [],
      "sets" => [FRAME1_31.dup], "ba_results" => ba,
      "playera" => side_31(result: 0, innings_list: [0], current: 4, hs: 0, goal: 5),
      "playerb" => side_31(result: 1, innings_list: [1], current: 0, hs: 1, goal: 5),
      "current_inning" => {"active_player" => "playera", "balls" => 4}
    })
    @tm.update_columns(game_id: game.id, state: "playing", panel_state: "pointer_mode", current_element: "pointer_mode")
    @tm.reload
    assert @tm.simple_set_game?, "VORBEDINGUNG: Pool ist ein Satzspiel"
  end

  def total_31(side) = @tm.data[side]["result"].to_i + Array(@tm.data[side]["innings_redo_list"]).last.to_i

  test "31-01: Pool — der Rueckweg nimmt den Matchball-Frame, den Satzstand und die letzte Eingabe zurueck" do
    prepare_pool_31
    @tm.suppress_broadcast = true
    @tm.add_n_balls(1) # der Matchball: 5 von 5
    @tm.reload
    assert_equal "set_over", @tm.state, "VORBEDINGUNG: Matchende ueber den echten Weg"
    assert_equal "protocol_final", @tm.panel_state, "VORBEDINGUNG"
    assert_equal 2, @tm.data["sets"].size, "VORBEDINGUNG: der Frame steht schon in data[\"sets\"]"
    assert_equal 2, @tm.data["ba_results"]["Sets1"], "VORBEDINGUNG"

    @reflex.back_to_game
    @tm.reload

    assert_equal "playing", @tm.state
    refute_equal "protocol_final", @tm.panel_state
    assert_equal [FRAME1_31], @tm.data["sets"], "Frame 1 unveraendert, Matchball-Frame entfernt"
    assert_equal [1, 0], [@tm.data["ba_results"]["Sets1"], @tm.data["ba_results"]["Sets2"]], "Satzstand wieder 1:0"
    # Ein Schritt zurueck wie bei Karambol (Phase 27, Betreiber 2026-10-23): der Matchball hatte As
    # Aufnahme abgeschlossen und B an den Tisch geholt — zurueckgenommen wird dieser Abschluss. A ist
    # wieder am Zug, seine offene Aufnahme zeigt den eingegebenen Stand; korrigiert wird mit -1.
    # Entscheidend: NICHT der Frameanfang (das taete TableMonitor#undo per PaperTrail).
    assert_equal "playera", @tm.data["current_inning"]["active_player"], "A ist wieder am Zug"
    assert_equal 5, total_31("playera"), "der Stand der offenen Aufnahme bleibt stehen (wie Karambol)"
    assert_equal 1, total_31("playerb"), "B unveraendert"
    refute @tm.end_of_set?, "das Protokoll kommt nicht sofort wieder"
  end

  # Snooker, 2 Gewinnframes, Frame 1 gewonnen; Frame 2: alle Roten weg, nur noch Schwarz, A am Tisch.
  def prepare_snooker_31
    prepare_pool_31
    snk = ->(innings_list, current, done, open) {
      {"discipline" => "Snooker", "result" => innings_list.sum, "innings" => innings_list.size, "innings_list" => innings_list,
       "innings_redo_list" => [current], "innings_foul_list" => [0] * innings_list.size, "innings_foul_redo_list" => [0],
       "break_balls_list" => done, "break_balls_redo_list" => [open], "hs" => 0, "gd" => "0.00", "balls_goal" => 0}
    }
    @tm.update!(data: @tm.data.merge(
      "free_game_form" => "snooker", "initial_red_balls" => 6, "snooker_frame_complete" => false,
      "snooker_state" => {"reds_remaining" => 0, "last_potted_ball" => 6, "free_ball_active" => false, "colors_sequence" => [7]},
      "playera" => snk.call([48], 20, [[1, 7, 1, 7, 1, 7, 1, 7, 1, 7, 1, 7]], [2, 3, 4, 5, 6]),
      "playerb" => snk.call([0], 0, [[]], []),
      "current_inning" => {"active_player" => "playera", "balls" => 0}
    ))
    @tm.reload
    assert @tm.simple_set_game?, "VORBEDINGUNG: Snooker ist ein Satzspiel"
  end

  test "31-01: Snooker — der Rueckweg nimmt den Frame und die letzte Kugel zurueck und loescht das Frame-Ende-Flag" do
    prepare_snooker_31
    @tm.suppress_broadcast = true
    @tm.add_n_balls(7) # die letzte Schwarze
    @tm.reload
    assert_equal "set_over", @tm.state, "VORBEDINGUNG: Matchende ueber den echten Weg"
    assert_equal "protocol_final", @tm.panel_state, "VORBEDINGUNG"
    assert_equal 2, @tm.data["sets"].size, "VORBEDINGUNG: der Frame steht schon in data[\"sets\"]"
    assert @tm.data["snooker_frame_complete"], "VORBEDINGUNG"

    @reflex.back_to_game
    @tm.reload

    assert_equal "playing", @tm.state
    refute_equal "protocol_final", @tm.panel_state
    assert_equal [FRAME1_31], @tm.data["sets"], "Frame 1 unveraendert, Matchball-Frame entfernt"
    assert_equal [1, 0], [@tm.data["ba_results"]["Sets1"], @tm.data["ba_results"]["Sets2"]], "Satzstand wieder 1:0"
    assert_equal false, @tm.data["snooker_frame_complete"], "sonst ginge das Protokoll sofort wieder auf"
    refute @tm.end_of_set?
    assert_equal "playera", @tm.data["current_inning"]["active_player"], "A ist weiter am Tisch"
    assert_equal 68, total_31("playera"), "die Schwarze ist zurueckgenommen (48 + Break 20)"
    # colors_sequence wird hier NICHT geprueft: recalculate_snooker_state_from_protocol (score_engine.rb)
    # streicht die Farbe nach der letzten Roten faelschlich aus der Folge — vorbestehend, trifft jedes
    # Snooker-Undo nach der letzten Roten (Befund 31-01, deferred). Fuer den Rueckweg zaehlt: der Frame
    # laesst sich regulaer zu Ende spielen.
    @tm.add_n_balls(7)
    @tm.reload
    assert_equal "set_over", @tm.state, "Schwarz erneut versenkt -> Matchende wie zuvor"
    assert_equal 2, @tm.data["sets"].size
    assert_equal [2, 0], [@tm.data["ba_results"]["Sets1"], @tm.data["ba_results"]["Sets2"]], "2:0, nicht 3:0"
  end
end
