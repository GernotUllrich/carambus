# == Schema Information
#
# Table name: league_team_ccs
#
#  id             :bigint           not null, primary key
#  data           :text
#  name           :string
#  shortname      :string
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  cc_id          :integer
#  league_cc_id   :integer
#  league_team_id :integer
#
class LeagueTeamCc < ApplicationRecord
  belongs_to :league_cc
  belongs_to :league_team
  has_many :party_a_ccs, class_name: "PartyCc", foreign_key: :league_team_a_cc_id
  has_many :party_b_ccs, class_name: "PartyCc", foreign_key: :league_team_b_cc_id
  has_many :party_host_ccs, class_name: "PartyCc", foreign_key: :league_team_host_cc_id

  delegate :fedId,:branchId, :subBranchId, :leagueId, :staffelId, :seasonId, :region_cc, :branch_cc, :competition_cc, :season_cc, to: :league_cc
  delegate :club, to: :league_team
  alias_attribute :p, :cc_id
  delegate :fedId, :branchId, :subBranchId, :season_id,  to: :league_cc

  has_paper_trail
  before_save :set_paper_trail_whodunnit
  def self.create_from_ba(league_team)
    RegionCc.logger.info "REPORT MISSING LeagueTeam #{league_team.league.season.name} #{league_team.league.discipline.andand.name} #{league_team.name} in Liga #{league_team.league.name}"
    #raise NotImplementedError, "league_team creation not yet implemented", caller
  end

end
