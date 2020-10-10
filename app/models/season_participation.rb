class SeasonParticipation < ActiveRecord::Base
  belongs_to :season
  belongs_to :player
  belongs_to :club
  REFLECTION_KEYS = ["season", "player", "club"]
  COLUMN_NAMES = {
      "Season" => "seasons.name",
      "Name" => "players.lastname||', '||players.firstname",
      "Club" => "clubs.shortname",
      "Region" => "regions.shortname"
  }
end
