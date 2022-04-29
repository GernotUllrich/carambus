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

  def fix_player_without_ba_id(firstname, lastname, should_be_ba_id = nil, should_be_club_id = nil)
    ret = nil
    # players = Player.joins(party_a_games: { party: :league }).where(leagues: { season_id: 2, organizer_type: "Region, organizer_id: id" }).where(firstname: firstname, lastname: lastname).where("players.ba_id > 99900000").uniq
    players = Player.where(firstname: firstname, lastname: lastname)
    if players.present?
      players.each do |player|
        players_same_name_arr = Player.where(firstname: player.firstname, lastname: player.lastname).to_a
        if players_same_name_arr.count == 1
          begin
            # try to update ba_id
            ret = players_same_name_arr[0]
            players_same_name_arr[0].update(ba_id: should_be_ba_id)
          rescue ActiveRecord::RecordNotUnique, PG::UniqueViolation, PG::DuplicateColumn => e
            Rails.logger.info "REPORT! [fix_players_without_ba_id] Spieler mit anderem Namen und gleicher ba_id (#{should_be_ba_id}) gefunden: #{Player.find_by_ba_id(should_be_ba_id).fullname} hier: #{lastname}, #{firstname}"
          end
        else
          begin
            player_ok_arr = Player.where(firstname: firstname, lastname: lastname, ba_id: should_be_ba_id).to_a
            player_tmp_arr = Player.where(firstname: firstname, lastname: lastname).where("ba_id > 999000000").to_a
            if player_ok_arr.count == 1 && player_tmp_arr.count >= 1
              ret = Player.merge_players(player_ok_arr.first, player_tmp_arr.first)
            else
              Rails.logger.info "REPORT! [fix_players_without_ba_id] Kein Ersatz Record für Spieler gefunden: should_be_ba_id: #{should_be_ba_id} hier: #{lastname}, #{firstname}"
              if should_be_ba_id.present?
                begin
                  ret = Player.create!(firstname: firstname, lastname: lastname, ba_id: should_be_ba_id, club_id: should_be_club_id)
                rescue Exception => e
                  Rails.logger.info "REPORT! [fix_player_without_ba_id] #{e}, kann Spieler Record nicht anlegen: firstname: #{firstname}, lastname: #{lastname}, ba_id: #{should_be_ba_id}, club_id: #{should_be_club_id}"
                end
              end
            end
          rescue ActiveRecord::RecordNotUnique, PG::UniqueViolation, PG::DuplicateColumn => e
            Rails.logger.info "REPORT! [fix_players_without_ba_id] Spieler mit anderem Namen und gleicher ba_id (#{should_be_ba_id}) gefunden: #{Player.find_by_ba_id(should_be_ba_id).fullname} hier: #{lastname}, #{firstname}"
          end
        end
      end
    else
      begin
        ret = Player.create(firstname: firstname, lastname: lastname, ba_id: should_be_ba_id, club_id: should_be_club_id)
      rescue Exception => e
        Rails.logger.info "REPORT! [fix_player_without_ba_id] #{e}, kann Spieler Record nicht anlegen: firstname: #{firstname}, lastname: #{lastname}, ba_id: #{should_be_ba_id}, club_id: #{should_be_club_id}"
      end
    end
    return ret
  end

  def display_shortname
    shortname
  end

end
