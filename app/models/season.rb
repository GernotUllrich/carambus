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
  REFLECTION_KEYS=["tournaments", "season_participations"]

  def self.current_season
    year = (Date.today - 6.month).year
    @current_season = Season.find_by_name("#{year}/#{year+1}")
  end

  def previous
    @previous || Season.find_by_ba_id(ba_id - 1)
  end
end
