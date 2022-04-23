# == Schema Information
#
# Table name: disciplines
#
#  id                  :bigint           not null, primary key
#  data                :text
#  name                :string
#  type                :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  super_discipline_id :integer
#  table_kind_id       :integer
#
# Indexes
#
#  index_disciplines_on_foreign_keys            (name,table_kind_id) UNIQUE
#  index_disciplines_on_name_and_table_kind_id  (name,table_kind_id) UNIQUE
#
class Competition < Discipline

  has_many :competition_ccs

  def self.get_competitions_from_cc(region)

    if Region::URL_MAP[region.shortname.downcase].blank?
      Rails.logger.error "ERROR CC [get_competitions_from_cc] Region unknown to CC migration"
      exit 1
    end
    region_cc = region.region_cc
    competitions = []
    # for all branches
    BranchCc.where(context: region.shortname.downcase).each do |branch_cc|
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
          Rails.logger.error "ERROR CC [get_competitions_from_cc] No Competition with name #{carambus_name} in database"
          exit 1
        else
          args = { cc_id: cc_id, branch_cc_id: branch_cc.id, discipline_id: competition.id, context: region.shortname.downcase, name: name }
          competition_cc = CompetitionCc.where(cc_id: cc_id, branch_cc_id: branch_cc.id).first || CompetitionCc.new(args)
          competition_cc.assign_attributes(args)
          competition_cc.save
          competitions.push(competition)
        end
      end
    end

    return competitions
  end
end
