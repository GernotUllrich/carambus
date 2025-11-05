# frozen_string_literal: true

class GameProtocolReflex < ApplicationReflex
  # Game Protocol Modal Reflexes
  # All manipulations of innings data happen here on the server
  
  before_reflex :load_table_monitor
  
  # Increment points for a specific inning and player
  def increment_points
    inning_index = element.dataset[:inning].to_i
    player = element.dataset[:player] # 'playera' or 'playerb'
    
    Rails.logger.info "🎯 GameProtocolReflex#increment_points: inning=#{inning_index}, player=#{player}" if TableMonitor::DEBUG
    
    @table_monitor.increment_inning_points(inning_index, player)
    
    # Morph the protocol table
    morph_protocol_table
  end
  
  # Decrement points for a specific inning and player
  def decrement_points
    inning_index = element.dataset[:inning].to_i
    player = element.dataset[:player] # 'playera' or 'playerb'
    
    Rails.logger.info "🎯 GameProtocolReflex#decrement_points: inning=#{inning_index}, player=#{player}" if TableMonitor::DEBUG
    
    @table_monitor.decrement_inning_points(inning_index, player)
    
    # Morph the protocol table
    morph_protocol_table
  end
  
  # Delete an inning (only if both players have 0 points)
  def delete_inning
    inning_index = element.dataset[:inning].to_i
    
    Rails.logger.info "🎯 GameProtocolReflex#delete_inning: inning=#{inning_index}" if TableMonitor::DEBUG
    
    result = @table_monitor.delete_inning(inning_index)
    
    if result[:success]
      # Morph the protocol table
      morph_protocol_table
    else
      # Show error message
      morph "#protocol-error-message", render(partial: 'table_monitors/protocol_error', locals: { error: result[:error] })
    end
  end
  
  # Insert an empty inning before the specified index
  def insert_inning
    before_index = element.dataset[:before].to_i
    
    Rails.logger.info "🎯 GameProtocolReflex#insert_inning: before=#{before_index}" if TableMonitor::DEBUG
    
    @table_monitor.insert_inning(before_index)
    
    # Morph the protocol table
    morph_protocol_table
  end
  
  private
  
  def load_table_monitor
    table_monitor_id = element.dataset[:tableMonitorId]
    @table_monitor = TableMonitor.find(table_monitor_id)
  end
  
  def morph_protocol_table
    # Get updated innings history
    history = @table_monitor.innings_history
    
    # Morph the entire modal content to update everything
    morph "#game-protocol-modal-content", render(
      partial: 'table_monitors/game_protocol_modal_content',
      locals: { 
        history: history,
        table_monitor: @table_monitor
      }
    )
  end
end

