# frozen_string_literal: true

module ExternalTournament
  # Plan 15-03: Round-Start-Processor.
  #
  # Verarbeitet carambus.round_start/v1-Payloads der externen Turnier-Apps (Pilot:
  # 3BandMannschaftsTurnier). Verantwortlich für:
  #
  #   1. Game finden (idempotent via Game.data["external_id"]) oder erzeugen
  #   2. Players matchen (via PlayerMatcher) und GameParticipation find_or_create_by!
  #      (idempotent via Unique-Index [game_id, player_id, role])
  #   3. TableMonitor für Game.table_no via Table.name-Convention zuweisen
  #      (D-15-03-A: Table.name == table_no.to_s)
  #
  # Alles in einer DB-Transaction. Custom-Errors werden im Controller auf 422 gemappt.
  #
  # @example
  #   processor = ExternalTournament::RoundStartProcessor.new(
  #     tournament: Tournament.find(1),
  #     region: Region.find_by(shortname: "NBV"),
  #     payload: { games: [...], round_no: 1, ... }
  #   )
  #   result = processor.call
  #   result.games           # => [{external_id:, game_id:, table_monitor_id:}, ...]
  #   result.created_any?    # => true wenn mindestens 1 Game neu erstellt
  class RoundStartProcessor
    class PlayerResolutionError < StandardError
      attr_reader :participant
      def initialize(participant)
        @participant = participant
        super("Player not resolved: #{participant.inspect}")
      end
    end

    # Plan 15-06 (R2): Tisch existiert nicht in der (aufgelösten) Location.
    # identifier ist der String-Name (table_name) bzw. table_no.to_s als Fallback.
    class TableNotFoundError < StandardError
      attr_reader :identifier
      def initialize(identifier)
        @identifier = identifier
        super("Table not found: #{identifier}")
      end
    end

    # Plan 15-06 (R2): Tisch gefunden, aber kein TableMonitor (z.B. !local_server?,
    # da Table#table_monitor! dann nil liefert). identifier = table_name/table_no.to_s.
    class TableMonitorNotFoundError < StandardError
      attr_reader :identifier
      def initialize(identifier)
        @identifier = identifier
        super("TableMonitor not found for #{identifier}")
      end
    end

    Result = Struct.new(:games, :created_any?, keyword_init: true)

    def initialize(tournament:, region:, payload:)
      @tournament = tournament
      @region = region
      @payload = payload.is_a?(Hash) ? payload.deep_symbolize_keys : payload
      @matcher = PlayerMatcher.new(region: region)
      @created_any = false
      @location_id = resolve_location_id
    end

    def call
      out = []
      ActiveRecord::Base.transaction do
        (@payload[:games] || []).each do |g|
          game = find_or_create_game(g)
          create_participations(game, g[:participants] || [])
          table_monitor = assign_table_monitor(game, g)
          out << {
            external_id: g[:external_id],
            game_id: game.id,
            table_monitor_id: table_monitor.id
          }
        end
      end
      Result.new(games: out, created_any?: @created_any)
    end

    private

    # Plan 15-06 (R2/D-15-06-B): Location explizit aus dem Payload (id|cc_id) auflösen,
    # mit Fallback auf tournament.location_id (Alt-Client-Verhalten). Nötig, weil
    # tournament.location_id nil sein kann (z.B. NordCup-Turnier ohne Location-Link).
    def resolve_location_id
      loc = @payload[:location] || {}
      resolved =
        if loc[:id].present?
          Location.find_by(id: loc[:id])&.id
        elsif loc[:cc_id].present?
          # D-15-07-A: cc_id ist nur intra-region eindeutig → region-scopen.
          Location.find_by(cc_id: loc[:cc_id], region_id: @region.id)&.id
        end
      resolved || @tournament.location_id
    end

    # Idempotenz via Game.data["external_id"] — Game.data ist serialized JSON (per
    # Game-Model `serialize :data, coder: JSON, type: Hash`), daher direkter In-Memory-
    # Filter über tournament-scoped Games. Für sehr große Tournaments (>100 Games)
    # wäre eine jsonb-Column-Migration angebracht — Defer auf v0.6 falls Bedarf.
    def find_or_create_game(g)
      existing = @tournament.games.find { |x| safe_data(x)["external_id"] == g[:external_id] }
      return existing if existing

      ctx = g[:context] || {}
      @created_any = true
      @tournament.games.create!(
        round_no: ctx[:round_no] || @payload[:round_no],
        gname: ctx[:gname],
        group_no: ctx[:group_no],
        seqno: ctx[:seqno],
        table_no: g[:table_no],
        data: {
          external_id: g[:external_id],
          discipline: g[:discipline],
          format: g[:format],
          table_name: g[:table_name], # Plan 15-06 (D-15-06-D): für round_result-Symmetrie
          round_name: ctx[:round_name] || @payload[:round_name]
        }
      )
    end

    def safe_data(game)
      d = game.data
      return d if d.is_a?(Hash)
      return {} if d.blank?
      JSON.parse(d.to_s)
    rescue JSON::ParserError
      {}
    end

    def create_participations(game, participants)
      participants.each do |p|
        player_attrs = p[:player] || {}
        player = @matcher.match(player_attrs)
        raise PlayerResolutionError, p unless player

        GameParticipation.find_or_create_by!(
          game_id: game.id,
          player_id: player.id,
          role: p[:role].to_s
        )
      end
    end

    # Plan 15-06 (R2/D-15-06-A): Tisch-Identifikation via Table#name.
    # Bevorzugt g[:table_name] (echter String wie "Tisch 5"), Fallback g[:table_no].to_s
    # (Alt-Client-Verhalten, supersedes D-15-03-A). Scope: aufgelöste @location_id.
    #
    # D-15-06-C: table_monitor || table_monitor! — existierenden Monitor nutzen, sonst
    # lazy-create (analog tournaments_controller.rb `@table.table_monitor || @table.table_monitor!`).
    # table_monitor! liefert nil wenn !local_server? → TableMonitorNotFoundError.
    # Skip-Reassignment falls TableMonitor schon auf diesem Game steht.
    def assign_table_monitor(game, g)
      identifier = g[:table_name].presence || g[:table_no].to_s
      table = Table
        .where(location_id: @location_id)
        .find_by(name: identifier)
      raise TableNotFoundError, identifier unless table

      tm = table.table_monitor || table.table_monitor!
      raise TableMonitorNotFoundError, identifier unless tm

      tm.update!(game_id: game.id) unless tm.game_id == game.id
      tm
    end
  end
end
