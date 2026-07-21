# frozen_string_literal: true

namespace :tournaments do
  # Plan 27-01: Kaltstart-Hilfe für einen Verband, der von der ClubCloud auf Carambus wechselt.
  # Kopiert die TURNIER-STRUKTUR einer abgelaufenen Saison in eine Zielsaison — Datum um n·52 Wochen
  # verschoben (Wochentag bleibt erhalten), als Entwurf angelegt (data["draft"]).
  #
  # BLAST-RADIUS: genau EINE Region und EINE Zielsaison. Keine Defaults — Region und beide Saisons
  # müssen explizit angegeben werden (ein implizites current_season hat beim CC-Rollover Schaden
  # angerichtet).
  #
  # ⚠️ Kopiert NIEMALS Ergebnisse, Seedings, Spiele oder fremde Provenienz (ba_id/source_url/...).
  #
  #   bin/rails tournaments:copy_season REGION=NBV FROM=2024/2025 TO=2026/2027           # dry-run
  #   ARMED=1 bin/rails tournaments:copy_season REGION=NBV FROM=2024/2025 TO=2026/2027   # schreibt
  desc "Turnier-Struktur einer Saison in eine Zielsaison kopieren (Entwürfe) — dry-run default, ARMED=1 schreibt"
  task copy_season: :environment do
    shortname = ENV["REGION"].to_s.strip
    from_name = ENV["FROM"].to_s.strip
    to_name = ENV["TO"].to_s.strip
    armed = ENV["ARMED"].present?

    if shortname.blank? || from_name.blank? || to_name.blank?
      puts "Usage: bin/rails tournaments:copy_season REGION=NBV FROM=2024/2025 TO=2026/2027 [ARMED=1]"
      exit 1
    end

    region = Region.find_by("UPPER(shortname) = ?", shortname.upcase)
    from_season = Season.find_by(name: from_name)
    to_season = Season.find_by(name: to_name)

    abort "Region '#{shortname}' nicht gefunden" if region.nil?
    abort "Saison '#{from_name}' nicht gefunden" if from_season.nil?
    abort "Saison '#{to_name}' nicht gefunden" if to_season.nil?

    puts "=" * 78
    puts "Saison-Kopie #{region.shortname}: #{from_season.name} → #{to_season.name}"
    puts armed ? "MODUS: ARMED — es wird geschrieben" : "MODUS: dry-run — es wird NICHTS geschrieben"
    puts "Blast-Radius: nur Region #{region.shortname}, nur Zielsaison #{to_season.name}"
    puts "=" * 78

    result = Tournament::SeasonCopier.new(
      region: region, from_season: from_season, to_season: to_season, armed: armed
    ).call

    if result.planned.any?
      puts "\nTurniere, die kopiert werden#{" würden" unless armed}:"
      result.planned.each do |row|
        puts format("  %-45s %s → %s", row[:title].to_s[0, 45], row[:from], row[:to])
      end
    end

    puts "\nErgebnis:"
    puts "  angelegt:              #{result.created}"
    puts "  übersprungen (Kopie existiert): #{result.skipped_existing}"
    puts "  übersprungen (kein brauchbares Datum): #{result.skipped_no_date}"
    puts "\nHinweis: Kopien sind Entwürfe und in der Turnierliste ausgeblendet." if result.created.positive?
    puts "Sichtbar über den Umschalter „Entwürfe anzeigen“ (/tournaments?drafts=1)." if result.created.positive?
    puts "\nDRY-RUN — für echtes Schreiben ARMED=1 setzen." unless armed
  end

  # Plan 29-02: Trägt die Gesamtrangliste für bereits abgeschlossene Turniere nach.
  #
  # Im Normalbetrieb schreibt sie der Turnier-Abschluss selbst (ResultProcessor#write_final_ranking).
  # Dieser Task ist für zwei Fälle da: (1) Turniere, die vor der Einführung abgeschlossen wurden,
  # (2) ein erneuter Lauf, falls der Writer je korrigiert werden muss — die Entscheidung für den
  # Schreib-Adapter (29-01 §5.0) nimmt in Kauf, dass Fehler persistiert werden; der Preis dafür ist
  # bezahlbar, solange ein Nachlauf genügt und kein Reparaturskript nötig ist.
  #
  # BLAST-RADIUS: genau EINE Region und EINE Saison. Keine Defaults.
  #
  # ⚠️ Aus der ClubCloud gescrapte Gesamtranglisten werden NIE überschrieben — nur eigene.
  #
  #   bin/rails tournaments:write_final_rankings REGION=NBV SEASON=2025/2026           # dry-run
  #   ARMED=1 bin/rails tournaments:write_final_rankings REGION=NBV SEASON=2025/2026   # schreibt
  desc "Gesamtrangliste abgeschlossener Turniere nachtragen — dry-run default, ARMED=1 schreibt"
  task write_final_rankings: :environment do
    shortname = ENV["REGION"].to_s.strip
    season_name = ENV["SEASON"].to_s.strip
    armed = ENV["ARMED"].present?

    if shortname.blank? || season_name.blank?
      puts "Usage: bin/rails tournaments:write_final_rankings REGION=NBV SEASON=2025/2026 [ARMED=1]"
      exit 1
    end

    region = Region.find_by("UPPER(shortname) = ?", shortname.upcase)
    season = Season.find_by(name: season_name)
    abort "Region '#{shortname}' nicht gefunden" if region.nil?
    abort "Saison '#{season_name}' nicht gefunden" if season.nil?

    puts "=" * 78
    puts "Gesamtrangliste nachtragen #{region.shortname} #{season.name}"
    puts armed ? "MODUS: ARMED — es wird geschrieben" : "MODUS: dry-run — es wird NICHTS geschrieben"
    puts "Blast-Radius: nur Region #{region.shortname}, nur Saison #{season.name}"
    puts "=" * 78

    totals = Hash.new(0)
    Tournament
      .where(season_id: season.id, organizer_type: "Region", organizer_id: region.id)
      .order(:date).each do |tournament|
      result = Tournament::FinalRankingWriter.new(tournament: tournament, armed: armed).call

      totals[:seedings] += result.seedings_written
      totals[:no_monitor] += result.skipped_no_monitor
      totals[:discipline] += result.skipped_discipline
      totals[:no_results] += result.skipped_no_results
      totals[:foreign] += result.skipped_foreign_result
      next unless result.seedings_written.positive?

      totals[:tournaments] += 1
      puts format("  %-45s %d Meldungen", tournament.title.to_s[0, 45], result.seedings_written)
    end

    puts "\nErgebnis:"
    puts "  Turniere mit Rangliste:        #{totals[:tournaments]}"
    puts "  geschriebene Platzierungen:    #{totals[:seedings]}"
    puts "  übersprungen (kein Monitor):   #{totals[:no_monitor]}"
    puts "  übersprungen (nicht Karambol): #{totals[:discipline]}"
    puts "  übersprungen (keine Ergebnisse): #{totals[:no_results]}"
    puts "  übersprungen (fremde Rangliste): #{totals[:foreign]}"
    puts "\nDRY-RUN — für echtes Schreiben ARMED=1 setzen." unless armed
  end

  # Plan 29-03: Meldet den Abschluss eines Turniers an den Region Server nach.
  #
  # Im Normalbetrieb geschieht das automatisch beim Turnier-Abschluss
  # (ResultProcessor#report_final_ranking). Dieser Task ist der Nachtrag, wenn die Meldung damals
  # scheiterte — etwa weil im Vereinslokal das Netz weg war. Genau dafür ist der Abschluss
  # fehlertolerant gebaut: er läuft durch, und die Meldung holt man hiermit nach.
  #
  # LÄUFT AUF DEM LOCATION SERVER (dort liegen die erspielten Ergebnisse).
  # BLAST-RADIUS: genau EIN Turnier.
  #
  #   bin/rails tournaments:report_results TOURNAMENT=12345            # dry-run
  #   ARMED=1 bin/rails tournaments:report_results TOURNAMENT=12345    # meldet
  desc "Turnier-Abschluss an den Region Server nachmelden — dry-run default, ARMED=1 meldet"
  task report_results: :environment do
    tournament_id = ENV["TOURNAMENT"].to_s.strip
    armed = ENV["ARMED"].present?

    if tournament_id.blank?
      puts "Usage: bin/rails tournaments:report_results TOURNAMENT=12345 [ARMED=1]"
      exit 1
    end

    tournament = Tournament.find_by(id: tournament_id)
    abort "Turnier '#{tournament_id}' nicht gefunden" if tournament.nil?

    puts "=" * 78
    puts "Abschluss nachmelden: #{tournament.title} (##{tournament.id})"
    puts "Ziel: #{tournament.source_url.presence || "— kein source_url, nichts zu melden"}"
    puts armed ? "MODUS: ARMED — es wird gemeldet" : "MODUS: dry-run — es wird NICHTS gemeldet"
    puts "Blast-Radius: nur dieses eine Turnier"
    puts "=" * 78

    begin
      result = LocationServer::ResultReporter.new(tournament: tournament, armed: armed).call
    rescue => e
      abort "Meldung abgebrochen: #{e.message}"
    end

    puts "\nErgebnis:"
    puts "  zu meldende Platzierungen:      #{result.reported}"
    puts "  übersprungen (kein source_url): #{result.skipped_no_source_url}"
    puts "  übersprungen (keine eigene Rangliste): #{result.skipped_no_own_ranking}"
    puts "  Antwort des Region Servers:     #{result.response.inspect}" if result.response.present?

    if result.skipped_no_source_url.positive?
      puts "\nHinweis: Ohne source_url gibt es keinen Region Server, der dieses Turnier führt —"
      puts "         es stammt vermutlich aus der ClubCloud."
    end
    puts "\nDRY-RUN — für echtes Melden ARMED=1 setzen." unless armed
  end
end
