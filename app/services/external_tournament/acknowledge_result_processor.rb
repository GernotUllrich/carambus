# frozen_string_literal: true

module ExternalTournament
  # Plan 17-04 (Vision J): App-driven Result-Hold + Pull — der Knackpunkt.
  #
  # Bei Spielende haelt der TableMonitor dank Phase-38.8-Operator-Gate bei
  # :final_match_score ("Endergebnis erfasst") mit befuelltem data["ba_results"]
  # (report_result schreibt es zusaetzlich nach game.data["ba_results"]). Der
  # Operator kann den Tisch NICHT freigeben (TableMonitor#external_result_pending?-
  # Guard auf :close_match/:start_rematch). Die App ruft das Ergebnis hier ab:
  #   1. Game per external_id im Turnier (region-scoped) finden.
  #   2. Hold-State pruefen (final_match_score) — sonst NotReadyError (→ 409).
  #   3. game.result_acknowledged_at setzen (Idempotenz: 2. Aufruf = no-op).
  #   4. Tisch freigeben: close_match! (jetzt erlaubt; Executor-Round-Cascade ist
  #      fuer manual_assignment ge-no-op't — TableMonitor#advance_tournament_round_if_present).
  #   5. Ergebnis im carambus.ack/v1-Format zurueckliefern.
  #
  # Single-Set-App-Spiele (StartGameProcessor-Default sets_to_play/win = 1) landen
  # in :final_match_score. Multi-Set-App-Spiele (Hold bei :final_set_score) sind in
  # diesem Slice noch nicht abgedeckt (→ Defer 17-04).
  class AcknowledgeResultProcessor
    Result = Struct.new(:tournament, :game, :table_monitor, :state, :acknowledged_at,
      :result, :already_acknowledged, keyword_init: true)

    class TournamentNotFoundError < StandardError; end

    class GameNotFoundError < StandardError
      attr_reader :identifier
      def initialize(identifier)
        @identifier = identifier
        super("Game not found: #{identifier}")
      end
    end

    class TableMonitorNotFoundError < StandardError
      attr_reader :identifier
      def initialize(identifier)
        @identifier = identifier
        super("TableMonitor not found for game #{identifier}")
      end
    end

    class NotReadyError < StandardError
      attr_reader :state
      def initialize(state)
        @state = state
        super("Result not ready (table_monitor state: #{state})")
      end
    end

    # States, in denen das App-Spielergebnis erfasst + abrufbar ist (Hold).
    HOLD_STATES = %w[final_match_score].freeze

    def initialize(region:, payload:)
      @region = region
      @payload = payload.is_a?(Hash) ? payload.deep_symbolize_keys : payload
    end

    def call
      tournament = resolve_tournament
      external_id = @payload.dig(:game, :external_id).to_s
      raise GameNotFoundError, "(missing game.external_id)" if external_id.blank?

      game = find_game(tournament, external_id)
      raise GameNotFoundError, external_id if game.blank?

      tm = game.table_monitor

      # Idempotenz ZUERST: bereits bestaetigt → Ergebnis erneut liefern, ohne
      # erneuten Release und unabhaengig vom aktuellen TM-State/-Linkage (ein
      # nachfolgendes start_game/Swap kann den TM bereits weiterbewegt haben).
      if game.result_acknowledged_at.present?
        return build_result(tournament, game, tm, already: true)
      end

      raise TableMonitorNotFoundError, external_id if tm.blank?
      raise NotReadyError, tm.state unless HOLD_STATES.include?(tm.state.to_s)

      game.update!(result_acknowledged_at: Time.current)
      tm.reload # damit der external_release_allowed?-Guard den frischen Wert sieht

      if tm.may_close_match?
        tm.close_match!
        tm.reload
      end

      build_result(tournament, game, tm, already: false)
    end

    private

    def build_result(tournament, game, tm, already:)
      Result.new(
        tournament: tournament,
        game: game,
        table_monitor: tm,
        state: tm&.state,
        acknowledged_at: game.result_acknowledged_at,
        result: extract_result(tm, game),
        already_acknowledged: already
      )
    end

    def resolve_tournament
      tournament =
        if @payload[:tournament_id].present?
          Tournament.find_by(id: @payload[:tournament_id], region_id: @region.id)
        elsif @payload.dig(:tournament, :external_id).present?
          Tournament.where(region_id: @region.id, external_id: @payload.dig(:tournament, :external_id)).first
        end
      raise TournamentNotFoundError, "tournament not found" if tournament.blank?
      tournament
    end

    # App-Games sind NUR ueber den gebundenen TableMonitor mit dem Turnier verknuepft
    # (GameSetup#create_new_game setzt KEIN tournament_id/tournament_type — nur tm.game_id).
    # Wir suchen daher ueber die an den TournamentMonitor gebundenen TableMonitors:
    # aktuelles Spiel (tm.game) + ggf. das vorige (tm.prev_game_id, nach Rematch/Swap).
    def find_game(tournament, external_id)
      owner = tournament.tournament_monitor
      return nil if owner.blank?
      bound = TableMonitor.where(tournament_monitor_id: owner.id, tournament_monitor_type: "TournamentMonitor")
      bound.each do |tm|
        g = tm.game
        return g if g.present? && safe_data(g)["external_id"].to_s == external_id
        if tm.prev_game_id.present?
          pg = Game.find_by(id: tm.prev_game_id)
          return pg if pg.present? && safe_data(pg)["external_id"].to_s == external_id
        end
      end
      nil
    end

    # carambus.ack/v1-result: bevorzugt das persistente Game-Ergebnis
    # (game.data["ba_results"] + tmp_results.sets, von report_result geschrieben),
    # Fallback auf den Live-Stand des TableMonitors.
    def extract_result(tm, game)
      gd = safe_data(game)
      ba = gd["ba_results"]
      sets = gd.dig("tmp_results", "sets")
      if ba.blank? && tm.present?
        td = tm.data.is_a?(Hash) ? tm.data : {}
        ba = td["ba_results"]
        sets = td["sets"] if sets.blank?
      end
      (ba || {}).merge("sets" => Array(sets))
    end

    def safe_data(record)
      d = record.data
      return d if d.is_a?(Hash)
      return {} if d.blank?
      JSON.parse(d.to_s)
    rescue JSON::ParserError
      {}
    end
  end
end
