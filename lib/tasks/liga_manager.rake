# frozen_string_literal: true

namespace :liga_manager do
  # Struktur-Abgleich CC↔LigaManager (Pilot TBV). Reiner Read-only-Report — ändert nichts.
  #
  #   bin/rails liga_manager:compare_tbv
  #   ASSOCIATION_ID=1 REGION_ID=16 SEASON_ID=17 bin/rails liga_manager:compare_tbv
  desc "Struktur-Abgleich CC↔LigaManager (Clubs/Ligen/Teams) für TBV — read-only Report"
  task compare_tbv: :environment do
    association_id = (ENV["ASSOCIATION_ID"] || 1).to_i
    region_id = (ENV["REGION_ID"] || 16).to_i
    season_id = (ENV["SEASON_ID"] || 17).to_i

    report = LigaManager::TbvComparison.new(
      association_id: association_id, region_id: region_id, season_id: season_id
    ).run

    puts "=" * 72
    puts "LigaManager ↔ Carambus (CC) — Struktur-Abgleich"
    puts "association_id=#{association_id}  region_id=#{region_id}  season_id=#{season_id}  (read-only)"
    puts "=" * 72

    %i[clubs leagues teams].each do |section|
      s = report[section]
      puts
      puts "── #{section.to_s.upcase} ──  matched=#{s[:matched]}  only_LM=#{s[:only_lm].size}  " \
           "only_Carambus=#{s[:only_carambus].size}  Namens-Mismatch=#{s[:mismatches].size}"

      print_list("nur in LigaManager", s[:only_lm])
      print_list("nur in Carambus", s[:only_carambus])
      unless s[:mismatches].empty?
        puts "   Namens-Mismatch (gleicher Schlüssel, abweichender Name):"
        s[:mismatches].each { |m| puts "     #{m[:key]}:  LM «#{m[:lm]}»  ≠  CB «#{m[:cb]}»" }
      end
    end
    puts
    puts "=" * 72
  end

  def print_list(label, items)
    return if items.empty?

    puts "   #{label} (#{items.size}):"
    items.each { |i| puts "     #{i}" }
  end

  # Ergebnis-Abgleich CC↔LigaManager (Pilot TBV). Reiner Read-only-Report — ändert nichts.
  #
  #   bin/rails liga_manager:compare_tbv_results
  #   ASSOCIATION_ID=1 REGION_ID=16 SEASON_ID=17 bin/rails liga_manager:compare_tbv_results
  desc "Ergebnis-Abgleich CC↔LigaManager (Begegnungen + Mannschaftsergebnisse) für TBV — read-only Report"
  task compare_tbv_results: :environment do
    association_id = (ENV["ASSOCIATION_ID"] || 1).to_i
    region_id = (ENV["REGION_ID"] || 16).to_i
    season_id = (ENV["SEASON_ID"] || 17).to_i

    report = LigaManager::ResultComparison.new(
      association_id: association_id, region_id: region_id, season_id: season_id
    ).run
    t = report[:totals]

    puts "=" * 72
    puts "LigaManager ↔ Carambus (CC) — Ergebnis-Abgleich (Begegnungen)"
    puts "association_id=#{association_id}  region_id=#{region_id}  season_id=#{season_id}  (read-only)"
    puts "=" * 72

    report[:per_league].each do |l|
      cb_missing, real_diff = l[:result_mismatches].partition { |m| m[:cb].to_s.gsub(/\D/, "").empty? }
      puts
      puts "── #{l[:league]}"
      puts "   Begegnungen matched=#{l[:matched]}  Ergebnis-OK=#{l[:result_ok]}  " \
           "CB-ohne-Ergebnis=#{cb_missing.size}  echte-Abweichung=#{real_diff.size}  " \
           "only_LM=#{l[:only_lm].size}  only_CB=#{l[:only_carambus].size}"
      real_diff.each { |m| puts "     ⚠ ABWEICHUNG #{m[:key]}: LM «#{m[:lm]}» ≠ CB «#{m[:cb]}»" }
      unless cb_missing.empty?
        puts "     (CB ohne Ergebnis, LM vorhanden — Migrations-Lag, Beispiele:)"
        cb_missing.first(5).each { |m| puts "       #{m[:key]}: LM #{m[:lm]}" }
      end
    end

    puts
    puts "── GESAMT: Ligen=#{t[:matched_leagues]}  Begegnungen matched=#{t[:encounters_matched]}  " \
         "Ergebnis-OK=#{t[:result_ok]}  Ergebnis-Mismatch=#{t[:result_mismatch]}"
    puts "=" * 72
  end

  # Struktur-Import LigaManager → Carambus (TBV-Cutover, Phase 10). DRY-RUN default; ARMED=1
  # schreibt (source_url der gematchten Clubs/Ligen/Teams, versioniert → Sync). Nur Authority
  # (LocalProtector schützt globale Records auf Regional-Servern). cc_id/ba_id/dbu_nr unangetastet.
  #
  #   bin/rails liga_manager:import_structure
  #   ARMED=1 ASSOCIATION_ID=1 REGION_ID=16 SEASON_ID=17 bin/rails liga_manager:import_structure
  desc "Struktur-Import LigaManager→Carambus (Clubs/Ligen/Teams source_url). DRY-RUN default; ARMED=1 schreibt"
  task import_structure: :environment do
    association_id = (ENV["ASSOCIATION_ID"] || 1).to_i
    region_id = (ENV["REGION_ID"] || 16).to_i
    season_id = (ENV["SEASON_ID"] || 17).to_i
    armed = ENV["ARMED"] == "1"

    report = LigaManager::Importer.new(
      association_id: association_id, region_id: region_id, season_id: season_id, armed: armed
    ).run

    puts "=" * 72
    puts "LigaManager → Carambus — Struktur-Import  #{armed ? "ARMED (mutating)" : "DRY-RUN (read-only preview)"}"
    puts "association_id=#{association_id}  region_id=#{region_id}  season_id=#{season_id}"
    puts "=" * 72

    %i[clubs leagues teams players].each do |section|
      s = report[section]
      ambiguous = s[:ambiguous] || []
      puts
      puts "── #{section.to_s.upcase} ──  matched=#{s[:matched]}  " \
           "#{armed ? "source_url gesetzt" : "würde setzen"}=#{s[:updated]}  " \
           "#{"ambiguous=#{ambiguous.size}  " unless ambiguous.empty?}unmatched=#{s[:unmatched].size}"
      print_list("mehrdeutig (Namensträger)", ambiguous)
      print_list("ohne Match (nur LigaManager)", s[:unmatched])
    end

    sd = report[:seedings]
    puts
    puts "── SEEDINGS ──  matched=#{sd[:seedings_matched]}  " \
         "#{armed ? "angelegt" : "würde anlegen"}=#{sd[:seedings_created]}  " \
         "sp_provenienz=#{sd[:sp_updated]}  ambiguous=#{sd[:ambiguous].size}  unmatched=#{sd[:unmatched].size}"
    print_list("mehrdeutig (Namensträger)", sd[:ambiguous])
    print_list("ohne Match (Team/Roster)", sd[:unmatched])

    puts
    puts armed ? "Fertig (versioniert → Sync)." : "DRY-RUN: keine Änderung. ARMED=1 schreibt source_url/Seedings."
    puts "=" * 72
  end

  # Kuratierter Club-Identitäts-Fix: gibt namentlich eindeutigen, noch nummernlosen Region-Clubs die
  # echte LM-Nummer (cc_id=asso_no), damit reconcile_clubs sie matcht (z. B. SV Sömmerda → 1567).
  #   bin/rails liga_manager:fix_club_identity
  #   ARMED=1 REGION_ID=16 bin/rails liga_manager:fix_club_identity
  desc "Kuratierter Club-Identitäts-Fix cc_id=asso_no (z.B. SV Sömmerda 1567). DRY-RUN default; ARMED=1 schreibt"
  task fix_club_identity: :environment do
    association_id = (ENV["ASSOCIATION_ID"] || 1).to_i
    region_id = (ENV["REGION_ID"] || 16).to_i
    season_id = (ENV["SEASON_ID"] || 17).to_i
    armed = ENV["ARMED"] == "1"

    # Kuratierte, TBV-spezifische Fix-Liste (asso_no => Namensfragment). Bewusst klein/explizit.
    fixes = {1567 => "Sömmerda"}

    r = LigaManager::Importer.new(
      association_id: association_id, region_id: region_id, season_id: season_id, armed: armed
    ).assign_club_identity(fixes)

    puts "=" * 72
    puts "LigaManager → Carambus — Club-Identitäts-Fix  #{armed ? "ARMED (mutating)" : "DRY-RUN (read-only preview)"}"
    puts "region_id=#{region_id}"
    puts "=" * 72
    puts "cc_id #{armed ? "gesetzt" : "würde setzen"}=#{armed ? r[:assigned] : r[:would_assign]}  skipped=#{r[:skipped].size}"
    print_list("übersprungen (kein eindeutiger cc_id-nil-Treffer)", r[:skipped])
    puts
    puts armed ? "Fertig (versioniert → Sync)." : "DRY-RUN: keine Änderung. ARMED=1 schreibt cc_id."
    puts "=" * 72
  end
end
