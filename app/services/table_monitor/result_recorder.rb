# frozen_string_literal: true

# Kapselt die gesamte Ergebnis-Persistenz-Logik aus TableMonitor in einen eigenstaendigen Service.
# Verantwortlichkeiten:
#   - Ergebnis-Hash aufbauen und in data["sets"] speichern (save_result, save_current_set)
#   - Saetze navigieren: naechsten Satz initialisieren (switch_to_next_set)
#   - Maximale Gewinnzahl berechnen (get_max_number_of_wins)
#   - AASM-Zustandsuebergaenge koordinieren (evaluate_result als Haupt-Einstiegspunkt)
#
# AASM-Events (end_of_set!, finish_match!) werden direkt auf @tm aufgerufen —
# die Guards bleiben am Modell. Keine direkten Broadcast-Aufrufe hier;
# Broadcasts erfolgen via after_update_commit auf dem TableMonitor.
#
# Einstiegspunkte:
#   TableMonitor::ResultRecorder.call(table_monitor: tm)            -> evaluate_result
#   TableMonitor::ResultRecorder.save_result(table_monitor: tm)     -> Ergebnis-Hash bauen
#   TableMonitor::ResultRecorder.save_current_set(table_monitor: tm)-> Satz abschliessen
#   TableMonitor::ResultRecorder.get_max_number_of_wins(table_monitor: tm) -> Integer
#   TableMonitor::ResultRecorder.switch_to_next_set(table_monitor: tm)     -> naechsten Satz init
class TableMonitor::ResultRecorder < ApplicationService
  def initialize(kwargs = {})
    @tm = kwargs[:table_monitor]
  end

  # Haupt-Einstiegspunkt: entspricht dem extrahierten evaluate_result-Body.
  def call
    perform_evaluate_result
  end

  # Klassenmethoden-Einstiegspunkte fuer die uebrigen 4 Operationen.

  def self.save_result(table_monitor:)
    new(table_monitor: table_monitor).perform_save_result
  end

  def self.save_current_set(table_monitor:)
    new(table_monitor: table_monitor).perform_save_current_set
  end

  def self.get_max_number_of_wins(table_monitor:)
    new(table_monitor: table_monitor).perform_get_max_number_of_wins
  end

  def self.switch_to_next_set(table_monitor:)
    new(table_monitor: table_monitor).perform_switch_to_next_set
  end

  # ---------------------------------------------------------------------------
  # Public perform_* methods (called by class-level entry points above)
  # ---------------------------------------------------------------------------

  def perform_save_result
    game_set_result = {}
    if @tm.game.present?
      # Fuer Snooker: Gesamtpunkte aus innings_redo_list berechnen (Break-Punkte akkumulieren dort)
      # Fuer andere Spiele: result-Feld verwenden
      ergebnis1 = @tm.data["playera"]["result"].to_i
      ergebnis2 = @tm.data["playerb"]["result"].to_i

      # Phase 38.4-P9: removed BK-* dispatch to Bk2::AdvanceMatchState.
      # The dispatch read shot_payload from data["current_bk2_shot_payload"] but
      # NOTHING in the codebase ever wrote that key, so shot_payload was always {},
      # crashing Bk2::ScoreShot#calculate_raw_points on nil obs at first set close.
      # The post-set persistence path only needs ergebnis1/2 from data[playera/b].result —
      # match-state was already advanced via the live-scoring CommitInning path
      # (TableMonitor#add_n_balls → bk_family_with_nachstoss? → Bk2::CommitInning).

      if @tm.data["free_game_form"] == "snooker"
        # Alle Break-Punkte summieren: innings_list (abgeschlossene Breaks) + innings_redo_list (aktueller Break)
        # Wenn ein Spieler wechselt, wandert sein Break von redo_list in list
        ergebnis1 = Array(@tm.data["playera"]["innings_list"]).sum(&:to_i) + Array(@tm.data["playera"]["innings_redo_list"]).sum(&:to_i)
        ergebnis2 = Array(@tm.data["playerb"]["innings_list"]).sum(&:to_i) + Array(@tm.data["playerb"]["innings_redo_list"]).sum(&:to_i)
        Rails.logger.info "[save_result] Snooker frame - Player A: #{ergebnis1} points (list:#{Array(@tm.data["playera"]["innings_list"]).sum} + redo:#{Array(@tm.data["playera"]["innings_redo_list"]).sum}), Player B: #{ergebnis2} points (list:#{Array(@tm.data["playerb"]["innings_list"]).sum} + redo:#{Array(@tm.data["playerb"]["innings_redo_list"]).sum})"
      end

      game_set_result = {
        "Gruppe" => @tm.game.group_no,
        "Partie" => @tm.game.seqno,

        "Spieler1" => @tm.game.game_participations.where(role: "playera").first&.player&.ba_id,
        "Spieler2" => @tm.game.game_participations.where(role: "playerb").first&.player&.ba_id,
        "Innings1" => @tm.data["playera"]["innings_list"].dup,
        "Innings2" => @tm.data["playerb"]["innings_list"].dup,
        "Ergebnis1" => ergebnis1,
        "Ergebnis2" => ergebnis2,
        "Aufnahmen1" => @tm.data["playera"]["innings"].to_i,
        "Aufnahmen2" => @tm.data["playerb"]["innings"].to_i,
        "3BErgebnis1" => @tm.data["playera"]["result_3b"].to_i,
        "3BErgebnis2" => @tm.data["playerb"]["result_3b"].to_i,
        "3BAufnahmen1" => @tm.data["playera"]["innings_3b"].to_i,
        "3BAufnahmen2" => @tm.data["playerb"]["innings_3b"].to_i,
        "Höchstserie1" => @tm.data["playera"]["hs"].to_i,
        "Höchstserie2" => @tm.data["playerb"]["hs"].to_i,
        "Tischnummer" => @tm.game.table_no
      }
      # Phase 38.4 R5-2: ba_results-Update wurde aus dieser Methode herausgelöst
      # und nach perform_save_current_set verschoben (atomisch mit data["sets"]
      # push). perform_save_result wird in perform_evaluate_result an ZWEI Stellen
      # aufgerufen (Übergang playing→set_over UND auf Bestätigung des Protokoll-
      # Modals). Vorher: Sets1/2 +=1 jedes Mal → Doppelzählung → Match endet
      # nach Satz 1 (Sets1=2 statt 1). Jetzt single source of truth in
      # perform_save_current_set.
    end
    game_set_result
  end

  # Phase 38.4 R5-2: ba_results-Aktualisierung extrahiert. Aufrufer ist
  # perform_save_current_set (genau einmal pro Satz, atomisch mit dem data["sets"]
  # push). NICHT von perform_save_result aufrufen — das wird mehrfach pro Satz
  # aufgerufen (siehe doc-comment in perform_save_result oben).
  def update_ba_results_with_set_result!(game_set_result)
    return unless @tm.game.present?

    ba_results = @tm.data["ba_results"] ||
      {
        "Gruppe" => @tm.game.group_no,
        "Partie" => @tm.game.seqno,
        "Spieler1" => @tm.game.game_participations.where(role: "playera").first&.player&.ba_id,
        "Spieler2" => @tm.game.game_participations.where(role: "playerb").first&.player&.ba_id,
        "Sets1" => 0,
        "Sets2" => 0,
        "Ergebnis1" => 0,
        "Ergebnis2" => 0,
        "Aufnahmen1" => 0,
        "Aufnahmen2" => 0,
        "Höchstserie1" => 0,
        "Höchstserie2" => 0,
        "Tischnummer" => @tm.game.table_no
      }
    if game_set_result["Ergebnis1"].to_i > game_set_result["Ergebnis2"].to_i
      ba_results["Sets1"] = ba_results["Sets1"].to_i + 1
    end
    if game_set_result["Ergebnis1"].to_i < game_set_result["Ergebnis2"].to_i
      ba_results["Sets2"] = ba_results["Sets2"].to_i + 1
    end
    ba_results["Ergebnis1"] = ba_results["Ergebnis1"].to_i + game_set_result["Ergebnis1"].to_i
    ba_results["Ergebnis2"] = ba_results["Ergebnis2"].to_i + game_set_result["Ergebnis2"].to_i
    ba_results["Aufnahmen1"] = ba_results["Aufnahmen1"].to_i + game_set_result["Aufnahmen1"].to_i
    ba_results["Aufnahmen2"] = ba_results["Aufnahmen2"].to_i + game_set_result["Aufnahmen2"].to_i
    ba_results["Höchstserie1"] = [ba_results["Höchstserie1"].to_i, game_set_result["Höchstserie1"].to_i].max
    ba_results["Höchstserie2"] = [ba_results["Höchstserie2"].to_i, game_set_result["Höchstserie2"].to_i].max
    # Phase 38.7 Plan 05 — D-08: derive TiebreakWinner from game.data['tiebreak_winner'].
    # Mechanical mapping playera→1 / playerb→2; any other value (nil, blank, forged
    # string, non-String) leaves the key absent — Plan 07's PDF view skips the
    # indicator when the key is missing. Defense-in-depth against forged data:
    # explicit String + whitelist check before assignment.
    tw = @tm.game.data&.[]("tiebreak_winner")
    if tw.is_a?(String) && %w[playera playerb].include?(tw)
      ba_results["TiebreakWinner"] = {"playera" => 1, "playerb" => 2}[tw]
    end
    @tm.deep_merge_data!("ba_results" => ba_results)
  end

  def perform_save_current_set
    Rails.logger.debug { "----------------m6[#{@tm.id}]----->>> save_current_set <<<------------------------------------------" }
    if @tm.game.present?
      # Fuer simple_set_game (Snooker, Pool): VOR save_result pruefen ob dieser Frame bereits gespeichert wurde
      # Dies verhindert doppeltes Speichern wenn Protocol-Modal bestaetigt wird
      # (welches evaluate_result -> save_current_set nochmals aufruft)
      if @tm.simple_set_game?
        # Berechnen was das aktuelle Ergebnis waere OHNE save_result aufzurufen
        # Fuer Snooker: innings_list und innings_redo_list summieren
        ergebnis1 = @tm.data["playera"]["result"].to_i
        ergebnis2 = @tm.data["playerb"]["result"].to_i

        if @tm.data["free_game_form"] == "snooker"
          ergebnis1 = Array(@tm.data["playera"]["innings_list"]).sum(&:to_i) + Array(@tm.data["playera"]["innings_redo_list"]).sum(&:to_i)
          ergebnis2 = Array(@tm.data["playerb"]["innings_list"]).sum(&:to_i) + Array(@tm.data["playerb"]["innings_redo_list"]).sum(&:to_i)
        end

        aufnahmen1 = @tm.data["playera"]["innings"].to_i
        aufnahmen2 = @tm.data["playerb"]["innings"].to_i

        # Pruefen ob der zuletzt gespeicherte Frame dasselbe Ergebnis hat
        last_saved_set = Array(@tm.data["sets"]).last
        if last_saved_set &&
            last_saved_set["Ergebnis1"] == ergebnis1 &&
            last_saved_set["Ergebnis2"] == ergebnis2 &&
            last_saved_set["Aufnahmen1"] == aufnahmen1 &&
            last_saved_set["Aufnahmen2"] == aufnahmen2
          Rails.logger.info "[save_current_set] m6[#{@tm.id}] Frame already saved (duplicate result: #{ergebnis1}:#{ergebnis2}, #{aufnahmen1}:#{aufnahmen2} innings) - skipping"
          return
        end
      end

      game_set_result = perform_save_result

      sets = Array(@tm.data["sets"]).push(game_set_result)
      # Phase 38.4 R5-2: update ba_results atomic mit dem data["sets"] push.
      # Stellt sicher, dass Sets1/2 nur einmal pro Satz inkrementieren.
      update_ba_results_with_set_result!(game_set_result)
      @tm.deep_merge_data!("redo_sets" => [])
      @tm.deep_merge_data!("sets" => sets)
      @tm.save!
    else
      Rails.logger.info "[prepare_final_game_result] m6[#{@tm.id}]ignored - no game"
    end
  rescue => e
    Rails.logger.error "ERROR: m6[#{@tm.id}]#{e}, #{e.backtrace&.join("\n")}"
    raise StandardError
  end

  def perform_get_max_number_of_wins
    Rails.logger.debug { "---------------m6[#{@tm.id}]------>>> get_max_number_of_wins <<<------------------------------------------" }
    [@tm.data["ba_results"].andand["Sets1"].to_i, @tm.data["ba_results"].andand["Sets2"].to_i].max
  rescue => e
    Rails.logger.error "ERROR:m6[#{@tm.id}] #{e}, #{e.backtrace&.join("\n")}"
    raise StandardError unless Rails.env == "production"
  end

  def perform_switch_to_next_set
    Rails.logger.debug { "---------------m6[#{@tm.id}]------>>> switch_to_next_set <<<------------------------------------------" }
    kickoff_switches_with = @tm.data["kickoff_switches_with"].presence || "set"
    current_kickoff_player = @tm.data["current_kickoff_player"]
    case kickoff_switches_with
    when "set"
      current_kickoff_player = (current_kickoff_player == "playera") ? "playerb" : "playera"
    when "winner"
      current_kickoff_player = (@tm.data["sets"][-1]["Innings1"][-1].to_i > @tm.data["sets"][-1]["Innings2"][-1].to_i) ? "playera" : "playerb"
    end
    options = {
      "Gruppe" => @tm.game.group_no,
      "Partie" => @tm.game.seqno,

      "Spieler1" => @tm.game.game_participations.where(role: "playera").first&.player&.ba_id,
      "Spieler2" => @tm.game.game_participations.where(role: "playerb").first&.player&.ba_id,
      "Ergebnis1" => 0,
      "Ergebnis2" => 0,
      "Aufnahmen1" => 0,
      "Aufnahmen2" => 0,
      "Höchstserie1" => 0,
      "Höchstserie2" => 0,
      "Tischnummer" => @tm.game.table_no,
      "current_kickoff_player" => current_kickoff_player,
      "playera" =>
        {"result" => 0,
         "innings" => 0,
         "innings_list" => [],
         "innings_redo_list" => [],
         "hs" => 0,
         "gd" => "0.00"},
      "playerb" =>
        {"result" => 0,
         "innings" => 0,
         "innings_list" => [],
         "innings_redo_list" => [],
         "hs" => 0,
         "gd" => "0.00"},
      "current_inning" => {
        "active_player" => current_kickoff_player,
        "balls" => 0
      }
    }

    # Snooker-Zustand fuer neuen Frame zuruecksetzen
    if @tm.data["free_game_form"] == "snooker"
      initial_reds = @tm.initial_red_balls
      options["snooker_state"] = {
        "reds_remaining" => initial_reds,
        "last_potted_ball" => nil,
        "free_ball_active" => false,
        "colors_sequence" => [2, 3, 4, 5, 6, 7]
      }
      options["snooker_frame_complete"] = false
      options["playera"]["break_balls_list"] = []
      options["playera"]["break_balls_redo_list"] = []
      options["playera"]["break_fouls_list"] = []
      options["playerb"]["break_balls_list"] = []
      options["playerb"]["break_balls_redo_list"] = []
      options["playerb"]["break_fouls_list"] = []
    end

    @tm.deep_merge_data!(options)
    # Phase 38.5 D-03 hook 2: re-bake at set-boundary for BK-2kombi only.
    # data["sets"] has the just-closed set pushed (perform_save_current_set, line 179),
    # so Array(data["sets"]).length + 1 is the new set index — the resolver naturally
    # picks the correct multiset_components entry (DZ <-> SP alternation).
    # Non-BK-2kombi families have stable effective_discipline across sets, so the
    # bake would be a no-op; the guard makes intent explicit.
    if @tm.data["free_game_form"] == "bk2_kombi"
      Bk2::AdvanceMatchState.rebake_at_set_open!(@tm)
    end
    @tm.assign_attributes(state: "playing", panel_state: "pointer_mode", current_element: "pointer_mode")
    @tm.save!
  rescue => e
    Rails.logger.error "ERROR: m6[#{@tm.id}]#{e}, #{e.backtrace&.join("\n")}"
    raise StandardError
  end

  private

  # Phase 38.7 Plan 05 — D-03 trigger detection helper.
  # Returns true iff: game.data['tiebreak_required']==true AND
  # game.data['tiebreak_winner'] is missing AND scores are tied.
  # When true, callers (perform_evaluate_result inning + simple-set branches,
  # training-rematch branch) gate their behaviour on this condition.
  # Pure read; no side effects. See result_recorder D-03 / D-13 / D-08 wiring.
  def tiebreak_pick_pending?
    return false unless @tm.game&.data&.[]("tiebreak_required") == true
    return false if @tm.game.data["tiebreak_winner"].present?

    # "Tied" definition aligns with TableMonitor#tiebreak_pending_block? (D-08
    # AASM guard predicate). Inning-based: data['playera']['result'] ==
    # data['playerb']['result']. Simple-set: most recent set's Ergebnis1==Ergebnis2.
    a = @tm.data&.dig("playera", "result").to_i
    b = @tm.data&.dig("playerb", "result").to_i
    if @tm.simple_set_game? && @tm.data["sets"].present?
      last_set = Array(@tm.data["sets"]).last
      a = last_set["Ergebnis1"].to_i
      b = last_set["Ergebnis2"].to_i
    end
    a == b
  end

  # Haupt-Ablauf: entspricht dem extrahierten evaluate_result-Body.
  # Alle return-Anweisungen aus dem Original sind erhalten (Pitfall 2: verhindert Rekursion).
  def perform_evaluate_result
    # GUARD: Auswertung bei brandneuen Spielen (innerhalb 5 Sekunden nach Platzierung) verhindern
    if @tm.game&.started_at.present? && @tm.game.started_at > 5.seconds.ago
      total_innings = @tm.data["playera"]["innings"].to_i + @tm.data["playerb"]["innings"].to_i
      total_points = @tm.data["playera"]["result"].to_i + @tm.data["playerb"]["result"].to_i

      if total_innings == 0 && total_points == 0
        Rails.logger.warn "[evaluate_result GUARD] Game[#{@tm.game_id}] on TM[#{@tm.id}] is brand new (started #{(Time.current - @tm.game.started_at).round(1)}s ago) with 0 innings/points - SKIPPING evaluation to prevent spurious finish"
        return
      end
    end

    # Phase 38.5: end_of_set? muss nur bei playing/set_over geprüft werden — bei
    # final_set_score/final_match_score IST der Satz definitiv vorbei (State sagt's),
    # und end_of_set? kann false zurückgeben (z.B. bei BK-2kombi nach dem 3. Satz, weil
    # bk2_kombi_current_phase für Set 4 fragt — den es nicht gibt). Dadurch hängt der
    # Rematch-Branch im final_set_score-Zweig.
    if (@tm.final_set_score? || @tm.final_match_score?) ||
       ((@tm.playing? || @tm.set_over?) && @tm.end_of_set?)
      # Merken ob wir vorher gespielt haben vor einem Zustandsuebergang
      was_playing = @tm.playing?
      is_simple_set = @tm.simple_set_game?

      Rails.logger.info "[evaluate_result] Frame end detected - was_playing: #{was_playing}, is_simple_set: #{is_simple_set}, may_end_of_set?: #{@tm.may_end_of_set?}, state: #{@tm.state}"

      # Fuer Simple-Set-Spiele (8-Ball, 9-Ball, 10-Ball, Snooker): Satz-Ende anders behandeln:
      # - Kein Protocol-Modal nach jedem Satz
      # - Automatisch zum naechsten Satz wechseln
      # - Modal nur zeigen wenn Match gewonnen
      if is_simple_set && was_playing && @tm.may_end_of_set?
        Rails.logger.info "[evaluate_result] Snooker/Pool frame end - checking if match is won"
        @tm.end_of_set!
        perform_save_current_set
        max_number_of_wins = perform_get_max_number_of_wins
        Rails.logger.info "[evaluate_result] max_number_of_wins: #{max_number_of_wins}, sets_to_win: #{@tm.data["sets_to_win"]}, Sets1: #{@tm.data["ba_results"]["Sets1"]}, Sets2: #{@tm.data["ba_results"]["Sets2"]}"
        if max_number_of_wins >= @tm.data["sets_to_win"].to_i
          # Match ist vorbei - finales Ergebnis-Modal zeigen
          Rails.logger.info "[evaluate_result] Match WON - showing final modal"
          @tm.panel_state = "protocol_final"
          # Phase 38.7 Plan 05 — D-03 trigger detection (simple-set branch).
          # Same marker-switch as inning-based branch above; covers BK-2/BK-2kombi-SP
          # and any future simple-set discipline that opts into tiebreak_on_draw.
          @tm.current_element = tiebreak_pick_pending? ? "tiebreak_winner_choice" : "confirm_result"
          @tm.save!
        else
          # Weitere Saetze zu spielen - automatisch zum naechsten Satz wechseln (kein Modal)
          Rails.logger.info "[evaluate_result] Match NOT won - switching to next frame"
          perform_switch_to_next_set
        end
        return
      elsif was_playing && !is_simple_set
        @tm.end_of_set! if @tm.playing? && @tm.may_end_of_set?
        # protocol_final-Modal fuer Ergebnispruefung bei JEDEM Satz-Ende zeigen
        # (fuer Inning-basierte Spiele wie Karambol, 14.1 endlos)
        @tm.panel_state = "protocol_final"
        # Phase 38.7 Plan 05 — D-03 trigger detection: switch marker to
        # tiebreak_winner_choice when a tiebreak winner pick is still pending
        # (tiebreak_required + tied + winner not yet set). Plan 06 view branch
        # renders the radio fieldset on this marker.
        @tm.current_element = tiebreak_pick_pending? ? "tiebreak_winner_choice" : "confirm_result"
        perform_save_result
        @tm.save!
        return
      elsif @tm.set_over?
        Rails.logger.info "[evaluate_result] set_over? branch - sets_to_win=#{@tm.data["sets_to_win"]}, sets_to_play=#{@tm.data["sets_to_play"]}"
        if @tm.data["sets_to_win"].to_i > 1 # TODO: sets to play not implemented correctly
          Rails.logger.info "[evaluate_result] Branch A: sets_to_win > 1"
          perform_save_current_set
          max_number_of_wins = perform_get_max_number_of_wins
          if @tm.automatic_next_set && @tm.data["sets_to_win"].to_i > 1 && max_number_of_wins < @tm.data["sets_to_win"].to_i
            perform_switch_to_next_set
          else
            @tm.acknowledge_result!
          end
          return
        elsif @tm.data["sets_to_play"].to_i > 1
          Rails.logger.info "[evaluate_result] Branch B: sets_to_play > 1"
          if @tm.automatic_next_set && @tm.sets_played < @tm.data["sets_to_play"].to_i
            perform_switch_to_next_set
          else
            @tm.acknowledge_result!
          end
          return
        else
          Rails.logger.info "[evaluate_result] Branch C: Single set game - calling acknowledge_result and report_result"
          @tm.acknowledge_result! if @tm.may_acknowledge_result?
          if @tm.final_set_score?
            Rails.logger.info "[evaluate_result] Calling report_result! state=#{@tm.state}"
            # FIX: finish_match! wird jetzt INNERHALB von report_result mit Lock aufgerufen
            # Dies verhindert Race Condition und stellt sicher dass Daten VOR dem Zustandswechsel geschrieben werden
            @tm.tournament_monitor&.report_result(@tm)

            # Trainingsspiel (kein tournament_monitor): Automatisch Rückspiel mit getauschten Spielern starten
            if @tm.tournament_monitor.blank? && @tm.game.present?
              # Phase 38.7 Plan 05 — D-13: block training rematch when tiebreak pending.
              # Otherwise revert_players + do_play would discard the tied result before
              # the operator gets to pick the tiebreak winner via the modal.
              if tiebreak_pick_pending?
                Rails.logger.info "[evaluate_result] Training game tied — tiebreak winner pending, NOT auto-rematching"
                return
              end
              Rails.logger.info "[evaluate_result] Training game finished - creating rematch with swapped players"
              @tm.revert_players
              @tm.update(state: "playing")
              @tm.do_play
              return
            end
          else
            Rails.logger.warn "[evaluate_result] NOT calling report_result - state is #{@tm.state}, not final_set_score!"
          end
        end
      elsif @tm.final_set_score?
        # FIX: Nur report_result aufrufen (finish_match! passiert darin)
        @tm.tournament_monitor&.report_result(@tm)

        # Trainingsspiel (kein tournament_monitor): Automatisch Rückspiel mit getauschten Spielern starten
        if @tm.tournament_monitor.blank? && @tm.game.present?
          # Phase 38.7 Plan 05 — D-13: block training rematch when tiebreak pending.
          if tiebreak_pick_pending?
            Rails.logger.info "[evaluate_result] Training game tied — tiebreak winner pending, NOT auto-rematching"
            return
          end
          Rails.logger.info "[evaluate_result] Training game finished - creating rematch with swapped players"
          @tm.revert_players
          @tm.update(state: "playing")
          @tm.do_play
          return
        end
      end
      @tm.save! if @tm.changes.present?
      @tm.reload

      # FIX: prepare_final_game_result nur aufrufen wenn wir in einem finalen Zustand sind
      # report_result soll nur einmal pro Ergebnis aufgerufen werden, nicht mehrfach
      if @tm.final_match_score?
        @tm.prepare_final_game_result
      end
    else
      Rails.logger.debug { "eval ***** K:  ! (playing? || set_over? || final_set_score? || final_match_score?) && end_of_set?" }
    end
  rescue => e
    Rails.logger.error "ERROR: #{e}, #{e.backtrace&.join("\n")}"
    raise StandardError unless Rails.env == "production"
  end
end
