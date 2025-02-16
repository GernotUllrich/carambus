# frozen_string_literal: true

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
  include LocalProtector
  belongs_to :league_cc
  belongs_to :league_team
  has_many :party_a_ccs, class_name: "PartyCc", foreign_key: :league_team_a_cc_id
  has_many :party_b_ccs, class_name: "PartyCc", foreign_key: :league_team_b_cc_id
  has_many :party_host_ccs, class_name: "PartyCc", foreign_key: :league_team_host_cc_id

  delegate :fedId, :branchId, :subBranchId, :leagueId, :staffelId, :seasonId, :region_cc, :branch_cc, :competition_cc,
           :season_cc, to: :league_cc
  delegate :club, to: :league_team
  alias_attribute :p, :cc_id
  delegate :fedId, :branchId, :subBranchId, :season_id, to: :league_cc

  before_save :set_paper_trail_whodunnit

  COLUMN_NAMES = { "Season" => "season_ccs.name",
                   "BA_ID" => "league_team_ccs.ba_id",
                   "CC_ID" => "league_team_ccs.cc_id",
                   "Region" => "regions.shortname",
                   "Name" => "league_team_ccs.name",
                   "Shortname" => "league_team_ccs.shortname",
                   "League" => "league_ccs.name",
                   "Homepage" => "",
                   "Status" => "",
                   "Founded" => "",
                   "Dbu entry" => "" }.freeze

  def self.search_hash(params)
    {
      model: LeagueTeamCc,
      sort: params[:sort],
      direction: sort_direction(params[:direction]),
      search: [params[:sSearch], params[:search]].compact.join("&").to_s,
      column_names: LeagueTeamCc::COLUMN_NAMES,
      raw_sql: "(season_ccs.name ilike :search)
or (league_ccs.cc_id = :isearch)
or (league_team_ccs.cc_id = :isearch)
or (league_team_ccs.shortname ilike :search)
or (league_team_ccs.name ilike :search)
or (league_teams.shortname ilike :search)
or (league_teams.name ilike :search)
or (league_ccs.name ilike :search)
or (branch_ccs.name ilike :search)",
      joins: [:league_team, { league_cc: { season_cc: { competition_cc: :branch_cc } } }]
    }
  end

  def self.create_from_ba(league_team)
    RegionCc.logger.info "REPORT MISSING LeagueTeam #{league_team.league.season.name} #{league_team.league.discipline.andand.name} #{league_team.name} in Liga #{league_team.league.name}"
    # raise NotImplementedError, "league_team creation not yet implemented", caller
  end
end
