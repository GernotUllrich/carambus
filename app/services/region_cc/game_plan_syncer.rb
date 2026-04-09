# frozen_string_literal: true

# Kapselt die Synchronisation von Spielplänen (GamePlanCc) und Spieldetails
# (GameDetailCc) aus ClubCloud. sync_game_details ist die grösste einzelne
# Methode (~323 Zeilen) und enthält komplexe HTML-Tabellen-Parsierung mit
# verschachtelten Schleifen und bedingter Logik für verschiedene Spielformate.
#
# Verwendung:
#   RegionCc::GamePlanSyncer.call(
#     region_cc: @region_cc,
#     client: @client,
#     operation: :sync_game_plans,
#     season_name: "2022/2023",
#     context: "nbv"
#   )
class RegionCc::GamePlanSyncer < ApplicationService
  def self.call(**kwargs)
    new(**kwargs).call
  end

  def initialize(region_cc:, client:, operation:, **opts)
    @region_cc = region_cc
    @client = client
    @operation = operation
    @opts = opts
  end

  def call
    case @operation
    when :sync_game_plans then sync_game_plans
    when :sync_game_details then sync_game_details
    else raise ArgumentError, "Unknown operation: #{@operation}"
    end
  end

  private

  def sync_game_plans
    Season.find_by_name(@opts[:season_name])
    region = Region.find_by_shortname(@opts[:context].upcase)

    region_cc = region.region_cc
    region_cc.branch_ccs.each do |branch_cc|
      # get game_plan definitions
      branch = branch_cc.discipline
      _, doc = @client.get(
        "spielberichte",
        { p: "#{branch_cc.fedId}-#{branch_cc.branchId}" }, @opts
      )
      doc.text
      tables = doc.css("form > table > tr > td > table > tr > td > table > tr > td > table")
      tables.each do |table|
        next unless table.css("> tr > th")[1].andand.text == "Spielbericht"

        table.css("> tr").each_with_index do |tr, _ix|
          tds = tr.css("> td")
          next if tds.blank?

          name = tds[1].text
          link = tds[1].css("a")[0]["href"]
          cc_id = link.match(/spielbericht_anzeigen.*=\d+-\d+-(\d+)-.*$/)[1]
          game_plan_cc = GamePlanCc.find_by_cc_id(cc_id)
          game_plan_cc ||= GamePlanCc.new(name: name, cc_id: cc_id, branch_cc_id: branch_cc.id,
                                          discipline_id: branch.id)

          # read single game plan

          _, doc2 = @client.get(
            "spielbericht_anzeigen",
            { p: "#{branch_cc.fedId}-#{branch_cc.branchId}-#{cc_id}-" },
            @opts
          )
          lines = []
          tables = doc2.css("form > table > tr > td > table > tr > td > table > tr > td > table > tr > td > table > tr > td > table")
          tables.each do |table|
            next if table.css("> tr > th")[0].andand.text == "Partie-Nr."

            begin
              table.css("> tr").each_with_index do |tr, _ix|
                tds = tr.css("> td")
                if tds.blank?
                  ths = tr.css("> th")
                  ths.text
                  lines.push(ths[1].text)
                else
                  next if tds[1].text.blank?

                  lines.push(tds[1].text)
                end
              end
              unless game_plan_cc.data["games"] == lines
                game_plan_cc.deep_merge_data!({ "games" => lines })
                game_plan_cc.save!
              end
            rescue StandardError => e
              Rails.logger.info "#{e} #{e.backtrace.join("\n")}"
            end
          end
        end
      end
    end
  end

  def sync_game_details
    season = Season.find_by_name(@opts[:season_name])
    region = Region.find_by_shortname(@opts[:context].upcase)
    @opts[:done_ids] = []
    region_cc = region.region_cc
    region_cc.branch_ccs.each do |branch_cc|
      branch_cc.competition_ccs.each do |competition_cc|
        competition_cc.season_ccs.where.not(name: @opts[:exclude_season_names]).each do |season_cc|
          next unless season_cc.name == season.name

          season_cc.league_ccs.order(cc_id: :asc).each do |league_cc|
            next if branch_cc.name == "Snooker" # TODO: TEST REMOVE ME
            next if branch_cc.name == "Pool" # TODO: TEST REMOVE ME
            # next if league_cc.league.discipline_id.blank? # TODO TEST REMOVE ME
            next if @opts[:exclude_league_ba_ids].include?(league_cc.league.ba_id)

            league_cc.party_ccs.joins(:party).where.not(parties: { id: @opts[:done_ids] }).uniq.each do |party_cc|
              # next unless league_cc.league_id == 3512
              # next unless party_cc.match_id == 3028
              party = party_cc.party
              # next unless party.ba_id == 81118
              # Kernel.sleep(0.5)
              if party.no_show_team_id.present?
                zuNullTeam = party.no_show_team_id == party.league_team_a.id ? party.league_team_b.id : party.league_team_a.id
              end
              params = {
                "memo" => party.remarks.andand.deep_stringify_keys.andand["remarks"].to_s.encode(Encoding::ISO_8859_1),
                "protest" => party.remarks.andand.deep_stringify_keys.andand["protest"].to_s.encode(Encoding::ISO_8859_1),
                "zuNullTeamId" => (LeagueTeam[zuNullTeam] if party.no_show_team_id.present?).andand.cc_id.to_i,
                "saveBut" => "",
                "woher" => 1,
                "matchId" => party_cc.match_id,
                "errMsgNew" => "",
                "teamId" => party_cc.league_team_a_cc.cc_id,
                "firstEntry" => 1,
                "wettbewerb" => party_cc.subBranchId,
                "partienr" => party_cc.cc_id
              }
              discipline_synonyms = {
                "14/1e" => "14.1 endlos",
                "15-reds" => "Snooker",
                "Dreiband (gr)" => "Dreiband groß",
                "Dreiband (kl)" => "Dreiband klein",
                "Einband (kl)" => "Einband klein",
                "Freie Partie (kl)" => "Freie Partie klein",
                "Cadre 35/2" => "Cadre 52/2"
              }
              if params["zuNullTeamId"].to_i > 0
                params["protest"] = ":: zu Null Ergebnis.".encode(Encoding::ISO_8859_1) if params["protest"].blank?
              elsif params["protest"].present?
                if /:0/.match?(party.data["result"])
                  params["zuNullTeamId"] = party.league_team_a.league_team_cc.cc_id
                elsif /0:/.match?(party.data["result"])
                  params["zuNullTeamId"] = party.league_team_b.league_team_cc.cc_id
                end
              else
                game_lines = league_cc.game_plan_cc.data["games"]
                pg_line_ix = 0
                party.party_games.each_with_index do |pg, _ix|
                  while pg_line_ix < game_lines.count && ((game_lines[pg_line_ix] =~ /Runde/) || (pg.discipline.name != game_lines[pg_line_ix] && pg.discipline.name != discipline_synonyms[game_lines[pg_line_ix]]))
                    pg_line_ix += 1
                  end
                  sc_ = pg.data["result"][pg.data["result"].keys[0]].gsub("Bälle (x0.00):",
                                                                        "").split(":").map(&:@strip).map(&:to_i)
                  in_ = if pg.data["result"].keys[1].present?
                          pg.data["result"][pg.data["result"].keys[1]].gsub(
                            "Aufn. (x0.00):", ""
                          ).split(":").map(&:@strip).map(&:to_i)
                        else
                          []
                        end
                  br_ = if pg.data["result"].keys[2].present?
                          pg.data["result"][pg.data["result"].keys[2]].gsub("HS:",
                                                                          "").split(":").map(&:@strip).map(&:to_i)
                        else
                          []
                        end

                  # 2:0 => 1:0, 1:0
                  # 2:1 => 1:0, 0:1, 1:0
                  player_a_noshow = player_b_noshow = false
                  if pg.player_a.andand.cc_id.blank?
                    if pg.player_a.blank? || pg.player_a.lastname == "Freilos"
                      player_a_noshow = true
                    else
                      player = Player.where(type: nil).where.not(cc_id: nil).where(firstname: pg.player_a.firstname,
                                                                                   lastname: pg.player_a.lastname).first
                      if player.present?
                        pg.update(player_a_id: player.id)
                        pg.reload
                      else
                        # TODO: THIS IS DUPLICATE CODE !!!
                        words_firstname = pg.player_a.firstname.split(/\s+/)
                        words_lastname = Array(pg.player_a.lastname)
                        player = nil
                        while words_firstname.count > 0
                          player_firstname = words_firstname.join(" ")
                          player_lastname = words_lastname.join(" ")
                          if player.blank?
                            player = Player.where(type: nil).where.not(cc_id: nil).where(firstname: player_firstname,
                                                                                         lastname: player_lastname).first
                          end
                          break if player.present?

                          take_last_word_from_firstname = words_firstname.pop
                          words_lastname.unshift(take_last_word_from_firstname)

                        end
                        if player.present?
                          pg.update(player_a_id: player.id)
                          pg.reload
                        else
                          RegionCc.logger.info "REPORT! Spieler hat keine PASS-NR: #{pg.player_a.fullname}[#{pg.player_a.id} -  ba_id: #{pg.player_a.ba_id}, team: #{pg.party.league_team_a.name}]"
                        end
                      end
                    end
                  end
                  if pg.player_b.andand.cc_id.blank?
                    if pg.player_b.blank? || pg.player_b.lastname == "Freilos"
                      player_b_noshow = true
                    else
                      player = Player.where(type: nil).where.not(cc_id: nil).where(firstname: pg.player_b.firstname,
                                                                                   lastname: pg.player_b.lastname).first
                      if player.present?
                        pg.update(player_b_id: player.id)
                        pg.reload
                      else
                        words_firstname = pg.player_b.firstname.split(/\s+/)
                        words_lastname = Array(pg.player_b.lastname)
                        player = nil
                        while words_firstname.count > 0
                          player_firstname = words_firstname.join(" ")
                          player_lastname = words_lastname.join(" ")
                          if player.blank?
                            player = Player.where(type: nil).where.not(cc_id: nil).where(firstname: player_firstname,
                                                                                         lastname: player_lastname).first
                          end
                          break if player.present?

                          take_last_word_from_firstname = words_firstname.pop
                          words_lastname.unshift(take_last_word_from_firstname)

                        end
                        if player.present?
                          pg.update(player_b_id: player.id)
                          pg.reload
                        else
                          RegionCc.logger.info "REPORT! Spieler hat keine PASS-NR: #{pg.player_b.fullname}[#{pg.player_b.id} -  ba_id: #{pg.player_b.ba_id}, team: #{pg.party.league_team_b.name}]"
                        end
                      end
                    end
                  end
                  add_pg = {
                    "#{party_cc.match_id}-#{pg_line_ix}-1-1-pid1" => pg.player_a.andand.cc_id.to_i,
                    "#{party_cc.match_id}-#{pg_line_ix}-1-1-pid2" => pg.player_b.andand.cc_id.to_i
                  }
                  if branch_cc.name == "Pool" || branch_cc.name == "Karambol"
                    if player_a_noshow && player_b_noshow && pg.party.data["result"] =~ /0:0/
                      RegionCc.logger.info "REPORT keine Ergebnisse - noch nicht gespielt? wer ist Gewinner?"
                    elsif player_a_noshow && sc_[0].to_i == 0
                      if /0:/.match?(pg.party.data["result"])
                        # team a nicht angetreten
                        if party.remarks.andand.deep_stringify_keys.andand["protest"].blank?
                          if party.remarks.andand.deep_stringify_keys.andand["remarks"].blank?
                            unless params["memo"].present?
                              add_pg["memo"] =
                                ":: Mannschaft #{party.league_team_a.name} nicht angetreten".encode(Encoding::ISO_8859_1)
                            end
                            unless params["memo"].present?
                              add_pg["protest"] =
                                ":: Mannschaft #{party.league_team_b.name} gewinnt mit einem zu Null Ergebnis. [Es werden keine Spiele gespeichert.]".encode(Encoding::ISO_8859_1)
                            end
                            add_pg["zuNullTeamId"] = party.league_team_b.league_team_cc.cc_id
                          else
                            RegionCc.logger.info "manual check"
                          end
                        else
                          RegionCc.logger.info "manual check"
                        end
                      end
                      unless add_pg["zuNullTeamId"].to_i > 0
                        if sc_[1].to_i > 0
                          add_pg["#{party_cc.match_id}-#{pg_line_ix}-1-sc2"] = sc_[1].presence
                        else
                          unless params["memo"].present?
                            add_pg["memo"] =
                              ":: Mannschaft #{party.league_team_a.name} nicht vollständig angetreten".encode(Encoding::ISO_8859_1)
                          end
                          add_pg["#{party_cc.match_id}-#{pg_line_ix}-1-sc2"] =
                            (/14/.match?(game_lines[pg_line_ix]) ? 125 : 7)
                        end
                      end
                    elsif player_b_noshow && sc_[1].to_i == 0

                      if /:0/.match?(pg.party.data["result"])
                        # team b nicht angetreten
                        if party.remarks.andand.deep_stringify_keys.andand["protest"].blank?
                          if party.remarks.andand.deep_stringify_keys.andand["remarks"].blank?
                            unless params["memo"].present?
                              add_pg["memo"] =
                                ":: Mannschaft #{party.league_team_b.name} nicht angetreten".encode(Encoding::ISO_8859_1)
                            end
                            unless params["memo"].present?
                              add_pg["protest"] =
                                ":: Mannschaft #{party.league_team_a.name} gewinnt mit einem zu Null Ergebnis. [Es werden keine Spiele gespeichert.]".encode(Encoding::ISO_8859_1)
                            end
                            add_pg["zuNullTeamId"] = party.league_team_a.league_team_cc.cc_id
                          else
                            RegionCc.logger.info "manual check"
                          end
                        else
                          RegionCc.logger.info "manual check"
                        end
                      end
                      unless add_pg["zuNullTeamId"].to_i > 0
                        if sc_[0].to_i > 0
                          add_pg["#{party_cc.match_id}-#{pg_line_ix}-1-sc1"] = sc_[0].presence
                        else
                          unless params["memo"].present?
                            add_pg["memo"] =
                              ":: Mannschaft #{party.league_team_b.name} nicht vollständig angetreten".encode(Encoding::ISO_8859_1)
                          end
                          add_pg["#{party_cc.match_id}-#{pg_line_ix}-1-sc1"] =
                            (/14/.match?(game_lines[pg_line_ix]) ? 125 : 7)
                        end
                      end
                    else
                      add_pg["#{party_cc.match_id}-#{pg_line_ix}-1-sc1"] = sc_[0].presence if sc_[0].present?
                      add_pg["#{party_cc.match_id}-#{pg_line_ix}-1-sc2"] = sc_[1].presence if sc_[1].present?
                      add_pg["#{party_cc.match_id}-#{pg_line_ix}-1-in1"] = in_[0].presence if in_[0].present?
                      add_pg["#{party_cc.match_id}-#{pg_line_ix}-1-in2"] = in_[1].presence if in_[1].present?
                      add_pg["#{party_cc.match_id}-#{pg_line_ix}-1-br1"] = br_[0].presence if br_[0].present?
                      add_pg["#{party_cc.match_id}-#{pg_line_ix}-1-br2"] = br_[1].presence if br_[1].present?
                    end
                  elsif branch_cc.name == "Snooker"
                    c1 = sc_[0]
                    c2 = sc_[1]
                    n_games = c1 + c2
                    (1..n_games).each do |ii|
                      if c1 >= c2
                        add_pg["#{party_cc.match_id}-#{pg_line_ix}-#{ii}-sc1"] = 1 unless player_a_noshow
                        add_pg["#{party_cc.match_id}-#{pg_line_ix}-#{ii}-sc2"] = 0
                        c1 -= 1
                      else
                        add_pg["#{party_cc.match_id}-#{pg_line_ix}-#{ii}-sc1"] = 0
                        add_pg["#{party_cc.match_id}-#{pg_line_ix}-#{ii}-sc2"] = 1 unless player_b_noshow
                        c2 -= 1
                      end
                      next unless ii == n_games

                      if in_[0].present? && !player_a_noshow
                        add_pg["#{party_cc.match_id}-#{pg_line_ix}-#{ii}-br1"] =
                          in_[0].presence
                      end
                      if in_[1].present? && !player_b_noshow
                        add_pg.merge!("#{party_cc.match_id}-#{pg_line_ix}-#{ii}-br2" => in_[1].presence)
                      end
                    end
                  end
                  params.merge!(add_pg)
                  pg_line_ix += 1
                  break if pg_line_ix > game_lines.count || params["zuNullTeamId"].to_i > 0
                end
              end
              args = params.merge(referer: "/admin/bm_mw/spielberichtCheck.php?")
              if true
                _res, doc = @client.post(
                  "spielberichtSave",
                  args,
                  @opts
                )
                doc.text
              else
                RegionCc.logger.info "REPORT [sync_game_details] WOULD ENTER Game Report il League #{league_cc.attributes}  and Part #{party_cc.attributes} with 'spielberichtSave' and payload #{args}"
              end
            end
          end
        end
      end
    end
  rescue StandardError => e
    RegionCc.logger.error "ERROR #{e} \n#{e.backtrace.join("\n")}"
  end
end
