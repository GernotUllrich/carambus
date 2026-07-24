# frozen_string_literal: true

namespace :region_server do
  # Plan 28-01: Holt die MELDELISTE eines Region Servers auf die AUTHORITY (Pull, analog CC-Scrape)
  # und uebersetzt dabei die lokalen IDs der Quelle in globale Records. Der regulaere Versions-Sync
  # verteilt sie anschliessend an alle Instanzen — auch an den Location Server, wo gespielt wird.
  #
  # BLAST-RADIUS: genau EINE Region und EINE Saison. Keine Defaults — beides muss explizit angegeben
  # werden (ein implizites current_season hat beim CC-Rollover Schaden angerichtet).
  #
  # ⚠️ Spieler werden ueber dbu_nr AUFGELOEST, nie neu angelegt. Unaufloesbare Meldungen werden
  # berichtet und sind Nacharbeit — Stammdaten bleiben DBU-CC-gepflegt.
  #
  #   bin/rails region_server:import_entry_lists REGION=NBV SEASON=2026/2027            # dry-run
  #   ARMED=1 bin/rails region_server:import_entry_lists REGION=NBV SEASON=2026/2027    # schreibt
  #   BASE_URL=http://localhost:3001 bin/rails region_server:import_entry_lists ...     # abweichende Quelle
  desc "Meldeliste eines Region Servers auf die Authority holen — dry-run default, ARMED=1 schreibt"
  task import_entry_lists: :environment do
    shortname = ENV["REGION"].to_s.strip
    season_name = ENV["SEASON"].to_s.strip
    base_url = ENV["BASE_URL"].presence
    armed = ENV["ARMED"].present?

    if shortname.blank? || season_name.blank?
      puts "Usage: bin/rails region_server:import_entry_lists REGION=NBV SEASON=2026/2027 [ARMED=1] [BASE_URL=...]"
      exit 1
    end

    region = Region.find_by("UPPER(shortname) = ?", shortname.upcase)
    season = Season.find_by(name: season_name)
    abort "Region '#{shortname}' nicht gefunden" if region.nil?
    abort "Saison '#{season_name}' nicht gefunden" if season.nil?

    effective_base = base_url || "https://#{region.shortname.downcase}.carambus.de"

    puts "=" * 78
    puts "Meldelisten-Ingest #{region.shortname} #{season.name}"
    puts "Quelle: #{effective_base}"
    puts "Zugang: #{RegionServer::EntryListImporter.credential_source(region.shortname)}"
    puts armed ? "MODUS: ARMED — es wird geschrieben" : "MODUS: dry-run — es wird NICHTS geschrieben"
    puts "Blast-Radius: nur Region #{region.shortname}, nur Saison #{season.name}"
    puts "=" * 78

    begin
      result = RegionServer::EntryListImporter.new(
        region: region, season: season, base_url: base_url, armed: armed
      ).call
    rescue => e
      # Mehrzeilige Meldungen (fehlender Zugang) ungekuerzt durchreichen — ihr Wert ist die
      # Handlungsanweisung, und ein einzeiliges "Ingest abgebrochen: …" wuerde sie unlesbar machen.
      puts "\nIngest abgebrochen:"
      puts e.message
      exit 1
    end

    # Die Zaehler laufen im dry-run mit (sie sind seine eigentliche Information), gezaehlt wird
    # VOR dem Schreib-Abbruch. Ohne ARMED heisst "neu" deshalb "wuerde entstehen" — sonst liest
    # sich ein Probelauf wie ein vollzogener Import.
    konjunktiv = armed ? "" : " (würden)"
    ueberschrift = armed ? "Ergebnis:" : "Ergebnis des Probelaufs:"
    puts "\n#{ueberschrift}"
    puts "  Turniere neu#{konjunktiv}:              #{result.tournaments_created}"
    puts "  Turniere bereits vorhanden: #{result.tournaments_matched}"
    puts "  Turniere aktualisiert#{konjunktiv}:     #{result.tournaments_updated}"
    puts "  Meldungen neu#{konjunktiv}:             #{result.seedings_created}"
    puts "  Meldungen entfernt#{konjunktiv}:        #{result.seedings_removed}"
    puts "  ohne Quell-Kennung übersprungen: #{result.skipped_no_source_id}"
    puts "  Ergebnisse übernommen#{konjunktiv}:     #{result.rankings_imported}"
    puts "  Ergebnisse übersprungen (fremde Rangliste): #{result.rankings_skipped_foreign}"

    if result.players_unresolved.any?
      puts "\n⚠️  #{result.players_unresolved.size} Meldung(en) NICHT zuordenbar — diese Spieler kennt die"
      puts "    Authority nicht. Sie wurden NICHT angelegt (Stammdaten bleiben CC-gepflegt):"
      result.players_unresolved.each { |label| puts "      - #{label}" }
    end

    puts "\nDRY-RUN — für echtes Schreiben ARMED=1 setzen." unless armed
  end

  # Plan 32-10: Holt die SPIELERGEBNISSE eines Region Servers auf die AUTHORITY und baut daraus
  # globale Game/GameParticipation — in derselben Form, in der der CC-Scrape sie anlegt. Erst
  # dadurch erreichen CC-lose Ergebnisse das turnieruebergreifende Ranking.
  #
  # BLAST-RADIUS: genau EINE Region und EINE Saison. Keine Defaults (wie beim Meldelisten-Ingest).
  #
  # KEIN ZUGANG NOETIG: die Quelle ist oeffentlich (Betreiber-Entscheidung D9) — anders als der
  # Meldelisten-Ingest braucht dieser Lauf keinen Service-Account.
  #
  # ⚠️ Weder Turniere noch Spieler werden angelegt. Ein Turnier ohne source_url-Treffer wird
  # berichtet — es ist nie ueber den Meldelisten-Ingest gelaufen.
  #
  #   bin/rails region_server:import_game_results REGION=TBV SEASON=2026/2027            # dry-run
  #   ARMED=1 bin/rails region_server:import_game_results REGION=TBV SEASON=2026/2027    # schreibt
  #   BASE_URL=http://localhost:3001 bin/rails region_server:import_game_results ...     # abweichende Quelle
  desc "Spielergebnisse eines Region Servers auf die Authority holen — dry-run default, ARMED=1 schreibt"
  task import_game_results: :environment do
    shortname = ENV["REGION"].to_s.strip
    season_name = ENV["SEASON"].to_s.strip
    base_url = ENV["BASE_URL"].presence
    armed = ENV["ARMED"].present?

    if shortname.blank? || season_name.blank?
      puts "Usage: bin/rails region_server:import_game_results REGION=TBV SEASON=2026/2027 [ARMED=1] [BASE_URL=...]"
      exit 1
    end

    region = Region.find_by("UPPER(shortname) = ?", shortname.upcase)
    season = Season.find_by(name: season_name)
    abort "Region '#{shortname}' nicht gefunden" if region.nil?
    abort "Saison '#{season_name}' nicht gefunden" if season.nil?

    effective_base = base_url || "https://#{region.shortname.downcase}.carambus.de"

    puts "=" * 78
    puts "Ergebnis-Ingest #{region.shortname} #{season.name}"
    puts "Quelle: #{effective_base}/api/public/game_results (öffentlich, kein Zugang nötig)"
    puts armed ? "MODUS: ARMED — es wird geschrieben" : "MODUS: dry-run — es wird NICHTS geschrieben"
    puts "Blast-Radius: nur Region #{region.shortname}, nur Saison #{season.name}"
    puts "=" * 78

    begin
      result = RegionServer::GameResultImporter.new(
        region: region, season: season, base_url: base_url, armed: armed
      ).call
    rescue => e
      puts "\nIngest abgebrochen:"
      puts e.message
      exit 1
    end

    # Wie beim Meldelisten-Ingest laufen die Zaehler im dry-run mit — sie sind seine eigentliche
    # Information. Ohne ARMED heisst "neu" deshalb "wuerde entstehen".
    konjunktiv = armed ? "" : " (würden)"
    puts "\n#{armed ? "Ergebnis:" : "Ergebnis des Probelaufs:"}"
    puts "  Turniere zugeordnet:        #{result.tournaments_matched}"
    puts "  Turniere übersprungen (CC): #{result.tournaments_skipped_cc}"
    puts "  Spiele neu#{konjunktiv}:                #{result.games_created}"
    puts "  Spiele aktualisiert#{konjunktiv}:       #{result.games_updated}"
    puts "  Spiele unverändert:         #{result.games_unchanged}" if armed

    if result.tournaments_unmatched.any?
      puts "\n⚠️  #{result.tournaments_unmatched.size} Turnier(e) NICHT zuordenbar — sie sind nie über den"
      puts "    Meldelisten-Ingest gelaufen. Sie wurden NICHT angelegt:"
      result.tournaments_unmatched.each { |url| puts "      - #{url}" }
    end

    if result.players_unresolved.any?
      puts "\n⚠️  #{result.players_unresolved.size} Spiel(e) NICHT zuordenbar — diese Spieler kennt die"
      puts "    Authority nicht. Sie wurden NICHT angelegt (Stammdaten bleiben CC-gepflegt):"
      result.players_unresolved.each { |label| puts "      - #{label}" }
    end

    puts "\nDRY-RUN — für echtes Schreiben ARMED=1 setzen." unless armed
  end
end
