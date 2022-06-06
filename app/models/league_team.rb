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
  has_many :parties_a, class_name: "Party", foreign_key: :league_team_a_id
  has_many :parties_b, class_name: "Party", foreign_key: :league_team_b_id
  has_many :parties_as_host, class_name: "Party", foreign_key: :host_league_team_id
  has_many :no_show_parties, class_name: "Party", foreign_key: :no_show_team_id
  has_one :league_team_cc
  has_many :seedings

  COLUMN_NAMES = {
                  "BA_ID" => "league_team_ccs.ba_id",
                  "CC_ID" => "league_team_ccs.cc_id",
                  "Name" => "league_team_ccs.name",
                  "Sparte" => "league_team_ccs.branch_cc.name",
                  "League" => "league_ccs.name",
  }

  def scrape_players_from_ba_league_team

  end
end
