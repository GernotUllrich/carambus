# frozen_string_literal: true

# Ligen-Reihen vereinheitlichen (League::SeriesUnifier): jüngster Name für alle Saisons, frühere
# Namen in leagues.synonyms, Staffel-Schreibweise vereinheitlicht, Staffel aus dem Namen gelöst.
#
# Ausgabe je Liga: N = wird umbenannt, S = Staffel ändert sich, s = bekommt nur Synonyme,
# ! = Dublette (nicht angefasst), ? = Saison mit Ligen mit und ohne Staffel (Verdacht Doppelanlage).
#
# Usage:
#   bundle exec rake leagues:unify_series_names                      # DRY-RUN, alle Regionen
#   bundle exec rake leagues:unify_series_names REGION=NBV           # DRY-RUN, eine Region
#   bundle exec rake leagues:unify_series_names REGION=NBV CSV=/tmp/nbv.csv
#   bundle exec rake leagues:unify_series_names REGION=NBV ARMED=true
#
# Nur auf der Authority (globale Records, Versionen replizieren an alle Server) und erst, wenn
# alle Server die Migration AddSynonymsToLeagues haben. Prod nur nach Freigabe.
namespace :leagues do
  desc "Ligen-Reihen auf den jüngsten Namen vereinheitlichen (ARMED=true schreibt, sonst DRY-RUN)"
  task unify_series_names: :environment do
    armed = ENV["ARMED"] == "true"
    region = ENV["REGION"].presence && Region.find_by!(shortname: ENV["REGION"])
    result = League::SeriesUnifier.new(region: region, armed: armed).call

    puts "Mode: #{armed ? "LIVE (ARMED)" : "DRY-RUN"} · Region: #{region&.shortname || "alle"}"
    result.series.each do |s|
      changed = s.changes.select(&:changed?)
      next if changed.empty? && s.duplicates.empty?

      puts "\n#{s.region.shortname} · #{s.discipline.name} · → „#{s.canonical}“"
      s.changes.each do |c|
        # N = Name, S = Staffel, s = nur Synonyme
        mark = [c.renamed? ? "N" : " ", c.restaffeled? ? "S" : " ", (!c.renamed? && !c.restaffeled? && c.synonyms_changed?) ? "s" : " "].join
        staffel = if c.restaffeled?
          " [#{c.old_staffel.inspect} → #{c.new_staffel.inspect}]"
        elsif c.new_staffel
          " [#{c.new_staffel}]"
        end
        puts "  #{mark} #{c.season}  #{c.league.id.to_s.rjust(6)}  #{c.old_name}#{staffel}"
      end
      s.duplicates.each { |c| puts "  ! #{c.season}  #{c.league.id.to_s.rjust(6)}  #{c.old_name} [#{c.old_staffel}]  DUBLETTE, nicht angefasst" }
      puts "  ? Saisons mit und ohne Staffel: #{s.mixed_seasons.join(", ")}" if s.mixed_seasons.any?
    end

    changes = result.changes
    puts "\nReihen: #{result.series.count { |s| s.changes.any?(&:changed?) }} · Ligen zu ändern: #{changes.size} " \
      "(Name #{changes.count(&:renamed?)}, Staffel #{changes.count(&:restaffeled?)}) · " \
      "Dubletten: #{result.series.sum { |s| s.duplicates.size }}"
    result.errors.each { |e| puts "FEHLER #{e}" }

    if ENV["CSV"].present?
      require "csv"
      CSV.open(ENV["CSV"], "w") do |csv|
        csv << %w[region discipline canonical season league_id old_name new_name old_staffel new_staffel status]
        result.series.each do |s|
          s.changes.each { |c| csv << [s.region.shortname, s.discipline.name, s.canonical, c.season, c.league.id, c.old_name, c.new_name, c.old_staffel, c.new_staffel, c.changed? ? "change" : "keep"] }
          s.duplicates.each { |c| csv << [s.region.shortname, s.discipline.name, s.canonical, c.season, c.league.id, c.old_name, c.new_name, c.old_staffel, c.new_staffel, "duplicate"] }
        end
      end
      puts "CSV: #{ENV["CSV"]}"
    end
  end
end
