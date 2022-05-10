# == Schema Information
#
# Table name: parties
#
#  id                  :bigint           not null, primary key
#  data                :text
#  date                :datetime
#  day_seqno           :integer
#  group               :string
#  register_at         :date
#  remarks             :text
#  round               :string
#  section             :string
#  status              :integer
#  time                :datetime
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  ba_id               :integer
#  cc_id               :integer
#  host_league_team_id :integer
#  league_id           :integer
#  league_team_a_id    :integer
#  league_team_b_id    :integer
#  no_show_team_id     :integer
#
class Party < ApplicationRecord
  belongs_to :league
  has_many :games
  belongs_to :league_team_a, class_name: "LeagueTeam", foreign_key: :league_team_a_id, optional: true
  belongs_to :league_team_b, class_name: "LeagueTeam", foreign_key: :league_team_b_id, optional: true
  belongs_to :host_league_team, class_name: "LeagueTeam", foreign_key: :host_league_team_id, optional: true
  belongs_to :no_show_team, class_name: "LeagueTeam", foreign_key: :no_show_team_id, optional: true
  has_one :party_tournament
  has_one :party_cc
  has_many :party_games, -> { order("seqno") }

  serialize :data, Hash
  serialize :remarks, Hash

  def name
    "#{league_team_a.name} - #{league_team_b.name}"
  end
end
