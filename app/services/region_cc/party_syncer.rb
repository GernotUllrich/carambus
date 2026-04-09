# frozen_string_literal: true

# Kapselt die Synchronisation von Partien (PartyCc) und Partienspielen
# aus ClubCloud. Verarbeitet Spieltagsdaten und Spielberichte für Ligen.
#
# Verwendung:
#   RegionCc::PartySyncer.call(
#     region_cc: @region_cc,
#     client: @client,
#     operation: :sync_parties,
#     season_name: "2022/2023"
#   )
#
#   RegionCc::PartySyncer.call(
#     region_cc: @region_cc,
#     client: @client,
#     operation: :sync_party_games,
#     parties_todo_ids: [1, 2, 3]
#   )
class RegionCc::PartySyncer < ApplicationService
  def self.call(**kwargs)
    new(**kwargs).call
  end

  def initialize(region_cc:, client:, operation:, parties_todo_ids: nil, **opts)
    @region_cc = region_cc
    @client = client
    @operation = operation
    @parties_todo_ids = parties_todo_ids
    @opts = opts
  end

  def call
    case @operation
    when :sync_parties then sync_parties
    when :sync_party_games then sync_party_games(@parties_todo_ids)
    else raise ArgumentError, "Unknown operation: #{@operation}"
    end
  end

  private

  def sync_parties
    parties = []
    party_ccs = []
    # for all branches
    BranchCc.where(context: @region_cc.context).each do |branch_cc|
      branch_cc.competition_ccs.each do |competition_cc|
        competition_cc.season_ccs.each do |season_cc|
          season_cc.league_ccs.order(:cc_id).each do |league_cc|
            next unless season_cc.name == @opts[:season_name]
            next unless league_cc.id == 177

            _, doc = @client.post(
              "admin_report_showLeague",
              { fedId: league_cc.fedId,
                branchId: league_cc.branchId,
                subBranchId: league_cc.subBranchId,
                seasonId: league_cc.seasonId,
                leagueId: league_cc.cc_id },
              @opts
            )
            league = league_cc.league
            doc.css("table > tr > td > table > tr > td > table").each do |table|
              if table.css("> tr > th").andand[1].andand.text == "Spieltag"
                table.css("tr").each do |line|
                  tds = line.css("> td")
                  next if tds.blank?

                  text_arr = tds.map(&:text)
                  day_seqno = text_arr[1].to_i
                  cc_id = text_arr[2].to_i
                  team_a_str = text_arr[3].split(" ").join(" ")
                  team_a_cc = league_cc.league_team_ccs.where(name: team_a_str).first
                  raise RuntimeError, "Team #{team_a_str} not found", caller unless team_a_cc.present?

                  team_b_str = text_arr[4].split(" ").join(" ")
                  team_b_cc = league_cc.league_team_ccs.where(name: team_b_str).first
                  raise RuntimeError, "Team #{team_b_str} not found", caller unless team_b_cc.present?

                  date_str = text_arr[5]
                  text_arr[6]
                  text_arr[7]
                  host_str = text_arr[8]
                  host_cc = league_cc.league_team_ccs.where(name: host_str).first
                  raise RuntimeError, "Team #{host_str} not found", caller unless team_b_cc.present?

                  time_str = text_arr[9]
                  DateTime.parse("#{date_str} #{time_str}")
                  reg_date_str = text_arr[10]
                  Date.parse(reg_date_str)
                  party = league.parties.where(day_seqno: day_seqno, league_team_a: team_a_cc.league_team,
                                               league_team_b: team_b_cc.league_team).first
                  unless team_b_cc.present?
                    raise RuntimeError,
                          "Party #{{ day_seqno: day_seqno, team_a_cc_name: team_a_cc.name, team_b_cc_name: team_b_cc.name }} not found", caller
                  end

                  party.assign_attributes(cc_id: cc_id)
                  party.save!
                  args = { cc_id: cc_id,
                           league_cc_id: league_cc.id,
                           party_id: party.id,
                           league_team_a_cc: team_a_cc,
                           league_team_b_cc: team_b_cc,
                           league_team_host_cc: host_cc }
                  party_cc = PartyCc.find_by_cc_id_and_league_cc_id(cc_id, league_cc.id)
                  party_cc = PartyCc.new(args) if party_cc.blank?
                  party_cc.assign_attributes(args)
                  party_cc.save!
                  party_ccs.push(party_cc)
                  parties.push(party)
                end
              elsif doc.css("table > tr > td > table > tr.tableContent > td > table > tr > td > input").present?
                if league.organizer_id == @region_cc.region_id && league.organizer_type == "Region"
                  RegionCc.logger.info "REPORT! Keine Spieltag gepflegt für Liga #{league.name}"
                end
              end
            end
          end
        end
      end
    end
    [parties, party_ccs]
  end

  def sync_party_games(parties_todo_ids, opts = {})
    parties_todo_ids.each do |id|
      party = Party[id]
      region = party.league.organizer
      region_cc = region.region_cc
      party_cc = party.party_cc
      party_cc.attributes
      _res, doc = @client.post(
        "spielberichtCheck",
        { errMsgNew: "",
          fedId: 20,
          branchId: 6,
          subBranchId: 1,
          wettbewerb: 1,
          leagueId: 34,
          seasonId: 8,
          teamId: 185,
          matchId: 571,
          saison: 2010 / 2011,
          partienr: 4003,
          woher: 1,
          woher2: 1,
          editBut: "" },
        @opts
        # get Spielbericht
        # _res, doc = region_cc.post_cc(
        #   "spielbericht",
        #   { errMsgNew: "",
        #   matchId: party_cc.party_game_ccs.first.cc_id,
        #   teamId: 189
        #   woher: 1
        #   firstEntry: 1
        #   #
        #   # sortKey: "NAME",
        #   # branchid: party_cc.branchId,
        #   # woher: 1,
        #   # wettbewerb: party_cc.subBranchId,
        #   # sportkreis: "*",
        #   # saison: season_name,
        #   # partienr: party_cc.cc_id,
        #   # seekBut: ""}, opts
      )
      err_msg = doc.present && doc.css('input[name="errMsg"]')[0].andand["value"]
      raise ArgumentError, err_msg if err_msg.present? || doc.blank?
    end
  end
end
