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

      if @tm.data["free_game_form"] == "bk2_kombi"
        # BK2-Kombi Satz-Ergebnis: Plan 03 implementiert Bk2Kombi::AdvanceMatchState vollstaendig.
        # Signatur: .call(table_monitor:, shot_payload:) → { scoring:, transitions:, state: }
        # Dispatch-Zweig sitzt neben dem Snooker-Zweig (Pattern: Phase 38.1 CONTEXT.md D-11).
        # Bk2Kombi::AdvanceMatchState — Plan 03 ersetzt den Stub mit der Implementierung.
        Bk2Kombi::AdvanceMatchState.call(
          table_monitor: @tm,
          shot_payload: @tm.data.fetch("current_bk2_shot_payload", {})
        )
      elsif @tm.data["free_game_form"] == "snooker"
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
        ba_results["Sets1"] =
          ba_results["Sets1"].to_i + 1
      end
      if game_set_result["Ergebnis1"].to_i < game_set_result["Ergebnis2"].to_i
        ba_results["Sets2"] =
          ba_results["Sets2"].to_i + 1
      end
      ba_results["Ergebnis1"] = ba_results["Ergebnis1"].to_i + game_set_result["Ergebnis1"]
      ba_results["Ergebnis2"] = ba_results["Ergebnis2"].to_i + game_set_result["Ergebnis2"]
      ba_results["Aufnahmen1"] = ba_results["Aufnahmen1"].to_i + game_set_result["Aufnahmen1"]
      ba_results["Aufnahmen2"] = ba_results["Aufnahmen2"].to_i + game_set_result["Aufnahmen2"]
      ba_results["Höchstserie1"] = [ba_results["Höchstserie1"].to_i, game_set_result["Höchstserie1"].to_i].max
      ba_results["Höchstserie2"] = [ba_results["Höchstserie2"].to_i, game_set_result["Höchstserie2"].to_i].max
      @tm.deep_merge_data!("ba_results" => ba_results)
    end
    game_set_result
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
    @tm.assign_attributes(state: "playing", panel_state: "pointer_mode", current_element: "pointer_mode")
    @tm.save!
  rescue => e
    Rails.logger.error "ERROR: m6[#{@tm.id}]#{e}, #{e.backtrace&.join("\n")}"
    raise StandardError
  end

  private

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

    if (@tm.playing? || @tm.set_over? || @tm.final_set_score? || @tm.final_match_score?) && @tm.end_of_set?
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
          @tm.current_element = "confirm_result"
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
        @tm.current_element = "confirm_result"
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
