class Season < ActiveRecord::Base
  has_many :tournaments
  has_many :season_participations
  REFLECTION_KEYS=["tournaments", "season_participations"]
end
