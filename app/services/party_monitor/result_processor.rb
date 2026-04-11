# frozen_string_literal: true

# Verarbeitet Spielergebnisse im PartyMonitor-Kontext.
# Extrahiert aus PartyMonitor als PORO (kein ApplicationService),
# da mehrere öffentliche Eintrittspunkte existieren (kein einzelnes `call`).
#
# Verantwortlichkeiten:
#   - report_result: Haupteinstiegspunkt für Ergebnismeldungen (mit DB-Pessimistic-Lock)
#   - write_game_result_data: Schreibt TableMonitor-Daten in Game (innerhalb Lock, PRIVAT)
#   - finalize_game_result: GameParticipation-Updates
#   - finalize_round: Schließt alle TableMonitor und akkumuliert Ergebnisse
#   - accumulate_results: Aggregiert Spielergebnisse in Rankings
#   - update_game_participations: Aktualisiert GameParticipation-Records
#
# DB-Lock-Scope: game.with_lock umfasst write_game_result_data + finish_match!
# TournamentMonitor.transaction: Scope bewusst beibehalten (Pitfall 5 — NICHT ändern).
#
# Verwendung:
#   PartyMonitor::ResultProcessor.new(party_monitor).report_result(table_monitor)
#   PartyMonitor::ResultProcessor.new(party_monitor).accumulate_results
class PartyMonitor::ResultProcessor
  def initialize(party_monitor)
    @party_monitor = party_monitor
  end

  # Haupteinstiegspunkt: Meldet ein Spielergebnis und verarbeitet die gesamte Pipeline.
  # DB-Pessimistic-Lock auf Game für atomare Datenschreibung + State-Transition.
  # TournamentMonitor.transaction bewusst beibehalten — NICHT auf PartyMonitor.transaction ändern.
  # PUBLIC
  def report_result(table_monitor)
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
          Rails.logger.info "🔒 [PartyMonitor#report_result] Acquiring lock for Game[#{game.id}]..."

          game.with_lock do
            # Reload to get latest state inside lock
            table_monitor.reload
            game.reload

            # Step 1: Write game data (idempotent, has guards)
            write_game_result_data(table_monitor)

            # Step 2: Transition state (triggers ActionCable broadcast)
            # By doing this AFTER data write, the broadcast will see correct data
            if table_monitor.may_finish_match?
              Rails.logger.info "🔒 [PartyMonitor#report_result] Calling finish_match! inside lock"
              table_monitor.finish_match!
            end
          end

          Rails.logger.info "✅ [PartyMonitor#report_result] Lock released for Game[#{game.id}], data written + state transitioned"
        end

        # Step 3: Finalize (ClubCloud upload, game participations, etc.)
        # This happens OUTSIDE the lock to avoid long lock duration
        finalize_game_result(table_monitor)

        accumulate_results
        @party_monitor.reload
        if @party_monitor.all_table_monitors_finished? # || tournament.manual_assignment || tournament.continuous_placements
          finalize_round # unless tournament.manual_assignment

          # incr_current_round! unless tournament.manual_assignment || tournament.continuous_placements
          # populate_tables unless tournament.manual_assignment
          # if group_phase_finished?
          #   if finals_finished?
          #     decr_current_round!
          #     update_ranking
          #     write_finale_csv_for_upload
          #     # noinspection RubyResolve
          #     end_of_tournament!
          #     # noinspection RubyResolve
          #     tournament.finish_tournament!
          #     # noinspection RubyResolve
          #     tournament.have_results_published!
          #     #tournament.tournament_monitor.andand.table_monitors.andand.destroy_all
          #   else
          #     # noinspection RubyResolve
          #     start_playing_finals!
          #   end
          # else
          #   # noinspection RubyResolve
          #   start_playing_groups!
          # end

          TournamentMonitorUpdateResultsJob.perform_later(@party_monitor)
        end
      rescue => e
        Rails.logger.info "StandardError #{e}, #{e.backtrace.to_a.join("\n")}"
        raise StandardError unless Rails.env == "production"

        raise ActiveRecord::Rollback
      end
    end
  end

  # Schließt alle TableMonitor-Records und akkumuliert Ergebnisse.
  # PUBLIC
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
    @party_monitor.table_monitors.joins(:game).each do |tabmon|
      game = tabmon.game
      next unless game.present? && game.data.present?

      update_game_participations(tabmon)
      # noinspection RubyResolve
      tabmon.close_match!
    end
    accumulate_results
  end

  # Finalisiert ein Spielergebnis: GameParticipation-Updates, manuelle Zuweisung.
  # PUBLIC
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
    game.deep_merge_data!({
      "ba_results" => table_monitor.data["ba_results"],
      "playera" => table_monitor.data["playera"],
      "playerb" => table_monitor.data["playerb"],
      "balls_counter_stack" => table_monitor.data["balls_counter_stack"].presence
    }.compact)
    game.save!
    if @party_monitor.tournament.manual_assignment || @party_monitor.tournament.continuous_placements
      update_game_participations(table_monitor)
      # noinspection RubyResolve
      table_monitor.close_match!
      args = {game_id: nil, prev_game_id: game.id, prev_data: table_monitor.data.dup, prev_tournament_monitor: @party_monitor}
      args[:tournament_monitor] = nil unless @party_monitor.tournament.continuous_placements
      table_monitor.update(args)
      @party_monitor.data_will_change!
      @party_monitor.save!
    end
  rescue => e
    Rails.logger.info "ERROR: #{e}, #{e.backtrace.join("\n")}" if PartyMonitor::DEBUG
    raise StandardError unless Rails.env == "production"
  end

  # Aggregiert alle GameParticipation-Ergebnisse in @party_monitor.data["rankings"].
  # CRITICAL: Preserve the data mutation bug (Pitfall 4).
  #   @party_monitor.data returns HashWithIndifferentAccess.
  #   Setting @party_monitor.data["rankings"] = rankings mutates the wrapper
  #   but does NOT persist because data= setter is never called.
  #   This is the documented behavior. DO NOT FIX IT.
  # PUBLIC
  def accumulate_results
    rankings = {
      "tmp_result" => {
        "game_points" => [0, 0],
        "match_points" => [0, 0]
      },
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
    @party_monitor.party.reload.games.where("games.id >= ?", Seeding::MIN_ID).map(&:game_participations).flatten.each do |gp|
      # GameParticipation.joins(game: :tournament).where("games.id >= ?", Seeding::MIN_ID).where(tournaments: { id: tournament.id }).each do |gp|
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
    @party_monitor.data_will_change!
    @party_monitor.data["rankings"] = rankings
    @party_monitor.save!
  end

  # Aktualisiert GameParticipation-Records für einen bestimmten TableMonitor.
  # PUBLIC
  def update_game_participations(tabmon)
    game = tabmon.game
    sets = nil
    sets_to_play = @party_monitor.get_attribute_by_gname(game.gname, "sets")
    game_points = HashWithIndifferentAccess.new(@party_monitor.get_game_plan_attribute_by_gname(game.gname, "game_points"))
    rank = {}
    points = {}
    if sets_to_play > 1
      ("a".."b").each do |c|
        rank["player#{c}"] = tabmon.data["ba_results"]["Sets#{(c == "a") ? 1 : 2}"]
      end
    else
      ("a".."b").each do |c|
        rank["player#{c}"] =
          tabmon.data["player#{c}"]["result"].to_f / tabmon.data["player#{c}"]["balls_goal"].to_f * 100.0
      end
    end
    points["playera"] = if rank["playera"] > rank["playerb"]
      game_points["win"]
    else
      ((rank["playera"] < rank["playerb"]) ? game_points["lost"] : game_points["draw"])
    end
    points["playerb"] = if rank["playerb"] > rank["playera"]
      game_points["win"]
    else
      ((rank["playerb"] < rank["playera"]) ? game_points["lost"] : game_points["draw"])
    end
    ("a".."b").each do |c|
      gp = game.game_participations.where(role: "player#{c}").first
      if sets_to_play > 1
        n = (c == "a") ? 1 : 2
        result = tabmon.data["ba_results"]["Ergebnis#{n}"].to_i
        innings = tabmon.data["ba_results"]["Aufnahmen#{n}"].to_i
        gd = format("%.2f", result.to_f / innings).to_f
        hs = tabmon.data["ba_results"]["Höchstserie#{n}"].to_i
        sets = tabmon.data["ba_results"]["Sets#{n}"].to_i
        results = {
          "Gr.": game.gname,
          Ergebnis: result,
          Aufnahme: innings,
          GD: gd,
          HS: hs,
          Sets: sets,
          gp_id: gp.id
        }
      else
        result = tabmon.data["player#{c}"]["result"].to_i
        innings = tabmon.data["player#{c}"]["innings"].to_i
        bg = tabmon.data["player#{c}"]["balls_goal"].to_i
        bg_p = format("%.2f",
          100.0 * tabmon.data["player#{c}"]["result"].to_f / tabmon.data["player#{c}"]["balls_goal"].to_i).to_f
        gd = format("%.2f", tabmon.data["player#{c}"]["result"].to_f / tabmon.data["player#{c}"]["innings"].to_i).to_f
        hs = tabmon.data["player#{c}"]["hs"].to_i
        results = {
          "Gr.": game.gname,
          Ergebnis: result,
          Aufnahme: innings,
          GD: gd,
          HS: hs,
          gp_id: gp.id,
          Sets: 1,
          BG: bg,
          BG_P: bg_p
        }
      end
      gp.deep_merge_data!("results" => results)
      gp.update(points: points["player#{c}"], result: result, innings: innings, gd: gd, hs: hs, sets: sets)
      if PartyMonitor::DEBUG
        Tournament.logger.info("RESULT #{game.gname} points: #{points["player#{c}"]}, result: #{result}, innings: #{innings}, gd: #{gd}, hs: #{hs}, sets: #{sets}")
      end
    end
  end

  private

  # Schreibt TableMonitor-Daten in Game (wird innerhalb des DB-Locks in report_result aufgerufen).
  # Nur für Datenschreibung zuständig — keine State-Transitions, keine Broadcasts.
  # PRIVAT — darf NICHT auf PartyMonitor model definiert sein.
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
      finalized_at = begin
        Time.parse(game.data["finalized_at"])
      rescue
        nil
      end
      if finalized_at && finalized_at > 1.minute.ago
        Rails.logger.warn "[write_game_result_data] ⊘ Already written at #{finalized_at.strftime("%H:%M:%S")} for game[#{game.id}]"
        return
      end
    end

    Rails.logger.info "[write_game_result_data] 💾 Writing game data for Game[#{game.id}], ba_results present: #{table_monitor.data["ba_results"].present?}"

    # Write all TableMonitor data to Game
    game.deep_merge_data!(
      "tmp_results" => table_monitor.data,
      "ba_results" => table_monitor.data["ba_results"],
      "finalized_at" => Time.current.iso8601
    )
    game.save!

    Rails.logger.info "[write_game_result_data] ✅ Game[#{game.id}] data written successfully"
  end

  # Fügt GameParticipation-Ergebnis zu einem Rankings-Hash hinzu.
  # SIMPLER als TournamentMonitor-Version — kein balls_goal, kein gd_pct, kein seedings-Lookup.
  # PRIVAT — darf NICHT auf PartyMonitor model definiert sein.
  def add_result_to(gp, hash)
    player_id = gp.player_id
    hash[player_id] ||= {
      "points" => 0,
      "result" => 0,
      "innings" => 0,
      "hs" => 0,
      "bed" => 0,
      "gd" => 0
    }
    hash[player_id]["points"] += gp.points
    hash[player_id]["result"] += gp.result
    hash[player_id]["innings"] += gp.innings
    hash[player_id]["bed"] = gp.gd if gp.gd > hash[player_id]["bed"]
    hash[player_id]["hs"] = gp.hs if gp.hs > hash[player_id]["hs"]
    hash[player_id]["gd"] = format("%.2f", hash[player_id]["result"].to_f / hash[player_id]["innings"]).to_f
  rescue => e
    Rails.logger.error "[add_result_to] Error for player #{gp.player_id}: #{e.message}\n#{e.backtrace.to_a.first(5).join("\n")}"
    raise e
  end
end
