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

  # Struktur-Import NuLiga → Carambus (BBV, Phase 16). DRY-RUN default; ARMED=1 schreibt
  # (reconcile_clubs source_url + create_leagues/create_teams). Nur Authority/Dev (Prod = Phase 18).
  #
  #   bin/rails nu_liga:import_bbv                      # dry-run
  #   ARMED=1 REGION_ID=3 SEASON_ID=17 BRANCHES=Pool bin/rails nu_liga:import_bbv
  desc "Struktur-Import NuLiga → Carambus (Clubs/Leagues/Teams) für BBV — dry-run default, ARMED=1 schreibt"
  task import_bbv: :environment do
    federation = ENV["FEDERATION"].presence || "BBV"
    region_id = (ENV["REGION_ID"] || 3).to_i
    season_id = (ENV["SEASON_ID"] || 17).to_i
    branches = ENV["BRANCHES"].present? ? ENV["BRANCHES"].split(",").map(&:strip) : NuLiga::Scraper::BRANCHES
    armed = ENV["ARMED"] == "1"

    report = NuLiga::Importer.new(
      federation: federation, region_id: region_id, season_id: season_id, branches: branches, armed: armed
    ).run

    puts "=" * 72
    puts "NuLiga → Carambus — Struktur-Import  #{armed ? "(ARMED — schreibt)" : "(DRY-RUN)"}"
    puts "federation=#{federation}  region_id=#{region_id}  season_id=#{season_id}  branches=#{branches.join(",")}"
    puts "=" * 72

    c = report[:clubs]
    puts
    puts "── CLUBS ──  matched=#{c[:matched]}  #{armed ? "updated" : "würde-updaten"}=#{c[:updated]}  " \
         "name_mismatch=#{c[:name_mismatches].size}  unmatched=#{c[:unmatched].size}"
    unless c[:name_mismatches].empty?
      puts "   Namens-Mismatch (VNr matcht, Name weicht ab — REVIEW):"
      c[:name_mismatches].each { |m| puts "     VNr #{m[:vnr]}:  NuLiga «#{m[:nu]}»  ≠  CB «#{m[:cb]}»" }
    end

    l = report[:leagues]
    puts
    puts "── LEAGUES ──  matched=#{l[:matched]}  #{armed ? "created" : "würde-anlegen"}=#{l[:created]}  " \
         "updated=#{l[:updated]}  skipped=#{l[:skipped].size}"
    print_nu_list("skipped (keine Discipline / Fehler)", l[:skipped])

    t = report[:teams]
    puts
    puts "── TEAMS ──  #{armed ? "created" : "würde-anlegen"}=#{t[:created]}  updated=#{t[:updated]}  " \
         "club_unmatched=#{t[:club_unmatched].size}  club_mismatch=#{t[:club_mismatch]&.size || 0}  " \
         "league_missing=#{t[:league_missing].size}"
    print_nu_list("club_unmatched (Team ohne VNr-Club)", t[:club_unmatched].first(20))
    print_nu_list("club_mismatch (VNr-Namens-Mismatch → club_id nil)", t[:club_mismatch] || [])

    p = report[:players]
    if p
      puts
      puts "── PLAYERS ──  matched=#{p[:matched]}  #{armed ? "created" : "würde-anlegen"}=#{p[:created]}  " \
           "ambiguous=#{p[:ambiguous].size}  sp_updated=#{p[:sp_updated]}"
      print_nu_list("ambiguous (>1 Namenstreffer)", p[:ambiguous].first(20))
    end

    s = report[:seedings]
    if s
      puts
      puts "── SEEDINGS ──  matched=#{s[:seedings_matched]}  #{armed ? "created" : "würde-anlegen"}=#{s[:seedings_created]}  " \
           "unmatched=#{s[:unmatched].size}"
    end

    puts
    puts "=" * 72
  end
end
