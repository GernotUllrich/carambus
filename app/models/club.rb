# == Schema Information
#
# Table name: clubs
#
#  id         :bigint           not null, primary key
#  address    :text
#  dbu_entry  :string
#  email      :string
#  founded    :string
#  homepage   :string
#  logo       :string
#  name       :string
#  priceinfo  :text
#  shortname  :string
#  status     :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  ba_id      :integer
#  cc_id      :integer
#  region_id  :integer
#
# Indexes
#
#  index_clubs_on_ba_id         (ba_id) UNIQUE
#  index_clubs_on_foreign_keys  (ba_id) UNIQUE
#
class Club < ApplicationRecord
  belongs_to :region
  has_many :players, -> { where(type: nil) }
  has_many :season_participations
  has_many :tournament_locations, as: :organizer, class_name: "Location"
  has_many :organized_tournaments, as: :organizer, class_name: "Tournament", dependent: :destroy
  has_many :league_teams

  attr_accessor :season_id

  BA_COLUMNS = [
    :address,
    :dbu_entry,
    :email,
    :founded,
    :homepage,
    :logo,
    :name,
    :priceinfo,
    :shortname,
    :status,
    :ba_id
  ]
  CA_COLUMNS = [
    :region_id,
    :id,
    :created_at,
    :updated_at
  ]

  REFLECTION_KEYS = ["region", "players", "season_participations"]
  COLUMN_NAMES = { #TODO FILTERS
                   "BA_ID" => "clubs.ba_id",
                   "CC_ID" => "clubs.cc_id",
                   "Region" => "regions.shortname",
                   "Name" => "clubs.name",
                   "Shortname" => "clubs.shortname",
                   "Homepage" => "",
                   "Status" => "",
                   "Founded" => "",
                   "Dbu entry" => "",
  }

  def self.scrape_clubs(opts = {})
    player_details = opts[:player_details].presence
    skip_r = true
    skip_c = true
    Region.where(shortname: Region::REGION_SHORTNAMES).order(:shortname).all.each do |region|
      region.scrape_clubs(player_details: player_details)
    end

    #fix title
    Player.where(type: nil).where("title ~ 'Herr.'").update_all(title: 'Herr')
    Player.where(type: nil).where("title ~ 'Frau.'").update_all(title: 'Frau')
  end

  #x clubs.ba_id regions.name clubs.name clubs.shortname
  def scrape_single_club(opts = {})
    season = opts[:season] || Season.last
    player_details = opts[:player_details]
    force_update = opts[:force_update]
    url = "https://#{region.shortname.downcase}.billardarea.de"
    club_detail = "/cms_clubs/details/#{ba_id}"
    detail_url = url + club_detail

    Rails.logger.info "reading #{detail_url} - club details"
    detail_uri = URI(detail_url)
    res = Net::HTTP.post_form(detail_uri, 'data[Season][check]' => '87gdsjk8734tkfdl', 'data[Season][season_id]' => "#{season.ba_id}")
    doc_detail = Nokogiri::HTML(res.body)
    club_logo = doc_detail.css("\#tabs-1 img").text.strip
    club_ba_id = club_detail.match(/.*\/(\d+)$/).andand[1].to_i
    club_name = doc_detail.css(".left fieldset:nth-child(1) .element").text.strip
    club_shortname = doc_detail.css(".left fieldset:nth-child(2) .element").text.strip
    club_homepage = doc_detail.css("\#tabs-1 a:nth-child(1)").text.strip
    club_players = doc_detail.css("\#clubs_table a").map { |d| d.attribute("href").value.match(/.*\/(\d+)$/).andand[1].to_i }

    club_email = doc_detail.css("\#tabs-1").children[1].children[9].andand.text.andand.strip.andand.gsub(/.*;< (.*) >.*/, '\1').andand.gsub(/[\t\r\n]/, "").andand.gsub("Email", "").andand.reverse
    club_priceinfo = doc_detail.css("pre").inner_html
    club_address = doc_detail.css(".left fieldset:nth-child(3) .element").inner_html
    club_status = doc_detail.css(".right fieldset:nth-child(1) .element").children
    club_founded = doc_detail.css(".right fieldset:nth-child(2) .element").text.strip
    club_dbu_entry = doc_detail.css(".right fieldset~ fieldset+ fieldset .element").text.strip
    update(
      name: club_name,
      shortname: club_shortname,
      homepage: club_homepage,
      email: club_email,
      address: club_address,
      priceinfo: club_priceinfo,
      status: club_status,
      founded: club_founded,
      dbu_entry: club_dbu_entry,
      region: region,
      logo: club_logo
    )
    if player_details
      known_players = players.map(&:ba_id)
      (club_players - known_players).each do |player_ba_id|
        player = Player.find_by_ba_id(player_ba_id)
        skip_details = player.present? && !force_update
        player ||= players.new()
        player.update(ba_id: player_ba_id)
        sp = SeasonParticipation.find_by_player_id_and_season_id_and_club_id(player.id, season.id, id) ||
          SeasonParticipation.create(player_id: player.id, season_id: season.id, club_id: id)
        unless skip_details
          url = "https://#{region.shortname.downcase}.billardarea.de"
          player_details_url = "#{url}/cms_clubs/playerdetails/#{ba_id}/#{player.ba_id}"
          Rails.logger.info "reading #{player_details_url} - player details of player [#{player.ba_id}] on club #{shortname} [#{ba_id}]"
          html_player_detail = URI.open(player_details_url)
          doc_player_detail = Nokogiri::HTML(html_player_detail)
          player_ba_id = doc_player_detail.css("#tabs-1 fieldset:nth-child(1) legend+ .element .field").text.strip.to_i
          if player_ba_id == player.ba_id
            player_title = doc_player_detail.css("#tabs-1 fieldset:nth-child(1) .element:nth-child(3) .field").text.strip
            player_lastname, player_firstname = doc_player_detail.css("#tabs-1 fieldset:nth-child(1) .element:nth-child(4) .field").text.strip.split(", ")
            player.update(title: player_title, lastname: player_lastname, firstname: player_firstname)
          end
        end
      end
    end
  end
end
