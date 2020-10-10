class Season < ActiveRecord::Base
  has_many :tournaments
  has_many :season_participations
  has_many :player_rankings
  REFLECTION_KEYS=["tournaments", "season_participations"]
end
