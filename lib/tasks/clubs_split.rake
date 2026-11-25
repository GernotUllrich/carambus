# frozen_string_literal: true

# Zwei verschiedene Vereine, die in einem Club-Datensatz stecken, wieder trennen (2026-11-25: PBC Würselen 81 +
# BC Phoenix Übach-Palenberg, BV Underground Osnabrück + SV Neu Zauche, BSV Wuppertal 1929 + 1999 Pool).
# Entstanden durch früheres merge_clubs bzw. einen cc_id-Abgleich ohne Region; before_save :update_synonyms
# hielt den fremden Namen danach als Synonym fest, und der nächtliche Vereins-Scrape schrieb beide Vereine
# abwechselnd auf denselben Datensatz.
#
# CLUB (A) behält seine Heimat (club_cc_entries) und bekommt dort seine cc_id zurück. Neu angelegt wird B mit
# den angegebenen Stammdaten; NAME/SHORTNAME/SYNONYMS wandern aus A's Synonymen zu B. Umgehängt werden:
#   - LeagueTeams von A, die TEAMS_NAME (ILIKE-Muster) bzw. TEAMS_REGION (Liga-Region) treffen
#   - SeasonParticipations von A, deren Spieler in dieser Saison nur in umgehängten Teams gemeldet sind
#     (Seedings). Teilnahmen ohne Team bleiben bei A — sie lassen sich nicht zuordnen.
#   - club_cc_entries von A in B's Region mit B's cc_id
# Alles per update!/create! → Versionen (Sync). Ohne ARMED=true nur Probelauf (Transaktion wird zurückgerollt).
#
# Usage:
#   bundle exec rake clubs:split CLUB=3294 NAME="Billard Club Phoenix Übach-Palenberg 1996 e.V." \
#     SHORTNAME="BC Phoenix Übach-Palenberg" REGION=BLMR CC_ID=6306 DBU_NR=1628 TEAMS_NAME="%phoenix%" [ARMED=true]
namespace :clubs do
  desc "Vermischten Verein trennen (CLUB NAME SHORTNAME REGION CC_ID [DBU_NR SYNONYMS TEAMS_NAME TEAMS_REGION] ARMED=true)"
  task split: :environment do
    armed = ENV["ARMED"] == "true"
    a = Club.find(ENV.fetch("CLUB"))
    region = Region.find_by!(shortname: ENV.fetch("REGION"))
    cc_id = ENV.fetch("CC_ID").to_i
    b_names = [ENV.fetch("NAME"), ENV.fetch("SHORTNAME"), *ENV["SYNONYMS"].to_s.split("|")].map(&:strip).reject(&:blank?).uniq
    teams_name = ENV["TEAMS_NAME"].presence
    teams_region = ENV["TEAMS_REGION"].presence && Region.find_by!(shortname: ENV["TEAMS_REGION"])

    abort "#{a.shortname}[#{a.id}]: eigener Name/Kurzname steht in NAME/SHORTNAME/SYNONYMS — erst A richtig benennen" if
      (b_names & [a.name, a.shortname]).any?
    other = Club.where(region_id: region.id, cc_id: cc_id).where.not(id: a.id).pick(:id) ||
      ClubCcEntry.where(region_id: region.id, cc_id: cc_id).where.not(club_id: a.id).pick(:club_id)
    abort "#{region.shortname} cc_id #{cc_id} gehört schon Verein #{other}" if other
    home = ClubCcEntry.find_by(club_id: a.id, region_id: a.region_id)

    puts armed ? "ARMED — schreibe" : "Probelauf (ARMED=true zum Schreiben)"
    ActiveRecord::Base.transaction do
      b = Club.create!(name: b_names[0], shortname: b_names[1], region_id: region.id, cc_id: cc_id,
        dbu_nr: ENV["DBU_NR"].presence&.to_i, synonyms: b_names.join("\n"),
        source_url: ClubCloudPublicClient.new(base_url: region.public_cc_url_base, fed_id: region.cc_id).url_for("cbdet.php", a: cc_id))
      puts "neu: #{b.shortname}[#{b.id}] #{region.shortname} cc_id #{cc_id}"

      kept = a.synonyms.to_s.split("\n").map(&:strip) - b_names
      a.synonyms = kept.join("\n")
      a.cc_id = home.cc_id if home
      puts "#{a.shortname}[#{a.id}]: Synonyme ohne #{b_names.inspect}, cc_id #{a.cc_id_was} → #{a.cc_id}" if a.changed?
      a.save!

      teams = LeagueTeam.where(club_id: a.id).joins(:league)
      teams = teams.where("league_teams.name ILIKE ?", teams_name) if teams_name
      teams = teams.where(leagues: {organizer_type: "Region", organizer_id: teams_region.id}) if teams_region
      teams = LeagueTeam.none unless teams_name || teams_region
      moved = teams.to_a
      moved.each { |lt| lt.update!(club_id: b.id) }
      puts "LeagueTeams → #{b.shortname}: #{moved.size}#{" (#{moved.map(&:name).uniq.first(4).join(", ")})" if moved.any?}"

      moved_ids = moved.map(&:id)
      remaining_ids = LeagueTeam.where(club_id: a.id).pluck(:id)
      team_season = LeagueTeam.joins(:league).where(id: moved_ids + remaining_ids).pluck("league_teams.id", "leagues.season_id").to_h
      seen = Seeding.where(league_team_id: team_season.keys).pluck(:player_id, :league_team_id)
      in_b = seen.select { |_, lt| moved_ids.include?(lt) }.map { |p, lt| [p, team_season[lt]] }.to_set
      in_a = seen.reject { |_, lt| moved_ids.include?(lt) }.map { |p, lt| [p, team_season[lt]] }.to_set
      sps = SeasonParticipation.where(club_id: a.id).select { |sp| in_b.include?([sp.player_id, sp.season_id]) && !in_a.include?([sp.player_id, sp.season_id]) }
      sps.each { |sp| sp.update!(club_id: b.id) }
      puts "SeasonParticipations → #{b.shortname}: #{sps.size} (bei #{a.shortname} bleiben #{SeasonParticipation.where(club_id: a.id).count})"

      entries = ClubCcEntry.where(club_id: a.id, region_id: region.id, cc_id: cc_id)
      puts "club_cc_entries → #{b.shortname}: #{entries.update_all(club_id: b.id)}"
      ClubCcEntry.record!(b, region, cc_id)

      raise ActiveRecord::Rollback unless armed
    end
  end

  # Spielort nach clubs:split dem richtigen Verein zuordnen: club_locations-Zeile von A auf B umhängen. Hat B den
  # Ort schon, entfällt A's Zuordnung. Andere Vereine am selben Ort bleiben unberührt.
  #   bundle exec rake clubs:move_locations MOVES="<location>:<von club>:<zu club>,…" [ARMED=true]
  desc "Spielorte zwischen Vereinen umhängen (MOVES=location:von:zu,… ARMED=true)"
  task move_locations: :environment do
    armed = ENV["ARMED"] == "true"
    puts armed ? "ARMED — schreibe" : "Probelauf (ARMED=true zum Schreiben)"
    ClubLocation.suppressing_turbo_broadcasts do
      ENV.fetch("MOVES").split(",").map(&:strip).each do |spec|
        location_id, from_id, to_id = spec.split(":").map(&:to_i)
        cl = ClubLocation.find_by(location_id: location_id, club_id: from_id)
        to = Club.find_by(id: to_id)
        if cl.nil? || to.nil?
          puts "#{spec}: übersprungen — Zuordnung Ort #{location_id} ↔ Verein #{from_id} oder Zielverein fehlt"
          next
        end

        label = "#{cl.location.name} [#{location_id}]: #{cl.club.shortname}[#{from_id}] → #{to.shortname}[#{to_id}]"
        if ClubLocation.exists?(location_id: location_id, club_id: to_id)
          puts "#{label} — Ziel hat den Ort schon, Zuordnung von #{from_id} entfällt"
          cl.destroy! if armed
        else
          puts label
          cl.update!(club_id: to_id) if armed
        end
      end
    end
  end
end
