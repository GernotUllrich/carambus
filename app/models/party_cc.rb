# == Schema Information
#
# Table name: party_ccs
#
#  id                     :bigint           not null, primary key
#  data                   :text
#  day_seqno              :integer
#  integer                :string
#  remarks                :text
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  cc_id                  :integer
#  league_cc_id           :integer
#  league_team_a_cc_id    :integer
#  league_team_b_cc_id    :integer
#  league_team_host_cc_id :string
#  party_id               :integer
#
class PartyCc < ApplicationRecord
  belongs_to :league_cc
  belongs_to :league_team_a_cc, class_name: "LeagueTeamCc", foreign_key: :league_team_a_cc_id, optional: true
  belongs_to :league_team_b_cc, class_name: "LeagueTeamCc", foreign_key: :league_team_b_cc_id, optional: true
  belongs_to :host_league_team_cc, class_name: "LeagueTeamCc", foreign_key: :league_team_host_cc_id, optional: true
  belongs_to :league_team
  has_many :party_game_ccs
  delegate :club, to: :league_team
  delegate :fedId, :branchId, :subBranchId, :season_id, :leagueId,  to: :league_team_a_cc

end
