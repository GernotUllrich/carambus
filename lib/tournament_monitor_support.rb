# frozen_string_literal: true

module TournamentMonitorSupport
  def update_game_participations(tabmon)
    game = tabmon.game
    sets = nil
    rank = {}
    points = {}
    if sets_to_play > 1
      ("a".."b").each do |c|
        rank["player#{c}"] = tabmon.data["ba_results"]["Sets#{c == "a" ? 1 : 2}"]
      end
    else
      ("a".."b").each do |c|
        rank["player#{c}"] =
          tabmon.data["player#{c}"]["result"].to_f / tabmon.data["player#{c}"]["balls_goal"] * 100.0
      end
    end
    points["playera"] = if rank["playera"] > rank["playerb"]
                          2
                        else
                          (rank["playera"] < rank["playerb"] ? 0 : 1)
                        end
    points["playerb"] = if rank["playerb"] > rank["playera"]
                          2
                        else
                          (rank["playerb"] < rank["playera"] ? 0 : 1)
                        end
    ("a".."b").each do |c|
      gp = game.game_participations.where(role: "player#{c}").first
      if sets_to_play > 1
        n = c == "a" ? 1 : 2
        result = tabmon.data["ba_results"]["Ergebnis#{n}"].to_i
        innings = tabmon.data["ba_results"]["Aufnahmen#{n}"].to_i
        gd = format("%.2f", result.to_f / innings).to_f
        hs = tabmon.data["ba_results"]["Höchstserie#{n}"].to_i
        sets = tabmon.data["ba_results"]["Sets#{n}"].to_i
        results = {
          "Gr." => game.gname,
          "Ergebnis" => result,
          "Aufnahme" => innings,
          "GD" => gd,
          "HS" => hs,
          "Sets" => sets,
          "gp_id" => gp.id
        }
      else
        result = tabmon.data["player#{c}"]["result"].to_i
        innings = tabmon.data["player#{c}"]["innings"].to_i
        bg = tabmon.data["player#{c}"]["balls_goal"].to_i
        gd = format("%.2f", tabmon.data["player#{c}"]["result"].to_f /
                            tabmon.data["player#{c}"]["innings"].to_i).to_f
        # bg_p is the percentage of achieving the balls_goal in this game
        bg_p = format("%.2f", 100.0 * tabmon.data["player#{c}"]["result"].to_f /
                              tabmon.data["player#{c}"]["balls_goal"].to_i).to_f
        hs = tabmon.data["player#{c}"]["hs"].to_i
        results = {
          "Gr." => game.gname,
          "Ergebnis" => result,
          "Aufnahme" => innings,
          "GD" => gd,
          "HS" => hs,
          "gp_id" => gp.id,
          "Sets" => 1,
          "BG" => bg,
          "BG_P" => bg_p
        }
      end
      gp.deep_merge_data!("results" => results)
      gp.update(points: points["player#{c}"], result: result, innings: innings, gd: gd, hs: hs, sets: sets)
      Tournament.logger.info("RESULT #{game.gname} points: #{points["player#{c}"]},
result: #{result}, innings: #{innings}, gd: #{gd}, hs: #{hs}, sets: #{sets}")
    end
  rescue StandardError => e
    Rails.logger.info "ERROR: #{e}, #{e.backtrace&.join("\n")}" if DEBUG
  end

  def accumulate_results
    rankings = {
      "total" => {},
      "groups" => {
        "total" => {}
      },
      "endgames" => {
        "total" => {},
        "groups" => {
          "total" => {}
        }
      }
    }
    # IMPORTANT: Filter by current tournament to avoid mixing results from other tournaments
    GameParticipation.joins(:game).where(
      "games.id >= ? AND games.tournament_id = ?", Seeding::MIN_ID, tournament.id
    ).each do |gp|
      game = gp.game
      results = gp.data["results"]
      if results.present?
        if (m = game.gname.match(%r{^group(\d+):(\d+)-(\d+)(?:/(\d+))?$}))
          group_no = m[1]
          add_result_to(gp, rankings["total"])
          add_result_to(gp, rankings["groups"]["total"])
          rankings["groups"]["group#{group_no}"] ||= {}
          add_result_to(gp, rankings["groups"]["group#{group_no}"])
        elsif (m = game.gname.match(/^fg(\d+):(\d+)-(\d+)$/))
          group_no = m[1]
          add_result_to(gp, rankings["total"])
          add_result_to(gp, rankings["endgames"]["total"])
          add_result_to(gp, rankings["endgames"]["groups"]["total"])
          rankings["endgames"]["groups"]["fg#{group_no}"] ||= {}
          add_result_to(gp, rankings["endgames"]["groups"]["fg#{group_no}"])
        elsif (m = game.gname.match(/^(\d+f|af|qf|vf|hf|fin|p<\d+(?:\.\.|-)\d+>)(\d+)?$/))
          level = m[1]
          group_no = m[2]
          add_result_to(gp, rankings["total"])
          add_result_to(gp, rankings["endgames"]["total"])
          rankings["endgames"][level.to_s] ||= {}
          add_result_to(gp, rankings["endgames"][level.to_s])
          rankings["endgames"]["#{level}#{group_no}"] ||= {} if group_no.present?
          add_result_to(gp, rankings["endgames"]["#{level}#{group_no}"]) if group_no.present?
        end
      end
    end
    data_will_change!
    data["rankings"] = rankings
    save!
  rescue StandardError => e
    Rails.logger.info "ERROR: #{e}, #{e.backtrace&.join("\n")}" if DEBUG
  end

  def add_result_to(gp, hash)
    player_id = gp.player_id
    hash[player_id] ||= {
      "points" => 0,
      "result" => 0,
      "innings" => 0,
      "hs" => 0,
      "bed" => 0,
      "gd" => 0,
      "balls_goal" => nil, # Player's handicap balls_goal (not sum!)
      "gd_pct" => 0.0

    }
    hash[player_id]["points"] += gp.points
    hash[player_id]["result"] += gp.result
    hash[player_id]["innings"] += gp.innings
    hash[player_id]["bed"] = gp.gd if gp.gd > hash[player_id]["bed"]
    hash[player_id]["hs"] = gp.hs if gp.hs > hash[player_id]["hs"]
    hash[player_id]["gd"] = format("%.2f", hash[player_id]["result"].to_f / hash[player_id]["innings"]).to_f

    # Get player's balls_goal from seeding (not from game!)
    if hash[player_id]["balls_goal"].nil?
      seeding = tournament.seedings
                          .where("seedings.id >= #{Seeding::MIN_ID}")
                          .find_by(player_id: player_id)
      hash[player_id]["balls_goal"] = seeding&.balls_goal || gp.data["results"]["BG"]
    end

    # Calculate gd_pct: achieved GD vs expected GD
    # Expected GD = balls_goal / innings_goal
    # gd_pct = 100 * gd_achieved / gd_expected
    if hash[player_id]["balls_goal"].present?
      innings_goal_value = innings_goal || tournament.innings_goal
      if innings_goal_value.present? && innings_goal_value > 0
        expected_gd = hash[player_id]["balls_goal"].to_f / innings_goal_value.to_f
        hash[player_id]["gd_pct"] =
          format("%.2f", 100.0 * hash[player_id]["gd"] / expected_gd).to_f
      end
    end
  rescue StandardError => e
    e
  end

  def report_result(table_monitor)
    TournamentMonitor.transaction do
      try do
        # noinspection RubyResolve
        # Tournament.logger.info "[tournament_monitor#report_result]\
        # #{caller[0..4].select{|s| s.include?("/app/").join("\n")}" if table_monitor.may_finish_match?
        table_monitor.finish_match! if table_monitor.may_finish_match?
        finalize_game_result(table_monitor)
        accumulate_results
        reload
        if all_table_monitors_finished? || tournament.manual_assignment || tournament.continuous_placements
          finalize_round # unless tournament.manual_assignment
          incr_current_round! unless tournament.manual_assignment || tournament.continuous_placements
          populate_tables unless tournament.manual_assignment
          if group_phase_finished?
            if finals_finished?
              decr_current_round!
              update_ranking
              write_finale_csv_for_upload
              # noinspection RubyResolve
              end_of_tournament!
              # noinspection RubyResolve
              tournament.finish_tournament!
              # noinspection RubyResolve
              tournament.have_results_published!
              # tournament.tournament_monitor.andand.table_monitors.andand.destroy_all
            else
              # noinspection RubyResolve
              start_playing_finals!
            end
          else
            # noinspection RubyResolve
            start_playing_groups!
          end
          TournamentMonitorUpdateResultsJob.perform_later(self)
          # Broadcast Status-Update für Tournament View
          TournamentStatusUpdateJob.perform_later(tournament)
        elsif tournament.tournament_started
          # Auch bei einzelnen Spiel-Updates broadcasten (wenn Spiel läuft)
          TournamentStatusUpdateJob.perform_later(tournament)
        end
      rescue StandardError => e
        Rails.logger.info "StandardError #{e}, #{e.backtrace&.join("\n")}"
        raise ActiveRecord::Rollback
      end
    end
  end

  def update_ranking
    tm = self
    rankings = tm.data["rankings"]
    executor_params = JSON.parse(tournament.tournament_plan.executor_params)
    rk_rules = executor_params["RK"]
    ix = 1
    rk_rules.each do |rule|
      if rule.is_a?(Array)
        rule.each do |rule_part|
          player_id = tm.player_id_from_ranking(rule_part, executor_params: executor_params)
          rankings["total"][player_id.to_s]["rank"] = ix
          tournament.seedings.where(seedings: { player_id: player_id }).first&.update(rank: ix + 1)
        end
        ix += rule.count
      else
        player_id = tm.player_id_from_ranking(rule, executor_params: executor_params)
        rankings["total"][player_id.to_s]["rank"] = ix
        tournament.seedings.where(seedings: { player_id: player_id }).first&.update(rank: ix + 1)
        ix += 1
      end
    end
    data_will_change!
    data["rankings"] = rankings
    save!
  end

  def write_finale_csv_for_upload
    # Gruppe;Partie;Spieler1;Spieler2;Ergebnis1;\
    # Ergebnis2;Aufnahmen1;Aufnahmen2;Höchstserie1;Höchstserie2;Tischnummer;Start;Ende
    # Hauptrunde;1;98765;95678;100;85;24;23;16;9;1;11:30:45;12:17:51
    game_data = []
    tournament.games.where("games.id >= #{Game::MIN_ID}").each do |game|
      # Verwende die gleiche Mapping-Logik wie beim Single-Game-Upload
      # um konsistente ClubCloud-Spielnamen zu generieren
      gruppe = Setting.map_game_gname_to_cc_group_name(game.gname)

      # Fallback auf alte Logik, falls Mapping fehlschlägt
      unless gruppe.present?
        Rails.logger.warn "[CSV-Export] Could not map game.gname '#{game.gname}' to ClubCloud group name, using fallback"
        gruppe = "#{/^group/.match?(game.gname) ? "Gruppe" : game.gname}#{if game.group_no.present?
                                                                            " #{game.group_no}"
                                                                          end}"
      end

      partie = game.seqno
      gp1 = game.game_participations.where(role: "playera").first
      gp2 = game.game_participations.where(role: "playerb").first
      # started = game.started_at.strftime('%R')
      ended = game.ended_at
      # GRUPPE/RUNDE;PARTIE;SATZ-NR.;PASS-NR. SPIELER 1;PASS-NR. SPIELER 2;PUNKTE SPIELER 1;\
      # PUNKTE SPIELER 2;AUFNAHMEN SPIELER 1;AUFNAHMEN SPIELER 2;HÖCHSTSERIE SPIELER 1;\
      # HÖCHSTSERIE SPIELER 2;DATUM;UHRZEIT
      next unless gp1.present? && gp2.present?

      game_data << "#{gruppe};#{partie};;#{gp1.player.cc_id};#{gp2.player.cc_id};#{gp1.result};\
#{gp2.result};#{gp1.innings};#{gp2.innings};#{gp1.hs};#{gp2.hs};#{ended.strftime("%d.%m.%Y")};\
#{ended.strftime("%H:%M")}"
    end
    f = File.new("#{Rails.root}/tmp/result-#{tournament.cc_id}.csv", "w")
    f.write(game_data.join("\n"))
    f.close
    NotifierMailer.result(tournament, current_admin.email, "Turnierergebnisse -\
    #{tournament.title}", "result-#{tournament.id}.csv" \
    , "#{Rails.root}/tmp/result-#{tournament.id}.csv").deliver
    NotifierMailer.result(tournament, "gernot.ullrich@gmx.de", "Turnierergebnisse - #{tournament.title}",
                          "result-#{tournament.id}.csv", "#{Rails.root}/tmp/result-#{tournament.id}.csv").deliver
  end

  def initialize_table_monitors
    Tournament.logger.info "[tmon-initialize_table_monitors]..."
    save!
    table_ids = Array(tournament.data["table_ids"].andand.map(&:to_i))
    if table_ids.present?
      max_tables = [tournament.tournament_plan.andand.tables.to_i, table_ids.count].min
      Tournament.logger.info "[tmon-initialize_table_monitors] table_ids: #{table_ids.inspect}, max_tables: #{max_tables}"
      (1..max_tables).each do |t_no|
        table_id = table_ids[t_no - 1]
        unless table_id.present?
          Tournament.logger.warn "[tmon-initialize_table_monitors] WARNING: table_id für Tisch #{t_no} fehlt (table_ids[#{t_no - 1}] = nil)"
          next
        end

        table = Table.find_by(id: table_id)
        unless table.present?
          Tournament.logger.error "[tmon-initialize_table_monitors] ERROR: Table[#{table_id}] nicht gefunden für Tisch #{t_no}"
          next
        end

        table_monitor = table.table_monitor
        unless table_monitor.present?
          Tournament.logger.error "[tmon-initialize_table_monitors] ERROR: TableMonitor für Table[#{table_id}] nicht gefunden für Tisch #{t_no}"
          next
        end

        table_monitor.reset_table_monitor if table_monitor.game.present?
        table_monitor.update(tournament_monitor: self)
        Tournament.logger.info "[tmon-initialize_table_monitors] Tisch #{t_no} (Table[#{table_id}]) zugewiesen"
      end
      reload
    else
      Tournament.logger.info "state:#{state}...[tmon-initialize_table_monitors] NO TABLES"
    end
    Tournament.logger.info "state:#{state}...[tmon-initialize_table_monitors]"
  end

  def populate_tables
    try do
      Tournament.logger.info "[tmon-populate_tables]..."
      self.allow_change_tables = false
      executor_params = JSON.parse(tournament.tournament_plan.executor_params)
      @placements = data["placements"].presence || {}

      @placements_done = @placements.keys.map do |k|
        @placements[k]
      end.flatten.first.andand.values.to_a.flatten

      @placement_candidates = data["placement_candidates"].presence || []
      ordered_ranking_nos = {}
      ordered_table_nos = {}
      admin_table_nos = {}
      table_ids = Array(tournament.data["table_ids"].andand.map(&:to_i))
      table_ids.each do |table_id|
        @table = Table.find(table_id)
        @table_monitor = @table.table_monitor || @table.table_monitor!
      end
      if @placement_candidates.empty?
        keys = executor_params.keys
        if tournament.tournament_plan&.name&.start_with?("KO")
          tier_map = { "fin" => 1, "hf" => 2, "qf" => 4 }
          keys = keys.sort_by do |k|
            prefix = k.gsub(/\d+$/, "")
            tier = tier_map[prefix] || prefix.to_i
            [-tier, k]
          end
        end
        keys.each do |k|
          if (m = k.match(/g(\d+)/))
            Tournament.logger.info "+++001 k,v = [#{k} => #{executor_params[k].inspect}]"
            group_no = m[1].to_i
            # apply table/round_rules
            if !executor_params[k]["sq"].is_a?(Hash) || executor_params[k]["sq"]["r#{current_round}"].blank?
              sets = executor_params[k]["sets"]
              balls = executor_params[k]["balls"]
              innings = executor_params[k]["innings"]
              Tournament.logger.info "+++002 k,v = [#{k} => #{executor_params[k].inspect}]\
 [k][\"sq\"][\"r#{current_round}\"] is blank"
              if executor_params[k]["rs"].to_s == "eae_pg"
                Tournament.logger.info "+++003 k,v = [#{k} => #{executor_params[k].inspect}]\
 params[k][\"rs\"] == \"eae_pg\""
                case current_round
                when 2
                  Tournament.logger.info "+++004 k,v = [#{k} => #{executor_params[k].inspect}] current_round == 2"
                  # if winner on both tables
                  winner = GameParticipation
                           .joins(:game)
                           .joins("left outer join tournaments on tournaments.id = games.tournament_id")
                           .where("games.id >= ?", Seeding::MIN_ID)
                           .where(games: { round_no: 1, group_no: group_no, tournament_id: tournament.id })
                           .order("points desc, game_id asc")
                  table_from_winner = winner.where(points: 2).count == 2
                  winner_arr = winner.to_a
                  # player1 = winner in first_game
                  winner1 = winner_arr[0].player_id
                  table_nos = tournament
                              .games.where("games.id >= #{Game::MIN_ID}")
                              .where(games: { round_no: 1, group_no: group_no })
                              .map(&:table_no).shuffle
                  if table_from_winner
                    # winner stays on table
                    t_no = winner_arr[0].game.table_no
                    table_nos.delete(t_no)
                    Tournament.logger.info "+++006 k,v = [#{k} => #{executor_params[k].inspect}]\
 table from winner t_no = #{t_no}\
 winner1 = #{Player[winner1].fullname} [#{winner1}]"
                  else
                    t_no = table_nos.shift
                    Tournament.logger.info "+++007 k,v = [#{k} => #{executor_params[k].inspect}] t_no = #{t_no}"
                  end
                  r_no = current_round
                  # groups data now contains player IDs directly, not player hashes
                  seqno1_a = tournament.tournament_monitor.data["groups"]["group#{group_no}"].index do |player_id|
                    player_id == winner1
                  end + 1
                  looser2 = winner_arr[3].player_id
                  seqno2_a = tournament.tournament_monitor.data["groups"]["group#{group_no}"].index do |player_id|
                    player_id == looser2
                  end + 1
                  gname_a = "group#{group_no}:#{[seqno1_a, seqno2_a].sort.map(&:to_s).join("-")}"
                  game_a = tournament.games
                                     .where.not(games: { id: @placements_done })
                                     .where("games.id >= #{Game::MIN_ID}")
                                     .where(gname: gname_a).first
                  Tournament.logger.info "+++008 do_placement(game a = #{game_a.gname}, r_no = #{r_no}, t_no = #{t_no})"
                  if tournament.continuous_placements
                    @placement_candidates.push([game_a.id, game_a.gname, r_no, t_no])
                  else
                    do_placement(game_a, r_no, t_no, sets, balls, innings)
                  end
                  winner2 = winner_arr[1].player_id
                  if table_from_winner
                    t_no = winner_arr[1].game.table_no
                    Tournament.logger.info "+++009 k,v = [#{k} => #{executor_params[k].inspect}]\
 table from winner t_no = #{t_no} winner2 = #{Player[winner2].fullname} [#{winner2}]"
                  else
                    t_no = table_nos.shift
                    Tournament.logger.info "+++010 k,v = [#{k} => #{executor_params[k].inspect}] t_no = #{t_no}"
                  end
                  r_no = current_round
                  # groups data now contains player IDs directly, not player hashes
                  seqno1_b = tournament.tournament_monitor.data["groups"]["group#{group_no}"].index do |player_id|
                    player_id == winner2
                  end + 1
                  looser1 = winner_arr[2].player_id
                  seqno2_b = tournament.tournament_monitor.data["groups"]["group#{group_no}"].index do |player_id|
                    player_id == looser1
                  end + 1
                  gname_b = "group#{group_no}:#{[seqno1_b, seqno2_b].sort.map(&:to_s).join("-")}"
                  game_b = tournament
                           .games
                           .where.not(games: { id: @placements_done })
                           .where("games.id >= #{Game::MIN_ID}")
                           .where(gname: gname_b).first
                  Tournament.logger.info "+++011 do_placement(game b = #{game_b.gname}, r_no = #{r_no}, t_no = #{t_no})"
                  if tournament.continuous_placements
                    @placement_candidates.push([game_b.id, game_b.gname, r_no, t_no])
                  else
                    do_placement(game_b, r_no, t_no, sets, balls, innings)
                  end
                when 3
                  Tournament.logger.info "+++012 current_round = 3"
                  # rubocop:disable all
                  winner = GameParticipation.joins(:game).joins("left outer join tournaments on tournaments.id = games.tournament_id").where(
                    "games.id >= ?", Seeding::MIN_ID
                  ).where(games: { round_no: 2, group_no: group_no, tournament_id: tournament.id}).order("gd desc")
                  # rubocop:enable all
                  winner_arr = winner.to_a
                  table_from_winner = winner_arr[0].gd != winner_arr[1].gd
                  winner1 = winner_arr[0].player_id
                  table_nos = tournament
                              .games.where.not(games: { id: @placements_done })
                              .where("games.id >= #{Game::MIN_ID}")
                              .where(games: { round_no: 2, group_no: group_no })
                              .map(&:table_no).shuffle
                  if table_from_winner
                    t_no = winner_arr[0].game.table_no
                    table_nos.delete(t_no)
                    Tournament.logger.info "+++012A k,v = [#{k} => #{executor_params[k].inspect}]\
 table from winner t_no = #{t_no} winner1 = #{Player[winner1].fullname} [#{winner1}]"
                  else
                    t_no = table_nos.shift
                    Tournament.logger.info "+++012B k,v = [#{k} => #{executor_params[k].inspect}] t_no = #{t_no}"
                  end
                  r_no = current_round
                  # groups data now contains player IDs directly, not player hashes
                  seqno = tournament.tournament_monitor.data["groups"]["group#{group_no}"].index do |player_id|
                    player_id == winner1
                  end + 1
                  game = tournament.games
                                   .where.not(games: { id: @placements_done })
                                   .where("games.id >= #{Game::MIN_ID}")
                                   .where(games: { round_no: nil, group_no: group_no })
                                   .where("gname ilike '%:#{seqno}-%' or gname ilike '%-#{seqno}'")
                                   .first
                  Tournament.logger.info "+++013 do_placement(game = #{game.attributes.inspect},\
 r_no = #{r_no}, t_no = #{t_no})"
                  if tournament.continuous_placements
                    @placement_candidates.push([game.id, game.gname, r_no, t_no])
                  else
                    do_placement(game, r_no, t_no, sets, balls, innings)
                  end
                  t_no = table_nos.shift
                  game = tournament
                         .games
                         .where("games.id >= #{Game::MIN_ID}")
                         .where(games: { round_no: nil, group_no: group_no })
                         .first
                  Tournament.logger.info "+++014 do_placement(game = #{game.attributes.inspect}, r_no = #{r_no}, t_no = #{t_no})"
                  if tournament.continuous_placements
                    @placement_candidates.push([game.id, game.gname, r_no, t_no])
                  else
                    do_placement(game, r_no, t_no, sets, balls, innings)
                  end
                else
                  Tournament.logger.info ""
                end
              end
            end
            sets = executor_params[k]["sets"]
            balls = executor_params[k]["balls"]
            innings = executor_params[k]["innings"]
            executor_params[k]["sq"].to_a.each do |round_no, h1|
              if round_no == "sets"
                sets = h1
                next
              end
              if round_no == "balls"
                balls = h1
                next
              end
              if round_no == "innings"
                innings = h1
                next
              end
              r_no = round_no.match(/r(\d+)/)[1].andand.to_i
              next if !tournament.continuous_placements && r_no != current_round

              Tournament.logger.info "+++020 k,v = [#{k} => #{executor_params[k].inspect}] t_no = #{r_no}"
              executor_params[k]["sq"][round_no].to_a.each do |tno_str, val|
                if (mm = tno_str.match(/t(\d+)/))
                  t_no = mm[1].andand.to_i
                  game = nil
                  if /(\d+)-(\d+)/.match?(val)
                    game = tournament.games
                                     .where.not(games: { id: @placements_done })
                                     .where("games.id >= #{Game::MIN_ID}")
                                     .where(gname: "group#{group_no}:#{val}")
                                     .first
                  end
                  if game.present?
                    Tournament.logger.info "+++015 do_placement(game = #{game.gname}, r_no = #{r_no}, t_no = #{t_no})"
                    if tournament.continuous_placements
                      @placement_candidates.push([game.id, game.gname, r_no, t_no])
                    else
                      do_placement(game, r_no, t_no, sets, balls, innings)
                    end
                  end
                elsif (mm = tno_str.match(/t-rand-(\d+)-(\d+)/))
                  ordered_table_nos[tno_str] ||= (mm[1].to_i..mm[2].to_i).to_a.shuffle
                  pairs = val.to_a
                  pairs.each do |pair|
                    players_match = pair.match(/(\d+)-(\d+)/)
                    players = [players_match[1].to_i, players_match[2].to_i]
                    t_no = ordered_table_nos[tno_str].pop
                    game = tournament.games
                                     .where.not(games: { id: @placements_done })
                                     .where("games.id >= #{Game::MIN_ID}")
                                     .where(gname: "group#{group_no}:#{pair}")
                                     .first
                    if game.present?
                      Tournament.logger.info "+++015 do_placement(game = #{game.gname}, r_no = #{r_no}, t_no = #{t_no})"
                      if tournament.continuous_placements
                        @placement_candidates.push([game.id, game.gname, r_no, t_no])
                      else
                        do_placement(game, r_no, t_no, sets, balls, innings)
                      end
                    else
                      game = tournament.games
                                       .where.not(games: { id: @placements_done })
                                       .where("games.id >= #{Game::MIN_ID}")
                                       .find_or_create_by(gname: "group#{group_no}:#{pair}")
                      game.game_participations = []
                      game.save
                      ("a".."b").each_with_index do |pl_no, ix|
                        rule_str = "g#{group_no}.#{players[ix]}"
                        player_id = player_id_from_ranking(rule_str, executor_params: executor_params)
                        game.game_participations.find_or_create_by(player_id: player_id, role: "player#{pl_no}")
                      end
                      reload
                      if t_no.present?
                        Tournament.logger.info "+++016 do_placement(game = #{game.attributes.inspect},\
 r_no = #{r_no}, t_no = #{t_no})"
                        if tournament.continuous_placements
                          @placement_candidates.push([game.id, game.gname, r_no, t_no])
                        else
                          do_placement(game, r_no, t_no, sets, balls, innings)
                        end
                      end
                    end
                  end
                end
              end
            end
          elsif /(?:\d+f|vf|hf|af|qf|fin|p<\d+(?:\.\.|-)\d+>)(\d+)?/.match?(k)
            r_no = executor_params[k].keys.find { |kk| kk =~ /r[*\d+]/ }.match(/r([*\d+])/)[1].to_i
            is_ko_plan = tournament.tournament_plan&.name&.start_with?("KO")
            if is_ko_plan || current_round == r_no
              t_no = nil
              sets = executor_params[k]["sets"]
              balls = executor_params[k]["balls"]
              innings = executor_params[k]["innings"]
              tno_str, players = executor_params[k]["r#{r_no}"].to_a[0]
              Tournament.logger.info "+++012B k, r_no, tno_str, players = #{k}, #{r_no}, #{tno_str}, #{players}"
              if (mm = tno_str.match(/t(\d+)/))
                t_no = mm[1].to_i
              elsif (mm = tno_str.match(/t-rand-(\d+)-(\d+)/))
                ordered_table_nos[tno_str] ||= (mm[1].to_i..mm[2].to_i).to_a.shuffle
                t_no = ordered_table_nos[tno_str].pop
              elsif (mm = tno_str.match(/t-admin-(\d+)-(\d+)/))
                admin_table_nos[tno_str] ||= (mm[1].to_i..mm[2].to_i).to_a
                t_no = admin_table_nos[tno_str].shift
                self.allow_change_tables = true
              end
              Tournament.logger.info "+++012D k,v = [#{k} => #{executor_params[k].inspect}] find or create game #{k}"
              game = tournament.games.where("games.id >= #{Game::MIN_ID}").find_or_create_by(gname: k)
              # game.game_participations = []
              game.save
              ("a".."b").each_with_index do |pl_no, ix|
                rule_str = players[ix]
                player_id = player_id_from_ranking(rule_str, executor_params: executor_params,
                                                             ordered_ranking_nos: ordered_ranking_nos)
                if player_id.present?
                  gp = game.game_participations.where(player_id: player_id, role: "player#{pl_no}").first
                  gp || game.game_participations.create(player_id: player_id, role: "player#{pl_no}")
                end
              end
              reload
              unless @placements_done.include?(game.id)
                if t_no.present?
                  Tournament.logger.info "+++016 do_placement(game = #{game.attributes.inspect},\
 r_no = #{r_no}, t_no = #{t_no})"
                  if tournament.continuous_placements
                    @placement_candidates.push([game.id, game.gname, r_no, t_no])
                  else
                    do_placement(game, r_no, t_no, sets, balls, innings)
                  end
                end
                if tno_str == "t-rand*" && game.game_participations.filter_map(&:player_id).count == 2
                  if tournament.continuous_placements
                    @placement_candidates.push([game.id, game.gname, r_no, t_no])
                  else
                    do_placement(game, r_no, t_no, sets, balls, innings)
                  end
                end
              end
            end
          elsif k != "RK" && k != "GK" && k != "rules"
            raise "TournamentPlanError"
          end
        end
      end
      deep_merge_data!("placements" => @placements, "placement_candidates" => @placement_candidates)
      current_players = table_monitors
                        .where.not(game_id: nil)
                        .to_a.map(&:game)
                        .map(&:game_participations)
                        .flatten
                        .map(&:player_id)
                        .flatten
      if @placement_candidates.present? && tournament.continuous_placements?
        found = false
        until found
          @placement_candidates.sort_by { |pc| [pc[1]] }.each_with_index do |placement_candidate, ix|
            game = Game[placement_candidate[0]]
            required_players = game.game_participations.map(&:player_id)
            next if (required_players & current_players).present?

            current_players += required_players
            next_available_table = table_monitors.where(game_id: nil).to_a.sample&.table
            next unless next_available_table.present?

            t_no = table_ids.index(next_available_table.id) + 1
            do_placement(game, current_round, t_no, nil, nil, nil)
            @placement_candidates.delete(@placement_candidates[ix])
            found = true
            next if found
          end
        end
      end
      deep_merge_data!("placements" => @placements, "placement_candidates" => @placement_candidates)
      save!
      Tournament.logger.info "[tmon-populate_tables] placements: #{@placements.inspect}"

      # Broadcast individual teaser updates nach initialem Placement
      # (tournament_scores view hat nur #teaser_X frames, kein #table_scores container)
      Tournament.logger.info "[tmon-populate_tables] Broadcasting teasers for all table monitors"
      table_monitors.each do |tm|
        TableMonitorJob.perform_later(tm.id, "teaser") if tm.game.present?
      end

      Tournament.logger.info "...[tmon-populate_tables]"
    rescue StandardError => e
      Tournament.logger.info "[tmon-populate_tables] StandardError - ROLLBACK - #{e} #{e.backtrace&.join("\n")}"
      raise ActiveRecord::Rollback
    end
  end

  def do_placement(new_game, r_no, t_no, sets, balls, innings)
    Rails.logger.info ">>>>> do_placement CALLED: game=#{new_game.gname}, r_no=#{r_no}, t_no=#{t_no}, sets=#{sets.inspect}, balls=#{balls.inspect}, innings=#{innings.inspect}"

    # CRITICAL: Wrap in transaction to prevent race conditions with background jobs
    # Jobs reload TableMonitor - if they run before transaction commits, they corrupt in-memory state
    ActiveRecord::Base.transaction do
      try do
        @placements ||= data["placements"].presence
        @placement_candidates ||= data["placement_candidates"].presence
        @placements ||= {}
        @placement_candidates ||= []
        @placements_done = @placements.keys.map do |k|
          @placements[k]
        end.flatten.first.andand.values.to_a.flatten
        info = "+++ 8a - tournament_monitor#do_placement new_game, r_no, t_no:\
 #{new_game.attributes.inspect}, #{r_no}, #{t_no}"
        Rails.logger.info info
        Rails.logger.info ">>>>> CHECK 1: @placements_done.include?(#{new_game.id})=#{@placements_done.include?(new_game.id)}, new_game.data.blank?=#{new_game.data.blank?}"
        if !@placements_done.include?(new_game.id) || new_game.data.blank? || new_game.data.keys == ["tmp_results"]
          info = "+++ 8b - tournament_monitor#do_placement"
          Rails.logger.info info
          Rails.logger.info ">>>>> CHECK 1 PASSED"
          table_ids = tournament.data["table_ids"]

          # Wenn vorgesehener Tisch belegt ist ODER noch kein Tisch zugewiesen wurde (z.B. t-rand*): Suche freien Tisch
          is_ko_plan = tournament.tournament_plan&.name&.start_with?("KO")
          if (t_no.blank? || t_no.to_i <= 0 || @placements.andand["round#{r_no}"].andand["table#{t_no}"].present?) &&
             (is_ko_plan || current_round == r_no) && new_game.present? && !tournament.continuous_placements
            Rails.logger.warn "[do_placement] Tisch #{t_no} nicht gesetzt oder belegt in Runde #{r_no}, suche freien Tisch..."

            # Finde ersten freien Tisch
            # Bestimme Anzahl verfügbarer Tische
            available_tables = if table_ids.is_a?(Array)
                                 # table_ids könnte ein Array von Arrays sein (pro Runde) oder ein flaches Array
                                 if table_ids.present? && table_ids.first.is_a?(Array)
                                   table_ids[r_no - 1]&.length || table_ids.first.length
                                 else
                                   table_ids.length
                                 end
                               else
                                 # Fallback: Anzahl aus TournamentPlan oder Location
                                 tournament.tournament_plan&.tables.to_i > 0 ? tournament.tournament_plan.tables : 4
                               end

            original_t_no = t_no
            t_no = nil
            (1..available_tables).each do |check_t_no|
              is_free = false
              if is_ko_plan
                table_id = Array(tournament.data["table_ids"]).map(&:to_i)[check_t_no - 1]
                table = Table.find_by(id: table_id)
                table_monitor = table&.table_monitor
                is_free = table_monitor.nil? || table_monitor.game_id.blank? || %w[free not_ready
                                                                                   ready_for_new_match].include?(table_monitor.state)
              else
                # Für normale Turniere: Tisch ist frei, wenn er in der Runde r_no noch nie belegt war
                is_free = @placements.andand["round#{r_no}"].andand["table#{check_t_no}"].blank?
              end

              next unless is_free

              t_no = check_t_no
              Rails.logger.info "[do_placement] Gefundener freier Tisch: #{t_no} (ursprünglich #{original_t_no})"
              break
            end

            unless t_no.present?
              Rails.logger.error "[do_placement] ERROR: Kein freier Tisch gefunden in Runde #{r_no} für Spiel #{new_game.gname} (verfügbar: #{available_tables} Tische)"
              # We shouldn't return immediately, maybe just drop to the continuous fallback below. However we'll return to prevent crashing
              return
            end
          end

          Rails.logger.info ">>>>> CHECK 2: t_no=#{t_no}, current_round=#{current_round}, r_no=#{r_no}, continuous=#{tournament.continuous_placements}"
          is_ko_plan = tournament.tournament_plan&.name&.start_with?("KO")
          if t_no.to_i.positive? &&
             (((is_ko_plan || current_round == r_no) &&
               new_game.present? &&
               (@placements.andand["round#{r_no}"].andand["table#{t_no}"].blank? || is_ko_plan)) || tournament.continuous_placements)

            Rails.logger.info ">>>>> CHECK 2 PASSED - will do placement"
            seqno = new_game.seqno.to_i.positive? ? new_game.seqno : next_seqno
            new_game.update(round_no: r_no.to_i, table_no: t_no, seqno: seqno)
            @placements ||= {}
            @placements["round#{r_no}"] ||= {}
            @placements["round#{r_no}"]["table#{t_no}"] ||= []
            @placements["round#{r_no}"]["table#{t_no}"].push(new_game.id)
            Tournament.logger.info "DO PLACEMENT round=#{r_no} table#{t_no} assign_game(#{new_game.gname})"

            @table = Table.find(table_ids[t_no - 1])
            @table_monitor = @table.table_monitor || @table.table_monitor!
            old_game = @table_monitor.game
            if old_game.present?
              # noinspection RubyResolve
              @table_monitor.data_will_change!
              info = "+++ 8c - tournament_monitor#do_placement - save current game"
              Rails.logger.info info
              tmp_results = {}
              tmp_results["playera"] = @table_monitor.deep_delete!("playera", false)
              tmp_results["playerb"] = @table_monitor.deep_delete!("playerb", false)
              tmp_results["current_inning"] = @table_monitor.deep_delete!("current_inning", false)
              if @table_monitor.data["ba_results"].present?
                tmp_results["ba_results"] =
                  @table_monitor.deep_delete!("ba_results", false)
              end
              tmp_results["state"] = @table_monitor.state
              old_game.deep_merge_data!("tmp_results" => tmp_results)
              old_game.save!
              # noinspection RubyResolve
              @table_monitor.data_will_change!
              @table_monitor.state = "ready"
              @table_monitor.game_id = nil
              @table_monitor.save!
            end
            if @table_monitor.present?
              attrs = {}
              attrs["sets_to_play"] = sets unless sets.nil?
              # PRIORITÄT: Formular (tournament_monitor) > Tournament > executor_params
              Rails.logger.info "===== PLACEMENT DEBUG ====="
              Rails.logger.info "self.class: #{self.class.name}"
              Rails.logger.info "self.id: #{id.inspect}"
              Rails.logger.info "self.innings_goal: #{innings_goal.inspect}"
              Rails.logger.info "self.attributes['innings_goal']: #{attributes["innings_goal"].inspect}"
              Rails.logger.info "tournament.id: #{tournament.id.inspect}"
              Rails.logger.info "tournament.innings_goal: #{tournament.innings_goal.inspect}"
              Rails.logger.info "innings (executor_params): #{innings.inspect}"
              Rails.logger.info "self.balls_goal: #{balls_goal.inspect}"
              Rails.logger.info "tournament.balls_goal: #{tournament.balls_goal.inspect}"
              Rails.logger.info "balls (executor_params): #{balls.inspect}"
              Rails.logger.info "tournament.handicap_tournier?: #{tournament.handicap_tournier?.inspect}"

              attrs["innings_goal"] = innings_goal || tournament.innings_goal || innings

              # Bei Handicap-Turnieren: Individuelle Vorgaben aus Seeding holen
              if tournament.handicap_tournier?
                Rails.logger.info "HANDICAP TURNIER: Hole individuelle balls_goal aus Seeding"

                # Reload game um sicherzustellen dass GameParticipations geladen sind
                new_game.reload

                # Hole die Spieler aus den GameParticipations
                gp_a = new_game.game_participations.find { |gp| gp.role == "playera" }
                gp_b = new_game.game_participations.find { |gp| gp.role == "playerb" }

                Rails.logger.info "GameParticipation A: player_id=#{gp_a&.player_id}, role=#{gp_a&.role}"
                Rails.logger.info "GameParticipation B: player_id=#{gp_b&.player_id}, role=#{gp_b&.role}"

                # Hole die Seedings der Spieler (priorisiere lokale Seedings >= MIN_ID)
                seeding_a = if gp_a&.player_id
                              # Erst lokale Seedings probieren
                              tournament.seedings.where("id >= ?",
                                                        Seeding::MIN_ID).find_by(player_id: gp_a.player_id) ||
                                # Fallback: ClubCloud Seedings
                                tournament.seedings.where("id < ?", Seeding::MIN_ID).find_by(player_id: gp_a.player_id)
                            end
                seeding_b = if gp_b&.player_id
                              # Erst lokale Seedings probieren
                              tournament.seedings.where("id >= ?",
                                                        Seeding::MIN_ID).find_by(player_id: gp_b.player_id) ||
                                # Fallback: ClubCloud Seedings
                                tournament.seedings.where("id < ?", Seeding::MIN_ID).find_by(player_id: gp_b.player_id)
                            end

                Rails.logger.info "Seeding A (Player #{gp_a&.player_id}): balls_goal=#{seeding_a&.balls_goal.inspect}"
                Rails.logger.info "Seeding B (Player #{gp_b&.player_id}): balls_goal=#{seeding_b&.balls_goal.inspect}"

                attrs["playera"] = {}
                attrs["playera"]["balls_goal"] =
                  seeding_a&.balls_goal&.presence || balls_goal || tournament.balls_goal || balls
                attrs["playerb"] = {}
                attrs["playerb"]["balls_goal"] =
                  seeding_b&.balls_goal&.presence || balls_goal || tournament.balls_goal || balls
              else
                # Bei normalen Turnieren: Einheitliches balls_goal für beide Spieler
                attrs["playera"] = {}
                attrs["playera"]["balls_goal"] = balls_goal || tournament.balls_goal || balls
                attrs["playerb"] = {}
                attrs["playerb"]["balls_goal"] = balls_goal || tournament.balls_goal || balls
              end

              Rails.logger.info "attrs['innings_goal']: #{attrs["innings_goal"].inspect}"
              Rails.logger.info "attrs['playera']['balls_goal']: #{attrs["playera"]["balls_goal"].inspect}"
              Rails.logger.info "attrs['playerb']['balls_goal']: #{attrs["playerb"]["balls_goal"].inspect}"
              Rails.logger.info "=========================="

              Rails.logger.info "BEFORE deep_merge: @table_monitor.data['playera']&.[]('balls_goal') = #{@table_monitor.data.dig(
                "playera", "balls_goal"
              ).inspect}"
              Rails.logger.info "BEFORE deep_merge: @table_monitor.data['playerb']&.[]('balls_goal') = #{@table_monitor.data.dig(
                "playerb", "balls_goal"
              ).inspect}"

              @table_monitor.deep_merge_data!(attrs)
              @table_monitor.data_will_change!

              Rails.logger.info "AFTER deep_merge: @table_monitor.data['playera']&.[]('balls_goal') = #{@table_monitor.data.dig(
                "playera", "balls_goal"
              ).inspect}"
              Rails.logger.info "AFTER deep_merge: @table_monitor.data['playerb']&.[]('balls_goal') = #{@table_monitor.data.dig(
                "playerb", "balls_goal"
              ).inspect}"

              @table_monitor.assign_attributes(tournament_monitor: self)
              @table_monitor.save! # Muss save! sein, nicht save

              Rails.logger.info "AFTER SAVE: @table_monitor.data['innings_goal'] = #{@table_monitor.data["innings_goal"].inspect}"
              Rails.logger.info "AFTER SAVE: @table_monitor.data['playera']&.[]('balls_goal') = #{@table_monitor.data.dig(
                "playera", "balls_goal"
              ).inspect}"
              Rails.logger.info "AFTER SAVE: @table_monitor.data['playerb']&.[]('balls_goal') = #{@table_monitor.data.dig(
                "playerb", "balls_goal"
              ).inspect}"
              @table_monitor.reload
              Rails.logger.info "AFTER RELOAD: @table_monitor.data['innings_goal'] = #{@table_monitor.data["innings_goal"].inspect}"
              Rails.logger.info "AFTER RELOAD: @table_monitor.data['playera']&.[]('balls_goal') = #{@table_monitor.data.dig(
                "playera", "balls_goal"
              ).inspect}"
              Rails.logger.info "AFTER RELOAD: @table_monitor.data['playerb']&.[]('balls_goal') = #{@table_monitor.data.dig(
                "playerb", "balls_goal"
              ).inspect}"
            end
            @table_monitor.andand.assign_game(new_game.reload)
          elsif tournament.continuous_placements?
            @placement_candidates.push(new_game.id)
          else
            info = "+++ 8a - tournament_monitor#do_placement FAILED new_game.data:\
 #{new_game.data.inspect}, @placements: #{@placements.inspect}, new_game:\
 #{new_game.andand.attributes.inspect}, current_round: #{current_round}"
            Rails.logger.info info
          end
        end
      rescue StandardError => e
        Rails.logger.info "StandardError #{e}, #{e.backtrace&.join("\n")}"
        raise ActiveRecord::Rollback
      end
    end # transaction
  end
end
