# frozen_string_literal: true

# == Schema Information
#
# Table name: region_ccs
#
#  id         :bigint           not null, primary key
#  base_url   :string
#  context    :string
#  name       :string
#  public_url :string
#  shortname  :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  cc_id      :integer
#  region_id  :integer
#
# Indexes
#
#  index_region_ccs_on_cc_id_and_context  (cc_id,context) UNIQUE
#  index_region_ccs_on_context            (context) UNIQUE
#
class RegionCc < ApplicationRecord
  belongs_to :region
  has_many :branch_ccs

  alias_attribute :fedId, :cc_id

  REPORT_LOGGER_FILE = "#{Rails.root}/log/report.log"
  REPORT_LOGGER = Logger.new(REPORT_LOGGER_FILE)

  DEBUG = true

  STATUS_MAP = {
    active: 1,
    passive: 2
  }.freeze

  PATH_MAP = { # maps to path and read_only {true|false}|}
               'home' => ['', true],
               # "showClubList" => "/admin/approvement/player/showClubList.php",
               'createLeagueSave' => ['/admin/league/createLeagueSave.php', true],
               # fedId: 20
               # branchId: 10
               # subBranchId: 2
               # seasonId: 11
               # seasonId: 11
               # leagueName: Oberliga Dreiband
               # leagueShortName: OD
               # reportId: 20
               # prefix: 0
               # staffelName:
               # sportdistrictId: 0
               # sbut:
               'showLeagueList' => ['/admin/report/showLeagueList.php', true],
               'showLeague' => ['/admin/league/showLeague.php', true],

               'admin_report_showLeague' => ['/admin/report/showLeague.php', true],
               # branchId: 6
               # fedId: 20
               # subBranchId: 1
               # seasonId: 8
               # leagueId: 34
               'admin_report_showLeague_create_team' => ['/admin/report/showLeague_create_team.php', false],
               # teamCounter: 2
               # fedId: 20
               # leagueId: 32
               # branchId: 6
               # subBranchId: 1
               # seasonId: 8
               'spielbericht_anzeigen' => ['/admin/reportbuilder2/spielbericht_anzeigen.php', true],
               # p=#{fedId}-#{branchId}-#{cc_id}-&    cc_id vom GamePlanCc
               'showTeam' => ['/admin/announcement/team/showTeam.php', true],
               # fedId: 20,
               # branchId: 6,
               # subBranchId: 1,
               # sportDistrictId: *,
               # clubId: 1004,
               # originalBranchId: 6,
               # seasonId: 1,
               # teamId: 98
               'editTeam' => ['admin/announcement/team/editTeamCheck.php', false],
               'showClubList' => ['/admin/announcement/team/showClubList.php', true],
               # fedId: 20
               # branchId: 6
               # subBranchId: 11
               # sportDistrictId: *
               # statusId: 1   (1 = active)
               'showLeague_show_teamplayer' => ['/admin/report/showLeague_show_teamplayer.php', true],
               # GET
               # p: 187
               'showLeague_add_teamplayer' => ['/admin/report/showLeague_add_teamplayer.php', false],
               # fedId: 20,
               # leagueId: 34,
               # staffelId: 0,
               # branchId: 6,
               # subBranchId: 1,
               # seasonId: 8,
               # p: 187,
               # passnr: 221109,
               'spielbericht' => ['/admin/bm_mw/spielbericht.php', true],
               # errMsgNew:
               # matchId: 572
               # teamId: 189
               # woher: 1
               # firstEntry: 1
               #  ODER ?!
               # sortKey: NAME
               # branchid: 6
               # woher: 1
               # wettbewerb: 1
               # sportkreis: *
               # saison: 2010/2011
               # partienr: 4003
               # seekBut:
               'showLeague_create_team_save' => ['/admin/report/showLeague_create_team_save.php', false],
               # fedId: 20
               # leagueId: 61
               # branchId: 10
               # subBranchId: 2
               # seasonId: 11
               # ncid: 1573   TODO was ist ncid
               # sbut:
               'spielberichte' => ["/admin/reportbuilder2/spielberichte.php", true],
               # GET Request
               # p: "#{fedId}-#{branchId}"
               'spielberichtCheck' => ['/admin/bm_mw/spielberichtCheck.php', true],
               "spielberichtSave" => ['/admin/bm_mw/spielberichtSave.php', false],
               # "errMsgNew:
               #  fedId: 20
               #  branchId: 6
               #  subBranchId: 1
               #  wettbewerb: 1
               #  leagueId: 34
               #  seasonId: 8
               #  teamId: 185
               #  matchId: 571
               #  saison: 2010/2011
               #  partienr: 4003
               #  woher: 1
               #  woher2: 1
               #  editBut: "
               #  TODO ODER MIT GET-REQUEST??
               #
               # a: 703     party_cc.match_id
               # b: 2        ???
               # c: 193>    team cc_id

               # memo: Die Partien von Florian Knipfer wurden aus der Wertung gestrichen, wegen Einsatz als Ersatz-Spieler in der Bundesliga !!
               # protest:
               # zuNullTeamId: 0
               # wettbewerb: 1
               # partienr: 4004
               # saison:
               # 572-1-1-1-pid1: 10130
               # 572-1-1-1-pid2: 10353
               # 572-1-1-sc1: 125
               # 572-1-1-sc2: 70
               # 572-1-1-in1: 46
               # 572-1-1-in2: 45
               # 572-1-1-br1: 13
               # 572-1-1-br2: 10
               # 572-1-1-vo1:
               # 572-1-1-vo2:
               # 572-2-1-1-pid1: 10243
               # 572-2-1-1-pid2: 0
               # 572-2-1-sc1: 0
               # 572-2-1-sc2: 0
               # 572-2-1-in1:
               # 572-2-1-in2:
               # 572-2-1-br1:
               # 572-2-1-br2:
               # 572-2-1-vo1:
               # 572-2-1-vo2:
               # 572-3-1-1-pid1: 0
               # 572-3-1-1-pid2: 10121
               # 572-3-1-sc1: 9
               # 572-3-1-sc2: 4
               # 572-3-1-in1:
               # 572-3-1-in2:
               # 572-3-1-br1:
               # 572-3-1-br2:
               # 572-3-1-vo1:
               # 572-3-1-vo2:
               # 572-4-1-1-pid1: 0
               # 572-4-1-1-pid2: 10108
               # 572-4-1-sc1: 2
               # 572-4-1-sc2: 8
               # 572-4-1-in1:
               # 572-4-1-in2:
               # 572-4-1-br1:
               # 572-4-1-br2:
               # 572-4-1-vo1:
               # 572-4-1-vo2:
               # 572-6-1-1-pid1: 0
               # 572-6-1-1-pid2: 0
               # 572-6-1-sc1: 8
               # 572-6-1-sc2: 4
               # 572-6-1-in1:
               # 572-6-1-in2:
               # 572-6-1-br1:
               # 572-6-1-br2:
               # 572-6-1-vo1:
               # 572-6-1-vo2:
               # 572-7-1-1-pid1: 0
               # 572-7-1-1-pid2: 10108
               # 572-7-1-sc1: 9
               # 572-7-1-sc2: 6
               # 572-7-1-in1:
               # 572-7-1-in2:
               # 572-7-1-br1:
               # 572-7-1-br2:
               # 572-7-1-vo1:
               # 572-7-1-vo2:
               # 572-8-1-1-pid1: 10130
               # 572-8-1-1-pid2: 10121
               # 572-8-1-sc1: 7
               # 572-8-1-sc2: 5
               # 572-8-1-in1:
               # 572-8-1-in2:
               # 572-8-1-br1:
               # 572-8-1-br2:
               # 572-8-1-vo1:
               # 572-8-1-vo2:
               # 572-9-1-1-pid1: 10243
               # 572-9-1-1-pid2: 0
               # 572-9-1-sc1:
               # 572-9-1-sc2:
               # 572-9-1-in1:
               # 572-9-1-in2:
               # 572-9-1-br1:
               # 572-9-1-br2:
               # 572-9-1-vo1:
               # 572-9-1-vo2:
               'massChangingCheck' => ['/admin/report/massChangingCheck.php', true],
               # fedId: 20,
               # leagueId: 34,
               # branchId: 6,
               # subBranchId: 1,
               # seasonId: 8,
               # staffelId:
               "massChangingCheckAuth" => ["/admin/report/massChangingCheckAuth.php", true]
               #https://e12112e2454d41f1824088919da39bc0.club-cloud.de/admin/report/massChangingCheckAuth.php?

               # teamCounter: 10
               # fedId: 20
               # leagueId: 36
               # branchId: 6
               # subBranchId: 1
               # seasonId: 8
               # editAll:
               # matchId: 715
  }

  # PHPSESSID = "3e7da06b0149fe5ad787246fc7a0e2b4"
  BASE_URL = 'https://e12112e2454d41f1824088919da39bc0.club-cloud.de'

  def self.logger
    REPORT_LOGGER
  end

  def self.save_log(name)
    FileUtils.mv(REPORT_LOGGER_FILE, "#{Rails.root}/log/#{name}.log")
    REPORT_LOGGER.reopen
  end

  def fix(opts = {})
    armed = opts.delete(:armed)
    if opts[:name].present?
      if armed
        RegionCc.logger.info "NOT_IMPLEMENTED fix region_name to \"#{opts[:name]}\""
      else
        RegionCc.logger.info "WILL fix region_name to \"#{opts[:name]}\""
      end
    else
      raise ArgumentError
    end
  rescue Exceptions => e
    e
  end

  def post_cc(action, post_options = {}, opts = {})
    dry_run = opts[:armed].blank?
    referer = post_options.delete(:referer)
    referer = referer.present? ? base_url + referer : nil
    if PATH_MAP[action].present?
      url = base_url + PATH_MAP[action][0]
      read_only_action = PATH_MAP[action][1]
      if read_only_action
        Rails.logger.debug "[#{action}] POST #{PATH_MAP[action][0]} with payload #{post_options}" if DEBUG
      else
        # read_only
        RegionCc.logger.debug "[#{action}] #{'WILL' if dry_run} POST #{action} #{PATH_MAP[action][0]} with payload #{post_options}"
      end
      doc = nil; res = nil
      if !dry_run || read_only_action
        uri = URI(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        req = Net::HTTP::Post.new(uri.request_uri)
        req['cookie'] = "PHPSESSID=#{opts[:session_id]}"
        req['Content-Type'] = 'application/x-www-form-urlencoded'
        req['referer'] = referer if referer.present?
        req.set_form_data(post_options.reject { |_k, v| v.blank? })
        res = http.request(req)
        doc = if res.message == 'OK'
                Nokogiri::HTML(res.body)
              else
                Nokogiri::HTML(res.message)
              end
      end
    end
    return res, doc
  end

  def get_cc(action, get_options = {}, opts = {})
    if PATH_MAP[action].present?
      get_options[:referer] ||= ""
      url = base_url + PATH_MAP[action][0]
      get_cc_with_url(action, url, get_options, opts)
    else
      raise ArgumentError, 'Unknown Action', caller
    end
  end

  def get_cc_with_url(action, url, get_options = {}, opts = {})
    referer = base_url + get_options.delete(:referer)
    Rails.logger.debug "[post_cc] POST #{action} with payload #{get_options}" if DEBUG
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    req = Net::HTTP::Get.new(uri.path)
    req.set_form_data(get_options)
    # instantiate a new Request object
    req = Net::HTTP::Get.new(uri.path + ('?' unless uri.path.match(/\?$/)).to_s + req.body)
    req['cookie'] = "PHPSESSID=#{opts[:session_id]}" if opts[:session_id].present?
    req['referer'] = referer if referer.present?
    res = http.request(req)
    doc = if res.message == 'OK'
            Nokogiri::HTML(res.body)
          else
            Nokogiri::HTML(res.message)
          end
    [res, doc]
  end

  def synchronize_league_structure(opts = {})
    season = Season.find_by_name(opts[:season_name])
    raise ArgumentError, "unknown season name #{season_name}", caller if season.blank?

    leagues_region_todo = League.joins(league_teams: :club).where(season: season, organizer_type: 'Region', organizer_id: region.id).where(
      'clubs.region_id = ?', region.id
    ).uniq
    # TODO forget DBU leagues for now
    # dbu_region = Region.find_by_shortname('portal')
    # dbu_leagues_todo = League.joins(league_teams: :club).where(season: season, organizer_type: 'Region', organizer_id: dbu_region.id).where(
    #   'clubs.region_id = ?', region.id
    # ).uniq
    # leagues_todo_ids = (leagues_region_todo.to_a + dbu_leagues_todo.to_a).map(&:id)
    leagues_todo_ids = (leagues_region_todo.to_a).map(&:id)
    leagues_done, errMsg = sync_leagues(opts)
    if errMsg.present?
      raise_err_msg('synchronize_league_structure', errMsg)
    end
    leagues_done_ids = leagues_done.map(&:id)
    leagues_still_todo_ids = leagues_todo_ids - leagues_done_ids
    unless leagues_still_todo_ids.blank?
      leagues_still_todo_ids.each do |league_id|
        league = League[league_id]
        if league.blank?
          raise_err_msg('synchronize_league_structure', "no league with id #{league_id}")
        else
          league_cc = LeagueCc.create_from_ba(league, opts)
        end
      end
    end
    league_ids_overdone = leagues_done_ids - leagues_todo_ids
    unless league_ids_overdone.blank?
      msg = "more league_ids with context #{opts[:context].upcase} than expected in CC: #{League.where(id: league_ids_overdone).map do |league|
        "#{league.name}[#{league.id}] - #{league.discipline.andand.name}"
      end }"
      RegionCc.logger.info msg
      Rails.logger.info msg
    end
  end

  def synchronize_league_plan_structure(opts = {})
    season = Season.find_by_name(opts[:season_name])
    force_update = opts[:armed]
    raise ArgumentError, "unknown season name #{season_name}", caller if season.blank?

    leagues_region_todo = League.joins(league_teams: :club).where(season: season, organizer_type: 'Region', organizer_id: region.id).where(
      'clubs.region_id = ?', region.id
    ).uniq
    # TODO forget DBU leagues for now
    # dbu_region = Region.find_by_shortname('portal')
    # dbu_leagues_todo = League.joins(league_teams: :club).where(season: season, organizer_type: 'Region', organizer_id: dbu_region.id).where(
    #   'clubs.region_id = ?', region.id
    # ).uniq
    # leagues_todo_ids = (leagues_region_todo.to_a + dbu_leagues_todo.to_a).map(&:id)
    leagues_todo_ids = (leagues_region_todo.to_a).map(&:id)
    leagues_done, errMsg = sync_league_plan(opts)
    raise_err_msg('synchronize_league_structure', errMsg) if errMsg.present?
    leagues_done_ids = leagues_done.map(&:id)
    leagues_still_todo_ids = leagues_todo_ids - leagues_done_ids
    unless leagues_still_todo_ids.blank?
      leagues_still_todo_ids.each do |league_id|
        league = League[league_id]
        if league.blank?
          raise_err_msg('synchronize_league_structure', "no league with id #{league_id}")
        else
          if force_update
            league_cc = LeagueCc.create_league_plan_from_ba(league, opts)
          else
            msg = "REPORT WOULD CREATE LeagueCc Plan from BA: #{league.attributes}"
            RegionCc.logger.info msg
            Rails.logger.info msg
          end
        end
      end
    end
    league_ids_overdone = leagues_done_ids - leagues_todo_ids
    unless league_ids_overdone.blank?
      msg = "more league_ids with context #{opts[:context].upcase} than expected in CC: #{League.where(id: league_ids_overdone).map do |league|
        "#{league.name}[#{league.id}] - #{league.discipline.andand.name}"
      end }"
      ReagionCc.logger.info msg
      Rails.logger.info msg
    end
  end

  def sync_team_players_structure(opts = {})
    season = Season.find_by_name(opts[:season_name])
    raise ArgumentError, "unknown season name #{opts[:season_name]}", caller if season.blank?
    region_cc = Region.where(shortname: opts[:context].upcase).first.region_cc
    League.where(season: season, organizer_type: 'Region', organizer_id: region.id).each do |league|
      league_team_players = {}
      league.parties.each do |party|
        league_team_players[party.league_team_a_id] ||= []
        league_team_players[party.league_team_b_id] ||= []
        party.party_games.each do |party_game|
          unless league_team_players[party.league_team_a_id].include?(party_game.player_a_id)
            league_team_players[party.league_team_a_id].push(party_game.player_a_id)
          end
          unless league_team_players[party.league_team_b_id].include?(party_game.player_b_id)
            league_team_players[party.league_team_b_id].push(party_game.player_b_id)
          end
        end
      end
      league_team_player_object_hash = {}
      league_team_players.each_key do |lt_id|
        league_team = LeagueTeam[lt_id]
        league_team_player_object_hash[league_team.id] ||= []
        league_team_players[lt_id].each do |p_id|
          player = Player[p_id]
          league_team_player_object_hash[league_team.id].push(player)
        end
      end
      league_team_player_object_hash.each_key do |lt_id|
        league_team = LeagueTeam[lt_id]
        league_team_cc = league_team.league_team_cc
        if league_team_cc.present?
          league_team_players_todo = league_team_player_object_hash[lt_id]
          league_team_player_done = region_cc.sync_team_players(league_team, opts)
          league_team_player_still_todo = league_team_players_todo - league_team_player_done
          league_team_player_still_todo.each do |player|
            next if player.ba_id > 999_000_000 || player.ba_id.blank?

            _, doc = region_cc.post_cc(
              'showLeague_add_teamplayer',
              { fedId: league_team_cc.fedId,
                leagueId: league_team_cc.leagueId,
                staffelId: 0,
                branchId: league_team_cc.branchId,
                subBranchId: league_team_cc.subBranchId,
                seasonId: league_team_cc.seasonId,
                p: league_team_cc.p,
                passnr: player.ba_id,
                referer: "/admin/bm_mw/spielberichtCheck.php?" },
              opts
            )
            doc
            err_msg = doc.css('input[name="errMsg"]')[0].andand['value']
            if err_msg.present?
              Rails.logger.info "REPORT! ERROR LeagueTeam #{league_team.andand.name} Player #{player.fullname} DBU-NR=#{player.ba_id} not in CC!"
            end
          end
        else
          Rails.logger.info "REPORT! [synchronize_team_players_structure] LeagueTeam #{league_team.andand.name} in Liga #{league_team.league.andand.name} nicht in CC"
        end
      end
    end
  end

  def sync_game_plans(opts = {})
    season = Season.find_by_name(opts[:season_name])
    region = Region.find_by_shortname(opts[:context].upcase)

    region_cc = region.region_cc
    region_cc.branch_ccs.each do |branch_cc|
      # get game_plan definitions
      branch = branch_cc.discipline
      _, doc = region_cc.get_cc(
        "spielberichte",
        { p: "#{branch_cc.fedId}-#{branch_cc.branchId}" }, opts
      )
      doc.text
      tables = doc.css("form > table > tr > td > table > tr > td > table > tr > td > table")
      tables.each do |table|
        next unless table.css('> tr > th')[1].andand.text == 'Spielbericht'

        table.css('> tr').each_with_index do |tr, ix|
          tds = tr.css('> td')
          next if tds.blank?
          name = tds[1].text
          link = tds[1].css("a")[0]["href"]
          cc_id = link.match(/spielbericht_anzeigen.*=\d+-\d+-(\d+)-.*$/)[1]
          game_plan_cc = GamePlanCc.find_by_cc_id(cc_id)
          game_plan_cc ||= GamePlanCc.new(name: name, cc_id: cc_id, branch_cc_id: branch_cc.id, discipline_id: branch.id)

          # read single game plan

          res2, doc2 = region_cc.get_cc(
            "spielbericht_anzeigen",
            { p: "#{branch_cc.fedId}-#{branch_cc.branchId}-#{cc_id}-" },
            opts
          )
          lines = []
          tables = doc2.css("form > table > tr > td > table > tr > td > table > tr > td > table > tr > td > table > tr > td > table")
          tables.each do |table|
            next if table.css('> tr > th')[0].andand.text == 'Partie-Nr.'

            table.css('> tr').each_with_index do |tr, ix|
              tds = tr.css('> td')
              if tds.blank?
                ths = tr.css('> th')
                ths.text
                lines.push(ths[1].text)
              else
                next if tds[1].text.blank?
                lines.push(tds[1].text)
              end
            end
            lines
            game_plan_cc.deep_merge_data!({ "games" => lines })
          end
        end
      end
    end
  end

  def sync_game_details(opts = {})
    season = Season.find_by_name(opts[:season_name])
    region = Region.find_by_shortname(opts[:context].upcase)
    opts[:done_ids] = []
    region_cc = region.region_cc
    region_cc.branch_ccs.each do |branch_cc|
      branch_cc.competition_ccs.each do |competition_cc|
        competition_cc.season_ccs.each do |season_cc|
          season_cc.league_ccs.order(cc_id: :asc).each do |league_cc|
            next if branch_cc.name == "Pool"
            league_cc.party_ccs.joins(:party).where.not(parties: { id: opts[:done_ids] }).each do |party_cc|
              party = party_cc.party
              Kernel.sleep(0.5)
              params = {
                'memo' => "#{party.remarks.andand["remarks"]}",
                'protest' => "#{party.remarks.andand["protest"]}",
                'zuNullTeamId' => (LeagueTeamCc[party.no_show_team_id] if party.no_show_team_id.present?).andand.cc_id.to_i,
                'saveBut' => "",
                'woher' => 1,
                'matchId' => party_cc.match_id,
                'errMsgNew' => "",
                'teamId' => party_cc.league_team_a_cc.cc_id,
                'firstEntry' => 1,
                'wettbewerb' => party_cc.subBranchId,
                'partienr' => party_cc.cc_id,
              }
              discipline_synonyms = {
                "14/1e" => "14.1 endlos",
                "15-reds" => "Snooker",

              }
              game_lines = party_cc.league_cc.game_plan_cc.data["games"]
              pg_line_ix = 0
              party.party_games.each_with_index do |pg, ix|
                while pg_line_ix < game_lines.count && ((game_lines[pg_line_ix] =~ /Runde/) || (pg.discipline.name != game_lines[pg_line_ix] && pg.discipline.name != discipline_synonyms[game_lines[pg_line_ix]])) do
                  pg_line_ix += 1
                end
                sc_ = pg.data[:result][pg.data[:result].keys[0]].split(":").map(&:strip).map(&:to_i)
                in_ = pg.data[:result].keys[1].present? ? pg.data[:result][pg.data[:result].keys[1]].split(":").map(&:strip).map(&:to_i) : []
                br_ = pg.data[:result].keys[2].present? ? pg.data[:result][pg.data[:result].keys[2]].split(":").map(&:strip).map(&:to_i) : []

                # 2:0 => 1:0, 1:0
                # 2:1 => 1:0, 0:1, 1:0
                add_pg = {
                  "#{party_cc.match_id}-#{pg_line_ix}-1-1-pid1" => pg.player_a.cc_id.to_i,
                  "#{party_cc.match_id}-#{pg_line_ix}-1-1-pid2" => pg.player_b.cc_id.to_i }
                if branch_cc.name == "Pool"
                  add_pg.merge!("#{party_cc.match_id}-#{pg_line_ix}-1-sc1" => sc_[0].presence) if sc_[0].present?
                  add_pg.merge!("#{party_cc.match_id}-#{pg_line_ix}-1-sc2" => sc_[1].presence) if sc_[1].present?
                  add_pg.merge!("#{party_cc.match_id}-#{pg_line_ix}-1-in1" => in_[0].presence) if in_[0].present?
                  add_pg.merge!("#{party_cc.match_id}-#{pg_line_ix}-1-in2" => in_[1].presence) if in_[1].present?
                  add_pg.merge!("#{party_cc.match_id}-#{pg_line_ix}-1-br1" => br_[0].presence) if br_[0].present?
                  add_pg.merge!("#{party_cc.match_id}-#{pg_line_ix}-1-br2" => br_[1].presence) if br_[1].present?
                elsif branch_cc.name == "Snooker"
                  c1 = sc_[0]; c2 = sc_[1]
                  n_games = c1 + c2
                  (1..n_games).each do |ii|
                    if c1 >= c2
                      add_pg.merge!("#{party_cc.match_id}-#{pg_line_ix}-#{ii}-sc1" => 1)
                      add_pg.merge!("#{party_cc.match_id}-#{pg_line_ix}-#{ii}-sc2" => 0)
                      c1 = c1 - 1
                    else
                      add_pg.merge!("#{party_cc.match_id}-#{pg_line_ix}-#{ii}-sc1" => 0)
                      add_pg.merge!("#{party_cc.match_id}-#{pg_line_ix}-#{ii}-sc2" => 1)
                      c2 = c2 - 1
                    end
                    if ii == n_games
                      # add_pg.merge!("#{party_cc.match_id}-#{pg_line_ix}-#{ii}-in1" => in_[0].presence) if in_[0].present?
                      # add_pg.merge!("#{party_cc.match_id}-#{pg_line_ix}-#{ii}-in2" => in_[1].presence) if in_[1].present?
                      add_pg.merge!("#{party_cc.match_id}-#{pg_line_ix}-#{ii}-br1" => in_[0].presence) if in_[0].present?
                      add_pg.merge!("#{party_cc.match_id}-#{pg_line_ix}-#{ii}-br2" => in_[1].presence) if in_[1].present?
                    end
                  end
                end
                params.merge!(add_pg)
                pg_line_ix += 1
                break if pg_line_ix > game_lines.count
              end
              _res, doc = region_cc.post_cc(
                "spielberichtSave",
                params.merge(referer: "/admin/bm_mw/spielberichtCheck.php?"),
                opts
              )
              doc.text
            end
          end
        end
      end
    end
  end

  def self.sync_regions(opts = {})
    armed = opts[:armed].present?
    regions = []
    res, doc = RegionCc.new(base_url: RegionCc::BASE_URL).get_cc('showClubList', {}, opts)
    if (msg = doc.css('input[name="errMsg"]')[0].andand['value']).present?
      RegionCc.logger.error msg
      return nil
    else
      selector = doc.css('select[name="fedId"]')[0]
      options_tags = selector.css('option')
      options_tags.each do |option|
        cc_id = option['value'].to_i
        name_str = option.text.strip
        match = name_str.match(/(.*) \((.*)\)/)
        region_name = match[1]
        shortname = match[2]
        region = Region.find_by_shortname(shortname)
        args = {
          cc_id: cc_id,
          region_id: region.id,
          context: region.shortname.downcase,
          shortname: shortname,
          name: region_name,
          base_url: BASE_URL
        }
        region_cc = RegionCc.find_by_cc_id(cc_id) || RegionCc.new(args)
        region_cc.assign_attributes(args)
        region_cc.save
        regions.push(region)

        if region_name != region.name
          RegionCc.logger.warn "REPORT! [sync_regions] Name des Regionalverbandes unterschiedlich: CC: #{region_name} BA: #{region.name}"
          region_cc.fix(name: region.name, armed: armed)
        end
      end
    end
    regions
  end

  def sync_branches(opts = {})
    branches = []
    context = shortname.downcase
    armed = opts.delete('armed')
    res, doc = get_cc('showClubList', {}, opts)
    selector = doc.css('select[name="branchId"]')[0]
    option_tags = selector.css('option')
    option_tags.each do |option|
      cc_id = option['value'].to_i
      name_str = option.text.strip
      match = name_str.match(/(.*)(:? \((.*)\))?/)
      branch_name = match[1]
      branch = Branch.find_by_name(branch_name)
      if branch.blank?
        msg = "No Branch with name #{branch_name} in database"
        RegionCc.logger.error "[get_branches_from_cc] #{msg}"
        raise ArgumentError, msg, caller
      else
        args = { cc_id: cc_id, region_cc_id: id, discipline_id: branch.id, context: context, name: branch_name }
        branch_cc = BranchCc.find_by_cc_id(cc_id) || BranchCc.new(args)
        branch_cc.assign_attributes(args)
        branch_cc.save
        branches.push(branch)
      end
    end
    branches
  end

  def sync_competitions(opts = {})
    competitions = []
    context = opts[:context]
    # for all branches
    BranchCc.where(context: context).each do |branch_cc|
      _, doc = post_cc('showLeagueList', { fedId: cc_id, branchId: branch_cc.cc_id }, opts)
      selector = doc.css('select[name="subBranchId"]')[0]
      option_tags = selector.css('option')
      option_tags.each do |option|
        cc_id = option['value'].to_i
        name_str = option.text.strip
        match = name_str.match(/(.*)(:? \((.*)\))?/)
        name = match[1]
        carambus_name = name == 'Mannschaft' ? "#{name} #{branch_cc.name}" : "Mannschaft #{name}"
        carambus_name = carambus_name.gsub('Großes Billard', 'Karambol großes Billard')
        carambus_name = carambus_name.gsub('Kleines Billard', 'Karambol kleines Billard')
        competition = Competition.find_by_name(carambus_name)
        if competition.blank?
          msg = "No Competition with name #{carambus_name} in database"
          RegionCc.logger.error "[sync_competitions] #{msg}"
          raise ArgumentError, msg, caller
        else
          args = { cc_id: cc_id, branch_cc_id: branch_cc.id, discipline_id: competition.id, context: context,
                   name: name }
          competition_cc = CompetitionCc.where(cc_id: cc_id,
                                               branch_cc_id: branch_cc.id).first || CompetitionCc.new(args)
          competition_cc.assign_attributes(args)
          competition_cc.save
          competitions.push(competition)
        end
      end
    end

    competitions
  end

  def sync_seasons_in_competitions(opts)
    context = shortname.downcase
    season = Season.find_by_name(opts[:season_name])
    raise ArgumentError, "unknown season name #{opts[:season_name]}", caller if season.blank?

    competition_ccs = []
    # for all branches
    BranchCc.where(context: context).each do |branch_cc|
      branch_cc.competition_ccs.each do |competition_cc|
        _, doc = post_cc(
          'showLeagueList',
          { fedId: cc_id,
            branchId: branch_cc.cc_id,
            subBranchId: competition_cc.cc_id },
          opts
        )
        selector = doc.css('select[name="seasonId"]')[0]
        option_tags = selector.css('option')
        option_tags.each do |option|
          cc_id = option['value'].to_i
          name_str = option.text.strip
          match = name_str.match(%r{\s*(.*/.*)\s*})
          s_name = match[1]
          next unless s_name == opts[:season_name]

          args = { cc_id: cc_id, context: context, name: s_name, season_id: season.id,
                   competition_cc_id: competition_cc.id }
          season_cc = SeasonCc.find_by_cc_id_and_competition_cc_id_and_context(cc_id, competition_cc.id,
                                                                               context) || SeasonCc.new(args)
          season_cc.assign_attributes(args)
          season_cc.save
          competition_ccs.push(competition_cc)
          break
        end
      end
    end

    competition_ccs
  end

  def sync_leagues(opts = {})
    context = opts[:context]
    season_name = opts[:season_name]
    season = Season.find_by_name(season_name)
    region = Region.find_by_shortname(context.upcase)
    raise ArgumentError, "unknown season name #{season_name}", caller if season.blank?

    dbu_region_id = Region.find_by_shortname('portal').id

    league_map = [] # league_cc.cc_id => league
    # for all branches
    leagues = []
    BranchCc.where(context: context).each do |branch_cc|
      branch_cc.competition_ccs.each do |competition_cc|
        competition_cc.season_ccs.each do |season_cc|
          next unless season_cc.name == season_name
          # Get List of Leagues in CC
          _res, doc = post_cc(
            'showLeagueList',
            { fedId: cc_id,
              branchId: branch_cc.cc_id,
              subBranchId: competition_cc.cc_id,
              seasonId: season_cc.cc_id },
            opts
          )
          if (msg = doc.css('input[name="errMsg"]')[0].andand['value']).present?
            RegionCc.logger.error msg
            return [[], msg]
          end
          selector = doc.css('select[name="leagueId"]')[0]
          next unless selector.present?

          option_tags = selector.css('option')
          option_tags.each do |option|
            cc_id = option['value'].to_i
            name_str = option.text.strip
            league_cc = nil
            league_ccs = LeagueCc.where(cc_id: cc_id)
            if (league_ccs.count == 1)
              league_cc = league_ccs.first
            elsif league_ccs.count > 1
              msg = "REPORT! ERROR cc_id #{cc_id} not uniq"
              RegionCc.logger.info msg
              raise ArgumentError, msg
            end
            league = League.find_by_cc_id(cc_id)
            unless league.present?
              name_str_match = name_str.gsub(' - ', ' ').gsub(/(\d+). /,
                                                              '\1.').match(%r{(.*)( (?:Nord|Süd|Nord/Ost))$})
              if name_str_match
                l_name = name_str_match[1].strip
                s_name = name_str_match[2].strip.gsub('/', '-')
              else
                l_name = name_str
                s_name = nil
              end
              if context == 'nbv'
                l_name = l_name == 'Regionalliga Pool' ? 'Regionalliga' : l_name
              end
              league = nil
              League.where(season: season, name: l_name, staffel_text: s_name, organizer_type: 'Region',
                           organizer_id: [region.id, dbu_region_id]).each do |l|
                if l.branch == branch_cc.discipline
                  league = l
                  break
                end
              end
            end
            if league.present?
              if league_cc.present?
                league_cc.sync_single_league(opts)
                league.assign_attributes(cc_id: cc_id)
                league.save
                league_map[league_cc.cc_id] = league
                leagues.push(league)
              else
                msg = "REPORT! ERROR no League for LeagueCc #{name_str} #{season_cc.name} branch: #{branch_cc.name}(#{branch_cc.cc_id}) competition: #{competition_cc.name}(#{competition_cc.cc_id})"
                RegionCc.logger.info msg
                Rails.logger.info msg
              end
            else
              msg = "REPORT! ERROR no League for LeagueCc #{name_str} #{season_cc.name} branch: #{branch_cc.name}(#{branch_cc.cc_id}) competition: #{competition_cc.name}(#{competition_cc.cc_id})"
              RegionCc.logger.info msg
              Rails.logger.info msg
            end
          end
        end
      end
    end

    [leagues, nil]
  rescue StandardError => e
    [[], e.to_s]
  end

  def sync_league_teams(opts = {})
    context = opts[:context]
    season_name = opts[:season_name]
    region = Region.find_by_shortname(context.upcase)
    season = Season.find_by_name(season_name)
    raise ArgumentError, "unknown season name #{season_name}", caller if season.blank?

    dbu_region_id = Region.find_by_shortname('portal').id

    league_teams = []
    league_team_ccs = []
    # for all branches
    BranchCc.where(context: context).each do |branch_cc|
      branch_cc.competition_ccs.each do |competition_cc|
        competition_cc.season_ccs.each do |season_cc|
          season_cc.league_ccs.order(:cc_id).each do |league_cc|
            next unless season_cc.name == season_name

            _, doc = post_cc(
              'admin_report_showLeague',
              { fedId: league_cc.fedId,
                branchId: league_cc.branchId,
                subBranchId: league_cc.subBranchId,
                seasonId: league_cc.seasonId,
                leagueId: league_cc.cc_id },
              opts
            )
            expected = league_cc.league.league_teams.joins(club: :region).where(regions: { id: region.id })
            league_teams_doc_cc = doc.css('table[name="teams"] tr.odd')
            next unless league_teams_doc_cc.present?

            league_teams_doc_cc.each do |league_team_doc_cc|
              tds = league_team_doc_cc.css('td')
              if tds.count == 2
                cc_id = tds[1].text.to_i
                name_str = tds[0].text.strip
              else
                # TODO: Ansicht mit SpielPlan
                cc_id = tds[2].text.to_i
                name_str = tds[1].text.strip
              end
              name_str = name_str.split(' ').join(' ')
              league_team = LeagueTeam.find_by_cc_id(cc_id)
              team_club_str = name_str
              if league_team.present?
                league_team_ccs.push(league_team.league_team_cc) if league_team.league_team_cc.present?
                league_teams.push(league_team)
              end

              if name_str.match(/.*[ [[:space:]]]+\d+$/)
                team_club_str = (m = name_str.match(/(.*[^ [[:space:]]])[ [[:space:]]]*(\d+)$/))[1]
                team_seqno = m[2]
              end
              club = Club.where(region: region, shortname: team_club_str).first
              if club.present?
                league_team = LeagueTeam.find_by_cc_id_and_league_id(cc_id, league_cc.league.id)
                league_team ||= LeagueTeam
                                  .joins(:league)
                                  .joins(club: :region)
                                  .where(regions: { id: region.id })
                                  .where(name: name_str, # shortname? TODO
                                         league_id: league_cc.league.id,
                                         club_id: club.id).first
                league_team ||= LeagueTeam
                                  .joins(:league)
                                  .joins(club: :region)
                                  .where(regions: { id: region.id })
                                  .where(name: team_club_str, # shortname? TODO
                                         league_id: league_cc.league.id,
                                         club_id: club.id).first
              else
                RegionCc.logger.warn "REPORT! [sync_league_teams] Name des Clubs entspricht keiner BA Liga: CC: #{{
                  shortname: team_club_str, region: region.shortname
                }.inspect}"
              end
              if league_team.present?
                league_team.assign_attributes(cc_id: cc_id)
                league_team.save!
                args = { cc_id: cc_id, name: name_str, league_cc_id: league_cc.id, league_team_id: league_team.id }
                league_team_cc = LeagueTeamCc.find_by_cc_id_and_league_cc_id(cc_id,
                                                                             league_cc.id) || LeagueTeamCc.new(args)
                league_team_cc.assign_attributes(args)
                league_team_cc.save!
                league_teams.push(league_team)
                league_team_ccs.push(league_team_cc)
              else
                RegionCc.logger.warn "REPORT! [sync_league_teams] Name der Liga Mannschaft #{team_club_str} entspricht keinem BA LigaTeam: CC: #{{
                  name: name_str, league_id: league_cc.league.id, club_id: club.andand.id
                }.inspect}"
              end
            end
          end
        end
      end
    end

    return [league_teams, league_team_ccs]
  rescue StandardError => e
    e
  end

  def sync_league_plan(opts = {})
    leagues = League.joins(league_teams: :club).where(season: season, organizer_type: 'Region', organizer_id: region.id).where(
      'clubs.region_id = ?', region.id
    ).uniq
    leagues_done = []
    errMsg = nil
    leagues.each do |league|
      league_cc = league.league_cc
      parties = league.parties
      # read spielplan
      #
      party_ccs = league_cc.party_ccs
      #Abgleich:
      #parties.map{|p| [p.day_seqno, p.league_team_a.name, p.league_team_b.name].join(";")}
      #party_ccs.map{|p| [p.day_seqno, p.league_team_a_cc.andand.name, p.league_team_b_cc.andand.name].join(";")}
      _, doc3 = post_cc(
        'massChangingCheck',
        { fedId: league_cc.fedId,
          leagueId: league_cc.leagueId,
          branchId: league_cc.branchId,
          subBranchId: league_cc.subBranchId,
          seasonId: league_cc.seasonId,
          staffelId: '' },
        opts)
      if (msg = doc3.css('input[name="errMsg"]')[0].andand['value']).present?
        RegionCc.logger.error msg
        return [leagues_done, msg]
      end
      party_match_id = nil
      tables = doc3.css('form > table > tr > td > table > tr > td > table > tr > td > table') #TODO why is an Array returned???
      tables.each do |table|
        next unless table.css('> tr > th')[0].andand.text == 'Spieltag'

        table.css('> tr').each_with_index do |tr, ix|
          tds = tr.css('> td')
          next if tds.blank?

          party_match_id = tds[0].css('> input')[0]['name'].match(/spieltagNr(\d+)$/)[1].to_i
          selectors = tds.css('> select')
          party_day_seqno = tds.css('> input')[0]['value']
          party_group = tds.css('> input')[1]['value']
          party_cc_id = tds.css('> input')[2]['value'].to_i
          party_round = tds.css('> input')[3]['value']
          party_team_a_cc_id = selectors[0].css('option[selected=selected]')[0]['value'].to_i
          party_team_b_cc_id = selectors[1].css('option[selected=selected]')[0]['value'].to_i
          # party_date = Date.parse(tds.css("input")[4]["value"])
          party_active_cell = tds.css('> input')[5]
          party_active = nil
          party_active ||= party_active_cell['value'].presence.to_i
          party_res_a = tds.css('> input')[6]['value']
          party_res_b = tds.css('> input')[7]['value']
          party_team_host_cc_id = selectors[2].css('option[selected=selected]')[0]['value'].to_i
          party_time = DateTime.parse("#{tds.css('> input')[4]['value']} #{tds.css('> input')[8]['value'] if tds.css('> input')[8]['value'] =~ /:/}")
          party_register = Date.parse(tds.css('> input')[9]['value'])

          party = parties.joins('INNER JOIN "league_teams" as "league_team_a" on "league_team_a"."id" = "parties"."league_team_a_id"').
            joins('INNER JOIN "league_teams" as "league_team_b" on "league_team_b"."id" = "parties"."league_team_b_id"').
            where('league_team_a.cc_id = ?', party_team_a_cc_id).
            where('league_team_b.cc_id = ?', party_team_b_cc_id).first
          args = { cc_id: party_cc_id,
                   group: party_group,
                   round: party_round,
                   time: party_time,
                   match_id: party_match_id,
                   register_at: party_register,
                   status: party_active,
                   league_cc_id: league_cc.id,
                   party_id: party.andand.id,
                   league_team_a_cc_id: league_cc.league_team_ccs.where(league_team_ccs: { cc_id: party_team_a_cc_id }).first.andand.id,
                   league_team_b_cc_id: league_cc.league_team_ccs.where(league_team_ccs: { cc_id: party_team_b_cc_id }).first.andand.id,
                   league_team_host_cc_id: league_cc.league_team_ccs.joins(:party_host_ccs).where(league_team_ccs: { cc_id: party_team_host_cc_id }).first.andand.id,
                   day_seqno: party_day_seqno,
                   data: { :result => "#{party_res_a}:#{party_res_b}" }
          }
          if party.present?
            party_cc = party_ccs.where(cc_id: party_cc_id).first || PartyCc.new(args)
            party_cc.assign_attributes(args)
            party_cc.save
            #
            # _, doc = post_cc(
            #   "massChangingCheckAuth",
            #   { teamCounter: 10,
            #   fedId: 20,
            #   leagueId: 36,
            #   branchId: 6,
            #   subBranchId: 1,
            #   seasonId: 8,
            #   editAll: "",
            #   matchId: 759}, opts)
            # doc.text
            # #https://e12112e2454d41f1824088919da39bc0.club-cloud.de/admin/report/massChangingCheckAuth.php?
            # _, doc = post_cc(
            #   'spielberichtCheck',
            #   {a: 715,
            #   b: 2,
            #   c: 111,
            #   referer: "/admin/report/massChangingCheckAuth.php?"}, opts
            # )
            # doc.text
            #
            # #https://e12112e2454d41f1824088919da39bc0.club-cloud.de/admin/bm_mw/spielberichtCheck.php?a=759&b=2&c=210&
            # _, doc = get_cc(
            #   'spielberichtCheck',
            #  { a: 715,
            #   b: 2,
            #   c: 111 }, opts
            # )
            # doc.text
            leagues_done.push(league)
          else
            msg = "REPORT ERROR party with cc_id: #{args[:cc_id]}, host: #{LeagueTeamCc[args[:league_team_host_cc_id]].name}, day_seqno: #{args[:day_seqno]} - arguments #{args.inspect} not in database"
            RegionCc.logger.info msg
            Rails.logger.info msg
          end
        end
      end
    end
    [leagues_done, errMsg]
  end

  def sync_clubs(opts = {})
    context ||= 'nbv'
    region = Region.find_by_shortname(context.upcase)
    done_clubs = []
    done_club_cc_ids = []
    BranchCc.where(context: context).each do |branch_cc|
      branch_cc.competition_ccs.each do |competition_cc|
        %i[active passive].each do |status|
          _, doc = post_cc(
            'showClubList',
            { sortKey: 'NAME',
              fedId: branch_cc.fedId,
              branchId: branch_cc.cc_id,
              subBranchId: competition_cc.cc_id,
              sportDistrictId: '*',
              statusId: STATUS_MAP[status] },
            opts
          )
          clubs = doc.css('select[name="clubId"] option')
          clubs.each do |club|
            cc_id = club['value'].to_i
            next if done_club_cc_ids.include?(cc_id)

            name_str = club.text.strip
            shortname = name_str.match(/\s*([^(]*)\s*(?:\(.*)?/).andand[1].strip
            c = Club.find_by_cc_id(cc_id)
            if c.present?
              if c.shortname != shortname
                RegionCc.logger.warn "REPORT! [sync_clubs] name mismatch found - CC: '#{shortname}' BA: #{c.shortname}"
              end
              c.assign_attributes(cc_id: cc_id, status: status)
              c.save!
              done_club_cc_ids.push(cc_id)
              done_clubs.push(c)
            else
              c = Club.where(shortname: shortname, region_id: region.id).first
              unless c.present?
                RegionCc.logger.warn "REPORT! [sync_clubs] no club with name '#{shortname}' found in region #{context}"
              end
            end
          end
        end
      end
    end
    done_clubs
  end

  def sync_parties(opts)
    parties = []
    party_ccs = []
    # for all branches
    BranchCc.where(context: context).each do |branch_cc|
      branch_cc.competition_ccs.each do |competition_cc|
        competition_cc.season_ccs.each do |season_cc|
          season_cc.league_ccs.order(:cc_id).each do |league_cc|
            next unless season_cc.name == opts[:season_name]

            _, doc = post_cc(
              'admin_report_showLeague',
              { fedId: league_cc.fedId,
                branchId: league_cc.branchId,
                subBranchId: league_cc.subBranchId,
                seasonId: league_cc.seasonId,
                leagueId: league_cc.cc_id },
              opts
            )
            league = league_cc.league
            doc.css('table > tr > td > table > tr > td > table').each do |table|
              if table.css('> tr > th').andand[1].andand.text == 'Spieltag'
                table_found = table
                table.css('tr').each do |line|
                  tds = line.css('> td')
                  next if tds.blank?

                  text_arr = tds.map(&:text)
                  day_seqno = text_arr[1].to_i
                  cc_id = text_arr[2].to_i
                  team_a_str = text_arr[3].split(' ').join(' ')
                  team_a_cc = league_cc.league_team_ccs.where(name: team_a_str).first
                  raise RuntimeError, "Team #{team_a_str} not found", caller unless team_a_cc.present?

                  team_b_str = text_arr[4].split(' ').join(' ')
                  team_b_cc = league_cc.league_team_ccs.where(name: team_b_str).first
                  raise RuntimeError, "Team #{team_b_str} not found", caller unless team_b_cc.present?

                  date_str = text_arr[5]
                  result = text_arr[6]
                  dummy = text_arr[7]
                  host_str = text_arr[8]
                  host_cc = league_cc.league_team_ccs.where(name: host_str).first
                  raise RuntimeError, "Team #{host_str} not found", caller unless team_b_cc.present?

                  time_str = text_arr[9]
                  date = DateTime.parse("#{date_str} #{time_str}")
                  reg_date_str = text_arr[10]
                  reg_date = Date.parse(reg_date_str)
                  party = league.parties.where(day_seqno: day_seqno, league_team_a: team_a_cc.league_team,
                                               league_team_b: team_b_cc.league_team).first
                  unless team_b_cc.present?
                    raise RuntimeError,
                          "Party #{{ day_seqno: day_seqno, team_a_cc_name: team_a_cc.name, team_b_cc_name: team_b_cc.name }} not found", caller
                  end

                  party.assign_attributes(cc_id: cc_id)
                  party.save!
                  args = { cc_id: cc_id,
                           league_cc_id: league_cc.id,
                           party_id: party.id,
                           league_team_a_cc: team_a_cc,
                           league_team_b_cc: team_b_cc,
                           league_team_host_cc: host_cc }
                  party_cc = PartyCc.find_by_cc_id_and_league_cc_id(cc_id, league_cc.id)
                  party_cc = PartyCc.new(args) if party_cc.blank?
                  party_cc.assign_attributes(args)
                  party_cc.save!
                  party_ccs.push(party_cc)
                  parties.push(party)
                end
              elsif doc.css('table > tr > td > table > tr.tableContent > td > table > tr > td > input').present?
                if league.organizer_id == region.id && league.organizer_type == 'Region'
                  RegionCc.logger.info "REPORT! Keine Spieltag gepflegt für Liga #{league.name}"
                end
              end
            end
          end
        end
      end
    end
    [parties, party_ccs]
  end

  def sync_party_games(parties_todo_ids, opts = {})
    parties_todo_ids.each do |id|
      party = Party[id]
      region = party.league.organizer
      region_cc = region.region_cc
      party_cc = party.party_cc
      party_cc.attributes
      _res, doc = region_cc.post_cc(
        'spielberichtCheck',
        { errMsgNew: '',
          fedId: 20,
          branchId: 6,
          subBranchId: 1,
          wettbewerb: 1,
          leagueId: 34,
          seasonId: 8,
          teamId: 185,
          matchId: 571,
          saison: 2010 / 2011,
          partienr: 4003,
          woher: 1,
          woher2: 1,
          editBut: '' },
        opts
      # get Spielbericht
      # _res, doc = region_cc.post_cc(
      #   "spielbericht",
      #   { errMsgNew: "",
      #   matchId: party_cc.party_game_ccs.first.cc_id,
      #   teamId: 189
      #   woher: 1
      #   firstEntry: 1
      #   #
      #   # sortKey: "NAME",
      #   # branchid: party_cc.branchId,
      #   # woher: 1,
      #   # wettbewerb: party_cc.subBranchId,
      #   # sportkreis: "*",
      #   # saison: season_name,
      #   # partienr: party_cc.cc_id,
      #   # seekBut: ""}, opts
      )
      err_msg = doc.present && doc.css('input[name="errMsg"]')[0].andand['value']
      raise ArgumentError, err_msg if err_msg.present? || doc.blank?
    end
  end

  def sync_team_players(league_team, opts = {})
    league_team_player_done = []
    league_team_cc = league_team.league_team_cc
    if league_team.league_team_cc.present?
      res, doc = get_cc(
        'showLeague_show_teamplayer',
        { p: league_team_cc.p,
          referer: "/admin/report/showLeague_show_teamplayer.php?p=#{league_team_cc.p}&" },
        opts
      )
      doc.css('tr.tableContent > td > table > tr > td > table').each do |table|
        ths = table.css('> tr > th')
        next unless ths.present? && ths[3].andand.text == 'Pass-Nr.'

        table.css('> tr').each do |tr|
          tds = tr.css('> td')
          next if tds.blank?

          cc_id = tds[3].text.to_i
          ba_id = tds[4].text.to_i
          player = Player.find_by_ba_id(ba_id) || Player.find_by_cc_id(cc_id)
          player = Player.find_by_ba_id(ba_id)
          unless player.present?
            player = Player.find_by_ba_id(cc_id)
            if player.blank?
              RegionCc.logger.info "REPORT ERROR Kein Spieler #{tds[1].text}, #{tds[2].text} mit PASS-NR #{cc_id} oder DBU-NR #{ba_id} in DB"
            elsif player.ba_id != ba_id
              RegionCc.logger.info "REPORT ERROR Spieler #{tds[1].text}, #{tds[2].text} hat andere DBU-NR #{player.ba_id} in DB als in CC #{ba_id}"
            end
          else
            player = Player.find_by_ba_id(cc_id)
            if player.blank?
              RegionCc.logger.info "REPORT ERROR Kein Spieler #{tds[1].text}, #{tds[2].text} mit PASS-NR #{cc_id} oder DBU-NR #{ba_id} in DB"
            elsif player.ba_id != ba_id
              RegionCc.logger.info "REPORT ERROR Spieler #{tds[1].text}, #{tds[2].text} hat andere DBU-NR #{player.ba_id} in DB als in CC #{ba_id}"
            end
          end
          league_team_player_done.push(player) if player.present?
        end
      end
    end

    league_team_player_done
  end

  private

  def raise_err_msg(context, msg)
    Rails.logger.error "[#{context}] #{msg} #{caller}"
    raise ArgumentError, msg, caller
  end

  def deep_merge_data!(hash)
    h = data.dup
    h.deep_merge!(hash)
    self.data_will_change!
    self.data = JSON.parse(h.to_json)
    save!
  end

end
