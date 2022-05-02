# frozen_string_literal: true

# == Schema Information
#
# Table name: league_ccs
#
#  id               :bigint           not null, primary key
#  cc_id2           :integer
#  context          :string
#  name             :string
#  report_form      :string
#  report_form_data :string
#  shortname        :string
#  status           :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  cc_id            :integer
#  league_id        :integer
#  season_cc_id     :integer
#
class LeagueCc < ApplicationRecord
  belongs_to :season_cc
  belongs_to :league
  has_many :league_team_ccs
  has_many :party_ccs
  delegate :fedId, :branchId, :subBranchId, :seasonId, :region_cc, :branch_cc, :competition_cc, to: :season_cc
  alias_attribute :leagueId, :cc_id
  alias_attribute :staffelId, :cc_id2

  def self.create_from_ba(session_id, league)
    region = league.organizer
    region_cc = region.region_cc
    competition = league.competition
    competition_cc = competition.competition_cc
    context = league.organizer.shortname.downcase
    season_cc = competition.competition_cc.season_ccs.where(name: league.season.name).first
    league_cc = LeagueCc.new(name: league.name, season_cc_id: season_cc.id, league_id: league.id, context: context)
    league_cc.attributes
    _, doc = region_cc.post_cc(
      'createLeagueSave',
      session_id,
      fedId: competition_cc.fedId,
      branchId: competition_cc.branchId,
      subBranchId: competition_cc.cc_id,
      seasonId: season_cc.cc_id,
      posId: 1,
      leagueName: league.name,
      leagueShortName: league.name.split(' ').map { |w| w[0] }.join('').upcase,
      prefix: 0,
      sportdistrictId: 0
    )
    doc.to_s
  end

  def link_name
    fedId = season_cc.competition_cc.branch_cc.region_cc.cc_id
    branchId = season_cc.competition_cc.branch_cc.cc_id
    subBranchId = season_cc.competition_cc.cc_id
    seasonId = season_cc.cc_id
    "#{fedId}_#{branchId}_#{subBranchId}_#{seasonId}_#{cc_id}"
  end

  def link_path
    fedId = season_cc.competition_cc.branch_cc.region_cc.cc_id
    branchId = season_cc.competition_cc.branch_cc.cc_id
    subBranchId = season_cc.competition_cc.cc_id
    seasonId = season_cc.cc_id
    "#{RegionCc::BASE_URL}#{RegionCc::PATH_MAP["showLeague"]}?fedId=#{fedId}&branchId=#{branchId}&subBranchId=#{subBranchId}&seasonId=#{seasonId}&leagueId=#{cc_id}"
  end
end
