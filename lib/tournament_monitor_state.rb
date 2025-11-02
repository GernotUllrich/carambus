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
        Tournament.logger.error "[tmon-reset_tournament_monitor] ERROR: Keine Seedings gefunden!"
        return { "ERROR" => "Keine Seedings gefunden (has_local: #{has_local_seedings})" }
      end
      
      # Validiere dass TournamentPlan zur Spieleranzahl passt
      if @tournament_plan.players != seedings_count
        Tournament.logger.error "[tmon-reset_tournament_monitor] ERROR: TournamentPlan #{@tournament_plan.name} erwartet #{@tournament_plan.players} Spieler, aber #{seedings_count} gefunden!"
        return { "ERROR" => "TournamentPlan #{@tournament_plan.name} passt nicht: erwartet #{@tournament_plan.players} Spieler, aber #{seedings_count} gefunden. Bitte wählen Sie den richtigen TournamentPlan (z.B. T21 für 11 Spieler)." }
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
        Tournament.logger.warn "[tmon-reset_tournament_monitor] WARNING: executor_params is empty for TournamentPlan[#{@tournament_plan.id}]"
        return { "ERROR" => "executor_params is empty for TournamentPlan #{@tournament_plan.name}" }
      end
      
      begin
        executor_params = JSON.parse(@tournament_plan.executor_params)
      rescue JSON::ParserError => e
        Tournament.logger.error "[tmon-reset_tournament_monitor] ERROR parsing executor_params: #{e.message}"
        return { "ERROR" => "Failed to parse executor_params: #{e.message}" }
      end
      groups_must_be_played = false
      executor_params.each_key do |k|
        next unless (m = k.match(/g(\d+)/))

        groups_must_be_played = true
        group_no = m[1].to_i
        expected_count = executor_params[k]["pl"].to_i
        actual_count = @groups["group#{group_no}"].count
        if actual_count != expected_count
          Tournament.logger.error "[tmon-reset_tournament_monitor] ERROR: Group #{group_no} Count Mismatch: #{actual_count} vs. #{expected_count} (executor_params)"
          return { "ERROR" => "Group Count Mismatch: Gruppe #{group_no} hat #{actual_count} Spieler, aber executor_params erwartet #{expected_count}. TournamentPlan #{@tournament_plan.name} passt möglicherweise nicht zur Spieleranzahl (#{seedings_count})." }
        end

        repeats = executor_params[k]["rp"].presence || 1
        (1..repeats).each do |rp|
          next unless /^eae/.match?(executor_params[k]["rs"])

          (1..@groups["group#{group_no}"].count).to_a.permutation(2).to_a.select { |v1, v2| v1 < v2 }.each do |a|
            i1, i2 = a
            Tournament.logger.info "NEW GAME group#{group_no}:#{i1}-#{i2}#{"/#{rp}" if repeats > 1}"
            game = tournament.games.create(gname: "group#{group_no}:#{i1}-#{i2}#{"/#{rp}" if repeats > 1}",
                                           group_no: group_no)
            # @groups now contains player IDs, not player objects
            game.game_participations.create(player_id: @groups["group#{group_no}"][i1 - 1], role: "playera")
            game.game_participations.create(player_id: @groups["group#{group_no}"][i2 - 1], role: "playerb")
          end
        end
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
      Tournament.logger.info "...[tmon-reset_tournament_monitor] ERROR MISSING TOURNAMENT_PLAN"
      return { "ERROR" => "...[tmon-reset_tournament_monitor] ERROR MISSING TOURNAMENT_PLAN" }
    end
    true
  rescue StandardError => e
    Rails.logger.info "ERROR: #{e}, #{e.backtrace&.join("\n")}"
  end
end
