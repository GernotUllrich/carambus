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
  has_one :setting

  COLUMN_NAMES = {
      "Logo" => "",
      "Shortname (BA)" => "regions.shortname",
      "Name" => "regions.name",
      "Email" => "regions.email",
      "Address" => "regions.address",
      "Country" => "",
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
end
