class TableMonitorJob < ApplicationJob
  include CableReady::Broadcaster
  queue_as :default

  def perform(*args)
    debug = true # Rails.env != 'production'
    table_monitor = args[0]
    operation_type = args[1]
    
    # Performance timing
    job_start = Time.now.to_f
    broadcast_timestamp = (Time.now.to_f * 1000).to_i # Milliseconds since epoch
    
    Rails.logger.info "📡 ========== TableMonitorJob START =========="
    Rails.logger.info "📡 TableMonitor ID: #{table_monitor.id}"
    Rails.logger.info "📡 Operation Type: #{operation_type}"
    Rails.logger.info "📡 Stream: table-monitor-stream"
    Rails.logger.info "📡 Broadcast Timestamp: #{broadcast_timestamp}"
    
    # Reload and clear cache to ensure fresh data
    table_monitor.reload
    table_monitor.clear_options_cache
    
    Rails.logger.info "📡 Reloaded state: #{table_monitor.state}, game_id: #{table_monitor.game_id}"
    
    info = "perf +++++++!!!! C: PERFORM JOB #{Time.now} TM[#{table_monitor.id}]"
    Rails.logger.info info if debug
    case operation_type
    when "party_monitor_scores"
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
      cable_ready["table-monitor-stream"].inner_html(
        selector: "#party_monitor_scores_#{row_nr}",
        html: ApplicationController.render(
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
      )
      # cable_ready.broadcast
    when "teaser"
      render_start = Time.now.to_f
      selector = "#teaser_#{table_monitor.id}"
      Rails.logger.info "📡 Broadcasting teaser to location stream (for table_scores view)"
      
      rendered_html = ApplicationController.render(
        partial: "table_monitors/teaser",
        locals: { table_monitor: table_monitor }
      )
      render_time = ((Time.now.to_f - render_start) * 1000).round(2)
      Rails.logger.info "📡 Render time: #{render_time}ms"
      
      # Send to location-specific stream (for table_scores pages)
      location_id = table_monitor.table.location_id
      cable_ready["location-#{location_id}-stream"].inner_html(
        selector: selector,
        html: rendered_html,
      )
      # cable_ready.broadcast
    when "table_scores"
      render_start = Time.now.to_f
      selector = "#table_scores"
      Rails.logger.info "📡 Broadcasting table_scores to location stream"
      location = table_monitor.table.location
      
      rendered_html = ApplicationController.render(
        partial: "locations/table_scores",
        locals: { location: location, table_kinds: location.table_kinds }
      )
      render_time = ((Time.now.to_f - render_start) * 1000).round(2)
      Rails.logger.info "📡 Render time: #{render_time}ms"
      Rails.logger.info "📡 HTML size: #{rendered_html.bytesize} bytes, blank?: #{rendered_html.strip.empty?}"
      
      # Send to location-specific stream (for table_scores pages)
      cable_ready["location-#{location.id}-stream"].inner_html(
        selector: selector,
        html: rendered_html,
      )
    else
      # Default case: Full scoreboard update
      # Triggered by empty string "" from after_update_commit callback
      # Updates: #full_screen_table_monitor_{id} (active scoreboard view)
      # This ensures browsers viewing the scoreboard get updates even when
      # only teaser or table_scores jobs are enqueued based on change type.
      # See docs/EMPTY_STRING_JOB_ANALYSIS.md for detailed explanation.
      show = case table_monitor.data["free_game_form"]
             when "pool"
               "_pool"
             when "snooker"
               "_snooker"
             else
               ""
             end

      render_start = Time.now.to_f
      selector = "#full_screen_table_monitor_#{table_monitor.id}"
      Rails.logger.info "📡 Broadcasting scoreboard to table-monitor stream (for scoreboard view)"
      
      full_screen_html = ApplicationController.render(
        partial: "table_monitors/show#{show}",
        locals: { table_monitor: table_monitor, full_screen: true }
      )
      render_time = ((Time.now.to_f - render_start) * 1000).round(2)
      Rails.logger.info "📡 Render time: #{render_time}ms"
      Rails.logger.info "📡 HTML size: #{full_screen_html.bytesize} bytes"
      Rails.logger.info " ########### table_monitor#show id: #{table_monitor.andand.id} ###########" if debug

      cable_ready["table-monitor-stream"].inner_html(
        selector: selector,
        html: full_screen_html,
      )
      if table_monitor.tournament_monitor.present? && false
        html_current_games = ApplicationController.render(
          partial: "tournament_monitors/current_games",
          locals: { tournament_monitor: table_monitor.tournament_monitor }
        )
        cable_ready["table-monitor-stream"].inner_html(
          selector: "#tournament_monitor_current_games_#{table_monitor.tournament_monitor.id}",
          html: html_current_games
        )
        html = ApplicationController.render(
          partial: "table_monitors/show#{show}",
          locals: { table_monitor: table_monitor, full_screen: false }
        )
        cable_ready["table-monitor-stream"].inner_html(
          selector: "#table_monitor_#{table_monitor.id}",
          html: html
        )

      end
    end
    
    broadcast_start = Time.now.to_f
    Rails.logger.info "📡 Calling cable_ready.broadcast..."
    Rails.logger.info "📡 Enqueued operations: #{cable_ready.instance_variable_get(:@enqueued_operations).size rescue 'unknown'}"
    
    # Send timestamp as separate message first for performance measurement
    # Send to appropriate stream(s) based on operation type
    case operation_type
    when "teaser", "table_scores"
      # For table_scores view - send to location stream
      location_id = table_monitor.table.location_id
      ActionCable.server.broadcast(
        "location-#{location_id}-stream",
        {
          type: "performance_timestamp",
          timestamp: broadcast_timestamp,
          table_monitor_id: table_monitor.id,
          operation_type: operation_type
        }
      )
    else
      # For scoreboard view - send to table-monitor stream
      ActionCable.server.broadcast(
        "table-monitor-stream",
        {
          type: "performance_timestamp",
          timestamp: broadcast_timestamp,
          table_monitor_id: table_monitor.id,
          operation_type: operation_type
        }
      )
    end
    
    cable_ready.broadcast
    broadcast_time = ((Time.now.to_f - broadcast_start) * 1000).round(2)
    total_time = ((Time.now.to_f - job_start) * 1000).round(2)
    
    Rails.logger.info "📡 Broadcast time: #{broadcast_time}ms"
    Rails.logger.info "📡 Total job time: #{total_time}ms"
    Rails.logger.info "📡 Broadcast complete!"
    Rails.logger.info "📡 ========== TableMonitorJob END =========="
  end
end
