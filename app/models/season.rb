# == Schema Information
#
# Table name: seasons
#
#  id         :bigint           not null, primary key
#  data       :text
#  name       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  ba_id      :integer
#
# Indexes
#
#  index_seasons_on_ba_id  (ba_id) UNIQUE
#  index_seasons_on_name   (name) UNIQUE
#
class Season < ApplicationRecord
  has_many :tournaments
  has_many :season_participations
  has_many :player_rankings
  has_many :season_ccs
  REFLECTION_KEYS = ["tournaments", "season_participations"]

  def self.current_season
    year = (Date.today - 6.month).year
    @current_season = Season.find_by_name("#{year}/#{year + 1}")
  end

  def self.season_from_date(date)
    year = (date - 6.month).year
    return Season.find_by_name("#{year}/#{year + 1}")
  end

  def self.update_seasons
    (2009..(Date.today.year)).each_with_index do |year, ix|
      Season.find_by_name("#{year}/#{year + 1}") || Season.create(ba_id: ix + 1, name: "#{year}/#{year + 1}")
    end
  end

  def previous
    @previous || Season.find_by_ba_id(ba_id - 1)
  end

  def self.get_competition_cc_ids_from_cc(season_name, region)
    if Region::URL_MAP[region.shortname.downcase].blank?
      Rails.logger.error "ERROR CC [get_competition_cc_ids_from_cc] Region unknown to CC migration"
      exit 1
    end
    context = region.shortname.downcase
    region_cc = region.region_cc
    competition_ccs = []
    # for all branches
    BranchCc.where(context: region.shortname.downcase).each do |branch_cc|
      branch_competition_cc_ids = []
      url = Region::URL_MAP[region.shortname.downcase] + "/admin/report/showLeagueList.php?p=#{region_cc.cc_id}-#{branch_cc.cc_id}-1-1"
      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      req = Net::HTTP::Get.new(uri.request_uri)
      req["cookie"] = "PHPSESSID=9310db9a9970e8a02ed95ed8cd8e4309"
      res = http.request(req)
      doc = Nokogiri::HTML(res.body)

      selector_1 = doc.css('select[name="fedId"]')[0]
      options_1 = selector_1.css('option[@selected="selected"]')
      hidden_fedId = doc.css('input[name="fedId"]').andand[0].andand["value"].to_i
      if options_1[0]["value"].to_i != region_cc.cc_id || hidden_fedId != region_cc.cc_id
        Rails.logger.error "ERROR CC [get_competitions_from_cc] scrape error unexpected fedId #{hidden_fedId} - requested #{region_cc.cc_id}"
      end
      hidden_branchId = doc.css('input[name="branchId"]').andand[0].andand["value"].to_i
      if hidden_branchId != branch_cc.cc_id
        Rails.logger.error "ERROR CC [get_competitions_from_cc] scrape error unexpected hidden branchId #{hidden_branchId} - requested #{branch_cc.cc_id}"
      end
      # at first look for seasons in currently selected competition
      selector_2 = doc.css('select[name="subBranchId"]')[0]
      options_2 = selector_2.css('option[@selected="selected"]')
      selected_branch_competition_cc_id = options_2[0]["value"].to_i
      competition_cc = CompetitionCc.where(cc_id: selected_branch_competition_cc_id, branch_cc_id: branch_cc.id, context: context).first
      selector = doc.css('select[name="seasonId"]')[0]
      options = selector.css("option")
      season_found = false
      options.each do |option|
        cc_id = option["value"].to_i
        name_str = option.text.strip
        match = name_str.match(/\s*(.*)\/(.*)\s*/)
        name = match[0].strip
        if name == season_name
          season_found = true
          break
        end
      end
      if season_found
        competition_ccs.push(competition_cc)
        branch_competition_cc_ids.push(competition_cc.cc_id)
      end

      # then post on other competitions
      selector_2 = doc.css('select[name="subBranchId"]')[0]
      options_2 = selector_2.css('option')
      options_2.each do |option|
        selected_branch_competition_cc_id = options_2[0]["value"].to_i
        competition_cc = CompetitionCc.where(cc_id: selected_branch_competition_cc_id, branch_cc_id: branch_cc.id, context: context).first
        next if branch_competition_cc_ids.include?(competition_cc.cc_id)

        url = Region::URL_MAP[region.shortname.downcase] + "/admin/report/showLeagueList.php?"
        uri = URI(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        req = Net::HTTP::Post.new(uri.request_uri)
        req["cookie"] = "PHPSESSID=9310db9a9970e8a02ed95ed8cd8e4309"
        req['Content-Type'] = 'application/x-www-form-urlencoded'
        req.set_form_data(fedId: region_cc.cc_id,
                          branchId: branch_cc.cc_id,
                          subBranchId: selected_branch_competition_cc_id
        )

        res = http.request(req)
        doc = Nokogiri::HTML(res.body)

        selector = doc.css('select[name="seasonId"]')[0]
        options = selector.css("option")
        season_found = false
        options.each do |option|
          cc_id = option["value"].to_i
          name_str = option.text.strip
          match = name_str.match(/\s*(.*)\/(.*)\s/)
          name = match[1]
          if name == season_name
            season_found = true
            break
          end
        end
        if season_found
          competition_ccs.push(competition_cc)
          branch_competition_cc_ids.push(competition_cc.cc_id)
        end
      end
    end

    return competitions_ccs
  end
end
