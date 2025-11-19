class TableMonitorJob < ApplicationJob
  include CableReady::Broadcaster
  queue_as :default

  # Debug infrastructure for TableMonitor operations
  class DebugLogger
    def self.log_operation(operation_type, table_monitor_id, selector, success, error = nil)
      timestamp = Time.current.strftime("%H:%M:%S.%3N")
      status = success ? "✅" : "❌"
      Rails.logger.info "#{status} [#{timestamp}] #{operation_type} TM[#{table_monitor_id}] -> #{selector}"
      
      if error
        Rails.logger.error "   Error: #{error.message}" if error.respond_to?(:message)
        Rails.logger.error "   Backtrace: #{error.backtrace.first(3).join(', ')}" if error.respond_to?(:backtrace)
      end
    end

    def self.log_dom_check(selector, exists)
      status = exists ? "✅" : "⚠️"
      Rails.logger.info "#{status} DOM Check: #{selector} #{exists ? 'exists' : 'missing'}"
    end
  end

  def perform(*args)
    debug = true # Rails.env != 'production'
    table_monitor = args[0]
    operation_type = args[1] || 'unknown'
    
    # WICHTIG: Reload from DB to get latest changes (especially after protocol edits!)
    table_monitor.reload
    
    # KRITISCH: Cache leeren, damit get_options! die aktuellen Daten verwendet!
    table_monitor.clear_options_cache
    
    info = "🚀 [#{Time.current.strftime("%H:%M:%S.%3N")}] PERFORM JOB #{operation_type} TM[#{table_monitor.id}]"
    Rails.logger.info info if debug
    
    # Track job performance
    start_time = Time.current
    begin
      case args[1]
      when "party_monitor_scores"
        perform_party_monitor_scores(table_monitor, debug)
      when "teaser"
        perform_teaser_update(table_monitor, debug)
      when "table_scores"
        perform_table_scores_update(table_monitor, debug)
      when "score_update"
        # Häufig: Nur Scores geändert (add_score, minus_n)
        perform_score_update(table_monitor, debug)
      when "player_switch"
        # Mittel: Spielerwechsel (next_step)
        perform_player_switch_update(table_monitor, debug)
      when "state_change"
        # Gelegentlich: Spielzustand geändert (start_game, end_of_set)
        perform_state_change_update(table_monitor, debug)
      when "full_screen"
        # Selten: Komplettes Scoreboard neu (komplexe Änderungen)
        perform_full_screen_update(table_monitor, debug)
      when "", nil
        # Leerer Job aus after_update_commit - ignorieren, da Reflexes eigene Jobs triggern
        Rails.logger.info "⏭️ Skipping empty job (triggered by callback)" if debug
      else
        # Fallback: Bei unbekanntem Typ → full_screen
        Rails.logger.warn "⚠️ Unknown job type '#{args[1]}' - falling back to full_screen"
        perform_full_screen_update(table_monitor, debug)
      end
      
      # Broadcast operations
      # Note: CableReady stores operations per channel (e.g., cable_ready["table-monitor-stream"])
      # We need to broadcast to actually send the queued operations to clients
      begin
        cable_ready.broadcast
        Rails.logger.info "✅ CableReady broadcast complete!" if debug
      rescue => e
        Rails.logger.error "💥 CableReady broadcast failed: #{e.message}"
        Rails.logger.error "   Backtrace: #{e.backtrace.first(3).join(', ')}"
      end
      
      # Log performance metrics
      duration = ((Time.current - start_time) * 1000).round(2)
      Rails.logger.info "⏱️ Job completed in #{duration}ms" if debug
      
    rescue StandardError => e
      Rails.logger.error "💥 TableMonitorJob failed: #{e.message}"
      Rails.logger.error "   Backtrace: #{e.backtrace.first(5).join(', ')}"
      DebugLogger.log_operation(operation_type, table_monitor.id, 'unknown', false, e)
      raise e
    end
  end

  private

  def perform_party_monitor_scores(table_monitor, debug)
    selector = "#party_monitor_scores_#{table_monitor.data['row_nr']}"
    DebugLogger.log_dom_check(selector, true) # Assume exists for now
    
    row = table_monitor.data["row"]
    r_no = table_monitor.game.andand.round_no
    row_nr = table_monitor.data["row_nr"]
    t_no = table_monitor.data["t_no"] + 1
    party_monitor = table_monitor.tournament_monitor
    party = party_monitor.party
    league = party.league
    assigned_players_a_ids = party_monitor.data["assigned_players_a_ids"]
    assigned_players_b_ids = party_monitor.data["assigned_players_b_ids"]

    available_fitting_table_ids = party.location.andand.tables.andand.joins(table_kind: :disciplines).andand.where(disciplines: { id: league.discipline_id }).andand.order("name").andand.map(&:id).to_a

    players = GameParticipation.joins(:game).joins("left outer join parties on parties.id = games.tournament_id")
                               .where(games: { tournament_id: party.id, tournament_type: "Party" }).map(&:player).uniq
    players_hash = players.each_with_object({}) do |player, memo|
      memo[player.id] = player
    end
    table_ids = Array(party_monitor.data["table_ids"].andand[r_no - 1])
    
    html = ApplicationController.render(
      partial: "party_monitors/game_row",
      locals: {
        rendered_from: "TableMonitorJob",
        row: row,
        r_no: r_no,
        row_nr: row_nr,
        t_no: t_no,
        table_ids: table_ids,
        players_hash: players_hash,
        party_monitor: party_monitor,
        assigned_players_a_ids: assigned_players_a_ids,
        assigned_players_b_ids: assigned_players_b_ids,
        available_fitting_table_ids: available_fitting_table_ids
      }
    )
    
    cable_ready["table-monitor-stream"].inner_html(selector: selector, html: html)
    DebugLogger.log_operation("party_monitor_scores", table_monitor.id, selector, true)
  end

  def perform_teaser_update(table_monitor, debug)
    selector = "#teaser_#{table_monitor.id}"
    DebugLogger.log_dom_check(selector, true) # Assume exists for now
    
    html = ApplicationController.render(
      partial: "table_monitors/teaser",
      locals: { table_monitor: table_monitor }
    )
    
    cable_ready["table-monitor-stream"].inner_html(selector: selector, html: html)
    DebugLogger.log_operation("teaser", table_monitor.id, selector, true)
  end

  def perform_table_scores_update(table_monitor, debug)
    selector = "#table_scores"
    DebugLogger.log_dom_check(selector, true) # Assume exists for now
    
    html = ApplicationController.render(
      partial: "locations/table_scores",
      locals: { table_monitor: table_monitor, table_kinds: table_monitor.table.location.table_kinds }
    )
    
    cable_ready["table-monitor-stream"].inner_html(selector: selector, html: html)
    DebugLogger.log_operation("table_scores", table_monitor.id, selector, true)
  end

  # ========================================================================
  # FAST JSON UPDATES (kein HTML-Morphing, direkte DOM-Updates)
  # ========================================================================
  
  def perform_score_update(table_monitor, debug)
    # Häufigster Fall: Nur Score-Werte haben sich geändert
    # → Mini-JSON mit nur den nötigsten Daten
    data = build_minimal_score_data(table_monitor)
    
    ActionCable.server.broadcast(
      "table-monitor-stream",
      {
        type: "score_update",
        table_monitor_id: table_monitor.id,
        data: data
      }
    )
    
    Rails.logger.info "⚡ Score update (JSON) for table #{table_monitor.id}" if debug
    DebugLogger.log_operation("score_update", table_monitor.id, "score_update", true)
  end
  
  def perform_player_switch_update(table_monitor, debug)
    # Spielerwechsel: Scores + aktiver Spieler + ggf. Farben
    data = build_player_switch_data(table_monitor)
    
    ActionCable.server.broadcast(
      "table-monitor-stream",
      {
        type: "player_switch",
        table_monitor_id: table_monitor.id,
        data: data
      }
    )
    
    Rails.logger.info "🔄 Player switch (JSON) for table #{table_monitor.id}" if debug
    DebugLogger.log_operation("player_switch", table_monitor.id, "player_switch", true)
  end
  
  def perform_state_change_update(table_monitor, debug)
    # Spielzustand geändert: Vollständige Daten, aber als JSON
    data = build_full_scoreboard_data(table_monitor)
    
    ActionCable.server.broadcast(
      "table-monitor-stream",
      {
        type: "state_change",
        table_monitor_id: table_monitor.id,
        data: data
      }
    )
    
    Rails.logger.info "🎮 State change (JSON) for table #{table_monitor.id}" if debug
    DebugLogger.log_operation("state_change", table_monitor.id, "state_change", true)
  end
  
  def perform_full_screen_update(table_monitor, debug)
    # Seltener Fall: Komplettes Scoreboard neu rendern
    # → HTML via inner_html (KEIN Morphing! Direkter Austausch!)
    
    Rails.logger.info "🔍 FULL_SCREEN START: TM[#{table_monitor.id}] updated_at=#{table_monitor.updated_at}" if debug
    Rails.logger.info "🔍 FULL_SCREEN: playera result=#{table_monitor.data['playera']['result']}, innings_list=#{table_monitor.data['playera']['innings_list']&.inspect}" if debug
    Rails.logger.info "🔍 FULL_SCREEN: playerb result=#{table_monitor.data['playerb']['result']}, innings_list=#{table_monitor.data['playerb']['innings_list']&.inspect}" if debug
    Rails.logger.info "🔍 FULL_SCREEN: panel_state=#{table_monitor.panel_state}" if debug
    
    # Render HTML (ja, mit DB-Abfragen - aber das passiert selten)
    Rails.logger.info "🔍 FULL_SCREEN: About to render partial..." if debug
    html = ApplicationController.render(
      partial: "table_monitors/scoreboard",
      locals: { 
        table_monitor: table_monitor, 
        fullscreen: true 
      }
    )
    
    Rails.logger.info "🔍 FULL_SCREEN: Rendered HTML length: #{html.length} bytes" if debug
    
    # inner_html statt morph → schneller, kein CPU-intensives Diffing
    selector = "#full_screen_table_monitor_#{table_monitor.id}"
    Rails.logger.info "🔍 FULL_SCREEN: About to broadcast to table-monitor-stream, selector: #{selector}" if debug
    
    cable_ready["table-monitor-stream"].inner_html(
      selector: selector,
      html: html
    )
    
    Rails.logger.info "🖼️ Full screen refresh (HTML inner_html) queued for table #{table_monitor.id}, selector: #{selector}" if debug
    Rails.logger.info "🔍 FULL_SCREEN: CableReady operations count: #{cable_ready['table-monitor-stream'].instance_variable_get(:@enqueued_operations)&.size || 0}" if debug
    Rails.logger.info "🔍 FULL_SCREEN: cable_ready operations count: #{cable_ready.instance_variable_get(:@enqueued_operations)&.size || 0}" if debug
    DebugLogger.log_operation("full_screen_html", table_monitor.id, selector, true)
  end

  # ========================================================================
  # DATA BUILDERS - Verschiedene Detail-Level für verschiedene Update-Typen
  # ========================================================================
  
  def build_minimal_score_data(table_monitor)
    # MINIMAL: Nur die Zahlen, die sich bei Score-Updates ändern
    # Perfekt für: add_score, minus_n
    # Payload: ~200 Bytes
    
    table_monitor.get_options!(I18n.locale)
    options = table_monitor.options
    
    {
      playera: {
        score: options.dig(:player_a, :result).to_i,
        innings: options.dig(:player_a, :innings).to_i,
        hs: options.dig(:player_a, :hs).to_i,
        gd: options.dig(:player_a, :gd).to_f.round(2),
        inning_score: table_monitor.data.dig("playera", "innings_redo_list")&.last || 0
      },
      playerb: {
        score: options.dig(:player_b, :result).to_i,
        innings: options.dig(:player_b, :innings).to_i,
        hs: options.dig(:player_b, :hs).to_i,
        gd: options.dig(:player_b, :gd).to_f.round(2),
        inning_score: table_monitor.data.dig("playerb", "innings_redo_list")&.last || 0
      }
    }
  end
  
  def build_player_switch_data(table_monitor)
    # MITTEL: Scores + aktiver Spieler + Layout-Info
    # Perfekt für: next_step, switch_players
    # Payload: ~500 Bytes
    
    table_monitor.get_options!(I18n.locale)
    options = table_monitor.options
    
    {
      playera: {
        score: options.dig(:player_a, :result).to_i,
        innings: options.dig(:player_a, :innings).to_i,
        hs: options.dig(:player_a, :hs).to_i,
        gd: options.dig(:player_a, :gd).to_f.round(2),
        active: options[:player_a_active] || false,
        inning_score: table_monitor.data.dig("playera", "innings_redo_list")&.last || 0
      },
      playerb: {
        score: options.dig(:player_b, :result).to_i,
        innings: options.dig(:player_b, :innings).to_i,
        hs: options.dig(:player_b, :hs).to_i,
        gd: options.dig(:player_b, :gd).to_f.round(2),
        active: options[:player_b_active] || false,
        inning_score: table_monitor.data.dig("playerb", "innings_redo_list")&.last || 0
      },
      left_player: options[:current_left_player],
      left_color: options[:current_left_color],
      right_color: options[:current_right_color]
    }
  end
  
  def build_full_scoreboard_data(table_monitor)
    # KOMPLETT: Alle Daten (aber immer noch als JSON, kein HTML!)
    # Perfekt für: start_game, end_of_set, state changes
    # Payload: ~1KB
    
    table_monitor.get_options!(I18n.locale)
    options = table_monitor.options
    game = table_monitor.game
    
    {
      table_monitor_id: table_monitor.id,
      game_id: game&.id,
      timestamp: Time.current.to_i,
      
      playera: {
        name: options.dig(:player_a, :fullname),
        score: options.dig(:player_a, :result).to_i,
        innings: options.dig(:player_a, :innings).to_i,
        hs: options.dig(:player_a, :hs).to_i,
        gd: options.dig(:player_a, :gd).to_f.round(2),
        active: options[:player_a_active] || false,
        balls_goal: options.dig(:player_a, :balls_goal).to_i,
        inning_score: table_monitor.data.dig("playera", "innings_redo_list")&.last || 0
      },
      
      playerb: {
        name: options.dig(:player_b, :fullname),
        score: options.dig(:player_b, :result).to_i,
        innings: options.dig(:player_b, :innings).to_i,
        hs: options.dig(:player_b, :hs).to_i,
        gd: options.dig(:player_b, :gd).to_f.round(2),
        active: options[:player_b_active] || false,
        balls_goal: options.dig(:player_b, :balls_goal).to_i,
        inning_score: table_monitor.data.dig("playerb", "innings_redo_list")&.last || 0
      },
      
      left_player: options[:current_left_player],
      left_color: options[:current_left_color],
      right_color: options[:current_right_color],
      
      state: table_monitor.state,
      state_display: table_monitor.state_display(I18n.locale).to_s,
      
      sets_a: table_monitor.data["current_sets_a"] || 0,
      sets_b: table_monitor.data["current_sets_b"] || 0
    }
  end
end
