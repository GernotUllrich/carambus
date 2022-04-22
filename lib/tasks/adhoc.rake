require "#{Rails.root}/app/helpers/application_helper"

namespace :adhoc do

  desc "Melde Tournament"
  task :test_add_tournament => :environment do
    url = "https://e12112e2454d41f1824088919da39bc0.club-cloud.de/admin/announcement/tournament/editTournamentSave.php"
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    req = Net::HTTP::Post.new(uri.request_uri)
    req["cookie"] = "PHPSESSID=9310db9a9970e8a02ed95ed8cd8e4309"
    req['Content-Type'] = 'application/x-www-form-urlencoded'
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

  desc "test league scraping"
  task :test_league_scraping => :environment do
    l = League.first
    l.scrape_single_league
  end
  desc "test settings"
  task :test_setting => :environment do
    Setting.connection
    Setting.key_delete(:admin_email)

  end

  task :test_league8 => :environment do
    League[358].scrape_single_league(game_details: true)
  end

  task :clean_local => :environment do
    TournamentMonitor.where("id > 50000000").destroy_all
    TableMonitor.where("id > 50000000").destroy_all
    Game.where("id > 50000000").destroy_all
    GameParticipation.where("id > 50000000").destroy_all
    Account.where("id > 50000000").destroy_all
    User.where("id > 50000000").destroy_all
  end

  task :test_player_id_from_ranking => :environment do
    tm = TournamentMonitor[50000018]
    player_id = tm.player_id_from_ranking("(g1.rk4 + g2.rk4 +g3.rk4).rk2")
    puts player_id
  end

  task :test_accumulate_results => :environment do
    tm = TournamentMonitor[50000026]
    tm.accumulate_results
  end

end

