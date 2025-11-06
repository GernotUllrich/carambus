# frozen_string_literal: true

class GameProtocolReflex < ApplicationReflex
  # Game Protocol Modal Reflexes
  # Server-side modal management - modal state tracked by panel_state
  # Similar pattern to warmup/shootout/numbers modals
  
  before_reflex :load_table_monitor
  
  # Open protocol modal in view mode
  def open_protocol
    Rails.logger.info "🎯 GameProtocolReflex#open_protocol" if TableMonitor::DEBUG
    @table_monitor.panel_state = "protocol"
    @table_monitor.save!
    # Full page morph - modal will be rendered by _show.html.erb
  end
  
  # Close protocol modal
  def close_protocol
    Rails.logger.info "🎯 GameProtocolReflex#close_protocol" if TableMonitor::DEBUG
    @table_monitor.panel_state = "pointer_mode"
    @table_monitor.save!
    # Full page morph - modal will not be rendered
  end
  
  # Switch to edit mode
  def switch_to_edit_mode
    Rails.logger.info "🎯 GameProtocolReflex#switch_to_edit_mode" if TableMonitor::DEBUG
    @table_monitor.panel_state = "protocol_edit"
    @table_monitor.save!
    # Full page morph - modal will render with edit partial
  end
  
  # Switch back to view mode
  def switch_to_view_mode
    Rails.logger.info "🎯 GameProtocolReflex#switch_to_view_mode" if TableMonitor::DEBUG
    @table_monitor.panel_state = "protocol"
    @table_monitor.save!
    # Full page morph - modal will render with view partial
  end
  
  # Increment points for a specific inning and player
  def increment_points
    inning_index = element.dataset['inning'].to_i
    player = element.dataset['player'] # 'playera' or 'playerb'
    
    Rails.logger.info "🎯 GameProtocolReflex#increment_points: inning=#{inning_index}, player=#{player}" if TableMonitor::DEBUG
    
    @table_monitor.increment_inning_points(inning_index, player)
    # Full page morph - entire modal re-renders with updated data
  end
  
  # Decrement points for a specific inning and player
  def decrement_points
    inning_index = element.dataset['inning'].to_i
    player = element.dataset['player'] # 'playera' or 'playerb'
    
    Rails.logger.info "🎯 GameProtocolReflex#decrement_points: inning=#{inning_index}, player=#{player}" if TableMonitor::DEBUG
    
    @table_monitor.decrement_inning_points(inning_index, player)
    # Full page morph - entire modal re-renders with updated data
  end
  
  # Delete an inning (only if both players have 0 points)
  def delete_inning
    inning_index = element.dataset['inning'].to_i
    
    Rails.logger.info "🎯 GameProtocolReflex#delete_inning: inning=#{inning_index}" if TableMonitor::DEBUG
    
    result = @table_monitor.delete_inning(inning_index)
    # Full page morph - entire modal re-renders (error handling TODO)
  end
  
  # Insert an empty inning before the specified index
  def insert_inning
    before_index = element.dataset['before'].to_i
    
    Rails.logger.info "🎯 GameProtocolReflex#insert_inning: before=#{before_index}" if TableMonitor::DEBUG
    
    @table_monitor.insert_inning(before_index)
    # Full page morph - entire modal re-renders with new row
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
end

