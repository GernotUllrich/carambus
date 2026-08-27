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
    # tournament_cc darf nil sein (App-Turniere haben keine ClubCloud-Entsprechung),
    # round_no ebenfalls -- ohne Runde liefert der Service alle Spiele, die Carambus zum
    # Turnier KENNT.
    #
    # WICHTIG, damit daraus keine falsche Erwartung entsteht: Carambus haelt bewusst nur die
    # laufende Runde, nicht die Turnier-Historie -- die Turnierfuehrung liegt bei der App,
    # Carambus faehrt die Tische. Ergebnisse abgeschlossener Partien sind hier deshalb in der
    # Regel NICHT mehr zu holen (am 22.08. belegt: 27 Spiele des laufenden Turniers, alle ohne
    # Ergebnis). Als Ausfallsicherung dient die lokale Sicherung der App, nicht dieser Service.
    def initialize(tournament:, region:, tournament_cc: nil, round_no: nil)
      @tournament = tournament
      @tournament_cc = tournament_cc
      @region = region
      @round_no = round_no
    end

    def call
      {
        schema: "carambus.round_result/v1",
        region: {shortname: @region.shortname},
        tournament: {id: @tournament.id, cc_id: @tournament_cc&.cc_id},
        round_no: @round_no,
        results: build_results
      }
    end

    private

    # D-15-04-A: Filter via tournament.games.where(round_no: N).
    # Order: nach seqno (Spielreihenfolge), dann id als Tiebreaker.
    def build_results
      games = @tournament.games
        .includes(game_participations: :player)
        .order(:seqno, :id)
      games = games.where(round_no: @round_no) unless @round_no.nil?
      games = games.to_a

      # App-Turniere: Das tatsaechlich gespielte Game entsteht am Tisch
      # (GameSetup#create_new_game) und traegt BEWUSST kein tournament_id/tournament_type
      # -- siehe StartGameProcessor ("zieht sonst Polymorphie/Unique-Index/acts_as_list
      # herein"). Ueber die Assoziation oben sind daher nur die Marker-Games aus round_start
      # erreichbar, und die haben keine Ergebnisse. Fuer die Wiederherstellung braucht die
      # App aber genau die Ergebnisse, deshalb zusaetzlich ueber die external_id suchen:
      # sie traegt das Format "attach-<tournament_id>-<key>". data ist eine text-Spalte
      # (serialize JSON), also Textsuche -- ohne round_no-Filter, weil diese Games kein
      # verlaessliches round_no fuehren.
      games += attached_games(games.map(&:id))
      games.map { |game| build_result(game) }
    end

    # Am Tisch entstandene Games desselben Turniers, dedupliziert gegen die bereits
    # gefundenen. Traegt ein Marker und ein Tisch-Game dieselbe external_id, gewinnt das
    # mit Ergebnis -- der Marker ist dann nur die leere Ankuendigung.
    def attached_games(known_ids)
      prefix = "attach-#{@tournament.id}-"
      candidates = Game.where("data LIKE ?", "%\"external_id\":\"#{prefix}%")
        .where.not(id: known_ids)
        .includes(game_participations: :player)
        .order(:seqno, :id)
        .to_a
      return [] if candidates.empty?

      by_external = {}
      candidates.each do |game|
        key = safe_data(game)["external_id"].to_s
        current = by_external[key]
        by_external[key] = game if current.nil? || (result?(game) && !result?(current))
      end
      by_external.values
    end

    def result?(game)
      safe_data(game)["ba_results"].present? ||
        game.game_participations.any? { |gp| gp.points.present? }
    end

    def build_result(game)
      gps = game.game_participations.to_a
      {
        external_id: safe_data(game)["external_id"],
        table_no: game.table_no,
        table_name: safe_data(game)["table_name"], # Plan 15-06 (D-15-06-D): table_name-only-Games wiederfindbar
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
        dbu_nr: player.dbu_nr&.to_s,
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
