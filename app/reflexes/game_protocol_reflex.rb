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
    send_modal_update(render_protocol_modal)
  end
  
  # Close protocol modal
  def close_protocol
    morph :nothing
    Rails.logger.info "🎯 GameProtocolReflex#close_protocol - STARTING" if TableMonitor::DEBUG
    Rails.logger.info "🔍 BEFORE CLOSE: playera result=#{@table_monitor.data['playera']['result']}, innings_list=#{@table_monitor.data['playera']['innings_list']&.inspect}" if TableMonitor::DEBUG
    Rails.logger.info "🔍 BEFORE CLOSE: playerb result=#{@table_monitor.data['playerb']['result']}, innings_list=#{@table_monitor.data['playerb']['innings_list']&.inspect}" if TableMonitor::DEBUG
    
    @table_monitor.skip_update_callbacks = true
    @table_monitor.panel_state = "pointer_mode"
    @table_monitor.save!
    @table_monitor.skip_update_callbacks = false
    
    send_modal_update("")
    
    Rails.logger.info "🚀 TRIGGERING full_screen update via TableMonitorJob" if TableMonitor::DEBUG
    TableMonitorJob.perform_later(@table_monitor, "full_screen")
    Rails.logger.info "🎯 GameProtocolReflex#close_protocol - COMPLETED" if TableMonitor::DEBUG
  end
  
  # Switch to edit mode
  def switch_to_edit_mode
    morph :nothing
    Rails.logger.info "🎯 GameProtocolReflex#switch_to_edit_mode" if TableMonitor::DEBUG
    @table_monitor.skip_update_callbacks = true
    @table_monitor.panel_state = "protocol_edit"
    @table_monitor.save!
    @table_monitor.skip_update_callbacks = false
    send_modal_update(render_protocol_modal)
  end
  
  # Switch back to view mode (not used - we close directly now)
  def switch_to_view_mode
    morph :nothing
    Rails.logger.info "🎯 GameProtocolReflex#switch_to_view_mode" if TableMonitor::DEBUG
    @table_monitor.skip_update_callbacks = true
    @table_monitor.panel_state = "protocol"
    @table_monitor.save!
    @table_monitor.skip_update_callbacks = false
    send_modal_update(render_protocol_modal)
  end
  
  # Increment points for a specific inning and player
  def increment_points
    morph :nothing
    inning_index = element.dataset['inning'].to_i
    player = element.dataset['player'] # 'playera' or 'playerb'
    
    Rails.logger.info "🎯 GameProtocolReflex#increment_points: inning=#{inning_index}, player=#{player}" if TableMonitor::DEBUG
    Rails.logger.info "🔍 INCREMENT BEFORE: #{player} result=#{@table_monitor.data[player]['result']}, innings_list=#{@table_monitor.data[player]['innings_list']&.inspect}" if TableMonitor::DEBUG
    
    @table_monitor.skip_update_callbacks = true
    @table_monitor.increment_inning_points(inning_index, player)
    @table_monitor.skip_update_callbacks = false
    
    Rails.logger.info "🔍 INCREMENT AFTER: #{player} result=#{@table_monitor.data[player]['result']}, innings_list=#{@table_monitor.data[player]['innings_list']&.inspect}" if TableMonitor::DEBUG
    Rails.logger.info "🔍 INCREMENT AFTER: updated_at=#{@table_monitor.updated_at}" if TableMonitor::DEBUG
    
    send_table_update(render_protocol_table_body)
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
    send_table_update(render_protocol_table_body)
  end
  
  # Delete an inning (only if both players have 0 points)
  def delete_inning
    morph :nothing
    inning_index = element.dataset['inning'].to_i
    
    Rails.logger.info "🎯 GameProtocolReflex#delete_inning: inning=#{inning_index}" if TableMonitor::DEBUG
    
    @table_monitor.skip_update_callbacks = true
    result = @table_monitor.delete_inning(inning_index)
    @table_monitor.skip_update_callbacks = false
    send_table_update(render_protocol_table_body) if result[:success]
  end
  
  # Insert an empty inning before the specified index
  def insert_inning
    morph :nothing
    before_index = element.dataset['before'].to_i
    
    Rails.logger.info "🎯 GameProtocolReflex#insert_inning: before=#{before_index}" if TableMonitor::DEBUG
    
    @table_monitor.skip_update_callbacks = true
    @table_monitor.insert_inning(before_index)
    @table_monitor.skip_update_callbacks = false
    send_table_update(render_protocol_table_body)
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

  def render_protocol_table_body
    return "" unless @table_monitor.protocol_modal_should_be_open?

    history = @table_monitor.innings_history
    partial = @table_monitor.panel_state == "protocol_edit" ? "table_monitors/game_protocol_table_body_edit" : "table_monitors/game_protocol_table_body"

    ApplicationController.render(
      partial: partial,
      locals: {
        history: history,
        table_monitor: @table_monitor
      }
    )
  end

  def send_modal_update(html)
    CableReady::Channels.instance["table-monitor-stream"].inner_html(
      selector: "#protocol-modal-container-#{@table_monitor.id}",
      html: html
    ).broadcast
  end

  def send_table_update(html)
    return if html.blank?

    CableReady::Channels.instance["table-monitor-stream"].inner_html(
      selector: "#protocol-tbody-#{@table_monitor.id}",
      html: html
    ).broadcast
  end
end

