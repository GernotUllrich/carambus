# frozen_string_literal: true

module ExternalTournament
  # Plan 41-01: Endstand und Spieletabelle eines App-Turniers als LOKALE Records ablegen.
  #
  # Hintergrund (Handoff carambus_app 2026-08-25): Carambus war als ephemere Scoreboard-Engine
  # gedacht und raeumt nach dem Turnier auf. Damit hinterlaesst ein Turnier, das im Verein
  # stattgefunden hat, auf dem lokalen Server keine Spur — das Ergebnis lebt nur in einer
  # CSV-Datei auf genau dem Geraet, dessen localStorage schon einmal weggebrochen ist.
  # Neue Aufteilung: die App bleibt System of Record, der Server bekommt eine lesbare Kopie.
  #
  # Die App liefert eine FERTIGE Tabelle — sie bestimmt ihre Spalten selbst (jede Disziplin
  # hat andere). Verbindlich ist allein `Rank` als Integer, weil die Anzeige darauf sortiert.
  # Dieser Service rechnet nichts, er legt ab.
  #
  # ZWEI DINGE, die beim Bauen gemessen wurden und die Form bestimmen:
  #
  # 1. Archiv-Games sind eigene STI-Records (`ArchivedGame`), NICHT Ersatz fuer die Live-Games.
  #    carambus_app pusht ausdruecklich nach JEDER RUNDE, also waehrend der Monitor laeuft.
  #    Wuerden Archiv-Zeilen die Live-Games ersetzen, entzoege der Push dem Monitor die Games,
  #    die er noch braucht. Und lagen beide Sorten ungetrennt am Turnier, wuerde
  #    `finals_finished?` (n_games == n_games_done) nie mehr wahr.
  #
  # 2. Seedings ohne aufgeloesten Spieler sind erlaubt, aber nur lokal — s. Kommentar an
  #    `Seeding#local_seeding?`. Ein internationales Feld enthaelt Spielerinnen ohne dbu_nr,
  #    die der PlayerMatcher nicht findet und die laut Vertrag NICHT angelegt werden duerfen.
  #
  # @example
  #   ExternalTournament::TournamentResultArchiver.new(
  #     tournament: t, region: region, payload: params
  #   ).call
  #   # => { seedings_written: 6, games_written: 15, players_unmatched: [...] }
  class TournamentResultArchiver
    def initialize(tournament:, region:, payload:)
      @tournament = tournament
      @region = region
      @payload = payload
      @matcher = PlayerMatcher.new(region: region)
      @unmatched = []
    end

    def call
      seedings_written = 0
      games_written = 0

      # Eine Transaktion fuer alles: ein halb geschriebenes Archiv ist schlechter als keines —
      # die Anzeige nimmt die Spaltenkoepfe aus dem ERSTEN Record und wuerde eine unvollstaendige
      # Tabelle stumm falsch rendern.
      ActiveRecord::Base.transaction do
        seedings_written = write_standings
        games_written = write_games
        mark_archived!
      end

      {
        seedings_written: seedings_written,
        games_written: games_written,
        players_unmatched: @unmatched
      }
    end

    private

    attr_reader :tournament, :region, :payload, :matcher

    def list_title
      payload[:title].presence || "Endstand"
    end

    def write_standings
      Array(payload[:standings]).count do |entry|
        rank = entry[:rank].to_i
        player = match_player(entry[:player])

        # Idempotenz-Schluessel ist (tournament, rank) — NICHT player_id: Zeilen ohne
        # aufgeloesten Spieler haetten dort alle denselben Schluessel (nil) und wuerden sich
        # gegenseitig ueberschreiben. Genau die Zeilen, um die es hier geht.
        seeding = tournament.seedings.where("seedings.id >= ?", Seeding::MIN_ID)
          .find_by(rank: rank) || tournament.seedings.new

        seeding.assign_attributes(
          player: player,
          rank: rank,
          state: "participated",
          tournament_type: "Tournament",
          region_id: region.id,
          global_context: false,
          data: seeding_data(seeding, entry, rank)
        )
        seeding.position = entry[:position] if entry[:position].present?
        seeding.save!
      end
    end

    # `data["result"][title]` ist die Form, die die Anzeige erwartet (tournaments/show.html.erb:
    # Listenname wird Tabellenueberschrift, Keys werden Spalten). "Rank" muss Integer sein —
    # die View sortiert darauf.
    def seeding_data(seeding, entry, rank)
      existing = seeding.data.is_a?(Hash) ? seeding.data : {}
      result = existing["result"].is_a?(Hash) ? existing["result"] : {}
      columns = (entry[:columns] || {}).to_h.transform_keys(&:to_s)
      existing.merge("result" => result.merge(list_title => columns.merge("Rank" => rank)))
    end

    def match_player(attrs)
      return nil if attrs.blank?

      player = matcher.match(attrs.to_h.symbolize_keys)
      if player.nil?
        # Kein Create — ausdruecklicher Vertragsbestandteil. Die Zeile entsteht trotzdem,
        # der Name steht in `columns`.
        @unmatched << {lastname: attrs[:lastname], firstname: attrs[:firstname]}
      end
      player
    end

    def write_games
      Array(payload[:games]).count do |entry|
        gname = entry[:gname].to_s
        seqno = entry[:seqno].to_i

        # Upsert ueber den vorhandenen Unique-Index (tournament_id, gname, seqno).
        game = ArchivedGame.find_by(tournament_id: tournament.id, gname: gname, seqno: seqno) ||
          ArchivedGame.new(tournament_id: tournament.id, gname: gname, seqno: seqno)

        game.assign_attributes(
          data: (entry[:columns] || {}).to_h.transform_keys(&:to_s),
          round_no: entry[:round_no],
          group_no: entry[:group_no],
          table_no: entry[:table_no],
          started_at: entry[:started_at],
          ended_at: entry[:ended_at],
          tournament_type: "Tournament",
          region_id: region.id,
          global_context: false
        )
        game.save!
      end
    end

    def mark_archived!
      data = tournament.data.is_a?(Hash) ? tournament.data : {}
      tournament.update!(data: data.merge("archived_at" => Time.current.iso8601))
    end
  end
end
