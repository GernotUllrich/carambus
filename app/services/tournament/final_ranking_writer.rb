# frozen_string_literal: true

# Plan 29-02: Schreibt die GESAMTRANGLISTE eines selbst gespielten Turniers je Seeding nach
# `seeding.data["result"]["Gesamtrangliste"]`.
#
# WARUM DAS NOETIG IST (Befund 29-01 §0.A): Die Gesamtrangliste hat bisher die ClubCloud BERECHNET,
# nicht Carambus. Einziger Schreiber dieser Struktur im Repo ist der CC-Scraper
# (tournament/public_cc_scraper.rb:483) — fuer ein CC-los gespieltes Turnier bleibt `data["result"]`
# deshalb leer, mit zwei sichtbaren Folgen: die Turnier-Detailseite zeigt kein Ergebnis, und
# `carambus:update_ranking_tables` findet nichts zu aggregieren. Der TournamentMonitor hat alle noetigen
# Groessen bereits aggregiert (data["rankings"]["total"]), nur unter englischen Schluesseln.
#
# Verwendung (dry-run ist Default):
#   Tournament::FinalRankingWriter.new(tournament: t).call
#   Tournament::FinalRankingWriter.new(tournament: t, armed: true).call
#
# PORO (kein ApplicationService) gemaess der Konvention von Tournament::SeasonCopier / RankingCalculator.
# NICHT verwechseln mit Tournament::RankingCalculator — der berechnet die EINGANGS-Rangliste fuer die
# Setzliste aus historischen PlayerRankings. Hier geht es um das ERGEBNIS nach dem Turnier.
class Tournament::FinalRankingWriter
  # Nur Karambol: `carambus:update_ranking_tables` verarbeitet ausschliesslich
  # `discipline.root.name == "Karambol"` (carambus.rake:721). Fuer Pool/Snooker/Kegel einen Zielsatz zu
  # erfinden, den niemand liest, waere Rateleistung — die Schluesselsaetze dort sind ausserdem nicht
  # disziplin-, sondern quellenabhaengig (Befund 29-01 §4.2).
  KARAMBOL_ROOT = "Karambol"

  # Provenienz-Marke NEBEN `data["result"]` (nicht darin): `Seeding.result_display` rendert jeden
  # Schluessel innerhalb von data["result"][<liste>] als Spalte — eine Marke dort wuerde als
  # Ergebnisspalte auftauchen. Hier dient sie dazu, eigene Schreibungen von gescrapten zu unterscheiden.
  SOURCE_MARKER = "carambus"

  Result = Struct.new(:seedings_written, :skipped_no_monitor, :skipped_discipline,
    :skipped_no_results, :skipped_foreign_result, :planned, keyword_init: true)

  class << self
    # Schutzlinie gegen Datenverlust: eine aus der ClubCloud gescrapte Gesamtrangliste wird NIE
    # ueberschrieben. Eigene Schreibungen dagegen schon — nur so bleibt der Vorgang wiederholbar
    # (29-01 §5.0: ein korrigierter Writer soll erneut laufen koennen statt ein Reparaturskript
    # zu brauchen).
    #
    # Auf Klassenebene, weil dieselbe Regel entlang der ganzen Kette gilt: hier beim Erzeugen,
    # in Api::TournamentResultsController beim Empfangen auf dem Region Server und im
    # RegionServer::EntryListImporter beim Hochtragen auf die Authority (Plan 29-03). Eine Kopie je
    # Station wuerde frueher oder spaeter auseinanderlaufen.
    def writable?(seeding)
      data = seeding.data
      return true unless data.is_a?(Hash)
      return true if data.dig("result", "Gesamtrangliste").blank?

      data["result_source"] == SOURCE_MARKER
    end

    # Schreibt eine Gesamtrangliste auf ein Seeding und setzt die Provenienz-Marke.
    # Geteilt aus demselben Grund wie `writable?`.
    def write_gesamtrangliste(seeding, entry)
      ::Seeding.skip_cable_ready_updates do
        data = seeding.data.is_a?(Hash) ? seeding.data.deep_dup : {}
        data["result"] = (data["result"].is_a?(Hash) ? data["result"] : {}).merge("Gesamtrangliste" => entry)
        data["result_source"] = SOURCE_MARKER
        seeding.update!(data: data)
      end
    end
  end

  def initialize(tournament:, armed: false)
    @tournament = tournament
    @armed = armed
  end

  def call
    result = Result.new(seedings_written: 0, skipped_no_monitor: 0, skipped_discipline: 0,
      skipped_no_results: 0, skipped_foreign_result: 0, planned: [])

    monitor = @tournament.tournament_monitor
    if monitor.blank?
      result.skipped_no_monitor += 1
      return result
    end
    unless karambol?
      result.skipped_discipline += 1
      return result
    end

    rankings = totals(monitor)
    if rankings.blank?
      result.skipped_no_results += 1
      return result
    end

    seedings_by_player.each do |player_id, seeding|
      values = lookup(rankings, player_id)
      next if values.blank?

      unless writable?(seeding)
        result.skipped_foreign_result += 1
        next
      end

      entry = gesamtrangliste_for(seeding, values)
      result.planned << {player: seeding.player&.fullname, rank: entry["Rang"], balls: entry["Bälle"]}
      result.seedings_written += 1

      next unless @armed

      write(seeding, entry)
    end

    result
  end

  private

  def karambol?
    @tournament.discipline&.root&.name == KARAMBOL_ROOT
  end

  def totals(monitor)
    data = monitor.data
    return nil unless data.is_a?(Hash)

    totals = data.dig("rankings", "total")
    totals.is_a?(Hash) ? totals : nil
  end

  # Der Monitor legt die Spieler-Schluessel als INTEGER an (result_processor.rb:446), greift aber mit
  # STRING zu (dort:228) — und `data` ist JSON-serialisiert, nach einem Round-Trip sind alle Schluessel
  # Strings. Je nach Aufrufzeitpunkt (direkt nach update_ranking vs. spaeter aus der DB) liegt also mal
  # das eine, mal das andere vor. Beides bedienen, statt sich auf einen Fall zu verlassen.
  def lookup(rankings, player_id)
    values = rankings[player_id] || rankings[player_id.to_s]
    values.is_a?(Hash) ? values : nil
  end

  # Am Turniertag gespielt wird auf den LOKALEN Seedings (Teilnehmerliste); die globalen tragen die
  # Meldung. Dieselbe Abgrenzung nutzt der bestehende CC-Upload (tournament_cc.rb:289).
  def seedings_by_player
    scope = @tournament.seedings.where("seedings.id >= ?", ::Seeding::MIN_ID)
    scope = @tournament.seedings.where("seedings.id < ?", ::Seeding::MIN_ID) if scope.empty?
    scope.includes(:player).index_by(&:player_id)
  end

  def writable?(seeding)
    self.class.writable?(seeding)
  end

  # Zielsatz aus 29-01 §4.4. Zwei Festlegungen, die nicht kosmetisch sind:
  #
  # 1. `Bälle` UND `Punkte` werden IMMER BEIDE gesetzt. `carambus.rake:740` deutet `Punkte` still zu
  #    `Bälle` um, wenn `Bälle` fehlt — bei uns gibt es nichts umzudeuten. `Punkte` sind hier
  #    Partiepunkte, `Bälle` die erspielten Baelle; die Messung in 29-01 §4.3 zeigt, dass diese
  #    Doppelbedeutung im Altbestand real vorkommt.
  # 2. `GD`/`BED` sind FLOAT. Die Aggregation macht `v.is_a?(Float) ? v : v.to_i` (carambus.rake:765) —
  #    ein Integer oder ein String ohne Komma wuerde 1.132 auf 1 abschneiden.
  def gesamtrangliste_for(seeding, values)
    {
      "Rang" => placement(values),
      "Name" => seeding.player&.fullname,
      "Verein" => club_name_for(seeding),
      "Bälle" => values["result"].to_i,
      "Aufn" => values["innings"].to_i,
      "GD" => values["gd"].to_f,
      "HS" => values["hs"].to_i,
      "BED" => values["bed"].to_f,
      "Punkte" => values["points"].to_i
    }.compact
  end

  # Die Platzierung kommt aus rankings["total"][...]["rank"], NICHT aus der Spalte `seedings.rank`.
  #
  # Grund: `update_ranking` (result_processor.rb:224-237) laeuft die RK-Regeln in Endreihenfolge durch,
  # beginnt bei ix = 1 und schreibt `rankings[...]["rank"] = ix` — der Sieger hat also 1. Dieselbe
  # Schleife setzt jedoch `seedings.rank = ix + 1`, der Sieger dort also 2.
  #
  # EMPIRISCH BELEGT (2026-07-21, read-only auf carambus_bcw_development): zwei real gespielte Turniere
  # (16403 und 50000005) mit je 6 Spielern tragen `seedings.rank` von 2 bis 7 — nicht von 1 bis 6.
  # Der Versatz ist also real und kein Fehlverstaendnis der Schleife.
  #
  # ⚠️ Die Abweichung ist VORBESTEHEND und wird hier NICHT korrigiert (Boundary: result_processor und
  # final_rank bleiben unangetastet) — sie ist als Befund vermerkt. Nebenwirkung ausserhalb dieses
  # Plans: `Seeding#final_rank` faellt fuer lokal gespielte Turniere auf diese Spalte zurueck und
  # meldet damit durchweg Platzierung+1.
  #
  # Fuer die Gesamtrangliste ist der 1-basierte Wert der richtige: er entspricht der Platzierung, die
  # auch die ClubCloud liefert.
  def placement(values)
    rank = values["rank"]
    rank.present? ? rank.to_i : nil
  end

  def club_name_for(seeding)
    ::SeasonParticipation
      .where(player_id: seeding.player_id, season_id: @tournament.season_id)
      .includes(:club).first&.club&.name
  end

  def write(seeding, entry)
    self.class.write_gesamtrangliste(seeding, entry)
  end
end
