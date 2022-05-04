# frozen_string_literal: true

require "#{Rails.root}/app/helpers/application_helper"

namespace :adhoc do
  desc 'Sequence Reset'
  task sequence_reset: :environment do
    Version.sequence_reset
  end

  desc 'Melde Tournament'
  task test_add_tournament: :environment do
    url = 'https://e12112e2454d41f1824088919da39bc0.club-cloud.de/admin/announcement/tournament/editTournamentSave.php'
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    req = Net::HTTP::Post.new(uri.request_uri)
    req['cookie'] = 'PHPSESSID=9310db9a9970e8a02ed95ed8cd8e4309'
    req['Content-Type'] = 'application/x-www-form-urlencoded'
    req.set_form_data(fedId: 20,
                      branchId: 10,
                      subBranchId: 3,
                      sportDistrictId: 7,
                      clubId: 1010,
                      stateId: 'new',
                      tournamentId: 2,
                      title: '5. NordCup Dreiband',
                      dateFrom: '01.05.2022',
                      participants: 0,
                      description: '',
                      startgeld: 0,
                      preisgeld: 0,
                      infoLink: nil,
                      deadline: '08.04.2022',
                      selectedBranchId: 10,
                      selectedFrequenceId: 1,
                      selectedDisciplinId: 6,
                      selectedCategory: 1)
    res = http.request(req)
    res
  end

  desc 'Spielerabgleich mit CC'
  task player_cc_matching: :environment do
    lines = []
    season = Season[2]
    Player
      .joins(club: :region)
      .joins(party_a_games: { party: { league: :season } })
      .where(seasons: { id: 2 })
      .where(regions: { id: 1 })
      .where('players.ba_id < 900000000')
      .order(:lastname).uniq.each do |p|
      next if p.firstname.blank?
      party_game_a_ids =
        p.party_a_games
         .joins(party: :league)
         .where(leagues: { season_id: 2 }).ids
      party_game_b_ids =
        p.party_b_games
         .joins(party: :league)
         .where(leagues: { season_id: 2 }).ids
      party_a_ids = Party.joins(:party_games).where(party_games: { id: party_game_a_ids }).map(&:id)
      party_b_ids = Party.joins(:party_games).where(party_games: { id: party_game_b_ids }).map(&:id)
      party_ids = Party.where(id: (party_a_ids + party_b_ids).uniq).ids
      league_team_a_ids = LeagueTeam.joins(:parties_a).where(parties: { id: party_a_ids }).ids
      league_team_b_ids = LeagueTeam.joins(:parties_b).where(parties: { id: party_b_ids }).ids
      league_teams = LeagueTeam.where(id: (league_team_a_ids + league_team_b_ids).uniq)
      league_teams.each do |league_team|
        lines.push([p.lastname, p.firstname, league_team.league.discipline.andand.name, league_team.league.name, league_team.name, p.ba_id].join(";"))
      end
      f = lines.join("\n")
      File.write("#{Rails.root}/tmp/#{season.name.gsub("\/", "-")}-players-no_pass-nr.csv", "#{%w{NACHNAME VORNAME SPARTE LIGA MANNSCHAFT DBU-NR}.join(";")}\n#{f}")

      # Player
      #   .joins(club: :region)
      #   .joins(party_a_games: { party: { league: :season } })
      #   .where(seasons: { id: 2 })
      #   .where(regions: { id: 1 })
      #   .order(:lastname)
      #   .where('players.ba_id > 900000000').uniq.each do |player|
      #   example_game = player.party_a_games
      #                        .joins(party: :league)
      #                        .where(leagues: { season_id: 2 }).first
      #   party = example_game.party
      #   league_team = party.league_team_a
      #   league = party.league
      #   url = "https://nbv.billardarea.de/cms_teams/show/#{league_team.ba_id}"
      #   Rails.logger.info "reading index page - to scrape league"
      #   html = open(url)
      #   doc = Nokogiri::HTML(html)
      #   links = doc.css("br+ .matchday_table a")
      #   links.map{|d| [d["href"], d.text]}.each do |arr|
      #     url, name_str = arr
      #     club_ba_id, player_ba_id = url.match(/.*\/(\d+)\/(\d+)$/).andand[1..2].map(&:to_i)
      #     club_ba_id
      #     name_str
      #     if "#{player.firstname} #{player.lastname}" == name_str
      #       #found player
      #       player.update(ba_id: player_ba_id, club_id: Club.find_by_ba_id(club_ba_id))
      #     end
      #   end
      # end
    end
  end

  desc 'test league scraping'
  task test_league_scraping: :environment do
    l = League.find_by_ba_id(776)
    l.scrape_single_league(game_details: true)
  end
  desc 'test settings'
  task test_setting: :environment do
    Setting.connection
    Setting.key_delete(:admin_email)
  end
  desc 'test version update'
  task test_version_update: :environment do
    Version.update_from_carambus_api(update_region_from_ba: 1, player_details: true)
  end

  desc 'test_league 8'
  task test_league8: :environment do
    #League[3464].scrape_single_league(game_details: true)
    region = Region[1]
    season = Season[2]
    League.scrape_leagues_by_region_and_season(region, season)
  end

  task clean_local: :environment do
    TournamentMonitor.where('id > 50000000').destroy_all
    TableMonitor.where('id > 50000000').destroy_all
    Game.where('id > 50000000').destroy_all
    GameParticipation.where('id > 50000000').destroy_all
    Account.where('id > 50000000').destroy_all
    User.where('id > 50000000').destroy_all
  end

  task test_player_id_from_ranking: :environment do
    tm = TournamentMonitor[50_000_018]
    player_id = tm.player_id_from_ranking('(g1.rk4 + g2.rk4 +g3.rk4).rk2')
    puts player_id
  end

  task test_accumulate_results: :environment do
    tm = TournamentMonitor[50_000_026]
    tm.accumulate_results
  end
end
