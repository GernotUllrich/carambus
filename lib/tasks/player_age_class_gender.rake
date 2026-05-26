# frozen_string_literal: true

# Plan 21-04 T3 / Slice C: NBV-Pilot-Rake-Task für PlayerAgeClassGenderHeuristic.
#
# Persistiert `players.age_class` + `players.gender` für Player mit qualifizierten seedings
# in den 2 abgeschlossenen Vorsaisons (analog 21-01 PlayerClassCalculator-Pattern).
# Authority-only (per [[project_clubcloud_scraping_authority_only]]) — globale Player-Writes;
# läuft auf carambus_api/master, KEIN ClubCloud-Login nötig (DB-only).
#
# Bekannte Datenlage NBV aus T1-Sniff (siehe .paul/phases/21-clubcloud-admin-scraping/
# 21-04-SNIFF-FINDINGS.md): Coverage 19.1% (NBV-home + active in 2 Vorsaisons), ~36% der
# qualifizierten Player bekommen age_class-Wert, ~95% gender-Wert. Konsistent mit 21-03-
# Defensiv-Bauen-Pattern: Infra ready, Daten dünn.
#
# Beispiel:
#   bin/rails players:heuristic_age_class_gender[NBV]     # NBV-Pilot
#   bin/rails players:heuristic_age_class_gender          # Default NBV
#
namespace :players do
  desc "Apply age_class/gender heuristic from seedings/category_ccs to players (Plan 21-04 Slice C, NBV-Pilot)"
  task :heuristic_age_class_gender, [:region] => :environment do |_t, args|
    region_abbr = (args[:region] || "NBV").upcase
    region = Region.find_by(shortname: region_abbr)
    raise "Region #{region_abbr} not found" if region.nil?

    puts "[players:heuristic_age_class_gender] region=#{region_abbr} (id=#{region.id})"
    puts "  current_season=#{Season.current_season&.name}"

    # Pre-Lauf-Counts (region-home Population — Slice-C-Scope = Player mit seedings,
    # aber die Persistierung wirkt auf via-seedings-erreichten Player. Hier zählt
    # die Heim-Region als Baseline für Coverage-Sanity.)
    scope = Player.where(region_id: region.id)
    before = {
      total_home: scope.count,
      with_age_class: scope.where.not(age_class: nil).count,
      with_gender: scope.where.not(gender: nil).count
    }
    puts "  before: total_home=#{before[:total_home]} " \
         "with_age_class=#{before[:with_age_class]} with_gender=#{before[:with_gender]}"

    result = PlayerAgeClassGenderHeuristic.call(region: region)

    after = {
      total_home: scope.count,
      with_age_class: scope.where.not(age_class: nil).count,
      with_gender: scope.where.not(gender: nil).count
    }
    puts "  after:  total_home=#{after[:total_home]} " \
         "with_age_class=#{after[:with_age_class]} with_gender=#{after[:with_gender]}"
    puts ""
    puts "  service-result:"
    puts "    seasons:        #{result.seasons.inspect}"
    puts "    visited:        #{result.visited}    (Player mit ≥1 qualifizierter seedings)"
    puts "    updated:        #{result.updated}    (Player mit ≥1 berechnetem Wert → DB-Update)"
    puts "    with_age_class: #{result.with_age_class}"
    puts "    with_gender:    #{result.with_gender}"
    puts "    both_null:      #{result.both_null}"
    puts "    skipped:        #{result.skipped} (= both_null, kein Update wegen NULL-Preservation)"
    puts ""
    puts format(
      "  delta:  with_age_class=%+d with_gender=%+d",
      after[:with_age_class] - before[:with_age_class],
      after[:with_gender] - before[:with_gender]
    )
  end
end
