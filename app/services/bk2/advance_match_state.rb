# frozen_string_literal: true

module Bk2
  # BK-Familie bk2_state-Initialisierung. Speichert die Spiel-Konfiguration
  # (first_set_mode, balls_goal, dz/sp-Limits) als Read-Only-Konfig für die
  # Views (Phase-Chip-Anzeige, Satz-Ziel). Ist KEINE Runtime-State-Maschine
  # mehr — Multiset, Anstoß-Wechsel, Set-Close laufen über die legacy-
  # karambol-Pfade. BK-spezifische Regeln (Nachstoß-Gate, Negativwert-
  # Routing, Phase-Switching) sind als Guards in TableMonitor#follow_up?,
  # TableMonitor#end_of_set?, TableMonitor#bk2_kombi_current_phase und
  # TableMonitor::ScoreEngine eingehängt.
  #
  # Verwendung:
  #   Bk2::AdvanceMatchState.initialize_bk2_state!(table_monitor)
  class AdvanceMatchState
    DEFAULT_SET_TARGET = 50
    DEFAULT_DZ_MAX_SHOTS_PER_TURN = 2
    DEFAULT_SP_MAX_INNINGS_PER_SET = 5
    DEFAULT_FIRST_SET_MODE = "direkter_zweikampf"

    # Phase 38.3-08 I6: public init entry-point for the shootout → playing transition.
    # Called from TableMonitorReflex#start_game, #switch_players_and_start_game, and
    # #key_d. Idempotent — no-op when bk2_state already exists.
    def self.initialize_bk2_state!(table_monitor)
      new(table_monitor: table_monitor).send(:init_state_if_missing!)
      table_monitor.save!
      table_monitor.data["bk2_state"]
    end

    # Phase 38.5 D-03 — bake-hook 2: set-boundary re-bake.
    #
    # Called from TableMonitor::ResultRecorder#perform_switch_to_next_set when
    # a new set opens for a BK-2kombi match. Re-resolves effective_discipline
    # (DZ <-> SP per multiset_components) and the two BK params
    # (allow_negative_score_input, negative_credits_opponent) into
    # table_monitor.data.
    #
    # Why this method lives in Bk2:: namespace (research finding 3): the actual
    # set-open file path is ResultRecorder, but D-03's mental model places BK
    # lifecycle under Bk2::. This thin orchestration delegate satisfies both:
    # callers see the Bk2 namespace; ResultRecorder remains the actual hook site.
    #
    # Idempotent: re-running on the same TableMonitor produces the same data values.
    # Does NOT save — caller (ResultRecorder) saves once after merging other state.
    def self.rebake_at_set_open!(table_monitor)
      BkParamResolver.bake!(table_monitor)
    end

    def initialize(table_monitor:)
      @tm = table_monitor
    end

    private

    # Initialisiere bk2_state falls noch nicht vorhanden. Liest first_set_mode,
    # balls_goal, dz/sp-Limits aus bk2_options und seeded den State-Hash.
    def init_state_if_missing!
      return if @tm.data["bk2_state"].is_a?(Hash)

      first_mode = derive_first_set_mode
      initial_phase = phase_for_set(1, first_mode)
      dz_max = derive_dz_max_shots
      sp_max = derive_sp_max_innings
      balls_goal_val = derive_balls_goal

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
        "balls_goal" => balls_goal_val,
        "set_target_points" => balls_goal_val
      }
    end

    def derive_balls_goal
      tm_balls_goal = @tm.tournament_monitor&.balls_goal.to_i
      return tm_balls_goal if tm_balls_goal.positive?

      opts_balls_goal = (@tm.data.dig("bk2_options", "balls_goal") || 0).to_i
      return opts_balls_goal if opts_balls_goal.positive?

      DEFAULT_SET_TARGET
    end

    def derive_dz_max_shots
      (@tm.data.dig("bk2_options", "direkter_zweikampf_max_shots_per_turn") || DEFAULT_DZ_MAX_SHOTS_PER_TURN).to_i
    end

    def derive_sp_max_innings
      (@tm.data.dig("bk2_options", "serienspiel_max_innings_per_set") || DEFAULT_SP_MAX_INNINGS_PER_SET).to_i
    end

    def derive_first_set_mode
      mode = @tm.data.dig("bk2_options", "first_set_mode").to_s
      %w[direkter_zweikampf serienspiel].include?(mode) ? mode : DEFAULT_FIRST_SET_MODE
    end

    # Satz 1 = first_set_mode; Satz 2 = flipped; Satz 3 = first_set_mode.
    def phase_for_set(set_number, first_set_mode)
      return first_set_mode if set_number.to_i == 1 || set_number.to_i == 3
      (first_set_mode == "direkter_zweikampf") ? "serienspiel" : "direkter_zweikampf"
    end
  end
end
