# frozen_string_literal: true

class TableMonitorValidationJob < ApplicationJob
  queue_as :default

  def perform(table_monitor_id, action_type, action_data = {})
    table_monitor = TableMonitor.find(table_monitor_id)
    
    Rails.logger.info "TableMonitorValidationJob: Validating #{action_type} for table_monitor #{table_monitor_id}"
    
    case action_type
    when 'score_update'
      validate_score_update(table_monitor, action_data)
    when 'player_change'
      validate_player_change(table_monitor, action_data)
    when 'game_state'
      validate_game_state(table_monitor)
    else
      Rails.logger.warn "TableMonitorValidationJob: Unknown action type #{action_type}"
    end
    
    # Broadcast updated state to all connected clients
    broadcast_updated_state(table_monitor)
    
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "TableMonitorValidationJob: TableMonitor #{table_monitor_id} not found: #{e.message}"
  rescue StandardError => e
    Rails.logger.error "TableMonitorValidationJob: Error processing #{action_type}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  private

  def validate_score_update(table_monitor, action_data)
    player_id = action_data['player_id']
    points = action_data['points'].to_i
    operation = action_data['operation'] || 'add'
    
    # Perform the real update
    case operation
    when 'add'
      # Use the real add_n_balls method for proper game logic
      if table_monitor.data["free_game_form"] == "pool" && table_monitor.data["playera"].andand["discipline"] != "14.1 endlos"
        table_monitor.add_n_balls(points, player_id)
      else
        table_monitor.add_n_balls(points)
      end
      table_monitor.do_play
      table_monitor.assign_attributes(panel_state: "pointer_mode", current_element: "pointer_mode")
    when 'subtract'
      table_monitor.add_n_balls(-points)
    when 'set'
      # For setting specific scores, we'd need different logic
      Rails.logger.warn "TableMonitorValidationJob: 'set' operation not implemented"
    end
    
    # Validate score consistency
    current_score = table_monitor.data[player_id]['result'].to_i
    current_innings_redo = table_monitor.data[player_id]['innings_redo_list']&.last&.to_i || 0
    
    case operation
    when 'add'
      expected_score = current_score + points
    when 'subtract'
      expected_score = [current_score - points, 0].max
    when 'set'
      expected_score = points
    else
      expected_score = current_score
    end
    
    # Check if the score is within valid bounds
    balls_goal = table_monitor.data[player_id]['balls_goal'].to_i
    if balls_goal > 0 && expected_score > balls_goal && !table_monitor.data['allow_overflow']
      Rails.logger.warn "TableMonitorValidationJob: Score #{expected_score} exceeds goal #{balls_goal} for #{player_id}"
    end
    
    # Validate innings consistency
    validate_innings_consistency(table_monitor, player_id)
    
    # Save the validated state
    table_monitor.save!
  end
    
    # Validate score consistency
    current_score = table_monitor.data[player_id]['result'].to_i
    current_innings_redo = table_monitor.data[player_id]['innings_redo_list']&.last&.to_i || 0
    
    case operation
    when 'add'
      expected_score = current_score + points
    when 'subtract'
      expected_score = [current_score - points, 0].max
    when 'set'
      expected_score = points
    else
      expected_score = current_score
    end
    
    # Check if the score is within valid bounds
    balls_goal = table_monitor.data[player_id]['balls_goal'].to_i
    if balls_goal > 0 && expected_score > balls_goal && !table_monitor.data['allow_overflow']
      Rails.logger.warn "TableMonitorValidationJob: Score #{expected_score} exceeds goal #{balls_goal} for #{player_id}"
      # Could implement auto-correction here if needed
    end
    
    # Validate innings consistency
    validate_innings_consistency(table_monitor, player_id)
    
    # Save the validated state
    table_monitor.save!
  end

  def validate_player_change(table_monitor, action_data)
    # Validate that the current player change is valid
    current_inning = table_monitor.data['current_inning']
    active_player = current_inning['active_player']
    
    # Check if the player change follows game rules
    if table_monitor.playing?
      # Validate that the current inning is properly terminated
      validate_inning_termination(table_monitor, active_player)
    end
    
    # Validate game state consistency
    validate_game_state(table_monitor)
  end

  def validate_inning_termination(table_monitor, player_id)
    # Ensure the current inning is properly recorded
    innings_redo = table_monitor.data[player_id]['innings_redo_list']&.last&.to_i || 0
    
    if innings_redo > 0
      # Move the current inning data to the innings list
      table_monitor.data[player_id]['innings_list'] ||= []
      table_monitor.data[player_id]['innings_list'] << innings_redo
      
      # Reset the current inning
      table_monitor.data[player_id]['innings_redo_list'] = [0]
      
      # Update innings count
      table_monitor.data[player_id]['innings'] = (table_monitor.data[player_id]['innings'] || 0) + 1
      
      # Recompute results
      table_monitor.recompute_result(player_id)
      
      Rails.logger.info "TableMonitorValidationJob: Fixed inning termination for #{player_id}"
    end
  end

  def validate_innings_consistency(table_monitor, player_id)
    # Ensure innings data is consistent
    innings_list = table_monitor.data[player_id]['innings_list'] || []
    innings_foul_list = table_monitor.data[player_id]['innings_foul_list'] || []
    
    # Pad foul list if it's shorter than innings list
    while innings_foul_list.length < innings_list.length
      innings_foul_list << 0
    end
    
    table_monitor.data[player_id]['innings_foul_list'] = innings_foul_list
    
    # Validate that innings sum matches the result
    expected_result = innings_list.sum + (table_monitor.data[player_id]['innings_redo_list']&.last&.to_i || 0)
    actual_result = table_monitor.data[player_id]['result'].to_i
    
    if expected_result != actual_result
      Rails.logger.warn "TableMonitorValidationJob: Score inconsistency detected for #{player_id}. Expected: #{expected_result}, Actual: #{actual_result}"
      # Auto-correct the result
      table_monitor.data[player_id]['result'] = expected_result
    end
  end

  def validate_game_state(table_monitor)
    # Validate overall game state consistency
    playera_result = table_monitor.data['playera']['result'].to_i
    playerb_result = table_monitor.data['playerb']['result'].to_i
    
    # Check if game should be finished
    playera_goal = table_monitor.data['playera']['balls_goal'].to_i
    playerb_goal = table_monitor.data['playerb']['balls_goal'].to_i
    
    if playera_goal > 0 && playera_result >= playera_goal
      if table_monitor.state != 'set_over'
        Rails.logger.info "TableMonitorValidationJob: Auto-correcting game state to 'set_over' for player A win"
        table_monitor.state = 'set_over'
      end
    elsif playerb_goal > 0 && playerb_result >= playerb_goal
      if table_monitor.state != 'set_over'
        Rails.logger.info "TableMonitorValidationJob: Auto-correcting game state to 'set_over' for player B win"
        table_monitor.state = 'set_over'
      end
    end
    
    # Validate innings goals
    innings_goal = table_monitor.data['innings_goal'].to_i
    if innings_goal > 0
      playera_innings = table_monitor.data['playera']['innings'].to_i
      playerb_innings = table_monitor.data['playerb']['innings'].to_i
      
      if playera_innings >= innings_goal || playerb_innings >= innings_goal
        if table_monitor.state != 'set_over'
          Rails.logger.info "TableMonitorValidationJob: Auto-correcting game state to 'set_over' for innings goal reached"
          table_monitor.state = 'set_over'
        end
      end
    end
  end

  def broadcast_updated_state(table_monitor)
    # Broadcast the corrected state to all connected clients
    table_monitor.broadcast_replace_to(
      table_monitor,
      target: "table_monitor_#{table_monitor.id}",
      partial: "table_monitors/scoreboard",
      locals: { 
        table_monitor: table_monitor,
        fullscreen: true,
        options: table_monitor.options
      }
    )
    
    Rails.logger.info "TableMonitorValidationJob: Broadcasted corrected state for table_monitor #{table_monitor.id}"
  end
en