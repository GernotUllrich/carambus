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
  class_attribute :session_id

  REPORT_LOGGER_FILE = "#{Rails.root}/log/report.log"
  REPORT_LOGGER = Logger.new(REPORT_LOGGER_FILE)

  DEBUG = true

  STATUS_MAP = {
    active: 1,
    passive: 2
  }

  PATH_MAP = { #maps to path and read_only {true|false}|}
               "home" => ["", true],
               #"showClubList" => "/admin/approvement/player/showClubList.php",
               "createLeagueSave" => ["/admin/league/createLeagueSave.php", true],
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
               "showLeagueList" => ["/admin/report/showLeagueList.php", true],
               "showLeague" => ["/admin/league/showLeague.php", true],
               "admin_report_showLeague" => ["/admin/report/showLeague.php", true],
               # branchId: 6
               # fedId: 20
               # subBranchId: 1
               # seasonId: 8
               # leagueId: 34
               "admin_report_showLeague_create_team" => ["/admin/report/showLeague_create_team.php", false],
               # teamCounter: 2
               # fedId: 20
               # leagueId: 32
               # branchId: 6
               # subBranchId: 1
               # seasonId: 8
               "spielbericht_anzeigen" => ["/admin/reportbuilder2/spielbericht_anzeigen.php", true],
               "showTeam" => ["/admin/announcement/team/showTeam.php", true],
               # fedId: 20,
               # branchId: 6,
               # subBranchId: 1,
               # sportDistrictId: *,
               # clubId: 1004,
               # originalBranchId: 6,
               # seasonId: 1,
               # teamId: 98
               "editTeam" => ["admin/announcement/team/editTeamCheck.php", false],
               "showClubList" => ["/admin/announcement/team/showClubList.php", true],
               # fedId: 20
               # branchId: 6
               # subBranchId: 11
               # sportDistrictId: *
               # statusId: 1   (1 = active)
               "showLeague_show_teamplayer" => ["/admin/report/showLeague_show_teamplayer.php", true],
               # GET
               # p: 187
               "showLeague_add_teamplayer" => ["/admin/report/showLeague_add_teamplayer.php", false],
               # fedId: 20,
               # leagueId: 34,
               # staffelId: 0,
               # branchId: 6,
               # subBranchId: 1,
               # seasonId: 8,
               # p: 187,
               # passnr: 221109,
               "spielbericht" => ["/admin/bm_mw/spielbericht.php", false],
               # errMsgNew:
               # matchId: 572
               # teamId: 189
               # woher: 1
               # firstEntry: 1
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
  }

  #PHPSESSID = "3e7da06b0149fe5ad787246fc7a0e2b4"
  BASE_URL = "https://e12112e2454d41f1824088919da39bc0.club-cloud.de"

  def self.logger
    REPORT_LOGGER
  end

  def self.save_log(name)
    FileUtils.mv(REPORT_LOGGER_FILE, "#{Rails.root}/log/#{name}.log")
    REPORT_LOGGER.reopen
  end

  def fix(options = {})
    armed = options.delete(:armed)
    if options[:name].present?
      if armed
        RegionCc.logger.info "NOT_IMPLEMENTED fix region_name to \"#{options[:name]}\""
      else
        RegionCc.logger.info "WILL fix region_name to \"#{options[:name]}\""
      end
    else
      raise ArgumentError
    end
  rescue Exceptions => e
    e
  end

  def post_cc(action, session_id, options = {})
    dry_run = options.delete(:armed).blank?
    if PATH_MAP[action].present?
      url = base_url + PATH_MAP[action][0]
      if PATH_MAP[action][1] #read_only
        Rails.logger.debug "[#{action}] #{"WILL" if dry_run} POST #{action} with payload #{options}" if DEBUG
      else
        RegionCc.logger.debug "[#{action}] POST with payload #{options}"
      end
      unless dry_run
        uri = URI(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        req = Net::HTTP::Post.new(uri.request_uri)
        req["cookie"] = "PHPSESSID=#{session_id}"
        req['Content-Type'] = 'application/x-www-form-urlencoded'
        req.set_form_data(options.reject { |k, v| v.blank? })
        res = http.request(req)
        if res.message == "OK"
          doc = Nokogiri::HTML(res.body)
        else
          doc = Nokogiri::HTML(res.message)
        end
      end
      return [res, doc]
    else
      raise ArgumentError, "Unknown Action", caller
    end
  end

  def get_cc(action, session_id, options = {})
    if PATH_MAP[action].present?
      url = base_url + PATH_MAP[action][0]
      return get_cc_with_url(action, session_id, url, options)
    else
      raise ArgumentError, "Unknown Action", caller
    end
  end

  def get_cc_with_url(action, session_id, url, options = {})
    Rails.logger.debug "[post_cc] POST #{action} with payload #{options}" if DEBUG
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    req = Net::HTTP::Get.new(uri.path)
    req.set_form_data(options)
    # instantiate a new Request object
    req = Net::HTTP::Get.new(uri.path + "#{'?' unless uri.path.match(/\?$/)}" + req.body)
    req["cookie"] = "PHPSESSID=#{session_id}" if session_id.present?
    res = http.request(req)
    if res.message == "OK"
      doc = Nokogiri::HTML(res.body)
    else
      doc = Nokogiri::HTML(res.message)
    end
    return [res, doc]
  end

  def self.sync_regions(session_id, region, options = {})
    armed = options[:armed].present?
    regions = []
    res, doc = RegionCc.new(base_url: RegionCc::BASE_URL).get_cc("showClubList", session_id)
    if (msg = doc.css("input[name=\"errMsg\"]")[0].andand["value"]).present?
      RegionCc.logger.error msg
    else
      selector = doc.css('select[name="fedId"]')[0]
      options = selector.css("option")
      options.each do |option|
        cc_id = option["value"].to_i
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
    return regions
  end

  def sync_branches(session_id)
    branches = []
    context = shortname.downcase
    res, doc = get_cc("showClubList", session_id)
    selector = doc.css('select[name="branchId"]')[0]
    options = selector.css("option")
    options.each do |option|
      cc_id = option["value"].to_i
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
    return branches
  end

  def sync_competitions(session_id)
    competitions = []
    context = shortname.downcase
    # for all branches
    BranchCc.where(context: context).each do |branch_cc|
      _, doc = post_cc("showLeagueList", session_id, fedId: cc_id, branchId: branch_cc.cc_id)
      selector = doc.css('select[name="subBranchId"]')[0]
      options = selector.css("option")
      options.each do |option|
        cc_id = option["value"].to_i
        name_str = option.text.strip
        match = name_str.match(/(.*)(:? \((.*)\))?/)
        name = match[1]
        carambus_name = name == "Mannschaft" ? "#{name} #{branch_cc.name}" : "Mannschaft #{name}"
        carambus_name.gsub!("Großes Billard", "Karambol großes Billard")
        carambus_name.gsub!("Kleines Billard", "Karambol kleines Billard")
        competition = Competition.find_by_name(carambus_name)
        if competition.blank?
          msg = "No Competition with name #{carambus_name} in database"
          RegionCc.logger.error "[sync_competitions] #{msg}"
          raise ArgumentError, msg, caller
        else
          args = { cc_id: cc_id, branch_cc_id: branch_cc.id, discipline_id: competition.id, context: context, name: name }
          competition_cc = CompetitionCc.where(cc_id: cc_id, branch_cc_id: branch_cc.id).first || CompetitionCc.new(args)
          competition_cc.assign_attributes(args)
          competition_cc.save
          competitions.push(competition)
        end
      end
    end

    return competitions
  end

  def sync_seasons_in_competitions(session_id, season_name)

    context = shortname.downcase
    season = Season.find_by_name(season_name)
    if season.blank?
      raise ArgumentError, "unknown season name #{season_name}", caller
    end
    competition_ccs = []
    # for all branches
    BranchCc.where(context: context).each do |branch_cc|
      branch_cc.competition_ccs.each do |competition_cc|
        _, doc = post_cc(
          "showLeagueList",
          session_id,
          fedId: cc_id,
          branchId: branch_cc.cc_id,
          subBranchId: competition_cc.cc_id
        )
        selector = doc.css('select[name="seasonId"]')[0]
        options = selector.css("option")
        options.each do |option|
          cc_id = option["value"].to_i
          name_str = option.text.strip
          match = name_str.match(/\s*(.*\/.*)\s*/)
          s_name = match[1]
          if s_name == season_name
            args = { cc_id: cc_id, context: context, name: s_name, season_id: season.id, competition_cc_id: competition_cc.id }
            season_cc = SeasonCc.find_by_cc_id_and_competition_cc_id_and_context(cc_id, competition_cc.id, context) || SeasonCc.new(args)
            season_cc.assign_attributes(args)
            season_cc.save
            competition_ccs.push(competition_cc)
            break
          end
        end
      end
    end

    return competition_ccs
  end

  def sync_leagues(session_id, season_name, opts = {})

    context = shortname.downcase
    region = Region.find_by_shortname(context.upcase)
    season = Season.find_by_name(season_name)
    if season.blank?
      raise ArgumentError, "unknown season name #{season_name}", caller
    end

    dbu_region_id = Region.find_by_shortname("portal").id

    leagues = []
    # for all branches
    BranchCc.where(context: context).each do |branch_cc|
      branch_cc.competition_ccs.each do |competition_cc|
        competition_cc.season_ccs.each do |season_cc|
          next unless season_cc.name == season_name
          _, doc = post_cc(
            "showLeagueList",
            session_id,
            fedId: cc_id,
            branchId: branch_cc.cc_id,
            subBranchId: competition_cc.cc_id,
            seasonId: season_cc.cc_id
          )
          selector = doc.css('select[name="leagueId"]')[0]
          if selector.present?
            options = selector.css("option")
            options.each do |option|
              cc_id = option["value"].to_i
              name_str = option.text.strip
              league = League.find_by_cc_id(cc_id)
              unless league.present?
                name_str_match = name_str.gsub(" - ", " ").gsub(/(\d+). /, '\1.').match(/(.*)( (?:Nord|Süd|Nord\/Ost))$/)
                if name_str_match
                  l_name = name_str_match[1].strip
                  s_name = name_str_match[2].strip.gsub("/", "-")
                else
                  l_name = name_str
                  s_name = nil
                end
                if context == "nbv"
                  l_name = l_name == "Regionalliga Pool" ? "Regionalliga" : l_name
                end
                league = nil
                League.where(season: season, name: l_name, staffel_text: s_name, organizer_type: "Region", organizer_id: [region.id, dbu_region_id]).each do |l|
                  if l.branch == branch_cc.discipline
                    league = l
                    break
                  end
                end
                league.assign_attributes(cc_id: cc_id)
              end
              unless league.present?
                RegionCc.logger.warn "REPORT! [sync_leagues] Name der Liga entspricht keiner BA Liga: CC: #{{ season_name: season.name, name: name_str, organizer_type: "Region", organizer_id: [self.id, dbu_region_id], discipline: competition_cc.discipline }.inspect}"
              else
                args = { cc_id: cc_id, context: context, name: name_str, season_cc_id: season_cc.id, league_id: league.id }
                league_cc = LeagueCc.find_by_cc_id_and_season_cc_id_and_context(cc_id, season_cc.id, context) || LeagueCc.new(args)
                league_cc.assign_attributes(args)
                _, doc2 = post_cc(
                  "showLeague",
                  session_id,
                  fedId: cc_id,
                  branchId: branch_cc.cc_id,
                  subBranchId: competition_cc.cc_id,
                  seasonId: season_cc.cc_id,
                  leagueId: league_cc.cc_id
                )
                lines = doc2.css("form tr.tableContent table tr")
                res_arr = lines.map { |l| l.css("td").map(&:text) }
                unless res_arr[4][0] == "Kürzel" && res_arr[5][0] == "Status"
                  raise SystemCallError, "Format of showLeague canged ???", caller
                end
                league_cc.assign_attributes(shortname: res_arr[4][2].strip, status: res_arr[5][4].strip, report_form: res_arr[7][2].strip)
                league_cc.save
                league.assign_attributes(shortname: res_arr[4][2].strip)
                league.save
                leagues.push(league)
              end
            end
          end
        end
      end
    end

    return leagues
  rescue StandardError => e
    e
  end

  def sync_league_teams(season_name, opts = {})

    context = shortname.downcase
    region = Region.find_by_shortname(context.upcase)
    season = Season.find_by_name(season_name)
    if season.blank?
      raise ArgumentError, "unknown season name #{season_name}", caller
    end

    dbu_region_id = Region.find_by_shortname("portal").id

    league_teams = []
    league_teams_cc = []
    # for all branches
    BranchCc.where(context: context).each do |branch_cc|
      branch_cc.competition_ccs.each do |competition_cc|
        competition_cc.season_ccs.each do |season_cc|
          season_cc.league_ccs.order(:cc_id).each do |league_cc|
            next unless season_cc.name == season_name
            _, doc = post_cc(
              "admin_report_showLeague",
              session_id,
              fedId: league_cc.fedId,
              branchId: league_cc.branchId,
              subBranchId: league_cc.subBranchId,
              seasonId: league_cc.seasonId,
              leagueId: league_cc.cc_id,
            )
            expected = league_cc.league.league_teams.joins(:club => :region).where(regions: { id: region.id })
            league_teams_doc_cc = doc.css('table[name="teams"] tr.odd')
            if league_teams_doc_cc.present?
              league_teams_doc_cc.each do |league_team_doc_cc|
                tds = league_team_doc_cc.css("td")
                if tds.count == 2
                  cc_id = tds[1].text.to_i
                  name_str = tds[0].text.strip
                else
                  #TODO Ansicht mit SpielPlan
                  cc_id = tds[2].text.to_i
                  name_str = tds[1].text.strip
                end
                name_str = name_str.split(" ").join(" ")
                league_team = LeagueTeam.find_by_cc_id(cc_id)
                team_club_str = name_str
                unless league_team.present?
                  if name_str.match(/.*[ [[:space:]]]+\d+$/)
                    team_club_str = (m = name_str.match(/(.*[^ [[:space:]]])[ [[:space:]]]*(\d+)$/))[1]
                    team_seqno = m[2]
                  end
                  club = Club.where(region: region, shortname: team_club_str).first
                  unless club.present?
                    RegionCc.logger.warn "REPORT! [sync_league_teams] Name des Clubs entspricht keiner BA Liga: CC: #{{ shortname: team_club_str, region: region.shortname }.inspect}"
                  else
                    league_team = LeagueTeam.find_by_cc_id_and_league_id(cc_id, league_cc.league.id)
                    league_team ||= LeagueTeam.
                      joins(:league).
                      joins(:club => :region).
                      where(regions: { id: region.id }).
                      where(name: name_str, #shortname? TODO
                            league_id: league_cc.league.id,
                            club_id: club.id).first
                    league_team ||= LeagueTeam.
                      joins(:league).
                      joins(:club => :region).
                      where(regions: { id: region.id }).
                      where(name: team_club_str, #shortname? TODO
                            league_id: league_cc.league.id,
                            club_id: club.id).first
                  end
                  unless league_team.present?
                    RegionCc.logger.warn "REPORT! [sync_league_teams] Name der Liga Mannschaft entspricht keinem BA LigaTeam: CC: #{{ name: name_str, league_id: league_cc.league.id, club_id: club.id }.inspect}"
                  else
                    league_team.assign_attributes(cc_id: cc_id)
                    league_team.save!
                    args = { cc_id: cc_id, name: name_str, league_cc_id: league_cc.id, league_team_id: league_team.id }
                    league_team_cc = LeagueTeamCc.find_by_cc_id_and_league_cc_id(cc_id, league_cc.id) || LeagueTeamCc.new(args)
                    league_team_cc.assign_attributes(args)
                    league_team_cc.save!
                    league_teams.push(league_team)
                    league_teams_cc.push(league_team_cc)
                  end
                end
              end
            end
          end
        end
      end
    end

    return league_teams
  rescue StandardError => e
    e
  end

  def sync_clubs(context)
    context ||= "nbv"
    region = Region.find_by_shortname(context.upcase)
    done_clubs = []
    done_club_cc_ids = []
    BranchCc.where(context: context).each do |branch_cc|
      branch_cc.competition_ccs.each do |competition_cc|
        [:active, :passive].each do |status|
          _, doc = post_cc(
            "showClubList",
            session_id,
            sortKey: "NAME",
            fedId: branch_cc.fedId,
            branchId: branch_cc.cc_id,
            subBranchId: competition_cc.cc_id,
            sportDistrictId: "*",
            statusId: STATUS_MAP[status],
          )
          clubs = doc.css('select[name="clubId"] option')
          clubs.each do |club|
            cc_id = club["value"].to_i
            next if done_club_cc_ids.include?(cc_id)
            name_str = club.text.strip
            shortname = name_str.match(/\s*([^\(]*)\s*(?:\(.*)?/).andand[1].strip
            c = Club.find_by_cc_id(cc_id)
            unless c.present?
              c = Club.where(shortname: shortname, region_id: region.id).first
              unless c.present?
                RegionCc.logger.warn "REPORT! [sync_clubs] no club with name '#{shortname}' found in region #{context}"
              end
            else
              if c.shortname != shortname
                RegionCc.logger.warn "REPORT! [sync_clubs] name mismatch found - CC: '#{shortname}' BA: #{c.shortname}"
              end
              c.assign_attributes(cc_id: cc_id, status: status)
              c.save!
              done_club_cc_ids.push(cc_id)
              done_clubs.push(c)
            end
          end
        end
      end
    end
    return done_clubs
  end

  def sync_parties(season_name)
    parties = []
    party_ccs = []
    # for all branches
    BranchCc.where(context: context).each do |branch_cc|
      branch_cc.competition_ccs.each do |competition_cc|
        competition_cc.season_ccs.each do |season_cc|
          season_cc.league_ccs.order(:cc_id).each do |league_cc|
            next unless season_cc.name == season_name
            _, doc = post_cc(
              "admin_report_showLeague",
              session_id,
              fedId: league_cc.fedId,
              branchId: league_cc.branchId,
              subBranchId: league_cc.subBranchId,
              seasonId: league_cc.seasonId,
              leagueId: league_cc.cc_id,
            )
            league = league_cc.league
            doc.css("table > tr > td > table > tr > td > table").each do |table|
              if table.css("> tr > th").andand[1].andand.text == "Spieltag"
                table_found = table
                table.css("tr").each do |line|
                  tds = line.css("> td")
                  next if tds.blank?
                  text_arr = tds.map(&:text)
                  day_seqno = text_arr[1].to_i
                  cc_id = text_arr[2].to_i
                  team_a_str = text_arr[3].split(" ").join(" ")
                  team_a_cc = league_cc.league_team_ccs.where(name: team_a_str).first
                  unless team_a_cc.present?
                    raise RuntimeError, "Team #{team_a_str} not found", caller
                  end
                  team_b_str = text_arr[4].split(" ").join(" ")
                  team_b_cc = league_cc.league_team_ccs.where(name: team_b_str).first
                  unless team_b_cc.present?
                    raise RuntimeError, "Team #{team_b_str} not found", caller
                  end
                  date_str = text_arr[5]
                  result = text_arr[6]
                  dummy = text_arr[7]
                  host_str = text_arr[8]
                  host_cc = league_cc.league_team_ccs.where(name: host_str).first
                  unless team_b_cc.present?
                    raise RuntimeError, "Team #{host_str} not found", caller
                  end
                  time_str = text_arr[9]
                  date = DateTime.parse("#{date_str} #{time_str}")
                  reg_date_str = text_arr[10]
                  reg_date = Date.parse(reg_date_str)
                  party = league.parties.where(day_seqno: day_seqno, league_team_a: team_a_cc.league_team, league_team_b: team_b_cc.league_team).first
                  unless team_b_cc.present?
                    raise RuntimeError, "Party #{{ day_seqno: day_seqno, team_a_cc_name: team_a_cc.name, team_b_cc_name: team_b_cc.name }} not found", caller
                  end
                  party.assign_attributes(cc_id: cc_id)
                  party.save!
                  args = { cc_id: cc_id,
                           league_cc_id: league_cc.id,
                           party_id: party.id,
                           league_team_a_cc: team_a_cc,
                           league_team_b_cc: team_b_cc,
                           league_team_host_cc: host_cc,

                  }
                  party_cc = PartyCc.find_by_cc_id_and_league_cc_id(cc_id, league_cc.id) || PartyCc.new(args)
                  party_cc.assign_attributes(args)
                  party_cc.save!
                  party_ccs.push(party_cc)
                  parties.push(party)
                end
              end
            end
          end
        end
      end
    end
    return parties, party_ccs
  end

  def sync_team_players(league_team, context)
    league_team_player_done = []
    league_team_cc = league_team.league_team_cc
    if league_team.league_team_cc.present?
      res, doc = get_cc(
        "showLeague_show_teamplayer",
        p: league_team_cc.p,
      )
      doc.css("tr.tableContent > td > table > tr > td > table").each do |table|
        ths = table.css("> tr > th")
        if ths.present? && ths[3].andand.text == "Pass-Nr."
          table.css("> tr").each do |tr|
            tds = tr.css("> td")
            next if tds.blank?
            cc_id = tds[3].text.to_i
            ba_id = tds[4].text.to_i
            player = Player.find_by_ba_id(ba_id) || Player.find_by_cc_id(cc_id)
            if player.present?
              league_team_player_done.push(player)
            end
          end
        end
      end
    end

    return league_team_player_done
  end
end
