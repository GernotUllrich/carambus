# frozen_string_literal: true

module RegionServer
  # Plan 36-01: Die Datenschicht der Ranglisten-Erfassung auf dem Region Server.
  #
  # Zwei Aufgaben in EINER Schicht, damit Formular und Speicherung dieselbe Sicht auf die Daten
  # haben — dasselbe Motiv, aus dem RegionServer::GameResultWriter (35-03) beide Ergebniswege
  # buendelt. Liefen Vorschlag und Schreibung auseinander, saehe der Sportwart Werte, die so nie
  # gespeichert wuerden.
  #
  #   #suggestions  Vorschlaege je Seeding, abgeleitet aus den ueber 35-03 erfassten Spielen
  #   #call         schreibt die abgeschickten Werte nach seeding.data["result"]["Gesamtrangliste"]
  #
  # GESCHRIEBEN WIRD NICHT SELBST, sondern ueber Tournament::FinalRankingWriter.write_gesamtrangliste:
  # die Klassenmethode setzt zugleich die Provenienz-Marke `result_source` und kapselt
  # `skip_cable_ready_updates`. Ebenso wird `FinalRankingWriter.writable?` benutzt statt
  # nachgebaut — dieselbe Schutzregel gilt an vier Stationen (Erzeuger, Api::TournamentResultsController,
  # RegionServer::EntryListImporter und hier), und eine vierte Kopie liefe frueher oder spaeter
  # auseinander.
  #
  # WAS HIER NICHT PASSIERT: keine Platzierungsberechnung, keine Serienpunkte, keine
  # Sortierkriterien. Rang und Punkte kommen vom Sportwart (Betreiber 2026-07-29: auch in der
  # ClubCloud wird die Ranking-Table bei Direkteingabe manuell eingetragen). Der Region Server ist
  # Verwaltungsplatz, kein Turniermanagement.
  class RankingWriter
    Result = Struct.new(:written, :skipped_foreign, :skipped_empty, keyword_init: true)

    def initialize(tournament:)
      @tournament = tournament
      @schema = RankingSchema.for(tournament)
    end

    attr_reader :schema

    # Dieselbe Menge, die Api::EntryListsController#entries_for ausliefert — ungefiltert und nach
    # Position sortiert, damit Erfassung und Propagation dieselben Zeilen sehen.
    def seedings
      @seedings ||= @tournament.seedings.includes(:player).order(:position).to_a
    end

    # Vorschlaege je Seeding-ID: { 42 => {"Bälle" => 44, "Aufn" => 105, "HS" => 3}, ... }
    #
    # Nur Felder, die das Schema als vorbelegbar fuehrt — Rang und Punkte sind nie dabei.
    # Ein Spieler ohne erfasste Spiele bekommt einen leeren Hash; das ist ein gueltiger Zustand
    # (die Ergebnisliste ist optional), kein Fehler.
    def suggestions
      stats = player_stats
      fields = @schema.prefillable_fields

      seedings.each_with_object({}) do |seeding, acc|
        values = stats[seeding.player_id]
        acc[seeding.id] = if values.nil?
          {}
        else
          fields.each_with_object({}) { |field, row| row[field.key] = values[field.prefill] }
        end
      end
    end

    # entries: { seeding_id => { "Rang" => "1", "Bälle" => "44", ... } }
    def call(entries)
      result = Result.new(written: 0, skipped_foreign: 0, skipped_empty: 0)
      clubs = club_names

      seedings.each do |seeding|
        submitted = entries[seeding.id] || entries[seeding.id.to_s]
        next if submitted.nil?

        values = cast_inputs(submitted)

        # Eine Zeile, in der nichts steht, erzeugt KEINEN Eintrag. Ein leeres
        # `Gesamtrangliste`-Objekt erschiene auf der Turnierseite als Ergebniszeile ohne Werte und
        # reiste im /api/entry_lists-Dokument mit nach oben.
        if values.empty?
          result.skipped_empty += 1
          next
        end

        unless ::Tournament::FinalRankingWriter.writable?(seeding)
          result.skipped_foreign += 1
          next
        end

        ::Tournament::FinalRankingWriter.write_gesamtrangliste(seeding, entry_for(seeding, values, clubs))
        result.written += 1
      end

      result
    end

    # Die bereits gespeicherte Rangliste je Seeding-ID — die Seite zeigt sie vor dem Vorschlag.
    def stored
      seedings.each_with_object({}) do |seeding, acc|
        data = seeding.data
        stored = data.is_a?(Hash) ? data.dig("result", "Gesamtrangliste") : nil
        acc[seeding.id] = stored.is_a?(Hash) ? stored : {}
      end
    end

    # Vereinsnamen in EINER Abfrage. FinalRankingWriter#club_name_for macht dasselbe je Seeding
    # einzeln; hier steht die ganze Meldeliste an, und N Abfragen waeren ohne Not.
    #
    # Oeffentlich, weil auch die Seite den Vereinsnamen anzeigt — sie darf ihn nicht aus dem
    # gespeicherten Eintrag lesen, den es bei einer noch unerfassten Zeile gar nicht gibt.
    def club_names
      @club_names ||= ::SeasonParticipation
        .where(player_id: seedings.map(&:player_id).compact, season_id: @tournament.season_id)
        .includes(:club)
        .each_with_object({}) { |sp, acc| acc[sp.player_id] ||= sp.club&.name }
    end

    private

    def cast_inputs(submitted)
      @schema.input_fields.each_with_object({}) do |field, acc|
        value = @schema.cast(field.key, submitted[field.key])
        acc[field.key] = value unless value.nil?
      end
    end

    # Reihenfolge wie im ClubCloud-Satz: Platzierung, Person, dann die Werte. Die Turnierseite
    # rendert die Schluessel in Einfuegereihenfolge.
    def entry_for(seeding, values, clubs)
      entry = {}
      entry["Rang"] = values["Rang"] if values.key?("Rang")
      entry["Name"] = seeding.player&.fullname
      entry["Verein"] = clubs[seeding.player_id]
      @schema.fields.each do |field|
        next if field.key == "Rang"

        entry[field.key] = values[field.key] if values.key?(field.key)
      end

      @schema.apply_computed(entry).compact
    end

    # Summen und Maxima aus den ueber 35-03 erfassten Spielen. Nur fuer Spieler, die ueberhaupt
    # gespielt haben — wer nicht vorkommt, bekommt keinen Vorschlag (statt einer vorgeschlagenen 0,
    # die eine Aussage ueber das Turnier waere).
    def player_stats
      stats = {}

      @tournament.games.includes(:game_participations).each do |game|
        rows = game.game_participations.to_a.select { |gp| gp.player_id.present? }

        rows.each do |gp|
          entry = (stats[gp.player_id] ||= {balls: 0, innings: 0, high_run: 0, wins: 0, losses: 0})
          entry[:balls] += gp.result.to_i
          entry[:innings] += gp.innings.to_i
          entry[:high_run] = [entry[:high_run], gp.hs.to_i].max
        end

        tally_win_loss(stats, rows)
      end

      stats
    end

    # Sieg/Niederlage nur bei genau zwei Beteiligten und nur bei echtem Unterschied — Gleichstand
    # zaehlt fuer keine der beiden Seiten (bei Karambol ist ein Unentschieden regulaer).
    def tally_win_loss(stats, rows)
      return unless rows.size == 2

      winner, loser = rows.sort_by { |gp| -gp.result.to_i }
      return if winner.result.to_i == loser.result.to_i

      stats[winner.player_id][:wins] += 1
      stats[loser.player_id][:losses] += 1
    end
  end
end
