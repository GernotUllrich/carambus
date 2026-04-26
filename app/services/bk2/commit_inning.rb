# frozen_string_literal: true

module Bk2
  # Wendet eine ganze Aufnahme auf TableMonitor.data['bk2_state'] an (Variante B Point-Entry).
  #
  # Phase 38.3 D-21 / Phase 38.4 I7 D-10/D-11. Einheitlicher Einstiegspunkt für alle
  # BK-*-Disziplinen. Dispatcher verzweigt intern nach discipline.data[:free_game_form]:
  #
  # - bk_2plus             → Gegner-Kredit-Regel: negatives inning_total → |abs| zum Gegner.
  # - bk_2 / bk50 / bk100 → Additive Regel: inning_total vorzeichenbehaftet zum eigenen Score.
  # - bk2_kombi            → Phasenabhängig: direkter_zweikampf = Gegner-Kredit; serienspiel = Additiv.
  # - unbekannt            → ArgumentError (kein stilles Fehlrouting — T-38.4-05-01).
  #
  # Idempotenz: optionale shot_sequence_number, gespeichert in bk2_state['applied_commit_sequences'].
  #
  # Verwendung:
  #   Bk2::CommitInning.call(table_monitor: tm, player: "playera", inning_total: 7)
  class CommitInning
    INNING_TOTAL_MIN = -999
    INNING_TOTAL_MAX = 999
    VALID_PLAYERS = %w[playera playerb].freeze

    def self.call(table_monitor:, player:, inning_total:, shot_sequence_number: nil)
      new(
        table_monitor: table_monitor,
        player: player,
        inning_total: inning_total,
        shot_sequence_number: shot_sequence_number
      ).call
    end

    def initialize(table_monitor:, player:, inning_total:, shot_sequence_number: nil)
      validate!(player: player, inning_total: inning_total)
      @tm = table_monitor
      @player = player
      @inning_total = inning_total
      @shot_sequence_number = shot_sequence_number
    end

    def call
      ensure_initialized!
      return idempotency_noop if already_applied?

      state = @tm.data["bk2_state"].deep_dup

      transitions = apply_inning!(state)

      # Phase 38.4 R5-1 step 1b-i: commit the inning karambolisch so data.result /
      # innings_list reflect the score (single source of truth at the call boundary).
      # Replaces the per-caller karambol_commit_inning! that lived in the reflex and
      # TableMonitor#route_goal_reached_through_bk2_commit_inning.
      @tm.karambol_commit_inning!(@player)

      # Phase 38.3 D-21: reuse AdvanceMatchState set-close / match-close paths
      # via Pattern A delegation (private method access via send).
      advance_helper = Bk2::AdvanceMatchState.new(
        table_monitor: @tm,
        shot_payload: {}
      )
      advance_helper.send(:close_set_if_reached!, state)
      advance_helper.send(:close_match_if_reached!, state)
      record_sequence!(state) if @shot_sequence_number

      @tm.data["bk2_state"] = state
      @tm.save!

      {state: state, transitions: transitions}
    end

    private

    def validate!(player:, inning_total:)
      unless VALID_PLAYERS.include?(player)
        raise ArgumentError, "player must be one of #{VALID_PLAYERS.inspect}, got #{player.inspect}"
      end
      unless inning_total.is_a?(Integer)
        raise ArgumentError, "inning_total must be Integer, got #{inning_total.class}"
      end
      unless (INNING_TOTAL_MIN..INNING_TOTAL_MAX).cover?(inning_total)
        raise ArgumentError, "inning_total out of range #{INNING_TOTAL_MIN}..#{INNING_TOTAL_MAX}: #{inning_total}"
      end
    end

    # Stelle sicher dass bk2_state initialisiert ist.
    # Delegiert an AdvanceMatchState#init_state_if_missing! als Single Source of Truth.
    def ensure_initialized!
      return if @tm.data["bk2_state"].is_a?(Hash) && @tm.data["bk2_state"].any?

      # init_state_if_missing! mutiert @tm.data direkt (in memory auf demselben Objekt).
      Bk2::AdvanceMatchState.new(
        table_monitor: @tm,
        shot_payload: {}
      ).send(:init_state_if_missing!)
    end

    # Phase 38.4 I7 D-10/D-11: BK-Familie-Dispatcher — verzweigt nach free_game_form.
    def apply_inning!(state)
      form = free_game_form
      case form
      when "bk_2plus"
        apply_opponent_credit_rule(state)
      when "bk_2", "bk50", "bk100"
        apply_additive_rule(state)
      when "bk2_kombi"
        apply_bk2_kombi_rule(state)
      else
        raise ArgumentError, "Unknown free_game_form: #{form.inspect} for Bk2::CommitInning"
      end
    end

    # Lese free_game_form aus discipline.data (bevorzugt) oder TableMonitor.data (Fallback).
    #
    # Phase 38.4-14 P4 (round-4 iteration-2 — Option B): TableMonitor#discipline can return
    # either an AR Discipline record OR a String (the production contract — see
    # TableMonitor#discipline:608, which returns data["playera"]["discipline"] String for
    # 15+ legacy callers). When it returns a String, look up the AR record by name. When
    # it returns nil or an unrecognized type, fall through to the @tm.data Hash fallback.
    # This keeps Plan 14's Option B dispatch path working in production wiring (no
    # define_singleton_method stub) while preserving the legacy String contract.
    def free_game_form
      discipline = @tm.discipline
      discipline = Discipline.find_by(name: discipline) if discipline.is_a?(String)
      if discipline.respond_to?(:data) && discipline.data.present?
        parsed = begin
          JSON.parse(discipline.data)
        rescue JSON::ParserError
          {}
        end
        form = parsed["free_game_form"]
        return form if form.present?
      end
      # Fallback: free_game_form direkt in TableMonitor.data (quick-game path)
      @tm.data.is_a?(Hash) ? @tm.data["free_game_form"] : nil
    end

    # BK-2plus + DZ-Phase von BK-2kombi: negatives inning_total → |abs| zum Gegner.
    # Positives inning_total → zum eigenen Score.
    def apply_opponent_credit_rule(state)
      set_no = state["current_set_number"].to_s
      opponent = (@player == "playera") ? "playerb" : "playera"

      if @inning_total >= 0
        state["set_scores"][set_no][@player] += @inning_total
      else
        # D-10: negatives inning_total → abs-Wert als Kredit an den Gegner.
        state["set_scores"][set_no][opponent] += @inning_total.abs
      end

      # Aufnahmewechsel: shots_left_in_turn aus bk2_options lesen (mit Default-Fallback).
      dz_max = (@tm.data.dig("bk2_options", "direkter_zweikampf_max_shots_per_turn") ||
        Bk2::AdvanceMatchState::DEFAULT_DZ_MAX_SHOTS_PER_TURN).to_i
      state["shots_left_in_turn"] = dz_max

      # Aufnahmewechsel — immer nach einem CommitInning den Spieler wechseln.
      state["player_at_table"] = opponent
      {next_player_at_table: opponent, phase_applied: "opponent_credit"}
    end

    # BK-2 / BK50 / BK100 / SP-Phase von BK-2kombi: vorzeichenbehaftet zum eigenen Score.
    # Negative inning_total bleiben beim Spieler (kein Gegner-Kredit) — D-12.
    def apply_additive_rule(state)
      set_no = state["current_set_number"].to_s
      opponent = (@player == "playera") ? "playerb" : "playera"

      # D-12: inning_total MIT Vorzeichen zum eigenen Score (darf negativ werden).
      state["set_scores"][set_no][@player] += @inning_total

      # Aufnahmewechsel: innings_left_in_set dekrementieren.
      current = state["innings_left_in_set"].to_i
      state["innings_left_in_set"] = [current - 1, 0].max

      # Aufnahmewechsel — immer nach einem CommitInning den Spieler wechseln.
      state["player_at_table"] = opponent
      {next_player_at_table: opponent, phase_applied: "additive"}
    end

    # BK-2kombi: phasenabhängige Regelauswahl.
    # direkter_zweikampf = Gegner-Kredit-Regel; serienspiel = Additive Regel.
    def apply_bk2_kombi_rule(state)
      phase = state["current_phase"].to_s
      case phase
      when "direkter_zweikampf"
        apply_opponent_credit_rule(state)
      when "serienspiel"
        apply_additive_rule(state)
      else
        raise ArgumentError, "Unknown bk2_kombi current_phase: #{phase.inspect}"
      end
    end

    def already_applied?
      return false if @shot_sequence_number.nil?

      (@tm.data["bk2_state"]["applied_commit_sequences"] || []).include?(@shot_sequence_number)
    end

    def record_sequence!(state)
      state["applied_commit_sequences"] ||= []
      state["applied_commit_sequences"] << @shot_sequence_number
    end

    def idempotency_noop
      {state: @tm.data["bk2_state"], transitions: nil, idempotent_noop: true}
    end
  end
end
