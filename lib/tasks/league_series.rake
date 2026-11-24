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
#   bundle exec rake leagues:purge_duplicates REGION=BLVN PLACEHOLDERS=true   # + leere BA-Platzhalter
namespace :leagues do
  desc "Dubletten-Ligen löschen, die vollständigere Anlage bleibt (ARMED=true schreibt, sonst DRY-RUN)"
  task purge_duplicates: :environment do
    armed = ENV["ARMED"] == "true"
    region = ENV["REGION"].presence && Region.find_by!(shortname: ENV["REGION"])
    placeholders = ENV["PLACEHOLDERS"] == "true"
    result = League::DuplicatePurger.new(region: region, armed: false, placeholders: placeholders).call
    fmt = ->(l, st) { format("%6d %-4s %-26s P%-4d G%-5d S%-5d T%-3d", l.id, l.cc_id ? "CC" : "BA", "#{l.read_attribute(:name)} #{l.staffel_text}".strip[0, 26], st[:parties], st[:games], st[:with_players], st[:teams]) }

    puts "Mode: #{armed ? "LIVE (ARMED)" : "DRY-RUN"} · Region: #{region&.shortname || "alle"}"
    puts "P = Partien, G = Einzelspiele, S = davon mit beiden Spielern, T = Teams"
    result.pairs.each do |p|
      puts "\n#{p.region.shortname} #{p.season}#{" — NICHT gelöscht: #{p.blocker}" if p.blocker}"
      puts "  behalten  #{fmt.call(p.keep, p.stats[p.keep.id])}"
      puts "  löschen   #{fmt.call(p.drop, p.stats[p.drop.id])}"
    end
    result.skipped.each { |ls| puts "\nÜbersprungen (#{ls.size} Ligen in einer Gruppe): #{ls.map(&:id).join(", ")}" }
    if result.placeholders.any?
      puts "\nPlatzhalter ohne Partien (werden gelöscht):"
      result.placeholders.each { |l| puts format("  %6d %-5s %s  %s%s", l.id, l.organizer.shortname, l.season&.name, l.read_attribute(:name), l.staffel_text.present? ? " [#{l.staffel_text}]" : "") }
    end

    t = result.totals
    puts "\nZu löschen: #{t[:leagues]} Ligen, #{t[:parties]} Partien, #{t[:party_games]} Einzelspiele, " \
      "#{t[:league_teams]} Teams, #{t[:seedings]} Seedings (≈ #{t.values.sum} Versionen)"

    if armed
      result = League::DuplicatePurger.new(region: region, armed: true, placeholders: placeholders).call
      puts "Gelöscht: #{result.pairs.count { |p| !p.blocker } + result.placeholders.size - result.errors.size} Ligen"
      result.errors.each { |e| puts "FEHLER #{e}" }
      puts "Jetzt: bundle exec rake leagues:unify_series_names ARMED=true"
    end
  end
end

# CC-Rollover-Reste einer Region und Saison abräumen (League::CcGhostPurger): Teams, die nicht in der
# LIVE-Teamliste der CC stehen (samt ihren Alt-Partien), und Ligen, die die CC nicht kennt. Holt dazu je
# Liga die öffentliche CC-Spielplanseite. Löschungen replizieren per PaperTrail an alle Server.
#
# Usage:
#   bundle exec rake leagues:purge_cc_ghosts REGION=BVS SEASON=2025/2026              # DRY-RUN
#   bundle exec rake leagues:purge_cc_ghosts REGION=BVS SEASON=2025/2026 ARMED=true
namespace :leagues do
  desc "CC-Rollover-Reste löschen: Teams/Ligen, die die CC live nicht führt (ARMED=true schreibt)"
  task purge_cc_ghosts: :environment do
    armed = ENV["ARMED"] == "true"
    region = Region.find_by!(shortname: ENV.fetch("REGION"))
    season = Season.find_by!(name: ENV.fetch("SEASON"))
    result = League::CcGhostPurger.new(region: region, season: season).call

    puts "Mode: #{armed ? "LIVE (ARMED)" : "DRY-RUN"} · #{region.shortname} #{season.name}"
    result.findings.each do |f|
      label = format("%6d %-28s", f.league.id, "#{f.league.read_attribute(:name)} #{f.league.staffel_text}".strip[0, 28])
      if f.skipped
        puts "  #{label} übersprungen: #{f.skipped}"
      elsif f.hull
        puts "  #{label} HÜLLE (CC kennt cc_id #{f.league.cc_id} nicht): Liga mit #{Party.where(league_id: f.league.id).count} Partien, #{LeagueTeam.where(league_id: f.league.id).count} Teams"
      elsif f.ghosts.any? || f.blocked.any?
        puts "  #{label} CC #{f.cc_team_ids.size} Teams · Geister #{f.ghosts.size} (#{f.ghost_parties.size} Partien)" \
          "#{" · BLOCKIERT #{f.blocked.map(&:id).join(",")}" if f.blocked.any?}"
      end
    end
    t = result.totals
    puts "\nZu löschen: #{t[:leagues]} Ligen, #{t[:league_teams]} Teams, #{t[:parties]} Partien, #{t[:party_games]} Einzelspiele, #{t[:seedings]} Seedings"
    result.errors.each { |e| puts "FEHLER #{e}" }

    if armed
      done = League::CcGhostPurger.new(region: region, season: season, armed: true).call
      puts "Gelöscht. Fehler: #{done.errors.size}"
      done.errors.each { |e| puts "FEHLER #{e}" }
    end
  end
