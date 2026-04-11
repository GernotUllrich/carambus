# frozen_string_literal: true

module TournamentMonitorSupport
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
        if tournament.tournament_plan&.name&.match?(/^(KO|DKO)/)
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
                    @placement_candidates.push([game_a.id, game_a.gname, r_no, t_no, sets, balls, innings])
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
                    @placement_candidates.push([game_b.id, game_b.gname, r_no, t_no, sets, balls, innings])
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
                    @placement_candidates.push([game.id, game.gname, r_no, t_no, sets, balls, innings])
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
                    @placement_candidates.push([game.id, game.gname, r_no, t_no, sets, balls, innings])
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
                      @placement_candidates.push([game.id, game.gname, r_no, t_no, sets, balls, innings])
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
                        @placement_candidates.push([game.id, game.gname, r_no, t_no, sets, balls, innings])
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
                          @placement_candidates.push([game.id, game.gname, r_no, t_no, sets, balls, innings])
                        else
                          do_placement(game, r_no, t_no, sets, balls, innings)
                        end
                      end
                    end
                  end
                end
              end
            end
          elsif /(?:64f|32f|16f|8f|vf|hf|af|qf|fin|p<\d+(?:\.\.|-)\d+>)(\d+)?/.match?(k)
            r_no = executor_params[k].keys.find { |kk| kk =~ /r[*\d+]/ }.match(/r([*\d+])/)[1].to_i
            is_ko_plan = tournament.tournament_plan&.name&.match?(/^(KO|DKO)/)
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
              elsif tno_str == "t-rand*"
                # Find next available table for t-rand* pattern
                available_tables = if table_ids.is_a?(Array)
                                     if table_ids.first.is_a?(Array)
                                       table_ids[r_no - 1]&.length || table_ids.first.length
                                     else
                                       table_ids.length
                                     end
                                   else
                                     tournament.tournament_plan&.tables.to_i > 0 ? tournament.tournament_plan.tables : 4
                                   end
                
                # Find first free table in this round
                (1..available_tables).each do |check_t_no|
                  if @placements.andand["round#{r_no}"].andand["table#{check_t_no}"].blank?
                    t_no = check_t_no
                    Tournament.logger.info "+++012C t-rand* assigned to table #{t_no} for game #{k}"
                    break
                  end
                end
                
                unless t_no.present?
                  Tournament.logger.warn "+++012C-WARN No free table found for t-rand* game #{k} in round #{r_no}"
                end
              end
              Tournament.logger.info "+++012D k,v = [#{k} => #{executor_params[k].inspect}] find or create game #{k}"
              game = tournament.games.where("games.id >= #{Game::MIN_ID}").find_or_create_by(gname: k)
              # game.game_participations = []
              game.save
        ("a".."b").each_with_index do |pl_no, ix|
          rule_str = players[ix]
          player_id = player_id_from_ranking(rule_str, executor_params: executor_params,
                                                       ordered_ranking_nos: ordered_ranking_nos)
          # Always create game_participation, even if player_id is nil (will be updated later)
          gp = game.game_participations.where(role: "player#{pl_no}").first
          if gp
            # Update existing participation
            # Store rule_str for later winner resolution
            gp.data ||= {}
            gp.data["rule_str"] = rule_str
            gp.data_will_change!
            gp.player_id = player_id if player_id.present? && gp.player_id != player_id
            gp.save! if gp.changed?
          else
            # Create new participation with rule_str stored in data
            game.game_participations.create!(
              player_id: player_id, 
              role: "player#{pl_no}",
              data: { "rule_str" => rule_str }
            )
          end
        end
              reload
              # Skip placement if game is already placed OR if game is already finished
              # For KO tournaments: Also skip if not all players are known yet
              all_players_known = game.game_participations.reload.all? { |gp| gp.player_id.present? }
              unless @placements_done.include?(game.id) || game.ended_at.present? || (is_ko_plan && !all_players_known)
                if t_no.present?
                  Tournament.logger.info "+++016 do_placement(game = #{game.attributes.inspect},\
 r_no = #{r_no}, t_no = #{t_no})"
                  if tournament.continuous_placements
                    @placement_candidates.push([game.id, game.gname, r_no, t_no, sets, balls, innings])
                  else
                    do_placement(game, r_no, t_no, sets, balls, innings)
                  end
                end
                # Note: t-rand* is now handled above by setting t_no, so no separate handling needed
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
          # Use safe handling for pc elements as some legacy items might just be integers.
          @placement_candidates.sort_by { |pc| [pc.is_a?(Array) ? pc[1].to_s : Game[pc].gname] }.each_with_index do |placement_candidate, ix|
            game_params = placement_candidate.is_a?(Array) ? placement_candidate : [placement_candidate]
            game = Game[game_params[0]]
            required_players = game.game_participations.map(&:player_id)
            next if (required_players & current_players).present?

            current_players += required_players
            next_available_table = table_monitors.where(game_id: nil).to_a.sample&.table
            next unless next_available_table.present?

            t_no = table_ids.index(next_available_table.id) + 1
            if game_params.length >= 7
              do_placement(game, current_round, t_no, game_params[4], game_params[5], game_params[6])
            else
              do_placement(game, current_round, t_no, nil, nil, nil)
            end
            
            @placement_candidates.delete_at(ix)
            found = true
            break if found
          end
          # Prevent infinite loop if no more candidates can be placed
          break unless found
        end
      end
      # Update game_participations with resolved player_ids for KO tournaments
      # This is needed when games finish and winners need to be assigned to next round
      if tournament.tournament_plan&.name&.match?(/^(KO|DKO)/)
        Tournament.logger.info "[tmon-populate_tables] Updating KO game participations with resolved player_ids..."
        
        # CRITICAL: Ensure rankings are up to date first (needed for player_id_from_ranking)
        accumulate_results
        reload
        
        updated_count = 0
        
        # Find all game_participations that are waiting for player assignment
        # (have rule_str stored but player_id is nil)
        tournament.games.where("games.id >= #{Game::MIN_ID}").includes(:game_participations).each do |game|
          game.game_participations.where(player_id: nil).each do |gp|
            # Get the stored rule_str (e.g., "16f1.rk1")
            rule_str = gp.data&.[]("rule_str")
            next unless rule_str.present?
            
            # Try to resolve the player_id now that more games may have finished
            player_id = player_id_from_ranking(rule_str, executor_params: executor_params,
                                                         ordered_ranking_nos: ordered_ranking_nos)
            if player_id.present?
              gp.update(player_id: player_id)
              updated_count += 1
              Tournament.logger.info "[tmon-populate_tables] Updated #{game.gname} #{gp.role}: #{rule_str} → Player[#{player_id}]"
            end
          end
        end
        
        Tournament.logger.info "[tmon-populate_tables] Updated #{updated_count} game participations with resolved player_ids"
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

          # Wenn vorgesehener Tisch belegt ist: Suche freien Tisch
          if t_no.to_i.positive? && current_round == r_no && new_game.present? &&
             @placements.andand["round#{r_no}"].andand["table#{t_no}"].present? &&
             !tournament.continuous_placements
            Tournament.logger.warn "[do_placement] Tisch #{t_no} bereits belegt in Runde #{r_no}, suche freien Tisch..."

            # Finde ersten freien Tisch
            # Bestimme Anzahl verfügbarer Tische
            available_tables = if table_ids.is_a?(Array)
                                 # table_ids könnte ein Array von Arrays sein (pro Runde) oder ein flaches Array
                                 if table_ids.first.is_a?(Array)
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
              next unless @placements.andand["round#{r_no}"].andand["table#{check_t_no}"].blank?

              t_no = check_t_no
              Rails.logger.info "[do_placement] Gefundener freier Tisch: #{t_no} (ursprünglich #{original_t_no})"
              break
            end

            unless t_no.present?
              Tournament.logger.error "[do_placement] ERROR: Kein freier Tisch gefunden in Runde #{r_no} für Spiel #{new_game.gname} (verfügbar: #{available_tables} Tische)"
              return
            end
          end

          Rails.logger.info ">>>>> CHECK 2: t_no=#{t_no}, current_round=#{current_round}, r_no=#{r_no}, continuous=#{tournament.continuous_placements}"
          if t_no.to_i.positive? &&
             ((current_round == r_no &&
               new_game.present? &&
               @placements.andand["round#{r_no}"].andand["table#{t_no}"].blank?) || tournament.continuous_placements)

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
              # PRIORITÄT: executor_params > Formular (tournament_monitor) > Tournament > Seeding
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

              attrs["innings_goal"] = innings.presence || innings_goal || tournament.innings_goal

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
                  balls.presence || seeding_a&.balls_goal&.presence || balls_goal || tournament.balls_goal
                attrs["playerb"] = {}
                attrs["playerb"]["balls_goal"] =
                  balls.presence || seeding_b&.balls_goal&.presence || balls_goal || tournament.balls_goal
              else
                # Bei normalen Turnieren: Einheitliches balls_goal für beide Spieler
                attrs["playera"] = {}
                attrs["playera"]["balls_goal"] = balls.presence || balls_goal || tournament.balls_goal
                attrs["playerb"] = {}
                attrs["playerb"]["balls_goal"] = balls.presence || balls_goal || tournament.balls_goal
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
            @placement_candidates.push([new_game.id, new_game.gname, r_no, t_no, sets, balls, innings])
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
