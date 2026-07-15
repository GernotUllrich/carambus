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
  # SEASON_ID ist optional: ohne Angabe wird Season.current_season verwendet (Phase 12).
  desc "Struktur-Import LigaManager→Carambus (Clubs/Ligen/Teams source_url). DRY-RUN default; ARMED=1 schreibt"
  task import_structure: :environment do
    association_id = (ENV["ASSOCIATION_ID"] || 1).to_i
    region_id = (ENV["REGION_ID"] || 16).to_i
    season_id = LigaManager::Importer.resolve_season_id
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

    pt = report[:parties]
    puts
    puts "── PARTIES ──  matched=#{pt[:matched]}  " \
         "#{armed ? "angelegt" : "würde anlegen"}=#{pt[:created]}  " \
         "#{armed ? "Ergebnis gefüllt" : "würde füllen"}=#{pt[:filled]}  " \
         "source_url=#{pt[:updated]}  unmatched=#{pt[:unmatched].size}"
    print_list("ohne Match (Team/Liga fehlt in Carambus)", pt[:unmatched])

    pg = report[:party_games]
    puts
    puts "── PARTY_GAMES ──  parties=#{pg[:parties_processed]}  " \
         "#{armed ? "angelegt" : "würde anlegen"}=#{pg[:games_created]}  " \
         "spieler_offen=#{pg[:players_unmatched]}  disziplin_offen=#{pg[:disciplines_unmatched]}  " \
         "übersprungen=#{pg[:parties_skipped]}"

    puts
    puts armed ? "Fertig (versioniert → Sync)." : "DRY-RUN: keine Änderung. ARMED=1 schreibt source_url/Seedings/Parties/Einzelspiele."
    puts "=" * 72
  end

  # Laufender TBV-Import aus dem LigaManager (Phase 12 v0.4 Cutover-Betrieb). Dedizierter Cron-Ziel-Task:
  # ARMED fix, TBV (association_id=1, region_id=16), Zielsaison = Season.current_season (rollt automatisch).
  # Ersetzt den abgeschalteten CC-Scrape für TBV. Verdrahtet in config/schedule.rb (täglich, roles :api).
  #   bin/rails liga_manager:daily_import
  desc "Laufender TBV-Import aus LigaManager (ARMED, current season) — Cron-Ziel-Task (Phase 12)"
  task daily_import: :environment do
    season_id = LigaManager::Importer.resolve_season_id
    report = LigaManager::Importer.new(
      association_id: 1, region_id: 16, season_id: season_id, armed: true
    ).run

    cl = report[:clubs]
    sd = report[:seedings]
    pt = report[:parties]
    pg = report[:party_games]
    puts "LigaManager daily_import (TBV, season_id=#{season_id}) — ARMED"
    puts "  clubs source_url=#{cl[:updated]}  seedings angelegt=#{sd[:seedings_created]}  " \
         "parties angelegt=#{pt[:created]}/gefüllt=#{pt[:filled]}  einzelspiele angelegt=#{pg[:games_created]}"
    puts "Fertig (versioniert → Sync)."
  end

  # GamePlan-Rekonstruktion aus vorhandenen Carambus-Spieldaten (NICHT aus LigaManager — LM liefert die
  # Regelparameter Aufnahmen/Satzziel/Punkte/Bretter nicht). Nutzt das Bestandswerkzeug.
  #   bin/rails liga_manager:reconstruct_game_plans            # dry-run: zählt Ligen ohne game_plan
  #   ARMED=1 REGION_ID=16 SEASON_ID=17 bin/rails liga_manager:reconstruct_game_plans
  # READ-ONLY GamePlan-Abgleich: der GamePlan ist saisonstabil (ändert sich CC→LM nicht). Prüft je Liga
  # die GamePlan-Spielanzahl gegen die LM-Spielanzahl einer Beispielbegegnung. Erwartet 0 Diskrepanzen.
  # Bewusst KEIN Rekonstruieren/Schreiben (reconstruct_game_plans_for_season wirkt saisonweit/alle Regionen).
  #   bin/rails liga_manager:check_game_plans
  desc "READ-ONLY Abgleich bestehender GamePlans gegen die LM-Spielstruktur (erwartet 0 Diskrepanzen)"
  task check_game_plans: :environment do
    association_id = (ENV["ASSOCIATION_ID"] || 1).to_i
    region_id = (ENV["REGION_ID"] || 16).to_i
    season_id = (ENV["SEASON_ID"] || 17).to_i

    rows = LigaManager::Importer.new(
      association_id: association_id, region_id: region_id, season_id: season_id
    ).check_game_plans

    puts "=" * 72
    puts "GamePlan-Abgleich (READ-ONLY, GamePlan ist saisonstabil)  region_id=#{region_id} season_id=#{season_id}"
    puts "=" * 72
    rows.sort_by { |r| r[:status].to_s }.each do |r|
      puts "  [#{r[:status]}]  #{r[:league]}  GamePlan-Spiele=#{r[:gameplan_games].inspect}  LM-Spiele=#{r[:lm_games].inspect}"
    end
    disc = rows.count { |r| r[:status] == :discrepancy }
    puts
    puts "Diskrepanzen: #{disc} (erwartet 0)  ·  ok=#{rows.count { |r| r[:status] == :ok }}  ·  " \
         "ohne GamePlan=#{rows.count { |r| r[:status] == :no_game_plan }}  ·  " \
         "ohne LM=#{rows.count { |r| %i[no_lm_league no_lm_report].include?(r[:status]) }}"
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
