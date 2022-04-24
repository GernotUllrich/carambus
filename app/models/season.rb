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

  def scrape_tournaments(ba_ids = [])
    season = self
    Region.all.each do |region|
      url = "https://#{region.shortname.downcase}.billardarea.de"
      uri = URI(url + '/cms_single')
      Rails.logger.info "reading #{url + '/cms_single'} - region #{region.shortname} single tournaments season #{season.name}"
      res = Net::HTTP.post_form(uri, 'data[Season][check]' => '87gdsjk8734tkfdl', 'data[Season][season_id]' => "#{season.ba_id}")
      doc = Nokogiri::HTML(res.body)
      tabs = doc.css("#tabs a")
      tabs.each_with_index do |tab, ix|
        tab_text = tab.text.strip
        if Discipline::DE_DISCIPLINE_NAMES.include?(tab_text)
          discipline_name = Discipline::DISCIPLINE_NAMES[Discipline::DE_DISCIPLINE_NAMES.index(tab_text)]
          discipline = Discipline.find_by_name(discipline_name)
          tab = "#tabs-#{ix + 1} a"
          lines = doc.css(tab)
          lines.each do |line|
            name = line.text.strip
            url = line.attribute("href").value
            m = url.match(/\/cms_(single|leagues)\/(plan|show)\/(\d+)$/)
            ba_id = m[3] rescue nil
            single_or_league = m[1] rescue nil
            plan_or_show = m[2] rescue nil
            if ba_id.present? && (ba_ids.blank? || ba_ids.include?(ba_id))
              tournament = Tournament.find_by_ba_id(ba_id) || Tournament.create(ba_id: ba_id, discipline_id: Discipline.find_by_name("-"))
              tournament.update(title: name, region_id: region.id, discipline_id: discipline.id, season_id: season.id, plan_or_show: plan_or_show, single_or_league: single_or_league, organizer: region)
              tournament.scrape_single_tournament(game_details: true)
              tournament.update_columns(last_ba_sync_date: Time.now)
            else
              ba_id
            end
          end
        else
          tab_text
          break
        end
      end
    end
  end

  def previous
    @previous || Season.find_by_ba_id(ba_id - 1)
  end

end
