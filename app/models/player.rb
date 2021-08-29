# == Schema Information
#
# Table name: players
#
#  id         :bigint           not null, primary key
#  firstname  :string
#  guest      :boolean          default(FALSE), not null
#  lastname   :string
#  title      :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  ba_id      :integer
#  club_id    :integer
#
# Indexes
#
#  index_players_on_ba_id    (ba_id) UNIQUE
#  index_players_on_club_id  (club_id)
#
class Player < ApplicationRecord
  belongs_to :club
  has_many :game_participations
  has_many :seedings
  has_many :season_participations
  has_many :player_rankings
  has_one :admin_user, class_name: "User", foreign_key: "player_id"
  REFLECTION_KEYS = ["club", "game_participations", "seedings", "season_participations"]

  COLUMN_NAMES = {#TODO FILTERS
                  "Id" => "players.id",
                  "Firstname" => "players.firstname",
                  "Lastname" => "players.lastname",
                  "Title" => "players.title",
                  "Club" => "clubs.shortname",
                  "Region" => "regions.shortname",
                  "BaId" => "players.ba_id",
  }

  def fullname
    "#{lastname}, #{firstname}"
  end

  def simple_firstname
    firstname.gsub("Dr.", "")
  end
end
