# frozen_string_literal: true

# == Schema Information
#
# Table name: party_ccs
#
#  id                     :bigint           not null, primary key
#  data                   :text
#  day_seqno              :integer
#  group                  :string
#  register_at            :date
#  remarks                :text
#  round                  :string
#  status                 :integer
#  time                   :datetime
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  cc_id                  :integer
#  league_cc_id           :integer
#  league_team_a_cc_id    :integer
#  league_team_b_cc_id    :integer
#  league_team_host_cc_id :integer
#  match_id               :integer
#  party_id               :integer
#
class PartyCc < ApplicationRecord
  include LocalProtector
  belongs_to :league_cc
  belongs_to :league_team_a_cc, class_name: "LeagueTeamCc", foreign_key: :league_team_a_cc_id, optional: true
  belongs_to :league_team_b_cc, class_name: "LeagueTeamCc", foreign_key: :league_team_b_cc_id, optional: true
  belongs_to :league_team_host_cc, class_name: "LeagueTeamCc", foreign_key: :league_team_host_cc_id, optional: true
  belongs_to :party
  has_many :party_game_ccs

  delegate :fedId, :branchId, :subBranchId, :seasonId, :leagueId, to: :league_cc

  def name
    "#{league_team_a_cc.name} - #{league_team_b_cc.name}"
  end
  before_save :set_paper_trail_whodunnit

  def sync_game_details(options = {})
    # get game report form
    party_cc = self
    party_cc.league_team_a_cc.cc_id
    party_cc.league_team_b_cc.cc_id
    party_cc.match_id
    region_cc = Region[1].region_cc

    region_cc.post_cc("spielbericht",
                      options[:session_id],
                      sortKey: "NAME",
                      branchid: 6,
                      woher: 1,
                      wettbewerb: 1,
                      sportkreis: "*",
                      saison: "2010/2011",
                      partienr: 6045,
                      seekBut: "",
                      referer: "/admin/bm_mw/vereine.php?")

    res2, doc2 = region_cc.post_cc("spielberichtCheck",
                                   options[:session_id],
                                   fedId: 20,
                                   branchId: 6,
                                   subBranchId: 1,
                                   wettbewerb: 1,
                                   leagueId: 36,
                                   seasonId: 8,
                                   teamId: 211,
                                   matchId: 759,
                                   saison: "2010/2011",
                                   partienr: 6045,
                                   woher: 1,
                                   woher2: 1,
                                   editBut: "",
                                   referer: "/admin/bm_mw/spielbericht.php?")
    [res2, doc2]
  end

  def self.create_from_ba(party)
    RegionCc.logger.info "REPORT ERROR [PartyCc.create_from_ba] unexpected armed status #{party.attributes}"
  end
end
