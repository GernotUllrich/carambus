# frozen_string_literal: true

# Verarbeitet Spielergebnisse im TournamentMonitor-Kontext.
# Extrahiert aus TournamentMonitorSupport und TournamentMonitorState als PORO (kein ApplicationService),
# da mehrere öffentliche Eintrittspunkte existieren (kein einzelnes `call`).
#
# Verantwortlichkeiten:
#   - report_result: Haupteinstiegspunkt für Ergebnismeldungen (mit DB-Pessimistic-Lock)
#   - write_game_result_data: Schreibt TableMonitor-Daten in Game (innerhalb Lock)
#   - finalize_game_result: ClubCloud-Upload, GameParticipation-Updates, KO-Cleanup
#   - accumulate_results: Aggregiert Spielergebnisse in Rankings (PUBLIC — auch von TablePopulator genutzt)
#   - update_ranking: Berechnet Endranking aus executor_params RK-Regeln (PUBLIC)
#   - update_game_participations: Delegiert an update_game_participations_for_game (PUBLIC)
#
# DB-Lock-Scope (D-01, T-15-01): game.with_lock umfasst exakt 4 Operationen —
#   table_monitor.reload, game.reload, write_game_result_data, game.reload, table_monitor.reload, finish_match!
#   Alles andere läuft außerhalb des Locks.
#
# AASM-Events (D-02): Alle AASM-Events werden auf @tournament_monitor gefeuert, NICHT auf self.
#
# Verwendung:
#   TournamentMonitor::ResultProcessor.new(tournament_monitor).report_result(table_monitor)
#   TournamentMonitor::ResultProcessor.new(tournament_monitor).accumulate_results
class TournamentMonitor::ResultProcessor
  def initialize(tournament_monitor)
    @tournament_monitor = tournament_monitor
  end

  # Haupteinstiegspunkt: Meldet ein Spielergebnis und verarbeitet die gesamte Pipeline.
  # DB-Pessimistic-Lock auf Game für atomare Datenschreibung + State-Transition.
  # PUBLIC
  def report_result(table_monitor)
    Rails.logger.info "[report_result] START for TM #{table_monitor.id}, game=#{table_monitor.game&.gname}"
    TournamentMonitor.transaction do
      try do
        game = table_monitor.game

        # CRITICAL FIX: Wrap data writing and state transition in a pessimistic lock
        # This prevents race condition where:
        # 1. Thread A reads game.data (sees old data)
        # 2. Thread B writes game.data and transitions state
        # 3. Thread A writes game.data (overwrites B's data)
        # 4. Thread A transitions state (triggers broadcast with wrong data)
        #
        # With the lock, the sequence becomes atomic:
        # 1. Thread A acquires lock
        # 2. Thread A writes data + transitions state
        # 3. Thread A releases lock
        # 4. Thread B acquires lock (sees new state, skips via idempotency check)

        if game.present? && table_monitor.may_finish_match?
          Rails.logger.info "🔒 [TournamentMonitorSupport#report_result] Acquiring lock for Game[#{game.id}]..."

          game.with_lock do
            # Reload to get latest state inside lock
            table_monitor.reload
            game.reload

            # Step 1: Write game data (idempotent, has guards)
            write_game_result_data(table_monitor)

            # CRITICAL: Reload BOTH game and table_monitor to clear ALL cached associations
            # The AASM callback reads table_monitor.game, so we must reload table_monitor
            # to ensure the game association is fresh and the callback sees the new data
            game.reload
            table_monitor.reload  # This refreshes table_monitor.game association!

            # Step 2: Transition state (triggers ActionCable broadcast)
            # By doing this AFTER data write, the broadcast will see correct data
            if table_monitor.may_finish_match?
              Rails.logger.info "🔒 [TournamentMonitorSupport#report_result] Calling finish_match! inside lock"
              table_monitor.finish_match!
            end
          end

          Rails.logger.info "✅ [TournamentMonitorSupport#report_result] Lock released for Game[#{game.id}], data written + state transitioned"
        end

        # Step 3: Finalize (ClubCloud upload, game participations, etc.)
        # This happens OUTSIDE the lock to avoid long lock duration
        Rails.logger.info "[report_result] Calling finalize_game_result for TM #{table_monitor.id}"
        finalize_game_result(table_monitor)

        # Phase 38.8 — round-progression cascade DEFERRED. Previously this
        # block ran (accumulate_results -> all_table_monitors_finished? gate ->
        # populate_tables / incr_current_round! / finalize_round / etc.)
        # immediately after finish_match!, clobbering the "Endergebnis erfasst"
        # display before the operator could see it.
        #
        # New flow: TM stays in :final_match_score after this method returns.
        # Operator clicks "Weiter"/"Continue" -> reflex fires close_match! ->
        # AASM after-callback `advance_tournament_round_if_present` (defined
        # in table_monitor.rb) calls advance_round_after_match_close below.
        #
        # Cascade extracted verbatim into advance_round_after_match_close —
        # no behavior changes, only deferred timing.
      rescue StandardError => e
        Rails.logger.info "StandardError #{e}, #{e.backtrace&.join("\n")}"
        raise ActiveRecord::Rollback
      end
    end
  end

  # Phase 38.8 — Deferred round-progression cascade. Extracted verbatim from
  # report_result so the cascade fires AFTER the operator has seen
  # :final_match_score ("Endergebnis erfasst") and explicitly triggered
  # close_match!. Wired from TableMonitor AASM close_match event via
  # `advance_tournament_round_if_present` after-callback.
  #
  # NOT idempotent — intended to be called exactly once per operator click.
  # Re-invocation will increment current_round again, re-populate tables
  # (potentially clobbering operator-set assignments), and re-enqueue both
  # TournamentMonitorUpdateResultsJob and TournamentStatusUpdateJob.
  # Re-entry is prevented by the thread-local sentinel
  # `Thread.current[:_advancing_round_for_tm]` set in
  # TableMonitor#advance_tournament_round_if_present (CR-02 guard);
  # finalize_round's internal `tabmon.close_match!` loop relies on that
  # sentinel to short-circuit nested re-entry. See Phase 38.8 REVIEW WR-01
  # and CR-02.
  #
  # PUBLIC — invoked from app/models/table_monitor.rb#advance_tournament_round_if_present.
  def advance_round_after_match_close(table_monitor)
    Rails.logger.info "[advance_round_after_match_close] START for TM #{table_monitor.id}"
    accumulate_results
    @tournament_monitor.reload
    if @tournament_monitor.all_table_monitors_finished? || @tournament_monitor.tournament.manual_assignment || @tournament_monitor.tournament.continuous_placements
      @tournament_monitor.finalize_round # unless tournament.manual_assignment
      @tournament_monitor.incr_current_round! unless @tournament_monitor.tournament.manual_assignment || @tournament_monitor.tournament.continuous_placements
      @tournament_monitor.populate_tables unless @tournament_monitor.tournament.manual_assignment
      if @tournament_monitor.group_phase_finished?
        if @tournament_monitor.finals_finished?
          @tournament_monitor.decr_current_round!
          update_ranking
          write_finale_csv_for_upload
          # noinspection RubyResolve
          @tournament_monitor.end_of_tournament!
          # noinspection RubyResolve
          @tournament_monitor.tournament.finish_tournament!
          # noinspection RubyResolve
          @tournament_monitor.tournament.have_results_published!
          # tournament.tournament_monitor.andand.table_monitors.andand.destroy_all
        else
          # noinspection RubyResolve
          @tournament_monitor.start_playing_finals!
        end
      else
        # noinspection RubyResolve
        @tournament_monitor.start_playing_groups!
      end
      TournamentMonitorUpdateResultsJob.perform_later(@tournament_monitor)
      # Broadcast Status-Update für Tournament View
      TournamentStatusUpdateJob.perform_later(@tournament_monitor.tournament)
    elsif @tournament_monitor.tournament.tournament_started
      # Auch bei einzelnen Spiel-Updates broadcasten (wenn Spiel läuft)
      TournamentStatusUpdateJob.perform_later(@tournament_monitor.tournament)
    end
  rescue StandardError => e
    Rails.logger.info "[advance_round_after_match_close] StandardError #{e}, #{e.backtrace&.join("\n")}"
    raise
  end

  # Aggregiert alle GameParticipation-Ergebnisse in @tournament_monitor.data["rankings"].
  # PUBLIC — wird auch von TablePopulator (Plan 15-02) via Model-Delegation aufgerufen.
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
      "games.id >= ? AND games.tournament_id = ?", Seeding::MIN_ID, @tournament_monitor.tournament.id
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
        elsif (m = game.gname.match(/^(64f|32f|16f|8f|af|qf|vf|hf|fin|p<\d+(?:\.\.|-)\d+>)(\d+)?$/))
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
    @tournament_monitor.data_will_change!
    @tournament_monitor.data["rankings"] = rankings
    @tournament_monitor.save!
  rescue StandardError => e
    Rails.logger.info "ERROR: #{e}, #{e.backtrace&.join("\n")}" if TournamentMonitor::DEBUG
  end

  # Berechnet das Endranking aus den executor_params RK-Regeln und schreibt es in Rankings.
  # PUBLIC — wird von Model-Delegation aufgerufen.
  def update_ranking
    tm = @tournament_monitor
    rankings = tm.data["rankings"]
    executor_params = JSON.parse(@tournament_monitor.tournament.tournament_plan.executor_params)
    rk_rules = executor_params["RK"]
    ix = 1
    rk_rules.each do |rule|
      if rule.is_a?(Array)
        rule.each do |rule_part|
          player_id = tm.player_id_from_ranking(rule_part, executor_params: executor_params)
          rankings["total"][player_id.to_s]["rank"] = ix
          @tournament_monitor.tournament.seedings.where(seedings: { player_id: player_id }).first&.update(rank: ix + 1)
        end
        ix += rule.count
      else
        player_id = tm.player_id_from_ranking(rule, executor_params: executor_params)
        rankings["total"][player_id.to_s]["rank"] = ix
        @tournament_monitor.tournament.seedings.where(seedings: { player_id: player_id }).first&.update(rank: ix + 1)
        ix += 1
      end
    end
    @tournament_monitor.data_will_change!
    @tournament_monitor.data["rankings"] = rankings
    @tournament_monitor.save!
  end

  # Delegiert an update_game_participations_for_game (alte API, für Abwärtskompatibilität).
  # PUBLIC — wird von Model-Delegation aufgerufen.
  def update_game_participations(tabmon)
    update_game_participations_for_game(tabmon.game, tabmon.data)
  end

  private

  # Schreibt TableMonitor-Daten in Game (wird innerhalb des DB-Locks in report_result aufgerufen).
  # Nur für Datenschreibung zuständig — keine State-Transitions, keine Broadcasts.
  def write_game_result_data(table_monitor)
    game = table_monitor.game
    return unless game.present? && !game.data.nil?

    # GUARD: Check if table_monitor.data has valid result data
    if table_monitor.data.blank? || table_monitor.data["ba_results"].blank?
      Rails.logger.warn "[write_game_result_data] ⊘ Skipping for game[#{game.id}] - table_monitor.data has no results"
      return
    end

    # GUARD: Check if table_monitor is in final state
    unless %w[final_match_score final_set_score].include?(table_monitor.state)
      Rails.logger.warn "[write_game_result_data] ⊘ Skipping for game[#{game.id}] - table_monitor not in final state (current: #{table_monitor.state})"
      return
    end

    # IDEMPOTENCY: Check if already written (within last minute)
    if game.data["finalized_at"].present?
      finalized_at = Time.parse(game.data["finalized_at"]) rescue nil
      if finalized_at && finalized_at > 1.minute.ago
        Rails.logger.warn "[write_game_result_data] ⊘ Already written at #{finalized_at.strftime('%H:%M:%S')} for game[#{game.id}]"
        return
      end
    end

    Rails.logger.info "[write_game_result_data] 💾 Writing game data for Game[#{game.id}], ba_results present: #{table_monitor.data['ba_results'].present?}"

    # Write all TableMonitor data to Game
    game.deep_merge_data!(
      "tmp_results" => table_monitor.data,
      "ba_results" => table_monitor.data["ba_results"],
      "finalized_at" => Time.current.iso8601
    )
    game.save!

    Rails.logger.info "[write_game_result_data] ✅ Game[#{game.id}] data written successfully"
  end

  # Finalisiert ein Spielergebnis: ClubCloud-Upload, GameParticipation-Updates, KO-Cleanup.
  # Wird NACH Datenschreibung und State-Transition in report_result aufgerufen (außerhalb Lock).
  def finalize_game_result(table_monitor)
    # This method is called AFTER data has been written and state transitioned in report_result
    # It handles: ClubCloud upload, game participation updates, and KO tournament cleanup
    #
    # NOTE: Data writing is now done in write_game_result_data (called inside lock in report_result)
    # So we no longer write data here to avoid race conditions

    Rails.logger.info "[finalize_game_result] START for TM #{table_monitor.id}"
    game = table_monitor.game
    Rails.logger.info "[finalize_game_result] game=#{game&.id} (#{game&.gname})"
    return unless game.present? && !game.data.nil?

    # GUARD: Check table_monitor state (data should already be written at this point)
    unless %w[final_match_score final_set_score].include?(table_monitor.state)
      Rails.logger.warn "[finalize_game_result] ⊘ Skipping for game[#{game.id}] - table_monitor not in final state (current: #{table_monitor.state})"
      return
    end

    # Automatische Übertragung in die ClubCloud
    if @tournament_monitor.tournament.tournament_cc.present? && @tournament_monitor.tournament.auto_upload_to_cc?
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

    # Update game participations unless manual assignment is enabled
    # WICHTIG: Wir übergeben das GAME (nicht table_monitor), weil table_monitor.game
    # durch populate_tables zu einem neuen Game reassigned werden könnte!
    Rails.logger.info "[finalize_game_result] manual_assignment=#{@tournament_monitor.tournament.manual_assignment}, calling update_game_participations=#{!@tournament_monitor.tournament.manual_assignment}"
    update_game_participations_for_game(game, table_monitor.data) unless @tournament_monitor.tournament.manual_assignment
    Rails.logger.info "[finalize_game_result] DONE"

    # For KO tournaments: Remove finished game from placements to free up the table
    if @tournament_monitor.tournament.tournament_plan&.name&.match?(/^(KO|DKO)/) && game.present?
      Rails.logger.info "[finalize_game_result] KO tournament - removing game #{game.gname} from placements"
      removed = false
      @tournament_monitor.data["placements"]&.each do |round_key, tables|
        tables&.each do |table_key, game_ids|
          if game_ids.is_a?(Array)
            if game_ids.include?(game.id)
              game_ids.delete(game.id)
              removed = true
              Rails.logger.info "[finalize_game_result] Removed game #{game.gname} from #{round_key}/#{table_key}"
            end
          elsif game_ids == game.id
            tables.delete(table_key)
            removed = true
            Rails.logger.info "[finalize_game_result] Removed game #{game.gname} from #{round_key}/#{table_key}"
          end
        end
      end
      @tournament_monitor.save! if removed
    end

    # TableMonitor wird NICHT hier gecleared - das passiert erst in populate_tables,
    # wenn alle Games der Runde fertig sind. So bleiben die Ergebnisse am Scoreboard sichtbar.
  end

  # Aktualisiert GameParticipation-Records für ein bestimmtes Game mit den gegebenen Daten.
  # Neue Version: Akzeptiert game und data direkt, um Race-Conditions zu vermeiden.
  def update_game_participations_for_game(game, table_monitor_data)
    sets = nil
    rank = {}
    points = {}

    # Use data from game.data["tmp_results"] if available, otherwise from table_monitor_data
    data_source = game.data["tmp_results"].present? ? game.data["tmp_results"] : table_monitor_data

    if @tournament_monitor.sets_to_play > 1
      ("a".."b").each do |c|
        rank["player#{c}"] = data_source["ba_results"]["Sets#{c == "a" ? 1 : 2}"]
      end
    else
      ("a".."b").each do |c|
        rank["player#{c}"] =
          data_source["player#{c}"]["result"].to_f / data_source["player#{c}"]["balls_goal"] * 100.0
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
      if @tournament_monitor.sets_to_play > 1
        n = c == "a" ? 1 : 2
        result = data_source["ba_results"]["Ergebnis#{n}"].to_i
        innings = data_source["ba_results"]["Aufnahmen#{n}"].to_i
        gd = format("%.2f", result.to_f / innings).to_f
        hs = data_source["ba_results"]["Höchstserie#{n}"].to_i
        sets = data_source["ba_results"]["Sets#{n}"].to_i
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
        result = data_source["player#{c}"]["result"].to_i
        innings = data_source["player#{c}"]["innings"].to_i
        bg = data_source["player#{c}"]["balls_goal"].to_i
        gd = format("%.2f", data_source["player#{c}"]["result"].to_f /
                            data_source["player#{c}"]["innings"].to_i).to_f
        # bg_p is the percentage of achieving the balls_goal in this game
        bg_p = format("%.2f", 100.0 * data_source["player#{c}"]["result"].to_f /
                              data_source["player#{c}"]["balls_goal"].to_i).to_f
        hs = data_source["player#{c}"]["hs"].to_i
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
    Rails.logger.info "ERROR: #{e}, #{e.backtrace&.join("\n")}" if TournamentMonitor::DEBUG
  end

  # Fügt GameParticipation-Ergebnis zu einem Rankings-Hash hinzu.
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
      seeding = @tournament_monitor.tournament.seedings
                                   .where("seedings.id >= #{Seeding::MIN_ID}")
                                   .find_by(player_id: player_id)
      hash[player_id]["balls_goal"] = seeding&.balls_goal || gp.data["results"]["BG"]
    end

    # Calculate gd_pct: achieved GD vs expected GD
    # Expected GD = balls_goal / innings_goal
    # gd_pct = 100 * gd_achieved / gd_expected
    if hash[player_id]["balls_goal"].present?
      innings_goal_value = @tournament_monitor.innings_goal || @tournament_monitor.tournament.innings_goal
      if innings_goal_value.present? && innings_goal_value > 0
        expected_gd = hash[player_id]["balls_goal"].to_f / innings_goal_value.to_f
        hash[player_id]["gd_pct"] =
          format("%.2f", 100.0 * hash[player_id]["gd"] / expected_gd).to_f
      end
    end
  rescue StandardError => e
    e
  end

  # Erstellt CSV-Datei mit Turnierergebnissen und versendet sie per E-Mail.
  def write_finale_csv_for_upload
    # Gruppe;Partie;Spieler1;Spieler2;Ergebnis1;\
    # Ergebnis2;Aufnahmen1;Aufnahmen2;Höchstserie1;Höchstserie2;Tischnummer;Start;Ende
    # Hauptrunde;1;98765;95678;100;85;24;23;16;9;1;11:30:45;12:17:51
    game_data = []
    @tournament_monitor.tournament.games.where("games.id >= #{Game::MIN_ID}").each do |game|
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
    f = File.new("#{Rails.root}/tmp/result-#{@tournament_monitor.tournament.cc_id}.csv", "w")
    f.write(game_data.join("\n"))
    f.close
    emails = ["gernot.ullrich@gmx.de"]

    # Safely try to fetch current_admin email without crashing
    begin
      if TournamentMonitor.current_admin.present?
        emails << TournamentMonitor.current_admin.email
      end
    rescue StandardError, NameError
    end

    # Safely try to fetch current_user email without crashing
    begin
      if @tournament_monitor.class.respond_to?(:current_user) && @tournament_monitor.class.current_user.present?
        emails << @tournament_monitor.class.current_user.email
      end
    rescue StandardError, NameError
    end

    # Send emails and isolate each attempt
    emails.compact.uniq.each do |recipient|
      begin
        NotifierMailer.result(
          @tournament_monitor.tournament,
          recipient,
          "Turnierergebnisse - #{@tournament_monitor.tournament.title}",
          "result-#{@tournament_monitor.tournament.id}.csv",
          "#{Rails.root}/tmp/result-#{@tournament_monitor.tournament.id}.csv"
        ).deliver
      rescue StandardError => e
        Rails.logger.error "[write_finale_csv_for_upload] Error sending result mail to #{recipient}: #{e.message}"
      end
    end
  end
end
