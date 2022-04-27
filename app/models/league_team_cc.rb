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

  delegate :fedId,:branchId, :subBranchId, :leagueId, :staffelId, :seasonId, to: :league_cc
  alias_attribute :p, :cc_id

  def self.create_from_ba(league)
    raise NotImplementedError, "league_team creation not yet implemented", caller
  end

end
