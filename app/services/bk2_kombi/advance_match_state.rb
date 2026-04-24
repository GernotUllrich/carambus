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
    # Phase 38.2 D-12 / D-20: rule limits driven by bk2_options; these are the
    # fallback defaults when a TableMonitor was persisted before Phase 38.2
    # (legacy bk2_options without the new keys) or when the keys are blank.
    DEFAULT_DZ_MAX_SHOTS_PER_TURN = 2
    DEFAULT_SP_MAX_INNINGS_PER_SET = 5
    DEFAULT_FIRST_SET_MODE = "direkter_zweikampf"

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
    # Phase 38.2 D-19/D-20: first_set_mode, shots/innings-Limits aus bk2_options lesen.
    def init_state_if_missing!
      return if @tm.data["bk2_state"].is_a?(Hash)

      first_mode = derive_first_set_mode
      initial_phase = phase_for_set(1, first_mode)
      dz_max = derive_dz_max_shots
      sp_max = derive_sp_max_innings

      @tm.data["bk2_state"] = {
        "current_set_number" => 1,
        "current_phase" => initial_phase,
        "first_set_mode" => first_mode,
        "player_at_table" => @tm.data["current_kickoff_player"].presence || "playera",
        "shots_left_in_turn" => (initial_phase == "direkter_zweikampf") ? dz_max : 0,
        "innings_left_in_set" => (initial_phase == "serienspiel") ? sp_max : 0,
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

    # Phase 38.2 D-20: max Stösse pro Aufnahme im Direkten Zweikampf.
    def derive_dz_max_shots
      (@tm.data.dig("bk2_options", "direkter_zweikampf_max_shots_per_turn") || DEFAULT_DZ_MAX_SHOTS_PER_TURN).to_i
    end

    # Phase 38.2 D-20: max Aufnahmen pro Satz im Serienspiel.
    def derive_sp_max_innings
      (@tm.data.dig("bk2_options", "serienspiel_max_innings_per_set") || DEFAULT_SP_MAX_INNINGS_PER_SET).to_i
    end

    # Phase 38.2 D-14 / D-20: erster Satz-Modus, whitelisted.
    def derive_first_set_mode
      mode = @tm.data.dig("bk2_options", "first_set_mode").to_s
      %w[direkter_zweikampf serienspiel].include?(mode) ? mode : DEFAULT_FIRST_SET_MODE
    end

    # Phase 38.2 D-14: Satz-Modus-Alternation.
    # Satz 1 = first_set_mode; Satz 2 = flipped; Satz 3 = first_set_mode.
    def phase_for_set(set_number, first_set_mode)
      return first_set_mode if set_number.to_i == 1 || set_number.to_i == 3
      (first_set_mode == "direkter_zweikampf") ? "serienspiel" : "direkter_zweikampf"
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
    # Phase 38.2 D-11/D-19: shots_left_in_turn wird NUR im Direkten Zweikampf
    # geschrieben (ScoreShot gibt dort nil in Serienspiel zurueck). In Serienspiel
    # dekrementiert stattdessen innings_left_in_set bei Aufnahmewechsel (turn_ends).
    def apply_transitions!(state, transitions)
      state["player_at_table"] = transitions[:next_player_at_table].to_s
      if state["current_phase"] == "direkter_zweikampf"
        state["shots_left_in_turn"] = transitions[:next_shots_left_in_turn]
      end

      if state["current_phase"] == "serienspiel" && transitions[:turn_ends]
        current = state["innings_left_in_set"].to_i
        state["innings_left_in_set"] = [current - 1, 0].max
      end
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
      # Phase 38.2 D-14: Phasenalternation Satz 1 → Satz 2 (flipped), Satz 2 → Satz 3 (back to first_set_mode).
      first_mode = state["first_set_mode"].presence || derive_first_set_mode
      new_phase = phase_for_set(state["current_set_number"], first_mode)
      state["current_phase"] = new_phase

      if new_phase == "direkter_zweikampf"
        state["shots_left_in_turn"] = derive_dz_max_shots
        state["innings_left_in_set"] = 0
      else # serienspiel
        state["shots_left_in_turn"] = 0
        state["innings_left_in_set"] = derive_sp_max_innings
      end

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
