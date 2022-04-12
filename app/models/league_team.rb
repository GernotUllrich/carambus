# == Schema Information
#
# Table name: league_teams
#
#  id         :bigint           not null, primary key
#  name       :string
#  shortname  :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  ba_id      :integer
#  club_id    :integer
#  league_id  :integer
#
class LeagueTeam < ApplicationRecord
  belongs_to :league, optional: true
  belongs_to :club, optional: true
  has_many :seedings
end
