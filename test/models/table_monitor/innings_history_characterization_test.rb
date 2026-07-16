# frozen_string_literal: true

require "test_helper"

# Characterization-Tests (Phase 13) für den Innings-History-Cluster von TableMonitor
# (table_monitor.rb Z.1969–2064). Pinnt das IST-Verhalten der ORCHESTRIERUNG (State-Guard +
# data_will_change!/save! + rescue-Fallback) VOR der Extraktion in Phase 14 — NICHT die
# ScoreEngine-Logik (die deckt score_engine_test.rb ab). Inklusive der dokumentierten
# Artefakte: Logger-Rückgabewert im rescue (truthy, kein Persist), Fallback-Hash bei Fehler.
class TableMonitor
  class InningsHistoryCharacterizationTest < ActiveSupport::TestCase
    include TableMonitorCharacterizationHelper

    # deep_dup für Vorher/Nachher-Vergleiche (serialisiertes data-Hash).
    def snapshot(tm)
      Marshal.load(Marshal.dump(tm.data))
    end

    # ---------------------------------------------------------------------------
    # innings_history (read) — Hash-Shape, Namen, Fallback
    # ---------------------------------------------------------------------------

    test "characterizes: innings_history liefert die dokumentierte Hash-Struktur" do
      tm = build_table_monitor(discipline: :karambol, state: "playing",
        innings: {a: [5, 3], b: [2, 4]}, with_game: true)

      h = tm.innings_history

      assert_equal %i[player_a player_b current_inning discipline balls_goal].sort, h.keys.sort
      assert_equal %i[name shortname innings totals result innings_count].sort, h[:player_a].keys.sort
      assert_kind_of Array, h[:player_a][:innings]
      assert_kind_of Array, h[:player_a][:totals]
      assert_kind_of Integer, h[:player_a][:result]
      assert_kind_of Integer, h[:player_a][:innings_count]
      assert_equal %i[number active_player].sort, h[:current_inning].keys.sort
      assert_equal "karambol", h[:discipline]
      assert_equal 100, h[:balls_goal]
    end

    test "characterizes: innings_history nutzt Default-Namen ohne Game" do
      tm = build_table_monitor(state: "playing", innings: {a: [1], b: [1]})

      h = tm.innings_history

      assert_equal "Spieler A", h[:player_a][:name]
      assert_equal "Spieler B", h[:player_b][:name]
    end

    test "characterizes: innings_history liefert den Fallback-Hash wenn die Engine wirft" do
      tm = build_table_monitor(state: "playing", innings: {a: [5], b: [3]})

      h = with_raising_score_engine(tm) { |t| t.innings_history }

      assert_equal 1, h[:current_inning][:number]
      assert_equal "playera", h[:current_inning][:active_player]
      assert_equal "", h[:discipline]
      assert_equal 0, h[:balls_goal]
      assert_equal 0, h[:player_a][:result]
      assert_equal [], h[:player_a][:innings]
    end

    # ---------------------------------------------------------------------------
    # State-Guard in :new — No-op bzw. "Not in playing state", keine Persistenz
    # ---------------------------------------------------------------------------

    test "characterizes: increment_inning_points ist No-op in :new (Guard vor Engine)" do
      tm = build_table_monitor(state: "new", innings: {a: [5], b: [3]})
      before = snapshot(tm)

      with_raising_score_engine(tm) do |t|
        assert_nothing_raised { t.increment_inning_points(0, "playera") }
      end

      assert_equal before, tm.data
      assert_equal before, tm.reload.data
    end

    test "characterizes: decrement_inning_points ist No-op in :new (Guard vor Engine)" do
      tm = build_table_monitor(state: "new", innings: {a: [5], b: [3]})
      before = snapshot(tm)

      with_raising_score_engine(tm) do |t|
        assert_nothing_raised { t.decrement_inning_points(0, "playera") }
      end

      assert_equal before, tm.reload.data
    end

    test "characterizes: insert_inning ist No-op in :new (Guard vor Engine)" do
      tm = build_table_monitor(state: "new", innings: {a: [5], b: [3]})
      before = snapshot(tm)

      with_raising_score_engine(tm) do |t|
        assert_nothing_raised { t.insert_inning(0) }
      end

      assert_equal before, tm.reload.data
    end

    test "characterizes: update_innings_history liefert 'Not in playing state' in :new" do
      tm = build_table_monitor(state: "new", innings: {a: [5], b: [3]})
      before = snapshot(tm)

      result = tm.update_innings_history("playera" => [6], "playerb" => [3])

      assert_equal false, result[:success]
      assert_equal "Not in playing state", result[:error]
      assert_equal before, tm.reload.data
    end

    test "characterizes: delete_inning liefert 'Not in playing state' in :new" do
      tm = build_table_monitor(state: "new", innings: {a: [0], b: [0]})
      before = snapshot(tm)

      result = tm.delete_inning(0)

      assert_equal false, result[:success]
      assert_equal "Not in playing state", result[:error]
      assert_equal before, tm.reload.data
    end

    # ---------------------------------------------------------------------------
    # Erfolg + Persistenz in :playing
    # ---------------------------------------------------------------------------

    test "characterizes: increment_inning_points erhöht innings_list[0] und persistiert" do
      tm = build_table_monitor(state: "playing", innings: {a: [5], b: [3]})

      tm.increment_inning_points(0, "playera")

      assert_equal 6, tm.reload.data["playera"]["innings_list"][0]
    end

    test "characterizes: decrement_inning_points hat Floor 0 und persistiert" do
      tm = build_table_monitor(state: "playing", innings: {a: [0], b: [0]})

      tm.decrement_inning_points(0, "playera")

      assert_equal 0, tm.reload.data["playera"]["innings_list"][0]
    end

    test "characterizes: update_innings_history liefert success und persistiert result" do
      tm = build_table_monitor(state: "playing", innings: {a: [4], b: [2]})

      result = tm.update_innings_history("playera" => [9], "playerb" => [2])

      assert_equal true, result[:success]
      assert_equal 9, tm.reload.data["playera"]["result"]
    end

    test "characterizes: delete_inning entfernt eine 0:0-Zeile und persistiert" do
      tm = build_table_monitor(state: "playing", innings: {a: [0, 5], b: [0, 3]})

      result = tm.delete_inning(0)

      assert_equal true, result[:success]
      assert_equal [5], tm.reload.data["playera"]["innings_list"]
      assert_equal [3], tm.data["playerb"]["innings_list"]
    end

    test "characterizes: delete_inning weist eine Nicht-0:0-Zeile ab, ohne zu persistieren" do
      tm = build_table_monitor(state: "playing", innings: {a: [5, 3], b: [2, 4]})
      before = snapshot(tm)

      result = tm.delete_inning(0)

      assert_equal false, result[:success]
      assert_match(/0:0/, result[:error])
      assert_equal before, tm.reload.data
    end

    # ---------------------------------------------------------------------------
    # rescue in :playing (Engine wirft) — Fehler-Kontrakt bzw. geschluckter Fehler
    # ---------------------------------------------------------------------------

    test "characterizes: update_innings_history fängt Engine-Fehler als {success:false, error:/boom/}" do
      tm = build_table_monitor(state: "playing", innings: {a: [1], b: [1]})

      result = with_raising_score_engine(tm) { |t| t.update_innings_history("playera" => [2], "playerb" => [1]) }

      assert_equal false, result[:success]
      assert_match(/boom/, result[:error])
    end

    test "characterizes: delete_inning fängt Engine-Fehler als {success:false, error:/boom/}" do
      tm = build_table_monitor(state: "playing", innings: {a: [0], b: [0]})

      result = with_raising_score_engine(tm) { |t| t.delete_inning(0) }

      assert_equal false, result[:success]
      assert_match(/boom/, result[:error])
    end

    test "characterizes: increment_inning_points schluckt Engine-Fehler in :playing (kein Raise, keine Persistenz)" do
      tm = build_table_monitor(state: "playing", innings: {a: [5], b: [3]})
      before = snapshot(tm)

      with_raising_score_engine(tm) do |t|
        assert_nothing_raised { t.increment_inning_points(0, "playera") }
      end

      assert_equal before, tm.reload.data
    end
  end
end
