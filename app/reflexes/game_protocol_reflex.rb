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
    Rails.logger.info "🎯 GameProtocolReflex#close_protocol" if TableMonitor::DEBUG
    @table_monitor.skip_update_callbacks = true
    @table_monitor.panel_state = "pointer_mode"
    @table_monitor.save!
    @table_monitor.skip_update_callbacks = false
    send_modal_update("")
    TableMonitorJob.perform_later(@table_monitor, "")
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
    
    @table_monitor.skip_update_callbacks = true
    @table_monitor.increment_inning_points(inning_index, player)
    @table_monitor.skip_update_callbacks = false
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

