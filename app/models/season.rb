class Season < ActiveRecord::Base
  has_many :tournaments
  has_many :season_participations
  has_many :player_rankings
  REFLECTION_KEYS=["tournaments", "season_participations"]

  def self.current_season
    year = (Date.today - 6.month).year
    @current_season = Season.find_by_name("#{year}/#{year+1}")
  end

  def previous
    @previous || Season.find_by_ba_id(ba_id - 1)
  end
end
