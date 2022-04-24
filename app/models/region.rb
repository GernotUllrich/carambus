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
  has_one :region_cc

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

  def scrape_clubs(opts = {})
    Rails.logger.info "region.scrape_clubs - opts=#{opts.inspect}"
    if Rails.env != 'production' || opts[:from_background] || (!opts[:player_details] && clubs.count < 15)
      player_details = opts[:player_details].presence
      url = "https://#{self.shortname.downcase}.billardarea.de"
      Rails.logger.info "reading #{url + '/cms_clubs'} - region clubs"
      html = URI.open(url + '/cms_clubs')
      doc = Nokogiri::HTML(html)
      club_details = doc.css("td:nth-child(2) a").map { |d| d.attribute("href").value }
      club_details.each do |club_detail|
        club_ba_id = club_detail.match(/.*\/(\d+)$/).andand[1].to_i
        club = Club.find_by_ba_id(club_ba_id)
        # skip_c = false if club.present? && club.ba_id == 3119 && skip_c == true
        # next if skip_c
        if club.blank?
          club = Club.new(ba_id: club_ba_id, region_id: self.id)
        end
        if player_details || club.new_record?
          club.save!
          Season.where("name ilike '%#{Date.today.year}%'").order(name: :desc).each do |season|
            club.scrape_single_club(player_details: player_details, season: season, force_update: false)
          end
        end
      end
    else
      Stalker.enqueue("scrape_clubs",
                      opts.merge(region_id: self.id)
      )
    end
  end

  def display_shortname
    shortname
  end

end
