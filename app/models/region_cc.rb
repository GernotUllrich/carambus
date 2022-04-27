# == Schema Information
#
# Table name: region_ccs
#
#  id         :bigint           not null, primary key
#  base_url   :string
#  context    :string
#  name       :string
#  shortname  :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  cc_id      :integer
#  region_id  :integer
#
# Indexes
#
#  index_region_ccs_on_cc_id_and_context  (cc_id,context) UNIQUE
#
class RegionCc < ApplicationRecord

  belongs_to :region
  has_many :branch_ccs

  alias_attribute :fedId, :cc_id

  PATH_MAP = {
    #"showClubList" => "/admin/approvement/player/showClubList.php",
    "createLeagueSave" => "/admin/league/createLeagueSave.php",
    "showLeagueList" => "/admin/report/showLeagueList.php",
    "showLeague" => "/admin/league/showLeague.php",
    "admin_report_showLeague" => "/admin/report/showLeague.php",
    "admin_report_showLeague_create_team" => "/admin/report/showLeague_create_team.php",
    # teamCounter: 2
    # fedId: 20
    # leagueId: 32
    # branchId: 6
    # subBranchId: 1
    # seasonId: 8
    "spielbericht_anzeigen" => "/admin/reportbuilder2/spielbericht_anzeigen.php",
    "showTeam" => "/admin/announcement/team/showTeam.php",
    "editTeam" => "admin/announcement/team/editTeamCheck.php",
    "showClubList" => "/admin/announcement/team/showClubList.php",
    # fedId: 20
    # branchId: 6
    # subBranchId: 11
    # sportDistrictId: *
    # statusId: 1   (1 = active)
  }

  PHPSESSID = "9310db9a9970e8a02ed95ed8cd8e4309"
  BASE_URL = "https://e12112e2454d41f1824088919da39bc0.club-cloud.de"

  def post_cc(action, options = {})
    if PATH_MAP[action].present?
      url = base_url + PATH_MAP[action]
      Rails.logger.debug "[post_cc] POST #{action} with payload #{options}"
      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      req = Net::HTTP::Post.new(uri.request_uri)
      req["cookie"] = "PHPSESSID=#{PHPSESSID}"
      req['Content-Type'] = 'application/x-www-form-urlencoded'
      req.set_form_data(options.reject { |k, v| v.blank? })
      res = http.request(req)
      if res.message == "OK"
        doc = Nokogiri::HTML(res.body)
      else
        doc = Nokogiri::HTML(res.message)
      end
      return [res, doc]
    else
      raise ArgumentError, "Unknown Action", caller
    end
  end

  def get_cc(action, options = {})
    if PATH_MAP[action].present?
      url = base_url + PATH_MAP[action]
      Rails.logger.debug "[post_cc] POST #{action} with payload #{options}"
      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      req = Net::HTTP::Get.new(uri.path)
      req.set_form_data(options)
      # instantiate a new Request object
      req = Net::HTTP::Get.new(uri.path + "#{'?' unless uri.path.match(/\?$/)}" + req.body)
      req["cookie"] = "PHPSESSID=#{PHPSESSID}"
      res = http.request(req)
      if res.message == "OK"
        doc = Nokogiri::HTML(res.body)
      else
        doc = Nokogiri::HTML(res.message)
      end
      return [res, doc]
    else
      raise ArgumentError, "Unknown Action", caller
    end
  end

  def self.sync_regions(region)
    regions = []
    res, doc = RegionCc.new(base_url: RegionCc::BASE_URL).get_cc("showClubList")
    selector = doc.css('select[name="fedId"]')[0]
    options = selector.css("option")
    options.each do |option|
      cc_id = option["value"].to_i
      name_str = option.text.strip
      match = name_str.match(/(.*) \((.*)\)/)
      region_name = match[1]
      shortname = match[2]
      region = Region.find_by_shortname(shortname)
      if region_name != region.name
        Rails.logger.warn "REPORT! [sync_regions] Name des Regionalverbandes unterschiedlich: CC: #{region_name} BA: #{region.name}"
      end
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
    end
    return regions
  end

  def sync_branches
    branches = []
    context = shortname.downcase
    res, doc = get_cc("showClubList")
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
        Rails.logger.error "[get_branches_from_cc] #{msg}"
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

  def sync_competitions
    competitions = []
    context = shortname.downcase
    # for all branches
    BranchCc.where(context: context).each do |branch_cc|
      res, doc = post_cc("showLeagueList", fedId: cc_id, branchId: branch_cc.cc_id)
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
          Rails.logger.error "[sync_competitions] #{msg}"
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

  def sync_seasons_in_competitions(season_name)

    context = shortname.downcase
    season = Season.find_by_name(season_name)
    if season.blank?
      raise ArgumentError, "unknown season name #{season_name}", caller
    end
    competition_ccs = []
    # for all branches
    BranchCc.where(context: context).each do |branch_cc|
      branch_cc.competition_ccs.each do |competition_cc|
        res, doc = post_cc(
          "showLeagueList",
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

  def sync_leagues(season_name, opts = {})

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
          res, doc = post_cc(
            "showLeagueList",
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
                league = League.where(season: season, name: l_name, staffel_text: s_name, organizer_type: "Region", organizer_id: [region.id, dbu_region_id], discipline: competition_cc.discipline.super_discipline).first
                league.assign_attributes(cc_id: cc_id)
              end
              unless league.present?
                Rails.logger.warn "REPORT! [sync_leagues] Name der Liga entspricht keiner BA Liga: CC: #{{ season_name: season.name, name: name_str, organizer_type: "Region", organizer_id: [self.id, dbu_region_id], discipline: competition_cc.discipline }.inspect}"
              else
                args = { cc_id: cc_id, context: context, name: name_str, season_cc_id: season_cc.id, league_id: league.id }
                league_cc = LeagueCc.find_by_cc_id_and_season_cc_id_and_context(cc_id, season_cc.id, context) || LeagueCc.new(args)
                league_cc.assign_attributes(args)
                res2, doc2 = post_cc(
                  "showLeague",
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
            res, doc = post_cc(
              "admin_report_showLeague",
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
                    Rails.logger.warn "REPORT! [sync_league_teams] Name des Clubs entspricht keiner BA Liga: CC: #{{ shortname: team_club_str, region: region.shortname }.inspect}"
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
                    Rails.logger.warn "REPORT! [sync_league_teams] Name der Liga Mannschaft entspricht keinem BA LigaTeam: CC: #{{ name: name_str, league_id: league_cc.league.id, club_id: club.id }.inspect}"
                  else
                    league_team.assign_attributes(cc_id: cc_id)
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
        res, doc = post_cc(
          "showClubList",
          sortKey: "NAME",
          fedId: branch_cc.fedId,
          branchId: branch_cc.cc_id,
          subBranchId: competition_cc.cc_id,
          sportDistrictId: "*",
          statusId: 1,
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
              Rails.logger.warn "REPORT! [sync_clubs] no club with name '#{shorname}' found in region #{context}"
            end
          else
            if c.shortname != shortname
              Rails.logger.warn "REPORT! [sync_clubs] name mismatch found - CC: '#{shorname}' BA: #{c.shortname}"
            end
            done_club_cc_ids.push(cc_id)
            done_clubs.push(c)
          end
        end
      end
    end
    return done_clubs
  end

end
