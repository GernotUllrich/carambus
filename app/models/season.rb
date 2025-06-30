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
  include LocalProtector
  has_many :tournaments
  has_many :season_participations
  has_many :player_rankings
  has_many :season_ccs
  has_many :leagues

  @year = (Date.today - 6.month).year
  @current_season = Season.find_by_name("#{@year}/#{@year + 1}")

  REFLECTION_KEYS = %w[tournaments season_participations]
  MAX_BA_SEASON = "2021/2022"

  def self.current_season
    if (Date.today - 6.month).year != @year
      @year = (Date.today - 6.month).year
      @current_season = Season.find_by_name("#{@year}/#{@year + 1}")
      unless @current_season.present?
        Season.update_seasons
        @current_season = Season.find_by_name("#{year}/#{year + 1}")
      end
    end
    @current_season
  end

  def self.season_from_date(date)
    year = (date - 6.month).year
    Season.find_by_name("#{year}/#{year + 1}")
  end

  def self.update_seasons
    (2009..(Date.today.year)).each_with_index do |year, ix|
      Season.find_by_name("#{year}/#{year + 1}") || Season.create(ba_id: ix + 1, name: "#{year}/#{year + 1}")
    end
  end

  def scrape_single_tournaments_public_cc(opts = {})
    (Region::SHORTNAMES_ROOF_ORGANIZATION + Region::SHORTNAMES_CARAMBUS_USERS + Region::SHORTNAMES_OTHERS).each do |shortname|
      # next unless shortname == "NBV"
      region = Region.find_by_shortname(shortname)
      region&.scrape_single_tournament_public(self, opts)
    end
  end

  def previous
    @previous || Season.find_by_ba_id(ba_id - 1)
  end

  def next_season
    @pnext_season || Season.find_by_ba_id(ba_id + 1)
  end

  def copy_season_participations_to_next_season
    new_season = next_season
    unless new_season.season_participations.present?
      season_participations.each do |sp|
        sp_new = SeasonParticipation.create(
          player_id: sp.player_id,
          season_id: new_season.id,
          club_id: sp.club_id,
          status: "temporary",
          region_id: sp.region_id,
          global_context: false
        )
      end
    end
  end
end
