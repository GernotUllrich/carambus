  class SeasonParticipation < ActiveRecord::Base
  belongs_to :season
  belongs_to :player
  belongs_to :club
  REFLECTION_KEYS = ["season", "player", "club"]
end
