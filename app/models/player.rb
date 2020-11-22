class Player < ActiveRecord::Base
  belongs_to :club
  has_many :game_participations
  has_many :seedings
  has_many :season_participations
  has_many :player_rankings
  has_one :admin_user, class_name: "User", foreign_key: "player_id"
  REFLECTION_KEYS = ["club", "game_participations", "seedings", "season_participations"]

  def fullname
    "#{lastname}, #{firstname}"
  end
end
