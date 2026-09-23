# frozen_string_literal: true

class GameProtocolReflex < ApplicationReflex
  # Game Protocol Modal Reflexes
  # Server-side modal management - modal state tracked by panel_state
  # Similar pattern to warmup/shootout/numbers modals

  before_reflex :load_table_monitor

  # Open protocol modal in view mode
  def open_protocol
    morph :nothing
    Rails.logger.debug { "🎯 GameProtocolReflex#open_protocol" }
    # Race-guard: stale-DOM click after set_game_over set protocol_final — re-render, do not downgrade
    if @table_monitor.panel_state == "protocol_final"
      send_modal_update(render_protocol_modal)
      return
    end
    @table_monitor.suppress_broadcast = true
    @table_monitor.panel_state = "protocol"
    @table_monitor.save!
    @table_monitor.suppress_broadcast = false
    send_modal_update(render_protocol_modal)
  end

  # Close protocol modal
  def close_protocol
    morph :nothing
    Rails.logger.debug { "🎯 GameProtocolReflex#close_protocol" }
    @table_monitor.suppress_broadcast = true
    @table_monitor.panel_state = "pointer_mode"
    @table_monitor.save!
    @table_monitor.suppress_broadcast = false
    send_modal_update("")
    TableMonitorJob.perform_later(@table_monitor.id, "")
  end

  # Plan 27-01: Zurueck ins laufende Spiel.
  #
  # Der Betreiber fand am Display: trifft eine Eingabe genau das Ballziel, endet das Spiel
  # sofort und der Protokoll-Editor ist eine Sackgasse. Korrigieren geht, weiterspielen nicht —
  # `confirm_result` ruft `evaluate_result`, und solange das Ergebnis das Spiel nicht beendet,
  # bleibt der Monitor in set_over, wo die before_save-Invariante protocol_final sofort wieder
  # herbeizwingt.
  #
  # ⚠️ `aasm.fire!(:undo)` und NICHT `@table_monitor.undo`: letzteres ist eine eigene Methode
  # (`table_monitor.rb:1482`), die das gleichnamige AASM-Ereignis UEBERSCHATTET und die letzte
  # EINGABE zuruecknimmt. Am Display belegt (2026-09-23): der Zustand blieb set_over, und
  # playera.result fiel von 21 auf 20. `aasm.fire!` spricht die Zustandsmaschine direkt an und
  # bleibt auch dann richtig, wenn jemand spaeter die Bang-Variante ebenfalls ueberschattet.
  # Test T6b haelt die Falle fest.
  #
  # ⚠️ Kein Setzen von `panel_state`. Die Invariante (`table_monitor.rb:662-668`) setzt
  # protocol_final auf pointer_mode, SOBALD set_over verlassen ist. Ein eigenes Setzen bliebe
  # wirkungslos, solange der Zustand noch set_over ist — genau daran scheiterte der erste
  # Entwurf dieses Plans.
  #
  # Die eingegebenen Punkte bleiben stehen; korrigiert wird danach mit den normalen
  # Bedienelementen.
  def back_to_game
    morph :nothing
    Rails.logger.info "[GameProtocolReflex#back_to_game] tm[#{@table_monitor.id}] " \
                      "state=#{@table_monitor.state} -> playing"

    @table_monitor.suppress_broadcast = true
    @table_monitor.aasm.fire!(:undo)
    @table_monitor.suppress_broadcast = false

    send_modal_update("")
    TableMonitorJob.perform_later(@table_monitor.id, "")
  end

  # Switch to edit mode
  def switch_to_edit_mode
    morph :nothing
    Rails.logger.debug { "🎯 GameProtocolReflex#switch_to_edit_mode" }
    # Race-guard: stale-DOM click after set_game_over set protocol_final — re-render, do not downgrade
    if @table_monitor.panel_state == "protocol_final"
      send_modal_update(render_protocol_modal)
      return
    end
    @table_monitor.suppress_broadcast = true
    @table_monitor.panel_state = "protocol_edit"
    @table_monitor.save!
    @table_monitor.suppress_broadcast = false
    send_modal_update(render_protocol_modal)
  end

  # Switch back to view mode (not used - we close directly now)
  def switch_to_view_mode
    morph :nothing
    Rails.logger.debug { "🎯 GameProtocolReflex#switch_to_view_mode" }
    # Race-guard: stale-DOM click after set_game_over set protocol_final — re-render, do not downgrade
    if @table_monitor.panel_state == "protocol_final"
      send_modal_update(render_protocol_modal)
      return
    end
    @table_monitor.suppress_broadcast = true
    @table_monitor.panel_state = "protocol"
    @table_monitor.save!
    @table_monitor.suppress_broadcast = false
    send_modal_update(render_protocol_modal)
  end

  # Increment points for a specific inning and player
  def increment_points
    morph :nothing
    inning_index = element.dataset['inning'].to_i
    player = element.dataset['player'] # 'playera' or 'playerb'

    Rails.logger.debug { "🎯 GameProtocolReflex#increment_points: inning=#{inning_index}, player=#{player}" }

    @table_monitor.suppress_broadcast = true
    @table_monitor.increment_inning_points(inning_index, player)
    @table_monitor.suppress_broadcast = false
    send_modal_morph(render_protocol_modal)
  end

  # Decrement points for a specific inning and player
  def decrement_points
    morph :nothing
    inning_index = element.dataset['inning'].to_i
    player = element.dataset['player'] # 'playera' or 'playerb'

    Rails.logger.debug { "🎯 GameProtocolReflex#decrement_points: inning=#{inning_index}, player=#{player}" }

    @table_monitor.suppress_broadcast = true
    @table_monitor.decrement_inning_points(inning_index, player)
    @table_monitor.suppress_broadcast = false
    send_modal_morph(render_protocol_modal)
  end

  # Delete an inning (only if both players have 0 points)
  def delete_inning
    morph :nothing
    inning_index = element.dataset['inning'].to_i

    Rails.logger.debug { "🎯 GameProtocolReflex#delete_inning: inning=#{inning_index}" }

    @table_monitor.suppress_broadcast = true
    result = @table_monitor.delete_inning(inning_index)
    @table_monitor.suppress_broadcast = false
    send_modal_morph(render_protocol_modal) if result[:success]
  end

  # Insert an empty inning before the specified index
  def insert_inning
    morph :nothing
    before_index = element.dataset['before'].to_i

    Rails.logger.debug { "🎯 GameProtocolReflex#insert_inning: before=#{before_index}" }

    @table_monitor.suppress_broadcast = true
    @table_monitor.insert_inning(before_index)
    @table_monitor.suppress_broadcast = false
    send_modal_morph(render_protocol_modal)
  end

  # Confirm the final result and close the protocol modal
  # This transitions the game to the final acknowledged state
  #
  # Phase 38.7 Plan 06 D-08: when current_element=='tiebreak_winner_choice', the
  # form serializes a `tiebreak_winner` param (value 'playera' or 'playerb'). We
  # validate server-side and persist to game.data['tiebreak_winner'] BEFORE calling
  # evaluate_result so update_ba_results_with_set_result! (Plan 05) can read it.
  def confirm_result
    morph :nothing
    Rails.logger.debug { "🎯 GameProtocolReflex#confirm_result params=#{params.to_unsafe_h.except("authenticity_token").inspect}" }

    # Phase 38.7 Plan 06 D-08: tiebreak winner persistence + server-side guard.
    if @table_monitor.current_element == "tiebreak_winner_choice"
      tw = params[:tiebreak_winner].to_s
      unless %w[playera playerb].include?(tw)
        Rails.logger.warn "[GameProtocolReflex#confirm_result] Tiebreak required but invalid/missing tiebreak_winner=#{tw.inspect}; refusing to advance state"
        send_modal_update(render_protocol_modal)
        return
      end
      if @table_monitor.game.present?
        # Phase 38.7 Plan 06 D-08 (Rule 1 deviation, same root cause as Plan 04):
        # Game#data returns a freshly-decoded Hash on every call, so direct mutation
        # does NOT dirty-track. Use deep_merge_data! which calls data_will_change!
        # and reassigns self.data so save! persists correctly.
        @table_monitor.game.deep_merge_data!("tiebreak_winner" => tw)
        @table_monitor.game.save!
        Rails.logger.info "[GameProtocolReflex#confirm_result] tiebreak_winner=#{tw} persisted to Game[#{@table_monitor.game.id}].data"
      end
    end

    # Close the modal first
    send_modal_update("")

    # Advance the game flow (state transition via ResultRecorder). Leaving set_over
    # releases the protocol_final panel through the before_save invariant
    # (enforce_protocol_final_panel_at_set_over) — no manual panel_state reset needed
    # here; the earlier in-set_over reset was clobbered by that same invariant.
    @table_monitor.evaluate_result

    # Broadcast the updated scoreboard
    TableMonitorJob.perform_later(@table_monitor.id, "")
  end

  # Snooker Inning Edit Methods

  def open_snooker_inning_edit
    morph :nothing
    return unless @table_monitor.data["free_game_form"] == "snooker"

    inning_index = element.dataset['inning'].to_i
    player = element.dataset['player'] # 'playera' or 'playerb'

    Rails.logger.debug { "🎯 GameProtocolReflex#open_snooker_inning_edit: inning=#{inning_index}, player=#{player}, current_panel_state=#{@table_monitor.panel_state}" }

    # Get current balls for this inning
    history = @table_monitor.innings_history
    player_data = player == 'playera' ? history[:player_a] : history[:player_b]
    current_balls = player_data[:break_balls][inning_index] || []

    Rails.logger.debug { "🎯 Current balls for inning #{inning_index}: #{current_balls.inspect}" }

    # Store edit state
    @table_monitor.data["snooker_inning_edit"] = {
      "inning_index" => inning_index,
      "player" => player,
      "balls" => current_balls
    }

    # Store previous panel state to restore after edit
    @table_monitor.data["previous_panel_state"] = @table_monitor.panel_state

    @table_monitor.suppress_broadcast = true
    @table_monitor.panel_state = "snooker_inning_edit"
    @table_monitor.data_will_change!
    @table_monitor.save!
    @table_monitor.suppress_broadcast = false

    Rails.logger.debug { "🎯 Panel state changed to: #{@table_monitor.panel_state}" }

    TableMonitorJob.perform_later(@table_monitor.id, "")
  end

  def add_ball_to_edit
    morph :nothing
    return unless @table_monitor.data["free_game_form"] == "snooker"

    ball_value = element.dataset['ball'].to_i
    edit_data = @table_monitor.data["snooker_inning_edit"] || {}
    balls = edit_data["balls"] || []
    balls << ball_value
    edit_data["balls"] = balls

    @table_monitor.data["snooker_inning_edit"] = edit_data
    @table_monitor.data_will_change!
    @table_monitor.save!

    TableMonitorJob.perform_later(@table_monitor.id, "")
  end

  def remove_ball_from_edit
    morph :nothing
    return unless @table_monitor.data["free_game_form"] == "snooker"

    index = element.dataset['index'].to_i
    edit_data = @table_monitor.data["snooker_inning_edit"] || {}
    balls = edit_data["balls"] || []
    balls.delete_at(index) if index < balls.length
    edit_data["balls"] = balls

    @table_monitor.data["snooker_inning_edit"] = edit_data
    @table_monitor.data_will_change!
    @table_monitor.save!

    TableMonitorJob.perform_later(@table_monitor.id, "")
  end

  def clear_balls_in_edit
    morph :nothing
    return unless @table_monitor.data["free_game_form"] == "snooker"

    edit_data = @table_monitor.data["snooker_inning_edit"] || {}
    edit_data["balls"] = []

    @table_monitor.data["snooker_inning_edit"] = edit_data
    @table_monitor.data_will_change!
    @table_monitor.save!

    TableMonitorJob.perform_later(@table_monitor.id, "")
  end

  def cancel_snooker_inning_edit
    morph :nothing
    return unless @table_monitor.data["free_game_form"] == "snooker"

    Rails.logger.debug { "🎯 GameProtocolReflex#cancel_snooker_inning_edit" }

    # Restore previous panel state
    previous_state = @table_monitor.data["previous_panel_state"] || "protocol_edit"

    # Clear edit state
    @table_monitor.data.delete("snooker_inning_edit")
    @table_monitor.data.delete("previous_panel_state")
    @table_monitor.suppress_broadcast = true
    @table_monitor.panel_state = previous_state
    @table_monitor.data_will_change!
    @table_monitor.save!
    @table_monitor.suppress_broadcast = false

    Rails.logger.debug { "🎯 Restored panel state to: #{previous_state}" }

    TableMonitorJob.perform_later(@table_monitor.id, "")
  end

  def save_snooker_inning_edit
    morph :nothing
    return unless @table_monitor.data["free_game_form"] == "snooker"

    edit_data = @table_monitor.data["snooker_inning_edit"]
    return unless edit_data

    inning_index = edit_data["inning_index"]
    player = edit_data["player"]
    new_balls = edit_data["balls"] || []

    Rails.logger.debug { "💾 Saving snooker inning edit: player=#{player}, inning=#{inning_index}, balls=#{new_balls.inspect}" }

    # Calculate new points from balls
    balls_points = new_balls.sum

    # Check if this inning has a pending foul (not yet completed)
    has_pending_foul = @table_monitor.data[player]["pending_foul"].present?

    if has_pending_foul
      # This is an ACTIVE inning with foul points waiting to be finalized
      # Update innings_redo_list (current break), NOT innings_list
      foul_points = @table_monitor.data[player]["pending_foul"]["points"].to_i
      total_points = balls_points + foul_points

      @table_monitor.data[player]["innings_redo_list"] ||= [0]
      @table_monitor.data[player]["innings_redo_list"][-1] = total_points

      # Update break_balls_redo_list (current break balls)
      @table_monitor.data[player]["break_balls_redo_list"] ||= [[]]
      @table_monitor.data[player]["break_balls_redo_list"][-1] = new_balls

      # Don't touch innings_list or break_balls_list - inning not yet completed
      Rails.logger.debug { "💾 Updated ACTIVE inning (with pending foul): balls=#{balls_points}, foul=#{foul_points}, total=#{total_points}" }
    else
      # This is a COMPLETED inning - update innings_list normally
      @table_monitor.data[player]["break_balls_list"] ||= []
      @table_monitor.data[player]["break_balls_list"][inning_index] = new_balls

      # CRITICAL: Ensure break_fouls_list has matching length with nil entries
      @table_monitor.data[player]["break_fouls_list"] ||= []
      while @table_monitor.data[player]["break_fouls_list"].length <= inning_index
        @table_monitor.data[player]["break_fouls_list"] << nil
      end
      @table_monitor.data[player]["break_fouls_list"][inning_index] = nil

      # Update innings_list
      @table_monitor.data[player]["innings_list"] ||= []
      @table_monitor.data[player]["innings_list"][inning_index] = balls_points

      # Recalculate result (sum of all completed innings)
      @table_monitor.data[player]["result"] = @table_monitor.data[player]["innings_list"].compact.sum

      # Recalculate innings count (number of completed innings)
      @table_monitor.data[player]["innings"] = @table_monitor.data[player]["innings_list"].compact.size

      # Update HS (high score) if this inning is higher
      current_hs = @table_monitor.data[player]["hs"].to_i
      @table_monitor.data[player]["hs"] = [current_hs, balls_points].max

      Rails.logger.debug { "💾 Updated COMPLETED inning: balls=#{balls_points}" }
    end

    # Restore previous panel state
    previous_state = @table_monitor.data["previous_panel_state"] || "protocol_edit"

    # Clear edit state
    @table_monitor.data.delete("snooker_inning_edit")
    @table_monitor.data.delete("previous_panel_state")
    @table_monitor.suppress_broadcast = true
    @table_monitor.panel_state = previous_state
    @table_monitor.data_will_change!
    @table_monitor.save!
    @table_monitor.suppress_broadcast = false

    Rails.logger.debug { "💾 Saved and restored panel state to: #{previous_state}" }

    # Refresh protocol table body only
    send_modal_morph(render_protocol_modal)
    TableMonitorJob.perform_later(@table_monitor.id, "")
  end

  private

  def load_table_monitor
    # Read from data-id attribute (standard for all reflexes)
    table_monitor_id = element.dataset['id']
    Rails.logger.debug { "🔍 Loading TableMonitor ##{table_monitor_id}" }
    @table_monitor = TableMonitor.find(table_monitor_id)
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "❌ TableMonitor not found: #{table_monitor_id}"
    raise e
  end

  def render_protocol_modal
    return "" unless @table_monitor.protocol_modal_should_be_open?

    ApplicationController.render(
      partial: "table_monitors/game_protocol_modal",
      locals: {
        table_monitor: @table_monitor,
        full_screen: true,
        modal_hidden: false
      }
    )
  end

  # Plan 25-02 (2026-09-23): Eine Aenderung im Protokoll muss auch KOPF und KNOPF erreichen,
  # nicht nur die Tabelle. Bis hierher riefen increment/decrement/delete/insert_inning
  # `send_table_update`, das ausschliesslich `#protocol-tbody-<id>` ersetzt — Kopf (Z. 42) und
  # Fuss (Z. 167) liegen ausserhalb und blieben stehen.
  #
  # Vorher war das eine stille Veraltung im Kopf. Seit Plan 25-01 traegt der Bestaetigungsknopf
  # das Ergebnis, und damit wurde daraus eine FALSCHAUSSAGE am Entscheidungsort: der Knopf
  # behauptete "21:30 / Sieger: Lüdemann", waehrend die Daten 21:28 trugen (Betreiber am
  # Display, 2026-09-23). Das ist die Umkehrung dessen, was Plan 25-01 erreichen wollte.
  #
  # `morph` statt `inner_html`: morphdom patcht in-place, statt Elemente zu ersetzen. Der
  # Scroll-Container der Protokolltabelle (`.protocol-table-container`, `overflow-y-auto`,
  # Z. 127) bleibt dasselbe DOM-Element und behaelt seine Scrollposition — bei einem langen
  # Protokoll klickt man `+`/`-` wiederholt, ein Sprung nach oben bei jedem Klick waere ein
  # eigener Bedienfehler.
  # ⚠️ `children_only: true` ist NICHT optional. `cable_ready.js:786` ruft
  # `morphdom(element, childrenOnly ? template.content : template.innerHTML, {childrenOnly: ...})`
  # — ohne das Flag morpht morphdom das ELEMENT SELBST in die gelieferte Wurzel, der Container
  # `#protocol-modal-container-<id>` wird also zu `<div id="game-protocol-modal">` und verliert
  # seine id. Jede spaetere Zustellung an diesen Selektor trifft danach ins Leere. Am Display
  # belegt (2026-09-23): Editieren sprang in die TableMonitor-Ansicht, und erst ein Reload
  # brachte den Editor mit den richtigen Werten zurueck.
  def send_modal_morph(html)
    return if html.blank?

    CableReady::Channels.instance["table-monitor-stream"].morph(
      selector: "#protocol-modal-container-#{@table_monitor.id}",
      children_only: true,
      html: html
    ).broadcast
  end

  def send_modal_update(html)
    CableReady::Channels.instance["table-monitor-stream"].inner_html(
      selector: "#protocol-modal-container-#{@table_monitor.id}",
      html: html
    ).broadcast
  end
end
