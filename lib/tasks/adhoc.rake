# frozen_string_literal: true

require "#{Rails.root}/app/helpers/application_helper"
require "aasm-diagram" if Rails.env == "development"

namespace :adhoc do
  desc "Current Test old"
  task test_old: :environment do
    Region.find_by_shortname("NBV").scrape_clubs_old(player_details: true)
  end

  desc "Current Test"
  task test: :environment do
    # Region.scrape_regions_cc
    # Region.find_by_shortname("DBU").scrape_clubs_cc
    # Club.find_duplicates
    # Season.find_by_name("2022/2023").scrape_single_tournaments_public_cc
    # Region.find_by_shortname("NBV").scrape_clubs(player_details: true)
    # Club.scrape_clubs(player_details: true, restrict_to_club_shortname: "BC Aalen")
    # Club[458].merge_clubs(2305)
    # Player.merge_players(Player[102], Player[8875])
    # Player.update_teams_fl_names
    # Player.merge_duplicates
    # Club.merge_duplicates
    # League.scrape_leagues_from_cc(Region.find_by_shortname("DBU"), Season.current_season, league_details: false)
    # Season.current_season.scrape_single_tournaments_public_cc
    # t = Tournament.last
    # tm = t.create_tournament_monitor!
    # puts tm.andand.attributes
    # Region.find_by_shortname("DBU").scrape_locations
    # Player.cross_domain_player_search("Gerd Schmitz")
    # Player.cross_domain_player_search("Arik Reiter")
    # Player.cross_domain_player_search("Rudolf Held")
    # Player.cross_domain_player_search("Andreas Fischer")
    # Player.cross_domain_player_search("Jürgen Adam")
    # Player.cross_domain_player_search("Alexander Koch")
    # Player.cross_domain_player_search("Klaus Schneider")
    # Player.cross_domain_player_search("Kevin Becker")
    # Player.analyse_duplicates(only_shortnames: "DBU", partial_recalc: true)
    # Player.analyse_duplicates
    # Player.merge_players_when_matching_club_and_dbu_nr
    # Club.merge_duplicates
    # Club.merge_duplicates_method_two
    # Player.merge_duplicates
    # Player.merge_duplicates_when_uniq_in_cc
    # Region.where(shortname: %w{BVRP BVNRW BVW BVS SBV TBV}).each {|r| r.scrape_clubs(player_details: true)}
    # Region.find_by_shortname("BVBW").scrape_locations
    # Location.scrape_locations
    # pm = PartyMonitor.last
    # res = pm.party.intermediate_result
    # puts "RESULT #{res.join(":")}"
    # Club.scrape_clubs(from_background: true, player_details: true)
    # Location.scrape_locations
    # tm = TableMonitor.new
    # AASMDiagram::Diagram.new(tm, 'doc/doc-local/table_monitor.png')
    # pm = PartyMonitor.new AASMDiagram::Diagram.new(pm, 'doc/doc-local/party_monitor.png')
    # League.scrape_leagues_from_cc(Region.find_by_shortname("BVBW"), Season.current_season, league_details: true,  first_five_parties_only: true, optimize_api_access: false)
    # Version.update_from_carambus_api
    # location = Tournament[242].match_location_from_location_text
    # Tournament[13215].scrape_single_tournament_public(reload_game_results: false)
    # Region[1].scrape_single_tournament_public(Season.current_season, optimize_api_access: true)
    # Location.scrape_locations
    # Region.where(cc_id:18).first.scrape_locations
    # Season.current_season.scrape_single_tournaments_public_cc(optimize_api_access: true)
    # @location = Location[1]
    # @tables = @location.tables.includes(:table_monitor)
    # @tables.map { |t| t.table_monitor.tournament_monitor_id }
    # tm = Tournament[15743].tournament_monitor
    # tm.update_ranking
    # season = Season.current_season
    # League.scrape_leagues_from_cc(Region.find_by_shortname("BVBW"), season, league_details: true, optimize_api_access: false)
    league = League[8695]
    league.scrape_single_league_from_cc(league_details: true)
  end

  desc "Sequence Reset"
  task sequence_reset: :environment do
    Version.sequence_reset
  end

  desc "fix source_urls"
  task fix_source_urls: :environment do
    Rails.application.eager_load!

    ActiveRecord::Base.descendants.each do |model|
      # Skip abstract models
      next if model.abstract_class?

      if model.column_names.include?('source_url')
        # this model has 'source_url' as a field
        model.where("source_url ilike '%ndbv.club-cloud.de%'").all.each do |m|
          m.source_url = m.source_url.gsub("ndbv.club-cloud.de", "ndbv.de")
          m.save
        end
        model.where("source_url ilike '%saar.club-cloud.de%'").all.each do |m|
          m.source_url = m.source_url.gsub("saar.club-cloud.de", "billard-ergebnisse.de")
          m.save
        end
        model.where("source_url ilike '%billard-union.net%'").all.each do |m|
          m.source_url = m.source_url.gsub("billard-union.net", "billard-ergebnisse.de")
          m.save
        end
        model.where("source_url ilike '%bvw.club-cloud.de%'").all.each do |m|
          m.source_url = m.source_url.gsub("bvw.club-cloud.de", "westfalenbillard.net")
          m.save
        end
        model.where("source_url ilike '%bbbv.club-cloud.de%'").all.each do |m|
          m.source_url = m.source_url.gsub("bbbv.club-cloud.de", "billard-brandenburg.net")
          m.save
        end
      end
    end
  end

  desc "fix season participations"
  task fix_season_participations: :environment do
    {
      "BC" => /(Billard-Club|Billardclub)/,
      "BSV" => nil,
      "BV" => /(Billard-Verein|Billardverein)/,
      "BV Pool" => nil,
      "LSV" => nil,
      "MSV" => nil,
      "PBC" => nil,
      "PC" => nil,
      "Pool" => nil,
      "SC" => nil,
      "SF" => nil,
      "SG" => nil,
      "SV" => nil,
      "TSG" => nil,
      "TSV" => nil,
      "TV" => nil,
      "VfB" => nil,
      "XXX" => nil,
      "XXXX" => nil
    }.each do |k, v|
      Club.where(name: k).each do |c|
        c.season_participations.each do |sp0|
          player = sp0.player
          clubs = sp0.player.season_participations.order(season_id: :desc).map { |spx|
            spx.club
          }.uniq
          club = clubs.select { |c| v.present? && c.name =~ v }.first
          club ||= clubs.select { |c| c.name != k }.first
          other_clubs = clubs.select { |c| (v.blank? || c.name !~ v) && c.name != k }
          if club.present?
            player.season_participations.each do |sp|
              spp = SeasonParticipation.where(club_id: club.id, player_id: player.id, season_id: sp.season_id).first
              if sp.club.name == k
                if spp.blank?
                  sp.club_id = club.id
                  sp.save
                else
                  sp.destroy
                end
              end
            end
          else
            sp0.destroy
          end
          if other_clubs.blank?
            sp0.destroy
          end
        end
        c.destroy
      end
    end
  end

  desc "Scrape NDBV Website"
  task scrape_ndbv_de: :environment do
    IonContent.scrape_website
  end

  desc "List module_type frequencies"
  task list_module_types: :environment do
    IonModule.list_module_types
  end

  desc "Scrape NDBV Website Images"
  task scrape_ndbv_de_images: :environment do
    IonContent.scrape_images
  end

  desc "Scrape NDBV Down loads"
  task scrape_downloads: :environment do
    IonContent.scrape_downloads
  end

  desc "populate_tables"
  task populate_tables: :environment do
    tm = TournamentMonitor[50000002]
    tm.populate_tables
  end

  desc "Melde Tournament"
  task test_add_tournament: :environment do
    url = "https://e12112e2454d41f1824088919da39bc0.club-cloud.de/admin/announcement/tournament/editTournamentSave.php"
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    req = Net::HTTP::Post.new(uri.request_uri)
    req["cookie"] = "PHPSESSID=9310db9a9970e8a02ed95ed8cd8e4309"
    req["Content-Type"] = "application/x-www-form-urlencoded"
    req.set_form_data(fedId: 20,
                      branchId: 10,
                      subBranchId: 3,
                      sportDistrictId: 7,
                      clubId: 1010,
                      stateId: "new",
                      tournamentId: 2,
                      title: "5. NordCup Dreiband",
                      dateFrom: "01.05.2022",
                      participants: 0,
                      description: "",
                      startgeld: 0,
                      preisgeld: 0,
                      infoLink: nil,
                      deadline: "08.04.2022",
                      selectedBranchId: 10,
                      selectedFrequenceId: 1,
                      selectedDisciplinId: 6,
                      selectedCategory: 1)
    res = http.request(req)
    res
  end

  desc "Spielerabgleich mit CC"
  task player_cc_matching: :environment do
    lines = []
    season = Season[2]
    Player
      .joins(club: :region)
      .joins(party_a_games: { party: { league: :season } })
      .joins(party_b_games: { party: { league: :season } })
      .where(seasons: { id: season.id })
      .where(regions: { id: 1 })
      .where("players.ba_id < 900000000")
      .order(:lastname).uniq.each do |p|
      next if p.firstname.blank?
      party_game_a_ids =
        p.party_a_games
         .joins(party: :league)
         .where(leagues: { season_id: season.id }).ids
      party_game_b_ids =
        p.party_b_games
         .joins(party: :league)
         .where(leagues: { season_id: season.id }).ids
      party_a_ids = Party.joins(:party_games).where(party_games: { id: party_game_a_ids }).map(&:id)
      party_b_ids = Party.joins(:party_games).where(party_games: { id: party_game_b_ids }).map(&:id)
      party_ids = Party.where(id: (party_a_ids + party_b_ids).uniq).ids
      league_team_a_ids = LeagueTeam.joins(:parties_a).where(parties: { id: party_a_ids }).ids
      league_team_b_ids = LeagueTeam.joins(:parties_b).where(parties: { id: party_b_ids }).ids
      league_teams = LeagueTeam.where(id: (league_team_a_ids + league_team_b_ids).uniq)
      league_teams.each do |league_team|
        lines.push([p.cc_id, p.lastname, p.firstname, league_team.league.discipline.andand.name, league_team.league.name, league_team.name, p.ba_id].join(";"))
      end
      f = lines.join("\n")
      f = "#{%w[PASS-NR NACHNAME VORNAME SPARTE LIGA MANNSCHAFT DBU-NR].join(";")}\n#{f}"
      # f = "#{%w{PASS-NR NACHNAME VORNAME SPARTE LIGA MANNSCHAFT DBU-NR}.join(";")}\n#{f}".encode("Windows-1252", crlf_newline: true)
      File.write("#{Rails.root}/tmp/#{season.name.tr("/", "-")}-players.csv", f)
    end
  end

  desc "test league scraping"
  task test_league_scraping: :environment do
    l = League[3553]
    l.scrape_single_league(game_details: true)
  end
  desc "test settings"
  task test_setting: :environment do
    Setting.connection
    Setting.key_delete(:admin_email)
  end
  desc "test version update"
  task test_version_update: :environment do
    Version.update_from_carambus_api(update_region_from_ba: 1, player_details: true)
  end

  desc "test_league 8"
  task test_league8: :environment do
    # League[3464].scrape_single_league(game_details: true)
    region = Region[1]
    season = Season[2]
    League.scrape_leagues_by_region_and_season(region, season, game_details: false, league_details: true)
  end

  task clean_local: :environment do
    TournamentMonitor.where("id > 50000000").destroy_all
    TableMonitor.where("id > 50000000").destroy_all
    Game.where("id > 50000000").destroy_all
    GameParticipation.where("id > 50000000").destroy_all
    Account.where("id > 50000000").destroy_all
    User.where("id > 50000000").destroy_all
  end

  task test_ko_plans: :environment do
    TournamentPlan.ko(20)
  end

  task test_player_id_from_ranking: :environment do
    tm = TournamentMonitor[50_000_018]
    player_id = tm.player_id_from_ranking("(g1.rk4 + g2.rk4 +g3.rk4).rk2")
    puts player_id
  end

  task test_accumulate_results: :environment do
    tm = TournamentMonitor[50_000_026]
    tm.accumulate_results
  end
end
