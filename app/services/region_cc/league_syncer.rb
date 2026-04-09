# frozen_string_literal: true

# Extrahiert League-Sync-Methoden aus RegionCc in einen eigenstaendigen Service.
# Koordiniert die Synchronisierung von Ligen, Liga-Mannschaften, Spielplaenen und Spielern
# aus der ClubCloud-API.
#
# Dispatcher-Muster per D-04: Alle Operationen laufen ueber einen einzigen .call-Einstiegspunkt.
#
# Verwendung:
#   RegionCc::LeagueSyncer.call(region_cc: rc, client: cc, operation: :sync_leagues, **opts)
#   RegionCc::LeagueSyncer.call(region_cc: rc, client: cc, operation: :sync_league_teams, **opts)
#   RegionCc::LeagueSyncer.call(region_cc: rc, client: cc, operation: :sync_league_teams_new, **opts)
#   RegionCc::LeagueSyncer.call(region_cc: rc, client: cc, operation: :sync_league_plan, **opts)
#   RegionCc::LeagueSyncer.call(region_cc: rc, client: cc, operation: :sync_team_players, league_team: lt, **opts)
#   RegionCc::LeagueSyncer.call(region_cc: rc, client: cc, operation: :sync_team_players_structure, **opts)
class RegionCc::LeagueSyncer < ApplicationService
  def initialize(region_cc:, client:, operation:, league_cc: nil, league: nil, league_team: nil, **opts)
    @region_cc = region_cc
    @client = client
    @operation = operation
    @league_cc = league_cc
    @league = league
    @league_team = league_team
    @opts = opts
  end

  # Dispatcher: leitet an die jeweilige private Sync-Methode weiter.
  def call
    case @operation
    when :sync_leagues then sync_leagues
    when :sync_league_teams then sync_league_teams(@opts)
    when :sync_league_teams_new then sync_league_teams_new(@opts)
    when :sync_league_plan then sync_league_plan(@opts)
    when :sync_team_players then sync_team_players(@league_team, @opts)
    when :sync_team_players_structure then sync_team_players_structure(@opts)
    else raise ArgumentError, "Unknown operation: #{@operation}"
    end
  end

  private

  # ---------------------------------------------------------------------------
  # sync_leagues (extrahiert aus RegionCc#sync_leagues, Zeilen 1883-1988)
  # ---------------------------------------------------------------------------
  def sync_leagues
    opts = @opts
    context = opts[:context]
    season_name = opts[:season_name]
    season = Season.find_by_name(season_name)
    region = Region.find_by_shortname(context.upcase)
    raise ArgumentError, "unknown season name #{season_name}", caller if season.blank?

    dbu_region_id = Region.find_by_shortname("DBU").id

    league_map = [] # league_cc.cc_id => league
    leagues = []
    BranchCc.where(context: context).each do |branch_cc|
      branch_cc.competition_ccs.each do |competition_cc|
        competition_cc.season_ccs.where.not(name: opts[:exclude_season_names]).each do |season_cc|
          next unless season_cc.name == season_name
          next if branch_cc.name == "Pool" || branch_cc.name == "Snooker"

          _res, doc = @client.post(
            "showLeagueList",
            { fedId: @region_cc.cc_id,
              branchId: branch_cc.cc_id,
              subBranchId: competition_cc.cc_id,
              seasonId: season_cc.cc_id },
            opts
          )
          if (msg = doc.css('input[name="errMsg"]')[0].andand["value"]).present?
            RegionCc.logger.error msg
            return [[], msg]
          end
          selector = doc.css('select[name="leagueId"]')[0]
          next unless selector.present?

          option_tags = selector.css("option")
          option_tags.each do |option|
            cc_id = option["value"].to_i
            name_str = option.text.strip
            league_cc = nil
            league_ccs = LeagueCc.where(cc_id: cc_id)
            if league_ccs.count == 1
              league_cc = league_ccs.first
            elsif league_ccs.count > 1
              msg = "REPORT! ERROR cc_id #{cc_id} not uniq"
              RegionCc.logger.info msg
              raise ArgumentError, msg
            end
            league = League.find_by_cc_id(cc_id)
            unless league.present?
              name_str_match = name_str.gsub(" - ", " ").gsub(/(\d+). /, '\1.').match(%r{(.*)( (?:A|B|Staffel A|Staffel B|Nord|Süd|Nord/Ost))$})
              if name_str_match
                l_name = name_str_match[1].strip
                s_name = name_str_match[2].strip.tr("/", "-")
                s_name = "Staffel #{s_name}" if /A|B/.match?(s_name)
              else
                l_name = name_str
                s_name = nil
              end
              if context == "nbv"
                l_name = l_name == "Regionalliga Pool" ? "Regionalliga" : l_name
              end
              league = nil
              League.where(season: season, name: [l_name, l_name.gsub("2er Teams", "2er-Teams").to_s, l_name.gsub("3er Team", "3'er Team").to_s, l_name.gsub("2er", "2'er").to_s, "#{l_name} #{branch_cc.discipline.name}", "#{l_name} Ligen #{branch_cc.discipline.name}"], staffel_text: s_name, organizer_type: "Region",
                           organizer_id: [region.id, dbu_region_id]).each do |l|
                if l.branch == branch_cc.discipline
                  league = l
                  break
                end
              end
            end
            if league.present?
              next if opts[:exclude_league_ba_ids].include?(league.ba_id)

              if league_cc.blank?
                league_cc = LeagueCc.create(cc_id: cc_id, name: "#{league.name}#{if league.staffel_text.present?
                                                                                   " #{league.staffel_text}"
                                                                                 end}", season_cc_id: season_cc.id, league_id: league.id, context: league.organizer.shortname.downcase, shortname: "#{league.name.gsub("Kreis", "Kreis ").gsub("lig", " lig")}#{" #{league.staffel_text}"}".split(" ").map do |w|
                                                                                                                                                                                                     w[0].upcase
                                                                                                                                                                                                   end.join(""))
              end
              if league_cc.present?
                league_cc.sync_single_league(opts)
                league.reload.assign_attributes(cc_id: cc_id)
                league.save
                league_map[league_cc.cc_id] = league
                leagues.push(league)
              else
                msg = "REPORT! ERROR no LeagueCc #{name_str} #{season_cc.name} branch: #{branch_cc.name}(#{branch_cc.cc_id}) competition: #{competition_cc.name}(#{competition_cc.cc_id})"
                RegionCc.logger.info msg
                Rails.logger.info msg
              end
            else
              msg = "REPORT! ERROR no League for LeagueCc #{name_str} #{season_cc.name} branch: #{branch_cc.name}(#{branch_cc.cc_id}) competition: #{competition_cc.name}(#{competition_cc.cc_id})"
              RegionCc.logger.info msg
              Rails.logger.info msg
            end
          end
        end
      end
    end

    [leagues, nil]
  rescue StandardError => e
    [[], e.to_s]
  end

  # ---------------------------------------------------------------------------
  # sync_league_teams (extrahiert aus RegionCc#sync_league_teams, Zeilen 2226-2360)
  # ---------------------------------------------------------------------------
  def sync_league_teams(opts = {})
    context = opts[:context]
    season_name = opts[:season_name]
    region = Region.find_by_shortname(context.upcase)
    season = Season.find_by_name(season_name)
    raise ArgumentError, "unknown season name #{season_name}", caller if season.blank?

    Region.find_by_shortname("DBU").id

    league_teams = []
    league_team_ccs = []
    BranchCc.where(context: context).each do |branch_cc|
      next unless branch_cc.name == "Karambol"

      branch_cc.competition_ccs.each do |competition_cc|
        competition_cc.season_ccs.each do |season_cc|
          season_cc.league_ccs.order(:cc_id).each do |league_cc|
            next if opts[:exclude_league_ba_ids].include?(league_cc.league.ba_id)
            next unless season_cc.name == season_name

            _, doc = @client.post(
              "admin_report_showLeague",
              { fedId: league_cc.fedId,
                branchId: league_cc.branchId,
                subBranchId: league_cc.subBranchId,
                seasonId: league_cc.seasonId,
                leagueId: league_cc.cc_id },
              opts
            )
            league_cc.league.league_teams.joins(club: :region).where(regions: { id: region.id })
            league_teams_doc_cc = doc.css('table[name="teams"] tr.odd')
            next unless league_teams_doc_cc.present?

            league_teams_doc_cc.each do |league_team_doc_cc|
              tds = league_team_doc_cc.css("td")
              if tds.count == 2
                cc_id = tds[1].text.to_i
                name_str = tds[0].text.strip
              else
                link = tds[1].css("a")[0]["href"]
                cc_id = link.match(/.*p=(\d+)/).andand[1]
                name_str = tds[1].text.strip
              end
              name_str = name_str.split(" ").join(" ")
              name_str_cc = name_str
              bgh_map = {
                "BG Hamburg 2" => "BG Hamburg",
                "BG Hamburg 3" => "BG Hamburg 2",
                "BG Hamburg 4" => "BG Hamburg 3"
              }
              name_str = bgh_map[name_str] if league_cc.name =~ /2er Team/ && name_str =~ /BG Hamburg [234]/
              mm3btb_map = {
                "2014/2015" => {
                  "BV Kiel 1" => "BV Kiel",
                  "BG Hamburg 2" => "BG Hamburg",
                  "BC Wedel 2" => "BC Wedel",
                  "BC Wedel 3" => "BC Wedel 2"
                },
                "2015/2016" => {
                  "BV Kiel 2" => "BV Kiel",
                  "BC Wedel 3" => "BC Wedel"
                },
                "2016/2017" => {
                  "BG Hamburg 2" => "BG Hamburg",
                  "BC Wedel 3" => "BC Wedel",
                  "BC Wedel 4" => "BC Wedel 2"
                },
                "2017/2018" => {
                  "BG Hamburg 2" => "BG Hamburg",
                  "BC Wedel 3" => "BC Wedel"
                },
                "2018/2019" => {
                  "BG Hamburg 2" => "BG Hamburg",
                  "BG Hamburg 3" => "BG Hamburg 2",
                  "BC Wedel 3" => "BC Wedel"
                }
              }
              if league_cc.name =~ /NDMM Dreiband TB/ && mm3btb_map[season_cc.name].andand[name_str].present?
                name_str = mm3btb_map[season_cc.name][name_str]
              end

              team_club_str = name_str

              if /.*[ [[:space:]]]+\d+$/.match?(name_str)
                team_club_str = (m = name_str.match(/(.*[^ [[:space:]]])[ [[:space:]]]*(\d+)$/))[1]
                m[2]
                team_club_str = team_club_str.tr("`", "'")
              end
              club = Club.where(region: region, shortname: team_club_str).first
              if club.present?
                league_team = LeagueTeam.joins(:league).joins(:league_team_cc).where(league_team_ccs: { cc_id: cc_id }).where(leagues: { id: league_cc.league_id }).first
                league_team ||= LeagueTeam
                                .joins(:league)
                                .joins(club: :region)
                                .where(regions: { id: region.id })
                                .where(name: name_str,
                                       league_id: league_cc.league.id,
                                       club_id: club.id).first
                league_team ||= LeagueTeam
                                .joins(:league)
                                .joins(club: :region)
                                .where(regions: { id: region.id })
                                .where(name: team_club_str,
                                       league_id: league_cc.league.id,
                                       club_id: club.id).first
              else
                RegionCc.logger.warn "REPORT! [sync_league_teams] Name des Clubs entspricht keiner BA Liga: CC: #{{
                  name: team_club_str, cc_id: cc_id, region: region.shortname
                }.inspect}"
              end
              if league_team.present?
                args = { cc_id: cc_id, name: name_str_cc, league_cc_id: league_cc.id, league_team_id: league_team.id }
                league_team_cc = LeagueTeamCc.find_by_cc_id_and_league_cc_id(cc_id,
                                                                             league_cc.id) || LeagueTeamCc.new(args)
                league_team_cc.assign_attributes(args)
                league_team_cc.save!
                league_teams.push(league_team) unless league_teams.include?(league_team)
                league_team_ccs.push(league_team_cc) unless league_team_ccs.include?(league_team_cc)
              else
                RegionCc.logger.warn "REPORT! [sync_league_teams] Name der Liga Mannschaft #{team_club_str} in Liga #{league_cc.attributes} entspricht keinem BA LigaTeam: CC: #{{
                  name: name_str, cc_id: cc_id, league_id: league_cc.league.id, club_id: club.andand.id
                }.inspect}"
              end
            end
          end
        end
      end
    end

    [league_teams, league_team_ccs]
  rescue StandardError => e
    RegionCc.logger.error "ERROR #{e} \n#{e.backtrace.join("\n")}"
  end

  # ---------------------------------------------------------------------------
  # sync_league_teams_new (extrahiert aus RegionCc#sync_league_teams_new, Zeilen 2047-2224)
  # ---------------------------------------------------------------------------
  def sync_league_teams_new(opts = {})
    context = opts[:context]
    season_name = opts[:season_name]
    region = Region.find_by_shortname(context.upcase)
    season = Season.find_by_name(season_name)
    raise ArgumentError, "unknown season name #{season_name}", caller if season.blank?

    Region.find_by_shortname("portal").id

    league_teams = []
    league_team_ccs = []
    BranchCc.where(context: context).each do |branch_cc|
      next unless branch_cc.name == "Karambol"

      branch_cc.competition_ccs.each do |competition_cc|
        competition_cc.season_ccs.each do |season_cc|
          season_cc.league_ccs.order(:cc_id).each do |league_cc|
            next if opts[:exclude_league_ba_ids].include?(league_cc.league.ba_id)
            next unless season_cc.name == season_name

            _, doc_club = @client.post(
              "showClubList",
              { fedId: league_cc.fedId,
                branchId: league_cc.branchId,
                subBranchId: league_cc.subBranchId,
                sportDistrictId: "*",
                statusId: 1 },
              opts
            )
            selector = doc_club.css('select[name="clubId"]')[0]
            options_tags = selector.css("option")
            options_tags.each do |option|
              clubstr = option.text.match(/(.*) \(\d+\)/).andand[1].strip
              club_cc_id = option["value"].to_i
              club = Club.find_by_cc_id(club_cc_id)
              unless club.present?
                club = Club.find_by_shortname(clubstr)
                club.update(cc_id: club_cc_id) if club.present?
              end
              if club.present?

                _, doc_teams = @client.post(
                  "showAnnounceList",
                  {
                    fedId: league_cc.fedId,
                    branchId: league_cc.branchId,
                    subBranchId: league_cc.subBranchId,
                    sportDistrictId: "*",
                    clubId: club_cc_id,
                    originalBranchId: league_cc.branchId,
                    seasonId: season_cc.cc_id
                  },
                  opts
                )
                selector_team = doc_teams.css('select[name="teamId"]')[0]
                if selector_team.present?
                  options_tags_team = selector_team.css("option")
                  options_tags_team.each do |option_team|
                    team_cc_id = option_team["value"].to_i
                    name_str = option_team.text.match(/(\d+) \((.*)\)/)
                    if name_str.present?
                      league_name = name_str[2].strip
                      next unless league_name == league_cc.name

                      team_seqno = name_str[1].to_i
                      name_str = "#{club.shortname} #{team_seqno}"
                      name_str = name_str.split(" ").join(" ")
                      name_str_cc = name_str
                      bgh_map = {
                        "BG Hamburg 2" => "BG Hamburg",
                        "BG Hamburg 3" => "BG Hamburg 2",
                        "BG Hamburg 4" => "BG Hamburg 3"
                      }
                      name_str = bgh_map[name_str] if league_cc.name =~ /2er Team/ && name_str =~ /BG Hamburg [234]/
                      mm3btb_map = {
                        "2014/2015" => {
                          "BV Kiel 1" => "BV Kiel",
                          "BG Hamburg 2" => "BG Hamburg",
                          "BC Wedel 2" => "BC Wedel",
                          "BC Wedel 3" => "BC Wedel 2"
                        },
                        "2015/2016" => {
                          "BV Kiel 2" => "BV Kiel",
                          "BC Wedel 3" => "BC Wedel"
                        },
                        "2016/2017" => {
                          "BG Hamburg 2" => "BG Hamburg",
                          "BC Wedel 3" => "BC Wedel",
                          "BC Wedel 4" => "BC Wedel 2"
                        },
                        "2017/2018" => {
                          "BG Hamburg 2" => "BG Hamburg",
                          "BC Wedel 3" => "BC Wedel"
                        },
                        "2018/2019" => {
                          "BG Hamburg 2" => "BG Hamburg",
                          "BG Hamburg 3" => "BG Hamburg 2",
                          "BC Wedel 3" => "BC Wedel"
                        }
                      }
                      if league_cc.name =~ /NDMM Dreiband TB/ && mm3btb_map[season_cc.name].andand[name_str].present?
                        name_str = mm3btb_map[season_cc.name][name_str]
                      end
                      mm3bmb_map = {
                        "2015/2016" => {
                          "BG Hamburg 2" => "BG Hamburg",
                          "BG Hamburg 3" => "BG Hamburg 2",
                          "BC Wedel 3" => "BC Wedel",
                          "BC Wedel 4" => "BC Wedel 2"
                        },
                        "2016/2017" => {
                          "BC Bergedorf 1" => "BC Bergedorf",
                          "BC Wedel 3" => "BC Wedel"
                        },

                        "2018/2019" => {
                          "BC Wedel 3" => "BC Wedel",
                          "BG Hamburg 4" => "BG Hamburg"
                        }
                      }
                      if league_cc.name =~ /NDMM Dreiband MB/ && mm3bmb_map[season_cc.name].andand[name_str].present?
                        name_str = mm3bmb_map[season_cc.name][name_str]
                      end
                      if club.present?
                        league_team = LeagueTeam.joins(:league).joins(:league_team_cc).where(league_team_ccs: { cc_id: team_cc_id }).where(leagues: { id: league_cc.league_id }).first
                        league_team ||= LeagueTeam
                                        .joins(:league)
                                        .joins(club: :region)
                                        .where(regions: { id: region.id })
                                        .where(name: name_str,
                                               league_id: league_cc.league.id,
                                               club_id: club.id).first
                        league_team ||= LeagueTeam
                                        .joins(:league)
                                        .joins(club: :region)
                                        .where(regions: { id: region.id })
                                        .where(name: club.shortname,
                                               league_id: league_cc.league.id,
                                               club_id: club.id).first
                      else
                        RegionCc.logger.warn "REPORT! [sync_league_teams] Name des Clubs entspricht keiner BA Liga: CC: #{{
                          name: team_club_str, cc_id: club_cc_id, region: region.shortname
                        }.inspect}"
                      end
                      if league_team.present?
                        args = { cc_id: team_cc_id, name: name_str_cc, league_cc_id: league_cc.id,
                                 league_team_id: league_team.id }
                        league_team_cc = LeagueTeamCc.find_by_cc_id_and_league_cc_id(team_cc_id,
                                                                                     league_cc.id) || LeagueTeamCc.new(args)
                        league_team_cc.assign_attributes(args)
                        league_team_cc.save!
                        league_teams.push(league_team) unless league_teams.include?(league_team)
                        league_team_ccs.push(league_team_cc) unless league_team_ccs.include?(league_team_cc)
                      else
                        RegionCc.logger.warn "REPORT! [sync_league_teams] Name der Liga Mannschaft #{club.andand.shortname} in Liga #{league_cc.attributes} entspricht keinem BA LigaTeam: CC: #{{
                          name: name_str, cc_id: team_cc_id, league_id: league_cc.league.id, club_id: club.andand.id
                        }.inspect}"
                      end
                    else
                      RegionCc.logger.info "REPORT CANNOT PARSE TEAM INFO #{name_str} with cc_id: #{team_cc_id}"
                    end
                  end
                end
              else
                RegionCc.logger.info "REPORT UNKNOWN CLUB #{clubstr} with cc_id: #{club_cc_id}"
              end
            end
          end
        end
      end
    end

    [league_teams, league_team_ccs]
  rescue StandardError => e
    RegionCc.logger.error "ERROR #{e} \n#{e.backtrace.join("\n")}"
  end

  # ---------------------------------------------------------------------------
  # sync_league_plan (extrahiert aus RegionCc#sync_league_plan, Zeilen 2362-2496)
  # ---------------------------------------------------------------------------
  def sync_league_plan(opts = {})
    season = Season.find_by_name(opts[:season_name])
    region = Region.find_by_shortname(opts[:context].upcase)
    leagues = League.joins(league_teams: :club).where(season: season, organizer_type: "Region", organizer_id: region.id).where(
      "clubs.region_id = ?", region.id
    ).where.not(leagues: { ba_id: opts[:exclude_league_ba_ids] }).uniq
    leagues_done = []
    errMsg = nil
    leagues.each do |league|
      next if opts[:exclude_league_ba_ids].include?(league.ba_id)

      league_cc = league.league_cc
      parties = league.parties
      if league_cc.present?
        party_ccs = league_cc.party_ccs
        _, doc3 = @client.post(
          "massChangingCheck",
          { fedId: league_cc.fedId,
            leagueId: league_cc.leagueId,
            branchId: league_cc.branchId,
            subBranchId: league_cc.subBranchId,
            seasonId: league_cc.seasonId,
            staffelId: "" },
          opts
        )
        if (msg = doc3.css('input[name="errMsg"]')[0].andand["value"]).present?
          RegionCc.logger.error msg
          return [leagues_done, msg]
        end
        party_match_id = nil
        party_done_ids = []
        tables = doc3.css("form > table > tr > td > table > tr > td > table > tr > td > table")
        tables.each do |table|
          next unless table.css("> tr > th")[0].andand.text == "Spieltag"

          table.css("> tr").each_with_index do |tr, _ix|
            tds = tr.css("> td")
            next if tds.blank?

            party_match_id = tds[0].css("> input")[0]["name"].match(/spieltagNr(\d+)$/)[1].to_i
            selectors = tds.css("> select")
            party_day_seqno = tds.css("> input")[0]["value"].to_i
            party_group = tds.css("> input")[1]["value"]
            party_cc_id = tds.css("> input")[2]["value"].to_i
            party_round = tds.css("> input")[3]["value"]
            party_team_a_cc_id = selectors[0].css("option[selected=selected]")[0]["value"].to_i
            party_team_b_cc_id = selectors[1].css("option[selected=selected]")[0]["value"].to_i
            party_active_cell = tds.css("> input")[5]
            party_active = nil
            party_active ||= party_active_cell["value"].presence.to_i
            party_res_a = tds.css("> input")[6]["value"]
            party_res_b = tds.css("> input")[7]["value"]
            party_team_host_cc_id = selectors[2].css("option[selected=selected]")[0]["value"].to_i
            party_time = DateTime.parse("#{tds.css("> input")[4]["value"]} #{if /:/.match?(tds.css("> input")[8]["value"])
                                                                               tds.css("> input")[8]["value"]
                                                                             end}")
            party_register = Date.parse(tds.css("> input")[9]["value"])

            party = parties.joins('INNER JOIN "league_teams" as "league_team_a" on "league_team_a"."id" = "parties"."league_team_a_id"')
                           .joins('INNER JOIN "league_teams" as "league_team_b" on "league_team_b"."id" = "parties"."league_team_b_id"')
                           .joins('INNER JOIN "league_team_ccs" as "league_team_cc_a" on "league_team_cc_a"."league_team_id" = "league_team_a"."id"')
                           .joins('INNER JOIN "league_team_ccs" as "league_team_cc_b" on "league_team_cc_b"."league_team_id" = "league_team_b"."id"')
                           .where("league_team_cc_a.cc_id = ?", party_team_a_cc_id)
                           .where("league_team_cc_b.cc_id = ?", party_team_b_cc_id)
                           .where.not(parties: { id: party_done_ids }).first
            args = { cc_id: party_cc_id,
                     group: party_group,
                     round: party_round,
                     time: party_time,
                     match_id: party_match_id,
                     register_at: party_register,
                     status: party_active,
                     league_cc_id: league_cc.id,
                     party_id: party.andand.id,
                     league_team_a_cc_id: league_cc.league_team_ccs.where(league_team_ccs: { cc_id: party_team_a_cc_id }).first.andand.id,
                     league_team_b_cc_id: league_cc.league_team_ccs.where(league_team_ccs: { cc_id: party_team_b_cc_id }).first.andand.id,
                     league_team_host_cc_id: league_cc.league_team_ccs.joins(:party_host_ccs).where(league_team_ccs: { cc_id: party_team_host_cc_id }).first.andand.id,
                     day_seqno: party_day_seqno,
                     data: { result: "#{party_res_a}:#{party_res_b}" } }
            if party.present?
              party_cc = party_ccs.where(cc_id: party_cc_id).first || PartyCc.new(args)
              party_cc.assign_attributes(args)
              party_cc.save
              party_done_ids.push(party.id)
              leagues_done.push(league) unless leagues_done.include?(league)
            else
              msg = "REPORT ERROR party with cc_id: #{args[:cc_id]}, host: #{LeagueTeamCc[args[:league_team_host_cc_id]].andand.name}, day_seqno: #{args[:day_seqno]} - arguments #{args.inspect} not in database"
              RegionCc.logger.info msg
              Rails.logger.info msg
            end
          end
        end
      else
        RegionCc.logger.info "REPORT [sync_league_plan] Liga nicht in CC: #{league.attributes}"
      end
    end
    [leagues_done, errMsg]
  end

  # ---------------------------------------------------------------------------
  # sync_team_players (extrahiert aus RegionCc#sync_team_players, Zeilen 2676-2712)
  # ---------------------------------------------------------------------------
  def sync_team_players(league_team, opts = {})
    league_team_player_done = []
    league_team_cc = league_team.league_team_cc
    if league_team.league_team_cc.present?
      _, doc = @client.get(
        "showLeague_show_teamplayer",
        { p: league_team_cc.p,
          referer: "/admin/report/showLeague_show_teamplayer.php?p=#{league_team_cc.p}&" },
        opts
      )
      doc.css("tr.tableContent > td > table > tr > td > table").each do |table|
        ths = table.css("> tr > th")
        next unless ths.present? && ths[3].andand.text == "Pass-Nr."

        table.css("> tr").each do |tr|
          tds = tr.css("> td")
          next if tds.blank?

          cc_id = tds[3].text.to_i
          ba_id = tds[4].text.to_i
          player = Player.where(type: nil).find_by_ba_id(ba_id)
          player = if player.present?
                   end
          Player.where(type: nil).find_by_cc_id(cc_id)
          if player.blank?
            RegionCc.logger.info "REPORT ERROR Kein Spieler #{tds[1].text}, #{tds[2].text} mit PASS-NR #{cc_id} oder DBU-NR #{ba_id} in DB"
          elsif player.ba_id != ba_id
            RegionCc.logger.info "REPORT ERROR Spieler #{tds[1].text}, #{tds[2].text} hat andere DBU-NR #{player.ba_id} in DB als in CC #{ba_id}"
          end
          league_team_player_done.push(player) if player.present?
        end
      end
    end

    league_team_player_done
  end

  # ---------------------------------------------------------------------------
  # sync_team_players_structure (extrahiert aus RegionCc#sync_team_players_structure, Zeilen 795-870)
  # ---------------------------------------------------------------------------
  def sync_team_players_structure(opts = {})
    season = Season.find_by_name(opts[:season_name])
    raise ArgumentError, "unknown season name #{opts[:season_name]}", caller if season.blank?

    region_cc = Region.where(shortname: opts[:context].upcase).first.region_cc
    League.where(season: season, organizer_type: "Region", organizer_id: @region_cc.region.id).each do |league|
      next if opts[:exclude_league_ba_ids].include?(league.ba_id)
      next if league.discipline_id.blank?

      league_team_players = {}
      league.parties.each do |party|
        league_team_players[party.league_team_a_id] ||= []
        league_team_players[party.league_team_b_id] ||= []
        party.party_games.each do |party_game|
          unless league_team_players[party.league_team_a_id].include?(party_game.player_a_id)
            league_team_players[party.league_team_a_id].push(party_game.player_a_id)
          end
          unless league_team_players[party.league_team_b_id].include?(party_game.player_b_id)
            league_team_players[party.league_team_b_id].push(party_game.player_b_id)
          end
        end
      end
      league_team_player_object_hash = {}
      league_team_players.each_key do |lt_id|
        league_team = LeagueTeam[lt_id]
        next unless league_team.present?

        league_team_player_object_hash[league_team.id] ||= []
        league_team_players[lt_id].each do |p_id|
          player = Player[p_id]
          league_team_player_object_hash[league_team.id].push(player)
        end
      end
      league_team_player_object_hash.each_key do |lt_id|
        league_team = LeagueTeam[lt_id]
        next unless league_team.present?

        league_team_cc = league_team.league_team_cc
        if league_team_cc.present?

          league_team_players_todo = league_team_player_object_hash[lt_id]
          league_team_player_done = region_cc.sync_team_players(league_team, opts)
          league_team_player_still_todo = league_team_players_todo - league_team_player_done
          league_team_player_still_todo.each do |player|
            next if player.andand.ba_id.blank? || player.ba_id.to_i > 999_000_000

            args = { fedId: league_team_cc.fedId,
                     leagueId: league_team_cc.leagueId,
                     staffelId: 0,
                     branchId: league_team_cc.branchId,
                     subBranchId: league_team_cc.subBranchId,
                     seasonId: league_team_cc.seasonId,
                     p: league_team_cc.p,
                     passnr: player.ba_id,
                     referer: "/admin/bm_mw/spielberichtCheck.php?" }
            if true
              _, doc = @client.post(
                "showLeague_add_teamplayer",
                args,
                opts
              )
              err_msg = doc.css('input[name="errMsg"]')[0].andand["value"]
              if err_msg.present?
                RegionCc.logger.info "REPORT! ERROR LeagueTeam #{league_team.andand.name} Player #{player.fullname} DBU-NR=#{player.ba_id} not in CC!"
              end
            else
              RegionCc.logger.info "REPORT! #{league.season.name}, #{league.name}, LeagueTeam: #{league_team.andand.name} Player: #{player.fullname} DBU-NR=#{player.ba_id} fehlt!!"
            end
          end
        else
          RegionCc.logger.info "REPORT! [synchronize_team_players_structure] LeagueTeam #{league_team.andand.name} in Liga #{league_team.league.andand.name} nicht in CC"
        end
      end
    end
  end
end