end

# Bestehende CC-Ligen einer Region und Saison neu scrapen (ClubCloudScraper, league_details: true, OHNE
# cleanup — parse_parties ist find-or-create, legt nichts doppelt an). Für abgeschlossene Saisons, die der
# tägliche Scrape (nur current_season) nicht mehr erfasst, z. B. nach einem Scraper-Fix.
# Broadcast-frei; neue Partien/Einzelspiele erzeugen Versionen (Sync an alle Server).
#
# Usage:
#   bundle exec rake leagues:rescrape_season REGION=BLVN SEASON=2022/2023
#   bundle exec rake leagues:rescrape_season REGION=BLVN SEASON=2022/2023 LEAGUE_IDS=8119,8126
namespace :leagues do
  desc "CC-Ligen einer Region und Saison neu scrapen, ohne cleanup (REGION, SEASON, optional LEAGUE_IDS)"
  task rescrape_season: :environment do
    region = Region.find_by!(shortname: ENV.fetch("REGION"))
    season = Season.find_by!(name: ENV.fetch("SEASON"))
    leagues = League.where(organizer: region, season: season).where.not(cc_id: nil).order(:id)
    leagues = leagues.where(id: ENV["LEAGUE_IDS"].split(",").map(&:to_i)) if ENV["LEAGUE_IDS"].present?
    count = ->(l) { [Party.where(league_id: l.id).count, PartyGame.joins(:party).where(parties: {league_id: l.id}).count, LeagueTeam.where(league_id: l.id).count] }

    puts "Rescrape #{region.shortname} #{season.name}: #{leagues.count} Ligen · (Partien, Einzelspiele, Teams)"
    sums = [[0, 0, 0], [0, 0, 0]]
    leagues.each do |l|
      before = count.call(l)
      League.skip_cable_ready_updates do
        Party.skip_cable_ready_updates do
          PartyGame.skip_cable_ready_updates { l.scrape_single_league_from_cc(league_details: true) }
        end
      end
      after = count.call(l)
      sums = [sums[0].zip(before).map(&:sum), sums[1].zip(after).map(&:sum)]
      puts format("  %6d %-34s %s → %s", l.id, "#{l.read_attribute(:name)} #{l.staffel_text}".strip[0, 34], before.inspect, after.inspect)
    end
    puts "Summe: #{sums[0].inspect} → #{sums[1].inspect}  (Abbrüche stehen als „Fatal Error“ in log/production.log)"
  end
end

# LeagueTeams ohne Liga löschen (League::OrphanTeamPurger): Reste von League#destroy, an denen nichts mehr
# hängt (keine Seedings, Partien, LeagueTeamCc). Regionsübergreifend; Versionen ohne region_id erreichen
# jeden Server (dort harmloses delete).
#
# Usage:
#   bundle exec rake leagues:purge_orphan_teams              # DRY-RUN
#   bundle exec rake leagues:purge_orphan_teams ARMED=true
namespace :leagues do
  desc "LeagueTeams ohne Liga und ohne Verweise löschen (ARMED=true schreibt, sonst DRY-RUN)"
  task purge_orphan_teams: :environment do
    armed = ENV["ARMED"] == "true"
    result = League::OrphanTeamPurger.new.call

    puts "Mode: #{armed ? "LIVE (ARMED)" : "DRY-RUN"} · alle Regionen"
    teams = LeagueTeam.where(id: result.orphans)
    by_region = teams.left_joins(:club).group("clubs.region_id").count
    names = Region.where(id: by_region.keys.compact).pluck(:id, :shortname).to_h
    by_region.sort_by { |_, n| -n }.each { |rid, n| puts format("  %-8s %5d", names[rid] || "(ohne)", n) }
    puts "\nTeams ohne Liga: #{result.orphans.size} frei, #{result.blocked.size} blockiert (haben noch Verweise)"
    puts "  blockiert: #{result.blocked.first(20).join(",")}#{" …" if result.blocked.size > 20}" if result.blocked.any?
    if armed
      done = League::OrphanTeamPurger.new(armed: true).call
      puts "Gelöscht: #{done.deleted} · Fehler: #{done.errors.size}"
      done.errors.each { |e| puts "FEHLER #{e}" }
    end
  end
end
