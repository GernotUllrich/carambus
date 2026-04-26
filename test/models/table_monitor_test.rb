# frozen_string_literal: true

require "test_helper"

# Unit tests for TableMonitor model-level predicates introduced in Phase 38.2
# Plan 01. Distinct from `test/characterization/table_monitor_char_test.rb`
# which pins AASM + after_commit behavior.
#
# Phase 38.2 D-18 / UAT-GAP-05: bk2_state_uninitialized? predicate signals
# that a TableMonitor in BK2-Kombi mode has no (or empty) bk2_state Hash.
# Consumed by _show_bk2_kombi.html.erb (Plan 03) to render a fallback banner.
class TableMonitorTest < ActiveSupport::TestCase
  # ---------------------------------------------------------------------------
  # Setup / Teardown
  # ---------------------------------------------------------------------------

  setup do
    TableMonitor.options = nil
    TableMonitor.gps = nil
    TableMonitor.location = nil
    TableMonitor.tournament = nil
    TableMonitor.my_table = nil
    TableMonitor.allow_change_tables = nil

    @tm = TableMonitor.create!(state: "new", data: {})
  end

  teardown do
    TableMonitor.options = nil
    TableMonitor.gps = nil
    TableMonitor.location = nil
    TableMonitor.tournament = nil
    TableMonitor.my_table = nil
    TableMonitor.allow_change_tables = nil
  end

  # ---------------------------------------------------------------------------
  # bk2_state_uninitialized? predicate
  # ---------------------------------------------------------------------------

  test "bk2_state_uninitialized? returns true when free_game_form is bk2_kombi and bk2_state is missing" do
    @tm.update!(data: {"free_game_form" => "bk2_kombi"})
    assert @tm.bk2_state_uninitialized?,
      "Missing bk2_state Hash must be flagged as uninitialized"
  end

  test "bk2_state_uninitialized? returns true when bk2_state is nil" do
    @tm.update!(data: {"free_game_form" => "bk2_kombi", "bk2_state" => nil})
    assert @tm.bk2_state_uninitialized?,
      "Nil bk2_state must be flagged as uninitialized"
  end

  test "bk2_state_uninitialized? returns true when bk2_state is an empty hash" do
    @tm.update!(data: {"free_game_form" => "bk2_kombi", "bk2_state" => {}})
    assert @tm.bk2_state_uninitialized?,
      "Empty bk2_state Hash must be flagged as uninitialized"
  end

  test "bk2_state_uninitialized? returns true when bk2_state is not a Hash" do
    @tm.update!(data: {"free_game_form" => "bk2_kombi", "bk2_state" => "not-a-hash"})
    assert @tm.bk2_state_uninitialized?,
      "Non-Hash bk2_state must be flagged as uninitialized"
  end

  test "bk2_state_uninitialized? returns false when bk2_state is a populated Hash" do
    @tm.update!(data: {
      "free_game_form" => "bk2_kombi",
      "bk2_state" => {"current_set_number" => 1, "current_phase" => "direkter_zweikampf"}
    })
    refute @tm.bk2_state_uninitialized?,
      "Populated bk2_state must be recognised as initialized"
  end

  test "bk2_state_uninitialized? returns false for non-bk2 games (karambol)" do
    @tm.update!(data: {"free_game_form" => "karambol"})
    refute @tm.bk2_state_uninitialized?,
      "Non-BK2 games must not be flagged regardless of bk2_state presence"
  end

  test "bk2_state_uninitialized? returns false for non-bk2 games (pool)" do
    @tm.update!(data: {"free_game_form" => "pool"})
    refute @tm.bk2_state_uninitialized?
  end

  test "bk2_state_uninitialized? returns false when data is empty" do
    @tm.update!(data: {})
    refute @tm.bk2_state_uninitialized?,
      "Empty data hash must not raise and must not flag"
  end

  test "bk2_state_uninitialized? returns false when data is nil-equivalent (raw write)" do
    # Simulate a raw write that yields non-Hash data. We cannot persist nil via
    # update!, but we can verify the predicate handles it in-memory.
    @tm.instance_variable_set(:@attributes, @tm.instance_variable_get(:@attributes))
    def @tm.data; nil; end
    refute @tm.bk2_state_uninitialized?,
      "Non-Hash data must not raise and must not flag"
  end

  # Phase 38.4 R5-1: karambol_commit_inning! commits the running inning into the
  # karambol data model (innings_list, result, active_player) so the view shows
  # the right score after a BK-* player switch. Replaces the buggy redo_list[-1]=0;
  # << 0 reset that left innings_redo_list = [0, 0] and innings_list = [].
  test "karambol_commit_inning! commits running inning_redo_list[-1] into innings_list and recomputes result" do
    @tm.update!(data: {
      "free_game_form" => "bk2_kombi",
      "current_inning" => {"active_player" => "playera"},
      "playera" => {
        "result" => 0, "innings" => 0,
        "innings_list" => [], "innings_redo_list" => [15],
        "innings_foul_list" => [], "innings_foul_redo_list" => [0]
      },
      "playerb" => {
        "result" => 0, "innings" => 0,
        "innings_list" => [], "innings_redo_list" => [],
        "innings_foul_list" => [], "innings_foul_redo_list" => []
      }
    })

    @tm.karambol_commit_inning!("playera")
    @tm.save!
    @tm.reload

    a = @tm.data["playera"]
    b = @tm.data["playerb"]
    assert_equal [15], a["innings_list"], "playera.innings_list must capture the committed running total"
    assert_equal [0], a["innings_redo_list"], "playera.innings_redo_list must reset to a fresh [0]"
    assert_equal 1, a["innings"].to_i, "playera.innings must increment"
    assert_equal 15, a["result"].to_i, "playera.result must equal sum(innings_list)"
    assert_equal "playerb", @tm.data["current_inning"]["active_player"],
      "active_player must flip to opponent"
    assert_equal [0], b["innings_redo_list"],
      "opponent must have a fresh [0] redo_list ready for their next inning"
  end

  test "karambol_commit_inning! is a no-op for unknown player" do
    initial = {"playera" => {"innings_list" => [], "innings_redo_list" => [5]}}
    @tm.update!(data: initial.merge("free_game_form" => "bk2_kombi"))
    @tm.karambol_commit_inning!("unknown")
    @tm.reload
    assert_equal [5], @tm.data["playera"]["innings_redo_list"],
      "Unknown player must not mutate any data"
  end
end
