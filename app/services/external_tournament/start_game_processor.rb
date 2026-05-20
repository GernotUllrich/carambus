# frozen_string_literal: true

module ExternalTournament
  # Plan 17-03 (B1): App-getriebener Spielstart pro Spiel.
  #
  # Die App startet ein Spiel direkt auf einem turnier-gebundenen Tisch — mit
  # PER-SPIELER-Disziplinen + Format (Mannschaftskampf: 4 Spiele/Spieler mit ggf.
  # unterschiedlichen Disziplinen, im Pool ueblich). Nutzt den bestehenden per-Spiel-Pfad
  # `TableMonitor#start_game(options)` (= manueller Scoreboard-/Quick-Game-Pfad), der
  # discipline_a/discipline_b + balls_goal_a/b nativ in data["playera"/"playerb"] ablegt.
  #
  # Warmup: perform_start_game macht KEIN start_new_match! → wir erzwingen state ready +
  # start_new_match! (Muster aus GameSetup#perform_assign). Loest den 15-06-Befund
  # "Game nach round_start nicht spielbereit".
  #
  # round_start (15-03) wird im App-Lifecycle NICHT mehr genutzt; dies ist die Write-Primitive.
  class StartGameProcessor
    Result = Struct.new(:game, :table_monitor, :state, :created?, keyword_init: true)

    class TournamentNotFoundError < StandardError; end

    class TableNotFoundError < StandardError
      attr_reader :identifier
      def initialize(identifier)
        @identifier = identifier
        super("Table not found: #{identifier}")
      end
    end

    class TableNotBoundError < StandardError
      attr_reader :identifier
      def initialize(identifier)
        @identifier = identifier
        super("Table not bound to this tournament: #{identifier}")
      end
    end

    class TableMonitorNotFoundError < StandardError
      attr_reader :identifier
      def initialize(identifier)
        @identifier = identifier
        super("TableMonitor not found for #{identifier}")
      end
    end

    class PlayerResolutionError < StandardError
      attr_reader :participant
      def initialize(participant)
        @participant = participant
        super("Player not resolved: #{participant.inspect}")
      end
    end

    def initialize(region:, payload:)
      @region = region
      @payload = payload.is_a?(Hash) ? payload.deep_symbolize_keys : payload
      @matcher = PlayerMatcher.new(region: region)
    end

    def call
      tournament = resolve_tournament
      owner = tournament.tournament_monitor
      raise TournamentNotFoundError, "tournament has no tournament_monitor" if owner.blank?

      table = resolve_table(tournament)
      tm = table.table_monitor || table.table_monitor!
      raise TableMonitorNotFoundError, table.name if tm.blank?

      unless tm.tournament_monitor_id == owner.id && tm.tournament_monitor_type == "TournamentMonitor"
        raise TableNotBoundError, table.name
      end

      external_id = @payload[:external_id].to_s

      # Idempotenz: laeuft bereits dieses external_id-Spiel auf dem Tisch?
      if external_id.present? && tm.game.present? && safe_data(tm.game)["external_id"] == external_id
        return Result.new(game: tm.game, table_monitor: tm, state: tm.state, created?: false)
      end

      ActiveRecord::Base.transaction do
        # Game-Swap (K): laufendes Spiel vor dem Ersetzen sichern (initialize_game resettet tm.data).
        snapshot_existing_game(tm) if tm.game.present?

        tm.start_game(build_options)
        tm.reload

        # Warmup-Transition (perform_start_game macht das nicht) — Muster perform_assign.
        unless warmup_state?(tm)
          tm.assign_attributes(state: "ready") unless tm.may_start_new_match?
          tm.save!
          tm.start_new_match! if tm.may_start_new_match?
        end
        tm.finish_warmup! if shootout?(build_options) && tm.may_finish_warmup?

        if external_id.present? && tm.game.present?
          # Plan 17-06 (D-17-06-A): zusaetzlich durabler Turnier-Marker fuer die CSV-Enumerierung.
          # Nur JSON-data (KEIN game.tournament_id-FK — zieht sonst Polymorphie/Unique-Index/
          # acts_as_list herein). Ueberlebt die TableMonitor-Entbindung beim Lifecycle-Exit (17-05).
          tm.game.update!(data: safe_data(tm.game).merge(
            "external_id" => external_id,
            "tournament_external_id" => tournament.external_id
          ))
        end
      end

      Result.new(game: tm.game, table_monitor: tm, state: tm.reload.state, created?: true)
    end

    private

    def warmup_state?(tm)
      %w[warmup warmup_a warmup_b match_shootout playing].include?(tm.state.to_s)
    end

    def shootout?(options)
      options["discipline_a"].to_s =~ /shootout/i || options["discipline_b"].to_s =~ /shootout/i
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

    def resolve_table(tournament)
      tbl = @payload[:table] || {}
      table =
        if tbl[:id].present?
          Table.find_by(id: tbl[:id])
        elsif tbl[:name].present?
          Table.where(location_id: tournament.location_id).find_by(name: tbl[:name])
        end
      raise TableNotFoundError, (tbl[:id] || tbl[:name]).to_s if table.blank?
      table
    end

    # Baut den per-Spiel/Spieler-Options-Hash fuer TableMonitor#start_game (GameSetup).
    def build_options
      @build_options ||= begin
        a = participant("playera")
        b = participant("playerb")
        {
          "free_game_form" => @payload[:free_game_form].to_s,
          "player_a_id" => [resolve_player_id(a)],
          "player_b_id" => [resolve_player_id(b)],
          "discipline_a" => a[:discipline].to_s,
          "discipline_b" => b[:discipline].to_s,
          "balls_goal_a" => a[:balls_goal],
          "balls_goal_b" => b[:balls_goal],
          "innings_goal" => @payload[:innings_goal],
          "sets_to_play" => @payload[:sets_to_play].presence || 1,
          "sets_to_win" => @payload[:sets_to_win].presence || 1,
          "timeouts" => @payload[:timeouts] || 0,
          "timeout" => @payload[:timeout] || 0,
          "kickoff_switches_with" => @payload[:kickoff_switches_with].presence || "set",
          "allow_follow_up" => @payload[:allow_follow_up],
          "allow_overflow" => @payload[:allow_overflow] || false,
          "initial_red_balls" => @payload[:initial_red_balls].presence || 15
        }.stringify_keys
      end
    end

    def participant(role)
      Array(@payload[:participants]).find { |p| p[:role].to_s == role } || {}
    end

    def resolve_player_id(participant)
      player = @matcher.match(participant[:player] || {})
      raise PlayerResolutionError, participant unless player
      player.id
    end

    # Game-Swap: aktuellen tm.data-Stand ins (alte) Game sichern, bevor es ersetzt/abgehaengt wird.
    def snapshot_existing_game(tm)
      old = tm.game
      return if old.blank?
      old.update!(data: safe_data(old).merge(
        "swap_snapshot" => tm.data,
        "swapped_at" => Time.current.iso8601
      ))
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
