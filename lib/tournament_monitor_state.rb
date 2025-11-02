# frozen_string_literal: true

module TournamentMonitorState
  def finalize_game_result(table_monitor)
    # "ba_results": {
    #     "Gruppe": null,
    #     "Partie": 16,
    #     "Spieler1": 228105,
    #     "Spieler2": 353803,
    #     "Ergebnis1": 0,
    #     "Ergebnis2": 0,
    #     "Aufnahmen1": 20,
    #     "Aufnahmen2": 20,
    #     "Höchstserie1": 0,
    #     "Höchstserie2": 0,
    #     "Tischnummer": 2
    # }
    game = table_monitor.game
    game.deep_merge_data!("ba_results" => table_monitor.data["ba_results"])
    game.save!
    return unless tournament.manual_assignment || tournament.continuous_placements

    update_game_participations(table_monitor)
    # noinspection RubyResolve
    table_monitor.close_match!
    args = { game_id: nil }
    args[:tournament_monitor] = nil unless tournament.continuous_placements
    table_monitor.update(args)
  end

  def all_table_monitors_finished?
    !(table_monitors.joins(:game).map(&:state) & %w[warmup warmup_a warmup_b
                                                    match_shootout playing final_set_score set_over]).present?
  end

  def finalize_round
    # TableMonitor e.g.
    # {
    #   "playera": {
    #     "result": 21,
    #     "innings": [1,0,3,2,2,0,13]
    #     "innings_count": 7,
    #     "hs": 10,
    #     "gd": "3.00",
    #     "balls_goal": 11,
    #     "innings_goal": 20
    #   },
    #   "playerb": {
    #     "result": 30,
    #     "innings": [10,0,3,2,2,0,13]
    #     "innings_count": 7,
    #     "hs": 20,
    #     "gd": "4.29",
    #     "balls_goal": 80,
    #     "innings_goal": 20
    #   },
    #   "current_inning": {
    #     "active_player": "playera",
    #     "balls": 0
    #   },
    # }
    # finalize gameParticipation data
    #
    # "results": {
    #     "Gr.": "Satz 1",
    #     "Ergebnis": 50,
    #     "Aufnahme": 32,
    #     "GD": 1.56,
    #     "HS": 6
    # }
    table_monitors.joins(:game).each do |tabmon|
      game = tabmon.game
      next unless game.present? && game.data.present?

      update_game_participations(tabmon)
      # noinspection RubyResolve
      tabmon.close_match!
    end
    accumulate_results
  end

  def group_phase_finished?
    n_group_games = tournament.games.where("games.id >= #{Game::MIN_ID}")
                              .where("gname ilike 'group%'")
                              .count
    n_group_games_done = tournament.games
                                   .where("games.id >= #{Game::MIN_ID}")
                                   .where("gname ilike 'group%'")
                                   .where.not(ended_at: nil)
                                   .count
    n_group_games == n_group_games_done
  end

  def finals_finished?
    executor_params = JSON.parse(tournament.tournament_plan.executor_params)
    n_games = executor_params["GK"] || tournament.games.where("games.id >= #{Game::MIN_ID}").count
    n_games_done = tournament.games.where("games.id >= #{Game::MIN_ID}").where.not(ended_at: nil).count
    n_games == n_games_done
  end

  def table_monitors_ready?
    Tournament.logger.info "[tmon-table_monitors_ready]..."
    # noinspection RubyResolve
    res = table_monitors.inject(true) do |memo, tm|
      memo = memo && tm.ready? || tm.ready_for_new_match? || tm.playing?
      memo.presence
    end
    Tournament.logger.info "returns #{res}...[tmon-table_monitors_ready]"
    res
  end

  def do_reset_tournament_monitor
    return nil if tournament.blank?

    Tournament.logger.info "[tmon-reset_tournament_monitor]..."
    update(
      sets_to_play: tournament.andand.sets_to_play.presence || 1,
      sets_to_win: tournament.andand.sets_to_win.presence || 1,
      team_size: tournament.andand.team_size.presence || 1,
      kickoff_switches_with: tournament.andand.kickoff_switches_with,
      allow_follow_up: tournament.andand.allow_follow_up,
      fixed_display_left: tournament.andand.fixed_display_left || "",
      color_remains_with_set: tournament.andand.color_remains_with_set
    )
    tournament.games.where("games.id >= #{Game::MIN_ID}").destroy_all
    # table_monitors.destroy_all
    update(data: {}) unless new_record?
    @tournament_plan ||= tournament.tournament_plan
    if @tournament_plan.present?
      initialize_table_monitors unless tournament.manual_assignment
      
      # Intelligentes seeding_scope: Lokale Seedings bevorzugen, sonst ClubCloud
      has_local_seedings = tournament.seedings.where("seedings.id >= #{Seeding::MIN_ID}").any?
      
      # Debug: Logging der verwendeten Seedings
      if has_local_seedings
        seedings_query = tournament.seedings.where.not(state: "no_show").where("seedings.id >= ?", Seeding::MIN_ID).order(:position)
      else
        seedings_query = tournament.seedings.where.not(state: "no_show").where("seedings.id < ?", Seeding::MIN_ID).order(:position)
      end
      
      seedings_count = seedings_query.count
      Tournament.logger.info "[tmon-reset_tournament_monitor] Seedings: #{seedings_count} (has_local: #{has_local_seedings})"
      Tournament.logger.info "[tmon-reset_tournament_monitor] Seedings IDs: #{seedings_query.pluck(:id).join(', ')}"
      
      if seedings_count == 0
        error_msg = "Keine Seedings gefunden (has_local: #{has_local_seedings})"
        Tournament.logger.error "[tmon-reset_tournament_monitor] ERROR: #{error_msg}"
        deep_merge_data!("error" => error_msg)
        save!
        return { "ERROR" => error_msg }
      end
      
      # Validiere dass TournamentPlan zur Spieleranzahl passt
      if @tournament_plan.players != seedings_count
        error_msg = "TournamentPlan #{@tournament_plan.name} passt nicht: erwartet #{@tournament_plan.players} Spieler, aber #{seedings_count} gefunden. Bitte wählen Sie den richtigen TournamentPlan (z.B. T21 für 11 Spieler)."
        Tournament.logger.error "[tmon-reset_tournament_monitor] ERROR: #{error_msg}"
        deep_merge_data!("error" => error_msg)
        save!
        return { "ERROR" => error_msg }
      end
      
      @groups = TournamentMonitor.distribute_to_group(
        seedings_query.map(&:player), 
        @tournament_plan.andand.ngroups.to_i,
        @tournament_plan.group_sizes  # NEU: Gruppengrößen aus executor_params
      )
      
      Tournament.logger.info "[tmon-reset_tournament_monitor] Gruppen berechnet: #{@groups.keys.map { |k| "#{k}: #{@groups[k].count}" }.join(', ')}"
      
      @placements = {}
      current_round!(1)
      deep_merge_data!("groups" => @groups, "placements" => @placements)
      save!
      
      # Prüfe ob executor_params vorhanden ist
      unless @tournament_plan.executor_params.present?
        error_msg = "executor_params is empty for TournamentPlan #{@tournament_plan.name}"
        Tournament.logger.warn "[tmon-reset_tournament_monitor] WARNING: #{error_msg}"
        deep_merge_data!("error" => error_msg)
        save!
        return { "ERROR" => error_msg }
      end
      
      begin
        executor_params = JSON.parse(@tournament_plan.executor_params)
        Tournament.logger.info "[tmon-reset_tournament_monitor] executor_params: #{executor_params.inspect}"
      rescue JSON::ParserError => e
        error_msg = "Failed to parse executor_params: #{e.message}"
        Tournament.logger.error "[tmon-reset_tournament_monitor] ERROR: #{error_msg}"
        deep_merge_data!("error" => error_msg)
        save!
        return { "ERROR" => error_msg }
      end
      groups_must_be_played = false
      executor_params.each_key do |k|
        next unless (m = k.match(/g(\d+)/))

        groups_must_be_played = true
        group_no = m[1].to_i
        expected_count = executor_params[k]["pl"].to_i
        actual_count = @groups["group#{group_no}"].count
        if actual_count != expected_count
          error_msg = "Group Count Mismatch: Gruppe #{group_no} hat #{actual_count} Spieler, aber executor_params erwartet #{expected_count}. TournamentPlan #{@tournament_plan.name} passt möglicherweise nicht zur Spieleranzahl (#{seedings_count})."
          Tournament.logger.error "[tmon-reset_tournament_monitor] ERROR: #{error_msg}"
          deep_merge_data!("error" => error_msg)
          save!
          return { "ERROR" => error_msg }
        end

        repeats = executor_params[k]["rp"].presence || 1
        rule_system = executor_params[k]["rs"]
        Tournament.logger.info "[tmon-reset_tournament_monitor] Gruppe #{group_no}: repeats=#{repeats}, rule_system=#{rule_system.inspect}, players=#{actual_count}"
        
        # rule_system könnte ein String oder Array sein
        rule_system_str = rule_system.is_a?(Array) ? rule_system.first : rule_system.to_s
        
        unless rule_system_str.present? && /^eae/.match?(rule_system_str)
          Tournament.logger.warn "[tmon-reset_tournament_monitor] WARNING: Gruppe #{group_no} hat rule_system '#{rule_system.inspect}' (#{rule_system_str}), das nicht mit /^eae/ übereinstimmt. Spiele werden übersprungen."
          next
        end

        (1..repeats).each do |rp|
          (1..@groups["group#{group_no}"].count).to_a.permutation(2).to_a.select { |v1, v2| v1 < v2 }.each do |a|
            i1, i2 = a
            player1_id = @groups["group#{group_no}"][i1 - 1]
            player2_id = @groups["group#{group_no}"][i2 - 1]
            
            unless player1_id.present? && player2_id.present?
              error_msg = "ERROR: Gruppe #{group_no}, Spiel #{i1}-#{i2}: Spieler-ID fehlt (player1: #{player1_id}, player2: #{player2_id})"
              Tournament.logger.error "[tmon-reset_tournament_monitor] #{error_msg}"
              deep_merge_data!("error" => error_msg)
              save!
              return { "ERROR" => error_msg }
            end
            
            begin
              gname = "group#{group_no}:#{i1}-#{i2}#{"/#{rp}" if repeats > 1}"
              Tournament.logger.info "[tmon-reset_tournament_monitor] NEW GAME #{gname} (player1_id: #{player1_id}, player2_id: #{player2_id})"
              game = tournament.games.create(gname: gname, group_no: group_no)
              
              unless game.persisted?
                error_msg = "ERROR: Spiel konnte nicht erstellt werden: #{game.errors.full_messages.join(', ')}"
                Tournament.logger.error "[tmon-reset_tournament_monitor] #{error_msg}"
                deep_merge_data!("error" => error_msg)
                save!
                return { "ERROR" => error_msg }
              end
              
              # @groups now contains player IDs, not player objects
              gp1 = game.game_participations.create(player_id: player1_id, role: "playera")
              gp2 = game.game_participations.create(player_id: player2_id, role: "playerb")
              
              unless gp1.persisted? && gp2.persisted?
                error_msg = "ERROR: GameParticipations konnten nicht erstellt werden: gp1.errors=#{gp1.errors.full_messages.join(', ')}, gp2.errors=#{gp2.errors.full_messages.join(', ')}"
                Tournament.logger.error "[tmon-reset_tournament_monitor] #{error_msg}"
                deep_merge_data!("error" => error_msg)
                save!
                return { "ERROR" => error_msg }
              end
            rescue StandardError => e
              error_msg = "ERROR beim Erstellen des Spiels group#{group_no}:#{i1}-#{i2}: #{e.message}"
              Tournament.logger.error "[tmon-reset_tournament_monitor] #{error_msg}"
              Tournament.logger.error "[tmon-reset_tournament_monitor] Backtrace: #{e.backtrace&.join("\n")}"
              deep_merge_data!("error" => error_msg)
              save!
              return { "ERROR" => error_msg }
            end
          end
        end
      end
      
      games_count = tournament.games.where("games.id >= #{Game::MIN_ID}").count
      Tournament.logger.info "[tmon-reset_tournament_monitor] Spiele erstellt: #{games_count}"
      
      if groups_must_be_played && games_count == 0
        error_msg = "ERROR: Keine Spiele erstellt, obwohl groups_must_be_played=true ist. Möglicherweise stimmt das rule_system (rs) in executor_params nicht mit /^eae/ überein."
        Tournament.logger.error "[tmon-reset_tournament_monitor] #{error_msg}"
        deep_merge_data!("error" => error_msg)
        save!
        return { "ERROR" => error_msg }
      end
      
      # noinspection RubyResolve
      start_playing_finals! unless groups_must_be_played
      populate_tables unless tournament.manual_assignment
      reload
      # noinspection RubyResolve
      tournament.reload.signal_tournament_monitors_ready!
      # noinspection RubyResolve
      start_playing_groups! if groups_must_be_played
      Tournament.logger.info "...[tmon-reset_tournament_monitor] tournament.state:\
 #{tournament.state} tournament_monitor.state: #{state}"
    else
      error_msg = "[tmon-reset_tournament_monitor] ERROR MISSING TOURNAMENT_PLAN"
      Tournament.logger.info "...#{error_msg}"
      deep_merge_data!("error" => error_msg)
      save!
      return { "ERROR" => error_msg }
    end
    true
  rescue StandardError => e
    error_msg = "ERROR: #{e.message}"
    Tournament.logger.error "[tmon-reset_tournament_monitor] #{error_msg}"
    Tournament.logger.error "[tmon-reset_tournament_monitor] Backtrace: #{e.backtrace&.join("\n")}"
    deep_merge_data!("error" => error_msg)
    save!
    return { "ERROR" => error_msg }
  end
end
