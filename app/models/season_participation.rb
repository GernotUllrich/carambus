# == Schema Information
#
# Table name: season_participations
#
#  id         :bigint           not null, primary key
#  data       :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  club_id    :integer
#  player_id  :integer
#  season_id  :integer
#
# Indexes
#
#  index_season_participations_on_foreign_keys  (player_id,club_id,season_id) UNIQUE
#
class SeasonParticipation < ApplicationRecord
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
