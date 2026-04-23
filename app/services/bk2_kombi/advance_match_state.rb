# frozen_string_literal: true

module Bk2Kombi
  # Wendet einen BK2-Kombi-Stoß auf TableMonitor.data['bk2_state'] an.
  #
  # Delegiert die reine Auswertung an Bk2Kombi::ScoreShot und persistiert das Ergebnis.
  # Schließt den Satz wenn ein Spieler set_target_points erreicht.
  # Schließt das Match wenn ein Spieler 2 Sätze gewinnt (Best-of-3).
  #
  # Idempotenz-Guard (T-38.1-13): Wenn shot_payload[:shot_sequence_number] gesetzt ist,
  # wird ein bereits verarbeiteter Stoß als No-Op zurückgegeben.
  #
  # Verwendung:
  #   Bk2Kombi::AdvanceMatchState.call(table_monitor: tm, shot_payload: payload)
  class AdvanceMatchState
    DEFAULT_SET_TARGET = 50

    def self.call(table_monitor:, shot_payload:)
      new(table_monitor: table_monitor, shot_payload: shot_payload).call
    end

    def initialize(table_monitor:, shot_payload:)
      @tm = table_monitor
      @shot_payload = shot_payload
    end

    def call
      init_state_if_missing!
      return idempotency_noop if already_applied?

      state = @tm.data["bk2_state"].deep_dup

      result = Bk2Kombi::ScoreShot.call(
        shot_payload: @shot_payload,
        state: state
      )

      apply_scoring!(state, result[:scoring])
      apply_transitions!(state, result[:transitions])
      close_set_if_reached!(state)
      close_match_if_reached!(state)
      record_sequence!(state) if sequence_number

      @tm.data["bk2_state"] = state
      @tm.save!

      {scoring: result[:scoring], transitions: result[:transitions], state: state}
    end

    private

    # Initialisiere bk2_state falls noch nicht vorhanden (z.B. frischer TableMonitor).
    def init_state_if_missing!
      return if @tm.data["bk2_state"].is_a?(Hash)

      @tm.data["bk2_state"] = {
        "current_set_number" => 1,
        "current_phase" => "direkter_zweikampf",
        "player_at_table" => @tm.data["current_kickoff_player"].presence || "playera",
        "shots_left_in_turn" => 2,
        "set_scores" => {
          "1" => {"playera" => 0, "playerb" => 0},
          "2" => {"playera" => 0, "playerb" => 0},
          "3" => {"playera" => 0, "playerb" => 0}
        },
        "sets_won" => {"playera" => 0, "playerb" => 0},
        "set_target_points" => derive_set_target
      }
    end

    # Lese set_target_points aus bk2_options (Plan 04) oder verwende Default 50.
    def derive_set_target
      (@tm.data.dig("bk2_options", "set_target_points") || DEFAULT_SET_TARGET).to_i
    end

    # Trage Punkte in den aktuellen Satz ein.
    def apply_scoring!(state, scoring)
      set_no = state["current_set_number"].to_s
      current = state["player_at_table"]
      opponent = (current == "playera") ? "playerb" : "playera"

      state["set_scores"][set_no][current] += scoring[:points_for_current_player].to_i
      state["set_scores"][set_no][opponent] += scoring[:points_for_opponent].to_i
    end

    # Aktualisiere Spieler am Tisch und verbleibende Schüsse.
    def apply_transitions!(state, transitions)
      state["player_at_table"] = transitions[:next_player_at_table].to_s
      state["shots_left_in_turn"] = transitions[:next_shots_left_in_turn]
    end

    # Schließe den aktuellen Satz wenn ein Spieler set_target_points erreicht hat.
    def close_set_if_reached!(state)
      set_no = state["current_set_number"].to_s
      target = state["set_target_points"].to_i
      a = state["set_scores"][set_no]["playera"]
      b = state["set_scores"][set_no]["playerb"]
      return unless a >= target || b >= target

      winner = (a >= target) ? "playera" : "playerb"
      state["sets_won"][winner] += 1
      state["set_finished_#{set_no}"] = true
      state["set_winner_#{set_no}"] = winner

      # Nicht über Satz 3 hinausgehen (Match endet dann in close_match_if_reached!).
      return if state["current_set_number"] >= 3

      state["current_set_number"] += 1
      state["current_phase"] = "direkter_zweikampf"
      state["shots_left_in_turn"] = 2
      # Anstoß-Alternation: neuer Satz beginnt mit dem anderen Spieler.
      state["player_at_table"] = (winner == "playera") ? "playerb" : "playera"
    end

    # Schließe das Match wenn ein Spieler 2 Sätze gewonnen hat.
    def close_match_if_reached!(state)
      return if state["match_finished"]

      if state["sets_won"]["playera"] >= 2
        state["match_finished"] = true
        state["match_winner"] = "playera"
      elsif state["sets_won"]["playerb"] >= 2
        state["match_finished"] = true
        state["match_winner"] = "playerb"
      end
    end

    # Prüfe ob dieser Stoß bereits verarbeitet wurde (Idempotenz-Guard T-38.1-13).
    def already_applied?
      seq = sequence_number
      return false if seq.nil?
      (@tm.data["bk2_state"]["applied_shot_sequences"] || []).include?(seq)
    end

    # Registriere die Sequenznummer als verarbeitet.
    def record_sequence!(state)
      state["applied_shot_sequences"] ||= []
      state["applied_shot_sequences"] << sequence_number
    end

    # Gib No-Op-Ergebnis zurück (Stoß bereits verarbeitet).
    def idempotency_noop
      {scoring: nil, transitions: nil, state: @tm.data["bk2_state"], idempotent_noop: true}
    end

    # Sequenznummer aus dem Stoß-Payload (optional; nil wenn nicht gesetzt).
    def sequence_number
      @shot_payload[:shot_sequence_number] || @shot_payload["shot_sequence_number"]
    end
  end
end
