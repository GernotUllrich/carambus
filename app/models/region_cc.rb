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

  PATH_MAP = {
    "showClubList" => "/admin/approvement/player/showClubList.php",
    "showLeagueList" => "/admin/report/showLeagueList.php"
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
      res,doc = post_cc("showLeagueList", fedId: cc_id, branchId: branch_cc.cc_id)
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
            args = {cc_id: cc_id, context: context, name: s_name, season_id: season.id, competition_cc_id: competition_cc.id}
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

  def sync_leagues(season_name)

    context = shortname.downcase
    season = Season.find_by_name(season_name)
    if season.blank?
      raise ArgumentError, "unknown season name #{season_name}", caller
    end
    # DBU Ligen mit Beteiligung der Region
    dbu_region = Region.find_by_shortname("portal")
    dbu_leagues = League.joins(:league_teams => :club).where(season: season, organizer_type: "Region", organizer_id: dbu_region.id).where("clubs.region_id = ?", id).uniq

    league_ccs = []
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
            args = {cc_id: cc_id, context: context, name: s_name, season_id: season.id, competition_cc_id: competition_cc.id}
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

end
