# frozen_string_literal: true

class GameProtocolReflex < ApplicationReflex
  # Game Protocol Modal Reflexes
  # Server-side modal management - modal state tracked by panel_state
  # Similar pattern to warmup/shootout/numbers modals
  
  before_reflex :load_table_monitor
  
  # Open protocol modal in view mode
  def open_protocol
    morph :nothing
    Rails.logger.info "🎯 GameProtocolReflex#open_protocol" if TableMonitor::DEBUG
    @table_monitor.skip_update_callbacks = true
    @table_monitor.panel_state = "protocol"
    @table_monitor.save!
    @table_monitor.skip_update_callbacks = false
    TableMonitorJob.perform_later(@table_monitor, "")
    # Full page morph - modal will be rendered by _show.html.erb
    # No background jobs - reflex handles the full page morph
  end
  
  # Close protocol modal
  def close_protocol
    morph :nothing
    Rails.logger.info "🎯 GameProtocolReflex#close_protocol" if TableMonitor::DEBUG
    @table_monitor.skip_update_callbacks = true
    @table_monitor.panel_state = "pointer_mode"
    @table_monitor.save!
    @table_monitor.skip_update_callbacks = false
    TableMonitorJob.perform_later(@table_monitor, "")
    # Full page morph - modal will not be rendered
    # No background jobs - reflex handles the full page morph
  end
  
  # Switch to edit mode
  def switch_to_edit_mode
    morph :nothing
    Rails.logger.info "🎯 GameProtocolReflex#switch_to_edit_mode" if TableMonitor::DEBUG
    @table_monitor.skip_update_callbacks = true
    @table_monitor.panel_state = "protocol_edit"
    @table_monitor.save!
    @table_monitor.skip_update_callbacks = false
    TableMonitorJob.perform_later(@table_monitor, "")
    refresh_protocol_modal
    TableMonitorJob.perform_later(@table_monitor, "")
    # Full page morph - modal will render with edit partial
    # No background jobs - reflex handles the full page morph
  end
  
  # Switch back to view mode (not used - we close directly now)
  def switch_to_view_mode
    morph :nothing
    Rails.logger.info "🎯 GameProtocolReflex#switch_to_view_mode" if TableMonitor::DEBUG
    @table_monitor.skip_update_callbacks = true
    @table_monitor.panel_state = "protocol"
    @table_monitor.save!
    @table_monitor.skip_update_callbacks = false
    TableMonitorJob.perform_later(@table_monitor, "")
    refresh_protocol_modal
    TableMonitorJob.perform_later(@table_monitor, "")
    # Full page morph - modal will render with view partial
    # No background jobs - reflex handles the full page morph
  end
  
  # Increment points for a specific inning and player
  def increment_points
    morph :nothing
    inning_index = element.dataset['inning'].to_i
    player = element.dataset['player'] # 'playera' or 'playerb'
    
    Rails.logger.info "🎯 GameProtocolReflex#increment_points: inning=#{inning_index}, player=#{player}" if TableMonitor::DEBUG
    
    @table_monitor.skip_update_callbacks = true
    @table_monitor.increment_inning_points(inning_index, player)
    @table_monitor.skip_update_callbacks = false
    TableMonitorJob.perform_later(@table_monitor, "")
    refresh_protocol_table
    # Full page morph - entire modal re-renders with updated data
    # No background jobs - reflex handles the full page morph
  end
  
  # Decrement points for a specific inning and player
  def decrement_points
    morph :nothing
    inning_index = element.dataset['inning'].to_i
    player = element.dataset['player'] # 'playera' or 'playerb'
    
    Rails.logger.info "🎯 GameProtocolReflex#decrement_points: inning=#{inning_index}, player=#{player}" if TableMonitor::DEBUG
    
    @table_monitor.skip_update_callbacks = true
    @table_monitor.decrement_inning_points(inning_index, player)
    @table_monitor.skip_update_callbacks = false
    TableMonitorJob.perform_later(@table_monitor, "")
    refresh_protocol_table
    # Full page morph - entire modal re-renders with updated data
    # No background jobs - reflex handles the full page morph
  end
  
  # Delete an inning (only if both players have 0 points)
  def delete_inning
    morph :nothing
    inning_index = element.dataset['inning'].to_i
    
    Rails.logger.info "🎯 GameProtocolReflex#delete_inning: inning=#{inning_index}" if TableMonitor::DEBUG
    
    @table_monitor.skip_update_callbacks = true
    result = @table_monitor.delete_inning(inning_index)
    @table_monitor.skip_update_callbacks = false
    TableMonitorJob.perform_later(@table_monitor, "")
    refresh_protocol_table if result[:success]
    # Full page morph - entire modal re-renders (error handling TODO)
    # No background jobs - reflex handles the full page morph
  end
  
  # Insert an empty inning before the specified index
  def insert_inning
    morph :nothing
    before_index = element.dataset['before'].to_i
    
    Rails.logger.info "🎯 GameProtocolReflex#insert_inning: before=#{before_index}" if TableMonitor::DEBUG
    
    @table_monitor.skip_update_callbacks = true
    @table_monitor.insert_inning(before_index)
    @table_monitor.skip_update_callbacks = false
    TableMonitorJob.perform_later(@table_monitor, "")
    refresh_protocol_table
    # Full page morph - entire modal re-renders with new row
    # No background jobs - reflex handles the full page morph
  end
  
  private
  
  def load_table_monitor
    # Read from data-id attribute (standard for all reflexes)
    table_monitor_id = element.dataset['id']
    Rails.logger.info "🔍 Loading TableMonitor ##{table_monitor_id}" if TableMonitor::DEBUG
    @table_monitor = TableMonitor.find(table_monitor_id)
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "❌ TableMonitor not found: #{table_monitor_id}"
    raise e
  end

  def refresh_protocol_modal
    html = ApplicationController.render(
      partial: "table_monitors/game_protocol_modal",
      locals: {
        table_monitor: @table_monitor,
        full_screen: true,
        modal_hidden: !@table_monitor.protocol_modal_should_be_open?
      }
    )

    cable_ready["table-monitor-stream"].inner_html(
      selector: "#game-protocol-modal",
      html: html
    )
    cable_ready.broadcast
  end

  def refresh_protocol_table
    history = @table_monitor.innings_history
    partial = @table_monitor.panel_state == "protocol_edit" ? "table_monitors/game_protocol_table_body_edit" : "table_monitors/game_protocol_table_body"

    html = ApplicationController.render(
      partial: partial,
      locals: {
        history: history,
        table_monitor: @table_monitor
      }
    )

    cable_ready["table-monitor-stream"].inner_html(
      selector: "#protocol-tbody",
      html: html
    )
    cable_ready.broadcast
  end
end

