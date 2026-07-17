# frozen_string_literal: true

namespace :nu_liga do
  # Struktur-/Deckungs-Abgleich Carambus ↔ NuLiga (BBV). Reiner Read-only-Report — ändert nichts.
  #
  #   bin/rails nu_liga:compare_bbv
  #   FEDERATION=BBV REGION_ID=3 SEASON_ID=17 BRANCHES=Pool,Snooker bin/rails nu_liga:compare_bbv
  desc "Struktur-/Deckungs-Abgleich Carambus ↔ NuLiga (Clubs/Ligen/Teams/Player) für BBV — read-only Report"
  task compare_bbv: :environment do
    federation = ENV["FEDERATION"].presence || "BBV"
    region_id = (ENV["REGION_ID"] || 3).to_i
    season_id = (ENV["SEASON_ID"] || 17).to_i
    branches = ENV["BRANCHES"].present? ? ENV["BRANCHES"].split(",").map(&:strip) : NuLiga::Scraper::BRANCHES

    args = {federation: federation, region_id: region_id, season_id: season_id, branches: branches}
    report = NuLiga::Comparison.new(**args).run

    puts "=" * 72
    puts "NuLiga ↔ Carambus — Struktur-/Deckungs-Abgleich (read-only)"
    puts "federation=#{federation}  region_id=#{region_id}  season_id=#{season_id}  branches=#{branches.join(",")}"
    puts "=" * 72

    c = report[:clubs]
    puts
    puts "── CLUBS ──  matched=#{c[:matched]} (VNr=#{c[:matched_by_vnr]} / Name=#{c[:matched_by_name]})  " \
         "only_NuLiga=#{c[:only_nuliga].size}  only_Carambus=#{c[:only_carambus].size}  Namens-Mismatch=#{c[:mismatches].size}"
    print_nu_list("nur in NuLiga", c[:only_nuliga])
    print_nu_list("nur in Carambus", c[:only_carambus])
    unless c[:mismatches].empty?
      puts "   Namens-Mismatch (VNr matcht, Name weicht ab):"
      c[:mismatches].each { |m| puts "     VNr #{m[:vnr]}:  NuLiga «#{m[:nu]}»  ≠  CB «#{m[:cb]}»" }
    end

    %i[leagues teams].each do |section|
      s = report[section]
      puts
      puts "── #{section.to_s.upcase} ──  matched=#{s[:matched]}  only_NuLiga=#{s[:only_nuliga].size}  " \
           "only_Carambus=#{s[:only_carambus].size}  Namens-Mismatch=#{s[:mismatches].size}"
      print_nu_list("nur in NuLiga (= Import-Umfang)", s[:only_nuliga])
      print_nu_list("nur in Carambus", s[:only_carambus])
    end

    p = report[:players]
    puts
    puts "── PLAYERS ──  matched=#{p[:matched]}  ambiguous=#{p[:ambiguous].size}  nur-NuLiga(neu)=#{p[:only_nuliga].size}"
    print_nu_list("ambiguous (>1 Namenstreffer in Carambus)", p[:ambiguous].first(30))
    print_nu_list("nur in NuLiga (neu anzulegen)", p[:only_nuliga].first(30))

    puts
    puts "=" * 72
  end

  def print_nu_list(label, items)
    return if items.empty?

    puts "   #{label} (#{items.size}):"
    items.each { |i| puts "     #{i}" }
  end

  # Struktur-/Ergebnis-Import NuLiga → Carambus (BBV, Phasen 16/17/18). DRY-RUN default; ARMED=1 schreibt.
  # Nur Authority/Dev (Prod = Phase 18-02).
  #
  #   bin/rails nu_liga:import_bbv                                  # dry-run, current season (Warnung)
  #   ARMED=1 REGION_ID=3 SEASON_ID=17 BRANCHES=Pool bin/rails nu_liga:import_bbv         # eine Saison
  #   SEASONS=14,15,16,17 BRANCHES=Pool,Snooker bin/rails nu_liga:import_bbv              # mehrere Saisons (18-01)
  desc "Struktur-/Ergebnis-Import NuLiga → Carambus für BBV — dry-run default, ARMED=1 schreibt; SEASONS für Multi-Season"
  task import_bbv: :environment do
    federation = ENV["FEDERATION"].presence || "BBV"
    region_id = (ENV["REGION_ID"] || 3).to_i
    branches = ENV["BRANCHES"].present? ? ENV["BRANCHES"].split(",").map(&:strip) : NuLiga::Scraper::BRANCHES
    armed = ENV["ARMED"] == "1"
    season_ids = nu_liga_season_ids

    puts "=" * 72
    puts "NuLiga → Carambus — Import  #{armed ? "(ARMED — schreibt)" : "(DRY-RUN)"}"
    puts "federation=#{federation}  region_id=#{region_id}  seasons=#{season_ids.join(",")}  branches=#{branches.join(",")}"
    puts "=" * 72

    totals = Hash.new(0)
    season_ids.each do |season_id|
      report = NuLiga::Importer.new(
        federation: federation, region_id: region_id, season_id: season_id, branches: branches, armed: armed
      ).run
      print_import_report(report, season_id, armed)
      accumulate_import_totals(totals, report)
    end

    if season_ids.size > 1
      puts
      puts "── Σ ALLE SAISONS ──  leagues_created=#{totals[:leagues_created]}  teams_created=#{totals[:teams_created]}  " \
           "players_created=#{totals[:players_created]}  seedings_created=#{totals[:seedings_created]}  " \
           "parties_created=#{totals[:parties_created]}  games_created=#{totals[:games_created]}"
    end

    puts
    puts "=" * 72
  end

  # Täglicher NuLiga-Import für den laufenden Betrieb (BBV, Phase 18-03). ARMED fix. Saison via Probe
  # (neueste NuLiga-verfügbare — NICHT blind current_season, das ist auf NuLiga evtl. nicht vorhanden).
  # Cron-Ziel (schedule.rb, roles :api). Idempotent: import_party_games zieht nur Parties OHNE Spiele tief;
  # find-or-create/fill-if-empty schreiben nur bei echter Änderung → kein Version-Churn bei unverändertem Lauf.
  #   bin/rails nu_liga:daily_import
  desc "Täglicher NuLiga-Import (BBV, ARMED fix, aktuelle NuLiga-Saison via Probe) — Cron-Ziel"
  task daily_import: :environment do
    federation = ENV["FEDERATION"].presence || "BBV"
    region_id = (ENV["REGION_ID"] || 3).to_i
    branches = ENV["BRANCHES"].present? ? ENV["BRANCHES"].split(",").map(&:strip) : %w[Pool Snooker Karambol]

    season = NuLiga::Importer.current_nuliga_season(federation: federation, branch: branches.first)
    unless season
      warn "nu_liga:daily_import: keine NuLiga-verfügbare Saison gefunden (federation=#{federation}) — übersprungen."
      next
    end

    puts "=" * 72
    puts "NuLiga daily_import (ARMED)  federation=#{federation}  region_id=#{region_id}  " \
         "season=#{season.name}(id #{season.id})  branches=#{branches.join(",")}"
    puts "=" * 72
    report = NuLiga::Importer.new(
      federation: federation, region_id: region_id, season_id: season.id, branches: branches, armed: true
    ).run
    print_import_report(report, season.id, true)
    puts "=" * 72
  end

  # Saison-Auswahl: SEASONS (Kommaliste) > SEASON_ID (Einzel, abwärtskompatibel) > current_season (mit Warnung).
  # current NIE implizit ohne Warnung: auf re-synctem Dev ist current bereits außerhalb der NuLiga-Range.
  def nu_liga_season_ids
    if ENV["SEASONS"].present?
      ENV["SEASONS"].split(",").map { |s| s.strip.to_i }
    elsif ENV["SEASON_ID"].present?
      [ENV["SEASON_ID"].to_i]
    else
      cur = Season.current_season&.id
      warn "⚠ Weder SEASONS noch SEASON_ID gesetzt → nutze current_season=#{cur.inspect} " \
           "(auf re-synctem Dev ggf. außerhalb der NuLiga-Range — SEASONS explizit setzen!)"
      [cur].compact
    end
  end

  def print_import_report(report, season_id, armed)
    season_name = Season.find_by(id: season_id)&.name || "?"
    puts
    puts "── SAISON #{season_name} (id #{season_id}) ──"

    c = report[:clubs]
    puts "  CLUBS       matched=#{c[:matched]}  #{armed ? "updated" : "würde-updaten"}=#{c[:updated]}  " \
         "name_mismatch=#{c[:name_mismatches].size}  unmatched=#{c[:unmatched].size}"
    unless c[:name_mismatches].empty?
      puts "    Namens-Mismatch (VNr matcht, Name weicht ab — REVIEW):"
      c[:name_mismatches].each { |m| puts "      VNr #{m[:vnr]}:  NuLiga «#{m[:nu]}»  ≠  CB «#{m[:cb]}»" }
    end

    l = report[:leagues]
    puts "  LEAGUES     matched=#{l[:matched]}  #{armed ? "created" : "würde-anlegen"}=#{l[:created]}  " \
         "updated=#{l[:updated]}  skipped=#{l[:skipped].size}"
    print_nu_list("skipped (keine Discipline / Fehler)", l[:skipped])

    t = report[:teams]
    puts "  TEAMS       #{armed ? "created" : "würde-anlegen"}=#{t[:created]}  updated=#{t[:updated]}  " \
         "club_unmatched=#{t[:club_unmatched].size}  club_mismatch=#{t[:club_mismatch]&.size || 0}  " \
         "league_missing=#{t[:league_missing].size}"
    print_nu_list("club_unmatched (Team ohne VNr-Club)", t[:club_unmatched].first(20))
    print_nu_list("club_mismatch (VNr-Namens-Mismatch → club_id nil)", t[:club_mismatch] || [])

    p = report[:players]
    if p
      puts "  PLAYERS     matched=#{p[:matched]}  #{armed ? "created" : "würde-anlegen"}=#{p[:created]}  " \
           "ambiguous=#{p[:ambiguous].size}  sp_updated=#{p[:sp_updated]}"
      print_nu_list("ambiguous (>1 Namenstreffer)", p[:ambiguous].first(20))
    end

    s = report[:seedings]
    if s
      puts "  SEEDINGS    matched=#{s[:seedings_matched]}  #{armed ? "created" : "würde-anlegen"}=#{s[:seedings_created]}  " \
           "unmatched=#{s[:unmatched].size}"
    end

    pa = report[:parties]
    if pa
      puts "  PARTIES     matched=#{pa[:matched]}  #{armed ? "created" : "würde-anlegen"}=#{pa[:created]}  " \
           "filled=#{pa[:filled]}  unmatched=#{pa[:unmatched].size}  ligen_unverändert=#{pa[:skipped_unchanged]}"
      print_nu_list("unmatched (Begegnung ohne LeagueTeam)", pa[:unmatched].first(20))
    end

    pg = report[:party_games]
    if pg
      puts "  PARTY_GAMES parties_processed=#{pg[:parties_processed]}  #{armed ? "games_created" : "würde-anlegen"}=#{pg[:games_created]}  " \
           "players_unmatched=#{pg[:players_unmatched]}  disciplines_unmatched=#{pg[:disciplines_unmatched]}  parties_skipped=#{pg[:parties_skipped]}  meetings_failed=#{pg[:meetings_failed]}"
    end
  end

  def accumulate_import_totals(totals, report)
    totals[:leagues_created] += report.dig(:leagues, :created).to_i
    totals[:teams_created] += report.dig(:teams, :created).to_i
    totals[:players_created] += report.dig(:players, :created).to_i
    totals[:seedings_created] += report.dig(:seedings, :seedings_created).to_i
    totals[:parties_created] += report.dig(:parties, :created).to_i
    totals[:games_created] += report.dig(:party_games, :games_created).to_i
  end
end
