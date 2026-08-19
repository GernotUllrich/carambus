# frozen_string_literal: true

require "test_helper"

# Regression: der Nachstoss geht durch ein nachlaufendes Tasten-Event verloren.
#
# Befund (Handoff carambus_app, 2026-08-19, Turnier bc-wedel):
# Die Scoreboard-Tasten sind POSITIONS-, nicht spielerbasiert. `key_a` heisst
# "linke Taste": ist der aktive Spieler links, bedeutet sie "Punkt", ist er
# rechts, bedeutet sie "Aufnahme beenden".
#
# Erreicht der Anstoss-Spieler sein balls_goal, meldet add_n_balls :goal_reached,
# terminate_current_inning schliesst seine Aufnahme und schaltet automatisch auf
# den Gegner um. Ein DANACH eintreffendes `key_a` (Doppelzustellung Touch+Click,
# im production.log 3 ms Abstand belegt) findet nun den rechten Spieler aktiv vor
# und wird als "Aufnahme beenden" ausgefuehrt -> der Nachstoss-Spieler bekommt
# 0 Punkte und 1 Aufnahme angerechnet, ohne gestossen zu haben. Damit ist die
# Paritaetsbedingung in end_of_set? erfuellt (innings gleich) und der Satz
# schliesst mit 15:0 — der Ausgleichsstoss faellt lautlos aus.
#
# Test-Pattern: echter Reflex ueber .allocate, aber — anders als im
# table_monitor_reflex_test — OHNE Stubs auf der Score-Logik. TableMonitor.find
# liefert pro Event eine FRISCHE Instanz, exakt wie im Live-Reflex; auf einer
# festgehaltenen Instanz haelt der memoisierte score_engine eine veraltete
# data-Referenz und der Fehler tritt gar nicht erst auf.
class TableMonitorNachstossRaceTest < ActiveSupport::TestCase
  BALLS_GOAL = 15
  INNINGS_GOAL = 15

  setup do
    @tm = TableMonitor.create!(state: "playing", data: nachstoss_data)
    @reflex = TableMonitorReflex.allocate
    @reflex.define_singleton_method(:morph) { |_target| nil }
    @reflex.define_singleton_method(:element) { OpenStruct.new(dataset: {id: 1}) }
  end

  # Ein Tastendruck auf die LINKE Taste, mit frischem find je Event (wie live).
  def press_key_a
    tm_id = @tm.id
    TableMonitor.stub(:find, ->(_id) { TableMonitor.where(id: tm_id).first }) do
      @reflex.key_a
    end
    @tm.reload
  end

  test "nach 15 Punkten des Anstoss-Spielers steht der Nachstoss (Vorbedingung)" do
    BALLS_GOAL.times { press_key_a }

    assert_equal "playing", @tm.state, "Satz darf nach dem Ballziel des Anstoss-Spielers NICHT enden"
    assert_equal "playerb", @tm.data.dig("current_inning", "active_player"),
      "nach :goal_reached muss automatisch auf den Nachstoss-Spieler umgeschaltet sein"
    assert_equal BALLS_GOAL, @tm.data.dig("playera", "result").to_i
    assert_equal 1, @tm.data.dig("playera", "innings").to_i
    assert_equal 0, @tm.data.dig("playerb", "innings").to_i, "Nachstoss-Spieler hat noch keine Aufnahme"
    assert @tm.follow_up?, "follow_up? muss den Nachstoss erkennen"
    refute @tm.end_of_set?, "end_of_set? darf hier noch nicht true sein"
  end

  test "ein nachlaufendes key_a darf den Nachstoss nicht in eine leere Aufnahme umdeuten" do
    BALLS_GOAL.times { press_key_a }

    # EIN nachlaufendes Event (Doppelzustellung), abgeschickt gegen den Zustand
    # VOR dem automatischen Spielerwechsel.
    press_key_a

    assert_equal 0, @tm.data.dig("playerb", "innings").to_i,
      "dem Nachstoss-Spieler darf keine Aufnahme angerechnet werden, die er nie gespielt hat"
    assert_equal [], Array(@tm.data.dig("playerb", "innings_list")),
      "innings_list des Nachstoss-Spielers muss leer bleiben"
    assert_equal "playerb", @tm.data.dig("current_inning", "active_player"),
      "der Nachstoss-Spieler muss am Tisch bleiben"
    assert_equal "playing", @tm.state,
      "der Satz darf nicht durch ein nachlaufendes Event geschlossen werden"
  end

  test "nach Ablauf der Schonfrist beendet key_a die Nachstoss-Aufnahme regulaer" do
    BALLS_GOAL.times { press_key_a }

    # Regulaerer Ablauf: der Nachstoss-Spieler stoesst, verfehlt, der Bediener
    # beendet seine Aufnahme — deutlich spaeter als die Schonfrist.
    travel TableMonitor::AUTO_SWITCH_GRACE + 1.second do
      press_key_a
    end

    assert_equal 1, @tm.data.dig("playerb", "innings").to_i,
      "regulaeres Beenden der Nachstoss-Aufnahme muss weiterhin funktionieren"
    assert_equal "set_over", @tm.state, "danach ist der Satz reguelaer vorbei (Ausgleich verfehlt)"
  end

  test "der Guard blockiert nur den automatischen Wechsel, nicht normale Aufnahmewechsel" do
    # Normaler Spielverlauf ohne Ballziel-Erreichen: der Bediener beendet die
    # Aufnahme von A per rechter Taste und sofort danach die von B per linker
    # Taste — schnelles Durchklicken leerer Aufnahmen muss unberuehrt bleiben.
    press_key_b # A ist links aktiv -> rechte Taste beendet A's Aufnahme
    @tm.reload
    assert_equal 1, @tm.data.dig("playera", "innings").to_i
    assert_equal "playerb", @tm.data.dig("current_inning", "active_player")

    press_key_a # B ist rechts aktiv -> linke Taste beendet B's Aufnahme
    assert_equal 1, @tm.data.dig("playerb", "innings").to_i,
      "ein normaler, benutzerausgeloester Aufnahmewechsel darf nicht verworfen werden"
  end

  private

  def press_key_b
    tm_id = @tm.id
    TableMonitor.stub(:find, ->(_id) { TableMonitor.where(id: tm_id).first }) do
      @reflex.key_b
    end
    @tm.reload
  end

  # Zustand direkt nach start_game: Round-Robin, Dreiband gross, 15 Punkte in
  # 15 Aufnahmen, Anstoss-Spieler A steht links.
  def nachstoss_data
    {
      "free_game_form" => "karambol",
      "allow_follow_up" => true,
      "allow_overflow" => false,
      "innings_goal" => INNINGS_GOAL.to_s,
      "current_kickoff_player" => "playera",
      "current_left_player" => "playera",
      "current_left_color" => "white",
      "fixed_display_left" => nil,
      "current_inning" => {"active_player" => "playera", "balls" => 0},
      "balls_on_table" => 0,
      "balls_counter" => 0,
      "balls_counter_stack" => [],
      "extra_balls" => 0,
      "timeouts" => 0,
      "timeout" => 0,
      "playera" => player_hash,
      "playerb" => player_hash
    }
  end

  def player_hash
    {
      "result" => 0,
      "innings" => 0,
      "innings_list" => [],
      "innings_redo_list" => [0],
      "innings_foul_list" => [],
      "innings_foul_redo_list" => [0],
      "hs" => 0,
      "gd" => 0.0,
      "tc" => 0,
      "fouls_1" => 0,
      "balls_goal" => BALLS_GOAL.to_s,
      "discipline" => "Dreiband gross"
    }
  end
end
