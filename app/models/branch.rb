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
class Branch < Discipline

  def self.get_branches_from_cc(context, region)

    branches = []
    if Region::URL_MAP[context.downcase].present?
      url = Region::URL_MAP[context.downcase] + "/admin/approvement/player/showClubList.php?"
      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      req = Net::HTTP::Get.new(uri.request_uri)
      req["cookie"] = "PHPSESSID=9310db9a9970e8a02ed95ed8cd8e4309"
      res = http.request(req)
      res
      doc = Nokogiri::HTML(res.body)
      selector_1 = doc.css('select[name="fedId"]')[0]
      options_1 = selector_1.css('option[@selected="selected"]')
      region_cc = RegionCc.find_by_cc_id(options_1[0]["value"].to_i)
      selector = doc.css('select[name="branchId"]')[0]
      options = selector.css("option")
      options.each do |option|
        cc_id = option["value"].to_i
        name_str = option.text.strip
        match = name_str.match(/(.*)(:? \((.*)\))?/)
        name = match[1]
        branch = Branch.find_by_name(name)
        if branch.blank?
          Rails.logger.error "ERROR CC [get_branches_from_cc] No Branch with name #{name} in database"
          exit 1
        else
          args = {cc_id: cc_id, region_cc_id: region_cc.id, discipline_id: branch.id, context: context, name: name}
          branch_cc = BranchCc.find_by_cc_id(cc_id) || BranchCc.new(args)
          branch_cc.assign_attributes(args)
          branch_cc.save
          branches.push(region)
        end
      end
    end
    return branches
  end
end
