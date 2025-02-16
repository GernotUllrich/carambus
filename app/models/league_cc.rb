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
#  game_plan_cc_id  :integer
#  league_id        :integer
#  season_cc_id     :integer
#
class LeagueCc < ApplicationRecord
  include LocalProtector
  belongs_to :season_cc
  belongs_to :league
  belongs_to :game_plan_cc, optional: true
  has_many :league_team_ccs
  has_many :party_ccs, -> { order(cc_id: :asc) }, dependent: :destroy
  delegate :fedId, :branchId, :subBranchId, :seasonId, :region_cc, :branch_cc, :competition_cc, to: :season_cc
  alias_attribute :leagueId, :cc_id
  alias_attribute :staffelId, :cc_id2

  before_save :set_paper_trail_whodunnit

  def self.create_from_ba(league, opts = {})
    RegionCc.logger.info "REPORT [LeagueCc.create_from_ba] MUST CREATE MISSING League #{league.season.name} #{league.discipline.andand.name} #{league.name}"
    return
    region = league.organizer
    region_cc = region.region_cc

    league.discipline || (if /Dreiband/.match?(league.name)
                            Competition.where(name: "Mannschaft Karambol großes Billard").first
                          end) ||
      (Competition.where(name: "Mannschaft Karambol kleines Billard").first if /Vierkampf/.match?(league.name))
    league_cc = league.league_cc
    if league_cc.present?
      competition_cc = league_cc.season_cc.competition_cc
      opts[:context]
      season_cc = league_cc.season_cc
      args = { fedId: competition_cc.fedId,
               branchId: competition_cc.branchId,
               subBranchId: competition_cc.cc_id,
               seasonId: season_cc.cc_id,
               posId: 1,
               leagueName: league.name,
               leagueShortName: league.name.split(" ").map { |w| w[0] }.join("").upcase,
               prefix: 0,
               sportdistrictId: 0 }
      if false
        _, doc = region_cc.post_cc(
          "createLeagueSave",
          args,
          opts
        )
        doc.to_s
      else
        RegionCc.logger.info "REPORT [create_from_ba| WOULD CREATE League #{league.name} #{league.season.name} #{league.discipline.andand.name} with 'createLeagueSave' and payload #{args}"
      end
    else
      RegionCc.logger.info "REPORT Liga #{league.name} #{league.season.name} #{league.discipline.andand.name} nicht in Club Cloud!"
    end
  end

  def self.create_league_plan_from_ba(league, _opts = {})
    RegionCc.logger.info "REPORT [LeaguePlanCc.create_from_ba] WOULD CREATE for #{league.attributes}"
  end

  def create_game_plan
    # SPIELTAG; PARTIE; RUNDE; MANNSCHAFT1 (Schlüssel); MANNSCHAFT2 (Schlüssel); TERMIN (TT.MM.JJJJ); GASTGEBER (Schlüssel); BEGINN (hh:mm); ANZEIGE-DATUM (TT.MM.JJJJ)
    league = self.league
    parties = league.parties
    csv = []
    s_no = 5000
    parties.order(:day_seqno, :date).each do |p|
      s_no += 1
      csv.push([
        p.day_seqno,
        s_no,
        p.round,
        p.league_team_a.league_team_cc.cc_id,
        p.league_team_b.league_team_cc.cc_id,
        p.date.strftime("%d.%m.%Y"),
        p.host_league_team.league_team_cc.cc_id,
        p.date.strftime("%H:%M"),
        p.date.strftime("%d.%m.%Y")
      ].join(";"))
    end
    csv.join("\n")
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

  def sync_single_league(opts = {})
    region_cc = Region.find_by_shortname(opts[:context].upcase).region_cc
    if league.present?
      _, doc2 = region_cc.post_cc(
        "showLeague",
        { fedId: cc_id,
          branchId: branch_cc.cc_id,
          subBranchId: competition_cc.cc_id,
          seasonId: season_cc.cc_id,
          leagueId: cc_id },
        opts
      )
      lines = doc2.css("form tr.tableContent table tr")
      res_arr = lines.map { |l| l.css("td").map(&:text) }
      game_plan_cc = GamePlanCc.find_by_name_and_branch_cc_id(res_arr[7][2].strip, branch_cc.id)
      unless res_arr[4][0] == "Kürzel" && res_arr[5][0] == "Status"
        raise SystemCallError, "Format of showLeague canged ???", caller
      end

      if game_plan_cc.present?
        assign_attributes(shortname: res_arr[4][2].strip, status: res_arr[5][4].strip,
                          report_form: res_arr[7][2].strip, game_plan_cc_id: game_plan_cc.id)
      end
      save
      league.assign_attributes(shortname: res_arr[4][2].strip)
      league.save

    else
      RegionCc.logger.warn "REPORT! [sync_leagues] Name der Liga entspricht keiner BA Liga: CC: #{{
        season_name: season.name, name: name_str, organizer_type: "Region", organizer_id: [id,
                                                                                           dbu_region_id], discipline: competition_cc.discipline
      }.inspect}"
    end
  rescue StandardError => e
    e.backtrace
  end
end
