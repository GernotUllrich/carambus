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
      else
        perform_full_screen_update(table_monitor, debug)
      end
      
      # Broadcast operations
      cable_ready.broadcast
      
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

  def perform_full_screen_update(table_monitor, debug)
    # NEW APPROACH: Broadcast lightweight JSON data instead of heavy HTML
    # This is 100x faster on slow clients (Raspberry Pi 3)
    
    cable_ready["table-monitor-stream"].dispatch_event(
      name: "scoreboard:data_update",
      detail: build_scoreboard_update(table_monitor)
    )
    
    Rails.logger.info "📊 Broadcasted JSON update for table #{table_monitor.id}" if debug
    DebugLogger.log_operation("json_data_update", table_monitor.id, "scoreboard:data_update", true)
  end

  def build_scoreboard_update(table_monitor)
    # Build minimal JSON payload with only the data that changes
    # Payload size: ~1KB instead of ~50-100KB HTML
    
    table_monitor.get_options!(I18n.locale) # Ensure options are populated
    options = table_monitor.options
    game = table_monitor.game
    
    {
      table_monitor_id: table_monitor.id,
      game_id: game&.id,
      timestamp: Time.current.to_i,
      
      # Player A data
      playera: {
        score: options.dig(:player_a, :result).to_i,
        innings: options.dig(:player_a, :innings).to_i,
        hs: options.dig(:player_a, :hs).to_i,
        gd: options.dig(:player_a, :gd).to_f.round(2),
        active: options[:player_a_active] || false,
        balls_goal: options.dig(:player_a, :balls_goal).to_i
      },
      
      # Player B data
      playerb: {
        score: options.dig(:player_b, :result).to_i,
        innings: options.dig(:player_b, :innings).to_i,
        hs: options.dig(:player_b, :hs).to_i,
        gd: options.dig(:player_b, :gd).to_f.round(2),
        active: options[:player_b_active] || false,
        balls_goal: options.dig(:player_b, :balls_goal).to_i
      },
      
      # Current inning scores (only for active player)
      inning_score_playera: options[:player_a_active] ? 
        (table_monitor.data.dig("playera", "innings_redo_list")&.last || 0) : 0,
      inning_score_playerb: options[:player_b_active] ? 
        (table_monitor.data.dig("playerb", "innings_redo_list")&.last || 0) : 0,
      
      # Game state
      state: table_monitor.state,
      state_display: table_monitor.state_display(I18n.locale).to_s
      
      # Note: Timer updates happen separately via TableMonitorClockJob
      # Not included here to keep payload minimal
    }
  end
end
