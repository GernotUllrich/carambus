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

    class TableMonitorNotFoundError < StandardError
      attr_reader :table_no
      def initialize(table_no)
        @table_no = table_no
        super("TableMonitor not found for table_no=#{table_no}")
      end
    end

    Result = Struct.new(:games, :created_any?, keyword_init: true)

    def initialize(tournament:, region:, payload:)
      @tournament = tournament
      @region = region
      @payload = payload.is_a?(Hash) ? payload.deep_symbolize_keys : payload
      @matcher = PlayerMatcher.new(region: region)
      @created_any = false
    end

    def call
      out = []
      ActiveRecord::Base.transaction do
        (@payload[:games] || []).each do |g|
          game = find_or_create_game(g)
          create_participations(game, g[:participants] || [])
          table_monitor = assign_table_monitor(game, g[:table_no])
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

    # D-15-03-A: Tisch-Identifikation via Table.name == table_no.to_s.
    # Scope: Tournament.location_id → Tables → Table.table_monitor.
    # (TableMonitor.tournament_monitor ist polymorphic — Lookup via Location-Scope
    # ist sauberer und benötigt keinen polymorphic-join.)
    # Skip-Reassignment falls TableMonitor schon auf diesem Game steht.
    def assign_table_monitor(game, table_no)
      table = Table
        .where(location_id: @tournament.location_id)
        .find_by(name: table_no.to_s)

      tm = table&.table_monitor
      raise TableMonitorNotFoundError, table_no unless tm

      tm.update!(game_id: game.id) unless tm.game_id == game.id
      tm
    end
  end
end
