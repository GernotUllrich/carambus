class DebugController < ApplicationController
  before_action :ensure_debug_mode

  def scoreboard_status
    @table_monitors = TableMonitor.includes(:table, :game, :tournament_monitor).limit(10)
    @recent_jobs = get_recent_job_stats
    @cable_ready_stats = get_cable_ready_stats
    @reflex_stats = get_reflex_stats
    
    render json: {
      timestamp: Time.current.iso8601,
      table_monitors: @table_monitors.map do |tm|
        {
          id: tm.id,
          table_name: tm.table.name,
          game_id: tm.game_id,
          panel_state: tm.panel_state,
          current_element: tm.current_element,
          data_keys: tm.data.keys
        }
      end,
      recent_jobs: @recent_jobs,
      cable_ready_stats: @cable_ready_stats,
      reflex_stats: @reflex_stats
    }
  end

  def dom_health
    # This would typically be called from the client side
    # but we can provide server-side validation
    table_monitor_ids = params[:table_monitor_ids] || []
    
    health_data = {
      timestamp: Time.current.iso8601,
      expected_elements: [],
      missing_elements: [],
      table_monitors: []
    }
    
    table_monitor_ids.each do |id|
      tm = TableMonitor.find_by(id: id)
      if tm
        health_data[:table_monitors] << {
          id: tm.id,
          table_name: tm.table.name,
          expected_selectors: [
            "#teaser_#{tm.id}",
            "#full_screen_table_monitor_#{tm.id}",
            "#table_monitor_#{tm.id}"
          ]
        }
      end
    end
    
    render json: health_data
  end

  def clear_debug_logs
    # Clear any cached debug information
    Rails.cache.delete_matched("debug_*")
    
    render json: { 
      message: "Debug logs cleared",
      timestamp: Time.current.iso8601 
    }
  end

  private

  def ensure_debug_mode
    unless Rails.env.development? || Rails.env.test?
      render json: { error: "Debug mode only available in development/test" }, status: 403
    end
  end

  def get_recent_job_stats
    # This would require implementing job tracking
    # For now, return basic stats
    {
      total_jobs: TableMonitorJob.jobs.size,
      failed_jobs: TableMonitorJob.failed.size,
      last_5_minutes: TableMonitorJob.where('created_at > ?', 5.minutes.ago).count
    }
  rescue
    { error: "Job stats unavailable" }
  end

  def get_cable_ready_stats
    # Basic CableReady statistics
    {
      active_connections: ActionCable.server.connections.size,
      subscriptions: ActionCable.server.subscriptions.size
    }
  rescue
    { error: "CableReady stats unavailable" }
  end

  def get_reflex_stats
    # Basic reflex statistics
    {
      total_reflexes: 0, # Would need to implement tracking
      failed_reflexes: 0,
      last_hour: 0
    }
  rescue
    { error: "Reflex stats unavailable" }
  end
end
