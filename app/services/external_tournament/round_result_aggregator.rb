# frozen_string_literal: true

module ExternalTournament
  # Plan 15-04: Round-Result-Aggregator.
  #
  # Aggregiert GameParticipations der angegebenen Runde zu einem
  # carambus.round_result/v1-konformen Hash für die External-Tournament-Bridge.
  #
  # Read-only Service: keine DB-Writes, keine Transaction nötig.
  #
  # Konsumiert die Substrate aus Plan 15-02 (Player-Serialization) und Plan 15-03
  # (Game.data["external_id"] als App-eigene Identifier-Quelle).
  #
  # @example
  #   payload = RoundResultAggregator.new(
  #     tournament: Tournament.find(1),
  #     tournament_cc: TournamentCc.find_by(cc_id: 12345),
  #     region: Region.find_by(shortname: "NBV"),
  #     round_no: 1
  #   ).call
  #   payload[:schema]   # => "carambus.round_result/v1"
  #   payload[:results]  # => [{external_id:, table_no:, ..., participants: [...]}, ...]
  class RoundResultAggregator
    def initialize(tournament:, tournament_cc:, region:, round_no:)
      @tournament = tournament
      @tournament_cc = tournament_cc
      @region = region
      @round_no = round_no
    end

    def call
      {
        schema: "carambus.round_result/v1",
        region: {shortname: @region.shortname},
        tournament: {cc_id: @tournament_cc.cc_id},
        round_no: @round_no,
        results: build_results
      }
    end

    private

    # D-15-04-A: Filter via tournament.games.where(round_no: N).
    # Order: nach seqno (Spielreihenfolge), dann id als Tiebreaker.
    def build_results
      games = @tournament.games
        .where(round_no: @round_no)
        .includes(game_participations: :player)
        .order(:seqno, :id)
      games.map { |game| build_result(game) }
    end

    def build_result(game)
      gps = game.game_participations.to_a
      {
        external_id: safe_data(game)["external_id"],
        table_no: game.table_no,
        started_at: game.started_at&.iso8601,
        ended_at: game.ended_at&.iso8601,
        innings_played: innings_played(gps),
        participants: gps.map { |gp| build_participant(gp) }
      }
    end

    # D-15-04-C: innings_played = max(Participant.innings).
    # Nachstoß-tolerant für 3-Band (playerA hat oft 1 Aufnahme mehr als playerB).
    def innings_played(gps)
      gps.filter_map { |gp| gp.innings&.to_i }.max || 0
    end

    def build_participant(gp)
      {
        role: gp.role,
        player: serialize_player(gp.player),
        points: gp.points,
        innings: gp.innings,
        high_series: gp.hs,
        gd: serialize_gd(gp),
        sets: gp.sets
      }.compact
    end

    # D-15-04-E: Player-Serialization analog 15-02 Seeding.
    # dbu_nr weggelassen (Spec macht es optional; App matched primär über external_id+role).
    def serialize_player(player)
      return nil unless player
      {
        cc_id: player.cc_id,
        firstname: player.firstname,
        lastname: player.lastname
      }
    end

    # D-15-04-D: gd aus DB übernehmen falls vorhanden, sonst aus points/innings berechnen.
    # Beide Pfade runden auf 3 Nachkommastellen.
    def serialize_gd(gp)
      return gp.gd.to_f.round(3) if gp.gd.is_a?(Numeric)
      return nil if gp.innings.to_i.zero? || gp.points.nil?
      (gp.points.to_f / gp.innings.to_f).round(3)
    end

    # Game.data ist serialized JSON (per Game-Model `serialize :data, coder: JSON, type: Hash`),
    # daher Hash-Access defensiv (analog 15-03 RoundStartProcessor).
    def safe_data(game)
      d = game.data
      return d if d.is_a?(Hash)
      return {} if d.blank?
      JSON.parse(d.to_s)
    rescue JSON::ParserError
      {}
    end
  end
end
