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
    
    # SCHUTZ: Prüfe ob finalize_game_result bereits aufgerufen wurde
    # (kann passieren wenn finish_match! mehrfach aufgerufen wird)
    if game.data["finalized_at"].present?
      finalized_at = Time.parse(game.data["finalized_at"]) rescue nil
      if finalized_at && finalized_at > 1.minute.ago
        Rails.logger.warn "[TournamentMonitorState] ⊘ Skipping finalize_game_result for game[#{game.id}] - already finalized at #{finalized_at.strftime('%H:%M:%S')}"
        return
      end
    end
    
    # Markiere als finalisiert
    game.deep_merge_data!(
      "ba_results" => table_monitor.data["ba_results"],
      "finalized_at" => Time.current.iso8601
    )
    game.save!

    # Automatische Übertragung in die ClubCloud
    if tournament.tournament_cc.present? && tournament.auto_upload_to_cc?
      Rails.logger.info "[TournamentMonitorState] Attempting ClubCloud upload for game[#{game.id}]..."
      result = Setting.upload_game_to_cc(table_monitor)
      if result[:success]
        if result[:dry_run]
          Rails.logger.info "[TournamentMonitorState] 🧪 ClubCloud upload DRY RUN completed for game[#{game.id}] (development mode)"
        elsif result[:skipped]
          Rails.logger.info "[TournamentMonitorState] ⊘ ClubCloud upload skipped for game[#{game.id}] (already uploaded)"
        else
          Rails.logger.info "[TournamentMonitorState] ✓ ClubCloud upload successful for game[#{game.id}]"
        end
      else
        Rails.logger.warn "[TournamentMonitorState] ✗ ClubCloud upload failed for game[#{game.id}]: #{result[:error]}"
        # Fehler ist bereits in tournament.data["cc_upload_errors"] geloggt
        # Nicht weiterwerfen, damit finalize_game_result nicht fehlschlägt
      end
    end

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
      # WICHTIG: Wenn bereits gesetzt (vom Controller), NICHT überschreiben!
      innings_goal: self.innings_goal || tournament.andand.innings_goal,
      balls_goal: self.balls_goal || tournament.andand.balls_goal,
      timeout: self.timeout || tournament.andand.timeout || 0,
      timeouts: self.timeouts || tournament.andand.timeouts || 0,
      kickoff_switches_with: self.kickoff_switches_with || tournament.andand.kickoff_switches_with,
      allow_follow_up: self.allow_follow_up.nil? ? tournament.andand.allow_follow_up : self.allow_follow_up,
      allow_overflow: self.allow_overflow || tournament.andand.allow_overflow || false,
      fixed_display_left: self.fixed_display_left.presence || tournament.andand.fixed_display_left || "",
      color_remains_with_set: self.color_remains_with_set.nil? ? tournament.andand.color_remains_with_set : self.color_remains_with_set
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

      # Validiere executor_params: Prüfe ob Tische mehrfach in derselben Runde verwendet werden
      table_usage = {} # { "r1" => { "t1" => ["g1", "g2"], ... }, ... }
      executor_params.each_key do |k|
        next unless (m = k.match(/g(\d+)/))
        group_no = m[1].to_i
        sequence = executor_params[k]["sq"]
        next unless sequence.present? && sequence.is_a?(Hash)

        sequence.each do |round_key, round_data|
          next unless round_key.is_a?(String) && round_key.match?(/^r\d+/)
          next unless round_data.is_a?(Hash)

          table_usage[round_key] ||= {}
          round_data.each do |tno_str, game_pair|
            next unless tno_str.is_a?(String) && tno_str.match?(/^t\d+/)
            table_usage[round_key][tno_str] ||= []
            table_usage[round_key][tno_str] << "g#{group_no}"
          end
        end
      end

      # Prüfe auf mehrfache Verwendung
      validation_errors = []
      table_usage.each do |round_key, tables|
        tables.each do |tno_str, groups|
          if groups.length > 1
            validation_errors << "#{round_key}: #{tno_str} wird mehrfach verwendet (Gruppen: #{groups.join(', ')})"
          end
        end
      end

      if validation_errors.any?
        error_msg = "executor_params Inkonsistenz: Tische werden mehrfach in derselben Runde verwendet:\n" + validation_errors.join("\n")
        Tournament.logger.error "[tmon-reset_tournament_monitor] ERROR: #{error_msg}"
        deep_merge_data!("error" => error_msg)
        save!
        return { "ERROR" => error_msg }
      end

      Tournament.logger.info "[tmon-reset_tournament_monitor] executor_params Validierung erfolgreich: Keine Tisch-Konflikte gefunden"

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
        sequence = executor_params[k]["sq"] # Reihenfolge der Spiele
        Tournament.logger.info "[tmon-reset_tournament_monitor] Gruppe #{group_no}: repeats=#{repeats}, rule_system=#{rule_system.inspect}, players=#{actual_count}, sequence=#{sequence.inspect}"

        # rule_system könnte ein String oder Array sein
        rule_system_str = rule_system.is_a?(Array) ? rule_system.first : rule_system.to_s

        unless rule_system_str.present? && /^eae/.match?(rule_system_str)
          Tournament.logger.warn "[tmon-reset_tournament_monitor] WARNING: Gruppe #{group_no} hat rule_system '#{rule_system.inspect}' (#{rule_system_str}), das nicht mit /^eae/ übereinstimmt. Spiele werden übersprungen."
          next
        end

        # Wenn sq vorhanden ist: Verwende die definierte Reihenfolge
        # Sonst: Erstelle alle Permutationen
        games_to_create = []
        if sequence.present?
          if sequence.is_a?(Hash)
            # Extrahiere alle Spiel-Paare aus sq (z.B. "1-2", "1-3", etc.)
            sequence.each do |round_key, round_data|
              next unless round_key.is_a?(String) && round_key.match?(/^r\d+/)
              next unless round_data.is_a?(Hash)
              round_data.each do |tno_str, game_pair|
                if game_pair.is_a?(String) && /(\d+)-(\d+)/.match?(game_pair)
                  games_to_create << game_pair
                end
              end
            end
          elsif sequence.is_a?(Array)
            # Falls sq ein Array ist (seltener Fall)
            sequence.each do |game_pair|
              if game_pair.is_a?(String) && /(\d+)-(\d+)/.match?(game_pair)
                games_to_create << game_pair
              end
            end
          end
          # füge weitere Spiele der Permutation hinzu für den Fall dynamisch generierter Paarungen
          if  rule_system == "eae_pg"
            (1..@groups["group#{group_no}"].count).to_a.permutation(2).to_a.select { |v1, v2| v1 < v2 }.each do |a|
              games_to_create << "#{a[0]}-#{a[1]}" unless games_to_create.include?("#{a[0]}-#{a[1]}")
            end
          end
          games_to_create.uniq!
          Tournament.logger.info "[tmon-reset_tournament_monitor] Gruppe #{group_no}: Verwendet sq-Sequenz: #{games_to_create.inspect}"
        end

        # Wenn keine Sequenz vorhanden: Erstelle alle Permutationen
        if games_to_create.empty?
          (1..@groups["group#{group_no}"].count).to_a.permutation(2).to_a.select { |v1, v2| v1 < v2 }.each do |a|
            games_to_create << "#{a[0]}-#{a[1]}"
          end
          Tournament.logger.info "[tmon-reset_tournament_monitor] Gruppe #{group_no}: Keine sq-Sequenz, erstelle alle Permutationen: #{games_to_create.inspect}"
        end

        (1..repeats).each do |rp|
          games_to_create.each do |game_pair|
            match = game_pair.match(/(\d+)-(\d+)/)
            next unless match
            i1 = match[1].to_i
            i2 = match[2].to_i
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

      # Vorbereitung des GroupCc Mappings für ClubCloud (nur wenn tournament_cc vorhanden)
      begin
        if tournament.tournament_cc.present?
          Tournament.logger.info "[tmon-reset_tournament_monitor] Preparing GroupCc mapping for ClubCloud..."
          opts = RegionCcAction.get_base_opts_from_environment
          group_cc = tournament.tournament_cc.prepare_group_mapping(opts)
          if group_cc
            Tournament.logger.info "[tmon-reset_tournament_monitor] GroupCc mapping prepared: GroupCc[#{group_cc.id}]"

            # Validiere Mapping
            validation = tournament.tournament_cc.validate_game_gname_mapping
            if validation[:missing].any?
              Tournament.logger.warn "[tmon-reset_tournament_monitor] WARNING: #{validation[:missing].count} game.gname patterns could not be mapped to ClubCloud group names"
              validation[:missing].each do |missing|
                Tournament.logger.warn "[tmon-reset_tournament_monitor] Missing mapping: #{missing[:gname]} (mapped to: #{missing[:cc_name]})"
              end
            else
              Tournament.logger.info "[tmon-reset_tournament_monitor] All #{validation[:total]} game.gname patterns successfully mapped to ClubCloud"
            end
          else
            Tournament.logger.warn "[tmon-reset_tournament_monitor] Could not prepare GroupCc mapping (no group options found)"
          end
        end
      rescue StandardError => e
        Tournament.logger.error "[tmon-reset_tournament_monitor] Error preparing GroupCc mapping: #{e.message}"
        Tournament.logger.error "[tmon-reset_tournament_monitor] Backtrace: #{e.backtrace&.join("\n")}"
        # Fehler nicht weiterwerfen, damit reset_tournament_monitor nicht fehlschlägt
      end

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
