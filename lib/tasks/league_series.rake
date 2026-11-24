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

# Übersicht „Liga-Einzelspiele je Region“ (League::SeriesTable) als statische Seite: index.html + data.json.
# Rein lesend. Die Seite lädt data.json per fetch, braucht also einen Webserver (oder Artifact-Publish).
#
# Usage:
#   bundle exec rake leagues:series_table                       # → tmp/league_series_table/
#   bundle exec rake leagues:series_table OUT=/tmp/ligen
namespace :leagues do
  desc "Tabelle Liga-Einzelspiele je Region erzeugen (OUT=Verzeichnis, Default tmp/league_series_table)"
  task series_table: :environment do
    out = Pathname(ENV["OUT"].presence || Rails.root.join("tmp/league_series_table"))
    FileUtils.mkdir_p(out)
    data = League::SeriesTable.new.call
    File.write(out.join("data.json"), JSON.generate(data))
    html = File.read(Rails.root.join("lib/templates/league_series_table.html"))
    File.write(out.join("index.html"), html.sub("__STAND__", Date.current.strftime("%d.%m.%Y")))

    data.each do |reg, r|
      dup = r["rows"].sum { |x| x[2].values.count { |c| c[4] == 1 } }
      puts "#{reg.ljust(5)} Ligen-Zeilen #{r["rows"].size} · Dubletten #{dup} · Hinweise #{r["rows"].count { |x| x[4] }}"
    end
    puts "Geschrieben: #{out}/index.html, data.json (#{File.size(out.join("data.json")) / 1024} KB)"
  end
end

# Dubletten-Paare des Reihen-Unifiers bereinigen (League::DuplicatePurger): je Paar bleibt die Anlage mit
# mehr Einzelspielen (dann: mehr aufgelösten), die andere wird samt Partien, Einzelspielen und Teams gelöscht.
# Die Löschung repliziert per PaperTrail an alle Server. Danach leagues:unify_series_names laufen lassen,
# damit der Überlebende den Reihennamen bekommt.
#
# Usage:
#   bundle exec rake leagues:purge_duplicates                  # DRY-RUN, alle Regionen
#   bundle exec rake leagues:purge_duplicates REGION=BLVN
#   bundle exec rake leagues:purge_duplicates ARMED=true
namespace :leagues do
  desc "Dubletten-Ligen löschen, die vollständigere Anlage bleibt (ARMED=true schreibt, sonst DRY-RUN)"
  task purge_duplicates: :environment do
    armed = ENV["ARMED"] == "true"
    region = ENV["REGION"].presence && Region.find_by!(shortname: ENV["REGION"])
    result = League::DuplicatePurger.new(region: region, armed: false).call
    fmt = ->(l, st) { format("%6d %-4s %-26s P%-4d G%-5d S%-5d T%-3d", l.id, l.cc_id ? "CC" : "BA", "#{l.read_attribute(:name)} #{l.staffel_text}".strip[0, 26], st[:parties], st[:games], st[:with_players], st[:teams]) }

    puts "Mode: #{armed ? "LIVE (ARMED)" : "DRY-RUN"} · Region: #{region&.shortname || "alle"}"
    puts "P = Partien, G = Einzelspiele, S = davon mit beiden Spielern, T = Teams"
    result.pairs.each do |p|
      puts "\n#{p.region.shortname} #{p.season}#{" — NICHT gelöscht: #{p.blocker}" if p.blocker}"
      puts "  behalten  #{fmt.call(p.keep, p.stats[p.keep.id])}"
      puts "  löschen   #{fmt.call(p.drop, p.stats[p.drop.id])}"
    end
    result.skipped.each { |ls| puts "\nÜbersprungen (#{ls.size} Ligen in einer Gruppe): #{ls.map(&:id).join(", ")}" }

    t = result.totals
    puts "\nZu löschen: #{t[:leagues]} Ligen, #{t[:parties]} Partien, #{t[:party_games]} Einzelspiele, " \
      "#{t[:league_teams]} Teams, #{t[:seedings]} Seedings (≈ #{t.values.sum} Versionen)"

    if armed
      result = League::DuplicatePurger.new(region: region, armed: true).call
      puts "Gelöscht: #{result.pairs.count { |p| !p.blocker } - result.errors.size} Ligen"
      result.errors.each { |e| puts "FEHLER #{e}" }
      puts "Jetzt: bundle exec rake leagues:unify_series_names ARMED=true"
    end
  end
end
