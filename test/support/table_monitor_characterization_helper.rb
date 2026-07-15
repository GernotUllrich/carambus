# frozen_string_literal: true

# Characterization-Harness (Phase 13) — reiner Builder, wiederverwendbar für Phasen 14/15/16.
#
# Konstruiert realistische TableMonitor-Zustände je Disziplin/State, damit Characterization-Tests
# das IST-Verhalten der Extraktions-Cluster (Innings-History, Modals, State-Glue) pinnen können,
# BEVOR die Methoden in Phase 14/15/16 in Kollaboratoren wandern.
#
# WICHTIG: enthält KEINE Assertions und baut die ScoreEngine-Logik NICHT nach — nur Zustände.
module TableMonitorCharacterizationHelper
  def build_table_monitor(discipline: :karambol, state: "playing", innings: nil, with_game: false, **data_overrides)
    data = default_tm_data(discipline)

    if innings
      data["playera"]["innings_list"] = Array(innings[:a])
      data["playerb"]["innings_list"] = Array(innings[:b])
      data["playera"]["innings"] = Array(innings[:a]).length
      data["playerb"]["innings"] = Array(innings[:b]).length
    end

    data_overrides.each { |k, v| data[k.to_s] = v }

    tm = TableMonitor.create!(state: state, data: data)
    attach_characterization_game(tm) if with_game
    tm
  end

  # Ersetzt tm.score_engine testlokal durch ein Objekt, dessen Aufrufe StandardError werfen (AC-4).
  def with_raising_score_engine(tm)
    raising = RaisingScoreEngine.new
    tm.define_singleton_method(:score_engine) { raising }
    yield tm
  end

  class RaisingScoreEngine
    def respond_to_missing?(_name, _include_private = false) = true

    def method_missing(name, *_args, **_kwargs)
      raise StandardError, "boom(#{name})"
    end
  end

  private

  def default_tm_data(discipline)
    {
      "free_game_form" => free_game_form_for(discipline),
      "current_inning" => {"active_player" => "playerb", "balls" => 0},
      "playera" => base_player_hash(discipline),
      "playerb" => base_player_hash(discipline)
    }
  end

  def free_game_form_for(discipline)
    case discipline.to_sym
    when :snooker then "snooker"
    when :pool then "pool"
    else "free_game" # karambol
    end
  end

  def base_player_hash(discipline)
    {
      "result" => 0,
      "innings" => 0,
      "innings_list" => [],
      "innings_redo_list" => [0],
      "balls_goal" => 100,
      "discipline" => discipline.to_s
    }
  end

  def attach_characterization_game(table_monitor)
    game = Game.create!(data: {}, group_no: 1, seqno: 1, table_no: 1)
    game.game_participations.create!(role: "playera")
    game.game_participations.create!(role: "playerb")
    table_monitor.update!(game: game)
    game
  end
end
