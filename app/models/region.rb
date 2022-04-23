require 'open-uri'

# == Schema Information
#
# Table name: regions
#
#  id         :bigint           not null, primary key
#  address    :text
#  email      :string
#  logo       :string
#  name       :string
#  shortname  :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  country_id :integer
#
# Indexes
#
#  index_regions_on_country_id  (country_id)
#  index_regions_on_shortname   (shortname) UNIQUE
#
class Region < ApplicationRecord
  belongs_to :country
  has_many :clubs
  has_many :tournaments
  has_many :player_rankings
  has_many :tournament_locations, as: :organizer, class_name: "Location"
  has_many :organized_tournaments, as: :organizer, class_name: "Tournament"
  has_many :organized_leagues, as: :organizer, class_name: "League"
  has_one :setting
  has_many :leagues, as: :organizer, class_name: "League"

  COLUMN_NAMES = {
      "Logo" => "",
      "Shortname (BA)" => "regions.shortname",
      "Name" => "regions.name",
      "Email" => "regions.email",
      "Address" => "regions.address",
      "Country" => "",
  }

  URL_MAP = {
    "nbv" => "https://e12112e2454d41f1824088919da39bc0.club-cloud.de"
  }

  def self.scrape_regions
    country_de = Country.find_by_code("DE")
    url = "https://portal.billardarea.de"
    Rails.logger.info "reading index page - to scrape regions"
    html = URI.open(url)
    doc = Nokogiri::HTML(html)
    regions = doc.css(".img_bw")
    regions.each do |region|
      region_name = region.attribute("alt").value
      region_shortname = region.attribute("name").value
      region_logo = url + region.attribute("onmouseover").value.gsub(/MM_swapImage\('#{region_shortname}','','(.*)',1\).*/, '\1')
      r = Region.find_by_shortname(region_shortname) || Region.new
      r.update(name: region_name, shortname: region_shortname, logo: region_logo, country: country_de)
    end
  end

  def display_shortname
    shortname
  end

  def self.get_regions_from_cc(context)
    regions = []
    if URL_MAP[context.downcase].present?
      url = URL_MAP[context.downcase] + "/admin/approvement/player/showClubList.php?"
      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      req = Net::HTTP::Get.new(uri.request_uri)
      req["cookie"] = "PHPSESSID=9310db9a9970e8a02ed95ed8cd8e4309"
      res = http.request(req)
      res
      doc = Nokogiri::HTML(res.body)
      selector = doc.css('select[name="fedId"]')[0]
      options = selector.css("option")
      options.each do |option|
        cc_id = option["value"].to_i
        name_str = option.text
        match = name_str.match(/(.*) \((.*)\)/)
        name = match[1]
        shortname = match[2]
        region = Region.find_by_shortname(shortname)
        unless region.blank?
          if region.name != name
            Rails.logger.warn "WARNING CC [get_regions_from_cc] Name of Region differs: CC: #{name} BA: #{region.name}"
          end
          region_cc = RegionCc.find_by_cc_id(cc_id) || RegionCc.create(cc_id: cc_id, region_id: region.id, context: context, shortname: shortname, name: name)
          region_cc.assign_attributes(cc_id: cc_id, region_id: region.id, context: context, shortname: shortname, name: name)
          region_cc.save
          regions.push(region)
        else
          Rails.logger.error "ERROR CC [get_regions_from_cc] No Region with shortname #{shortname} in database"
        end
      end
    end
    return regions
  end
end
