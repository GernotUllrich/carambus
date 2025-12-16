class TableMonitorJob < ApplicationJob
  include CableReady::Broadcaster
  queue_as :default

  def perform(*args)
    # Skip execution on API Server (no scoreboards running)
    # Local servers are identified by having a carambus_api_url configured
    unless ApplicationRecord.local_server?
      Rails.logger.info "📡 TableMonitorJob skipped (API Server - no scoreboards)"
      return
    end

    debug = true # Rails.env != 'production'
    table_monitor = args[0]
    operation_type = args[1]
    options = args[2] || {}
    
    # Performance timing
    job_start = Time.now.to_f
    broadcast_timestamp = (Time.now.to_f * 1000).to_i # Milliseconds since epoch
    
    Rails.logger.info "📡 ========== TableMonitorJob START =========="
    Rails.logger.info "📡 TableMonitor ID: #{table_monitor.id}"
    Rails.logger.info "📡 Table ID: #{table_monitor.table&.id}"
    Rails.logger.info "📡 Location ID: #{table_monitor.table&.location&.id}"
    Rails.logger.info "📡 Operation Type: #{operation_type}"
    Rails.logger.info "📡 Options: #{options.inspect}" if options.present?
    Rails.logger.info "📡 Stream: table-monitor-stream (SHARED - clients filter by table_monitor_id)"
    Rails.logger.info "📡 Broadcast Timestamp: #{broadcast_timestamp}"
    
    # Reload and clear cache to ensure fresh data
    # Transaction wrapper in do_placement ensures this doesn't pull stale data
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
      Rails.logger.info "📡 Broadcasting teaser to table-monitor-stream (filtered by client)"
      
      rendered_html = ApplicationController.render(
        partial: "table_monitors/teaser",
        locals: { table_monitor: table_monitor }
      )
      render_time = ((Time.now.to_f - render_start) * 1000).round(2)
      Rails.logger.info "📡 Render time: #{render_time}ms"
      
      # Send to table-monitor-stream (client will ignore if element doesn't exist)
      cable_ready["table-monitor-stream"].inner_html(
        selector: selector,
        html: rendered_html,
      )
      # cable_ready.broadcast
    when "table_scores"
      render_start = Time.now.to_f
      selector = "#table_scores"
      Rails.logger.info "📡 Broadcasting table_scores to table-monitor-stream (filtered by client)"
      location = table_monitor.table.location
      
      rendered_html = ApplicationController.render(
        partial: "locations/table_scores",
        locals: { location: location, table_kinds: location.table_kinds }
      )
      render_time = ((Time.now.to_f - render_start) * 1000).round(2)
      Rails.logger.info "📡 Render time: #{render_time}ms"
      Rails.logger.info "📡 HTML size: #{rendered_html.bytesize} bytes, blank?: #{rendered_html.strip.empty?}"
      
      # Send to table-monitor-stream (client will ignore if element doesn't exist)
      cable_ready["table-monitor-stream"].inner_html(
        selector: selector,
        html: rendered_html,
      )
    when "score_data"
      # ULTRA-FAST PATH: Send only JSON data for score update
      # No HTML rendering - JavaScript updates DOM directly
      player_key = options[:player]
      
      # Get fresh data
      table_monitor.get_options!(I18n.locale)
      player_option = player_key == "playera" ? table_monitor.options[:player_a] : table_monitor.options[:player_b]
      
      # Calculate current score
      innings_redo_list = table_monitor.data[player_key]["innings_redo_list"] || []
      current_inning = innings_redo_list.last || 0
      total_score = player_option[:result].to_i + current_inning
      
      # Send minimal JSON data (keys will be camelCased by CableReady)
      data = {
        tableMonitorId: table_monitor.id,
        playerKey: player_key,
        score: total_score,
        inning: current_inning
      }
      
      # Broadcast as dispatchEvent (custom event that JavaScript can listen to)
      cable_ready["table-monitor-stream"].dispatch_event(
        name: "score:update",
        detail: data
      )
      
      # Broadcast immediately (don't wait for batching at end of job)
      cable_ready.broadcast
      
      # Exit early to prevent double broadcast
      return
    when "player_score_panel"
      # FAST PATH: Targeted player panel update
      # Only renders and sends one player's panel (~10KB instead of ~100KB)
      # Uses morph for efficient DOM updates
      player_key = options[:player]
      
      Rails.logger.info "📡 ⚡ FAST PATH: Broadcasting player panel update for #{player_key}"
      
      render_start = Time.now.to_f
      # Target the wrapper div, not the panel itself
      selector = "#player_score_wrapper_#{player_key}_#{table_monitor.id}"
      
      begin
        # Ensure fresh options are loaded before rendering
        # Get options and pass as local to avoid race condition (options is cattr_accessor)
        table_monitor.get_options!(I18n.locale)
        options_snapshot = table_monitor.options.dup
        
        # Render ONLY the changed player's panel (without wrapper - wrapper is in scoreboard)
        player_panel_html = ApplicationController.render(
          partial: "table_monitors/player_score_panel",
          locals: { 
            table_monitor: table_monitor,
            player_key: player_key,
            fullscreen: true,
            options: options_snapshot
          }
        )
        
        render_time = ((Time.now.to_f - render_start) * 1000).round(2)
        Rails.logger.info "📡 ⚡ Render time: #{render_time}ms"
        Rails.logger.info "📡 ⚡ HTML size: #{player_panel_html.bytesize} bytes (vs ~100KB for full scoreboard)"
        Rails.logger.info "📡 ⚡ HTML blank?: #{player_panel_html.strip.empty?}"
        Rails.logger.info "📡 ⚡ HTML preview: #{player_panel_html[0..200]}" if debug
        
        # Use inner_html to replace the wrapper's content
        cable_ready["table-monitor-stream"].inner_html(
          selector: selector,
          html: player_panel_html,
        )
      rescue => e
        Rails.logger.error "📡 ⚡ ERROR rendering player panel: #{e.message}"
        Rails.logger.error "📡 ⚡ Backtrace: #{e.backtrace.first(5).join("\n")}"
        # Fallback to full update
        show = case table_monitor.data["free_game_form"]
               when "pool" then "_pool"
               when "snooker" then "_snooker"
               else ""
               end
        full_screen_html = ApplicationController.render(
          partial: "table_monitors/show#{show}",
          locals: { table_monitor: table_monitor, full_screen: true }
        )
        cable_ready["table-monitor-stream"].inner_html(
          selector: "#full_screen_table_monitor_#{table_monitor.id}",
          html: full_screen_html,
        )
      end
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
      Rails.logger.info "📡 ⚠️  FULL SCOREBOARD UPDATE: This will be sent to ALL clients via shared stream"
      Rails.logger.info "📡 ⚠️  Clients MUST filter by table_monitor_id=#{table_monitor.id} to prevent mix-ups"
      
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
    # Always send to table-monitor-stream (clients filter by DOM presence)
    ActionCable.server.broadcast(
      "table-monitor-stream",
      {
        type: "performance_timestamp",
        timestamp: broadcast_timestamp,
        table_monitor_id: table_monitor.id,
        operation_type: operation_type
      }
    )
    
    cable_ready.broadcast
    broadcast_time = ((Time.now.to_f - broadcast_start) * 1000).round(2)
    total_time = ((Time.now.to_f - job_start) * 1000).round(2)
    
    Rails.logger.info "📡 Broadcast time: #{broadcast_time}ms"
    Rails.logger.info "📡 Total job time: #{total_time}ms"
    Rails.logger.info "📡 Broadcast complete!"
    Rails.logger.info "📡 ========== TableMonitorJob END =========="
  end
end
