# frozen_string_literal: true

module Bk2Kombi
  # Wendet eine ganze Aufnahme auf TableMonitor.data['bk2_state'] an (Variante B Point-Entry).
  #
  # Phase 38.3 D-21. Ersetzt den event-basierten live-Pfad (Bk2Kombi::ScoreShot + AdvanceMatchState).
  # ScoreShot bleibt als dormant code für eine spätere Variante-A-Wiederbelebung im Repository.
  #
  # Scoring per Phase (Plan 38.3 D-11 / D-12):
  # - direkter_zweikampf: negatives inning_total -> abs zum Gegner; positives zum eigenen Score.
  # - serienspiel:        inning_total MIT Vorzeichen zum eigenen Score (darf negativ werden).
  #
  # Idempotency: optional shot_sequence_number, gespeichert in bk2_state['applied_commit_sequences'].
  #
  # Verwendung:
  #   Bk2Kombi::CommitInning.call(table_monitor: tm, player: "playera", inning_total: 7)
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

      # Phase 38.3 D-21: reuse AdvanceMatchState set-close / match-close paths
      # via Pattern A delegation (private method access via send).
      advance_helper = Bk2Kombi::AdvanceMatchState.new(
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
      Bk2Kombi::AdvanceMatchState.new(
        table_monitor: @tm,
        shot_payload: {}
      ).send(:init_state_if_missing!)
    end

    def apply_inning!(state)
      set_no = state["current_set_number"].to_s
      opponent = (@player == "playera") ? "playerb" : "playera"
      phase = state["current_phase"].to_s

      if phase == "direkter_zweikampf"
        if @inning_total >= 0
          state["set_scores"][set_no][@player] += @inning_total
        else
          # D-11: negatives inning_total -> abs zum Gegner
          state["set_scores"][set_no][opponent] += @inning_total.abs
        end
        # Aufnahmewechsel: shots_left_in_turn aus bk2_options lesen (mit Default-Fallback).
        dz_max = (@tm.data.dig("bk2_options", "direkter_zweikampf_max_shots_per_turn") ||
          Bk2Kombi::AdvanceMatchState::DEFAULT_DZ_MAX_SHOTS_PER_TURN).to_i
        state["shots_left_in_turn"] = dz_max
      elsif phase == "serienspiel"
        # D-12: inning_total MIT Vorzeichen zum eigenen Score (darf negativ werden).
        state["set_scores"][set_no][@player] += @inning_total
        # Aufnahmewechsel: innings_left_in_set dekrementieren.
        current = state["innings_left_in_set"].to_i
        state["innings_left_in_set"] = [current - 1, 0].max
      else
        raise ArgumentError, "unknown current_phase: #{phase.inspect}"
      end

      # Aufnahmewechsel — immer nach einem CommitInning den Spieler wechseln.
      state["player_at_table"] = opponent

      {next_player_at_table: opponent, phase_applied: phase}
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
