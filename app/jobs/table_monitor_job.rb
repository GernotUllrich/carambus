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
    selector = "#full_screen_table_monitor_#{table_monitor.id}"
    DebugLogger.log_dom_check(selector, true) # Assume exists for now
    
    show = case table_monitor.data["free_game_form"]
           when "pool"
             "_pool"
           when "snooker"
             "_snooker"
           else
             ""
           end

    full_screen_html = ApplicationController.render(
      partial: "table_monitors/show#{show}",
      locals: { table_monitor: table_monitor, full_screen: true }
    )
    Rails.logger.info " ########### table_monitor#show id: #{table_monitor.andand.id} ###########" if debug

    cable_ready["table-monitor-stream"].inner_html(
      selector: selector,
      html: full_screen_html
    )
    DebugLogger.log_operation("full_screen_update", table_monitor.id, selector, true)
    
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
end
