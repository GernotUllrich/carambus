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
end
