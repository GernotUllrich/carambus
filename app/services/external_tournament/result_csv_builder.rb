# frozen_string_literal: true

require "csv"

module ExternalTournament
  # Plan 17-06 (Vision 6 / D-17-vision-3): Ergebnis-CSV eines lokalen App-Turniers.
  #
  # Analog Carambus-Turnier-Export (TournamentMonitor::ResultProcessor#write_finale_csv_for_upload),
  # ERWEITERT um die dbu_nr je Spieler (Crosscheck fuer den Ergebnis-Einpfleger).
  #
  # Ergebnis-Quelle (D-17-06-B): game.data["ba_results"] — bei App-Turnieren (manual_assignment)
  # bleiben die GameParticipation-Spalten leer (update_game_participations_for_game wird
  # uebersprungen), waehrend report_result die ba_results in game.data persistiert.
  #
  # Enumerierung (D-17-06-A): durabel + turnier-eindeutig ueber den beim start_game gestempelten
  # Marker game.data["tournament_external_id"]. Es gibt KEINEN durablen Game→Monitor/Tournament-FK
  # fuer App-Spiele: TableMonitor#game_id zeigt nur auf das AKTUELLE Spiel, ein Game-Swap loest die
  # Bindung des alten Spiels (StartGameProcessor-Test). Auch KEIN game.tournament_id-FK (zoge
  # Polymorphie/Unique-Index/acts_as_list herein). Der Marker im serialisierten game.data ist somit
  # der einzige durable Anker — er ueberlebt die TableMonitor-Entbindung des Lifecycle-Exit (17-05).
  # Coarse SQL-LIKE-Vorfilter auf den external_id-String, danach exakter Marker-Abgleich in Ruby.
  class ResultCsvBuilder
    HEADER = %w[
      Gruppe Partie ExternalId
      Spieler1_cc_id Spieler1_dbu_nr Spieler1 Ergebnis1 Aufnahmen1 HS1
      Spieler2_cc_id Spieler2_dbu_nr Spieler2 Ergebnis2 Aufnahmen2 HS2
      Datum Uhrzeit
    ].freeze

    def initialize(tournament:)
      @tournament = tournament
    end

    # @return [String] CSV (Semikolon-getrennt, UTF-8): Header + 1 Zeile je abgeschlossenem Spiel.
    def call
      CSV.generate(col_sep: ";") do |csv|
        csv << HEADER
        games.each { |g| csv << row_for(g) }
      end
    end

    private

    def games
      # Der tournament_external_id-Marker ist der praezise Diskriminator: globale/fremde Spiele
      # tragen ihn nie. Kein zusaetzlicher id>=MIN_ID-Filter (Marker impliziert lokales App-Spiel).
      candidates
        .select { |g| safe_data(g)["tournament_external_id"].to_s == @tournament.external_id.to_s }
        .select { |g| safe_data(g)["ba_results"].present? }
        .sort_by { |g| [g.ended_at || Time.zone.at(0), g.id] }
    end

    # Kandidaten-Scope: Games, deren serialisiertes data den external_id-String enthaelt
    # (coarse LIKE als Index-/Scan-Begrenzung), praezise gefiltert wird dann in #games.
    # game.data ist ein serialized-JSON-Textfeld (serialize :data, coder: JSON) → LIKE greift.
    def candidates
      ext = @tournament.external_id.to_s
      return [] if ext.blank?
      Game.where("data LIKE ?", "%#{ext}%")
        .includes(game_participations: :player)
        .to_a
    end

    def row_for(game)
      ba = safe_data(game)["ba_results"] || {}
      p1 = participation(game, "playera")&.player
      p2 = participation(game, "playerb")&.player
      ended = game.ended_at
      [
        group_name(game),
        game.seqno,
        safe_data(game)["external_id"],
        p1&.cc_id, p1&.dbu_nr, p1&.fl_name, ba["Ergebnis1"], ba["Aufnahmen1"], ba["Höchstserie1"],
        p2&.cc_id, p2&.dbu_nr, p2&.fl_name, ba["Ergebnis2"], ba["Aufnahmen2"], ba["Höchstserie2"],
        ended&.strftime("%d.%m.%Y"), ended&.strftime("%H:%M")
      ]
    end

    def participation(game, role)
      game.game_participations.detect { |gp| gp.role == role }
    end

    # gname kann bei App-Spielen nil sein → leer lassen; sonst CC-Gruppenname-Mapping wie Legacy-Export.
    def group_name(game)
      return nil if game.gname.blank?
      Setting.map_game_gname_to_cc_group_name(game.gname).presence || game.gname
    end

    # game.data ist serialized JSON (Game-Model serialize :data) — defensiv (analog 15-04 Aggregator).
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
