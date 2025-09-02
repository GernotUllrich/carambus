# frozen_string_literal: true

class ScoreboardOptimisticService
  attr_reader :table_monitor

  def initialize(table_monitor)
    @table_monitor = table_monitor
  end

  # Immediate score update without heavy validation
  def add_points_optimistically(player_id, points)
    return false unless valid_quick_update?(player_id, points)

    # Basic bounds checking
    balls_goal = @table_monitor.data[player_id]['balls_goal'].to_i
    current_innings_redo = @table_monitor.data[player_id]['innings_redo_list']&.last&.to_i || 0
    new_innings_redo = current_innings_redo + points
    
    if balls_goal > 0 && new_innings_redo > balls_goal && !@table_monitor.data['allow_overflow']
      return false
    end
    
    # Store optimistic values for display only (don't persist to database)
    @optimistic_scores ||= {}
    @optimistic_scores[player_id] ||= {
      'result' => @table_monitor.data[player_id]['result']&.to_i || 0,
      'innings_redo' => current_innings_redo
    }
    
    # Only update the current inning (innings_redo) for optimistic display
    # The result field will be updated by the background job
    @optimistic_scores[player_id]['innings_redo'] = new_innings_redo
    
    # Return true to indicate success (but don't persist)
    true
  rescue StandardError => e
    Rails.logger.error "ScoreboardOptimisticService: Error in add_points_optimistically: #{e.message}"
    false
  end

  # Immediate player change without heavy validation
  def change_player_optimistically
    return false unless @table_monitor.playing?

    current_inning = @table_monitor.data['current_inning']
    current_player = current_inning['active_player']
    new_player = current_player == 'playera' ? 'playerb' : 'playera'
    
    # Quick player switch
    current_inning['active_player'] = new_player
    
    # Reset timer for new player
    @table_monitor.reset_timer!
    
    # Mark for change
    @table_monitor.data_will_change!
    
    true
  rescue StandardError => e
    Rails.logger.error "ScoreboardOptimisticService: Error in change_player_optimistically: #{e.message}"
    false
  end

  # Quick validation check for immediate feedback
  def valid_quick_update?(player_id, points)
    return false unless @table_monitor.playing?
    return false unless @table_monitor.data[player_id]
    return false if points < 0 && @table_monitor.data[player_id]['innings_redo_list']&.last&.to_i < points.abs
    
    true
  end

  # Get current score for immediate display
  def current_score(player_id)
    if @optimistic_scores && @optimistic_scores[player_id]
      # Use optimistic values if available
      @optimistic_scores[player_id]['result'] + @optimistic_scores[player_id]['innings_redo']
    else
      # Use real values
      base_score = @table_monitor.data[player_id]['result']&.to_i || 0
      current_inning = @table_monitor.data[player_id]['innings_redo_list']&.last&.to_i || 0
      base_score + current_inning
    end
  end

  # Get current active player
  def current_active_player
    @table_monitor.data['current_inning']['active_player']
  end

  # Get current inning value for display
  def current_inning_value(player_id)
    if @optimistic_scores && @optimistic_scores[player_id]
      # Use optimistic value if available
      @optimistic_scores[player_id]['innings_redo']
    else
      # Use real value
      @table_monitor.data[player_id]['innings_redo_list']&.last&.to_i || 0
    end
  end

  # Check if player is active
  def player_active?(player_id)
    current_active_player == player_id
  end

  # Quick save without heavy callbacks
  def quick_save
    @table_monitor.save(validate: false)
  rescue StandardError => e
    Rails.logger.error "ScoreboardOptimisticService: Error in quick_save: #{e.message}"
    false
  end

  # Revert optimistic changes if needed
  def revert_changes
    @table_monitor.reload
  rescue StandardError => e
    Rails.logger.error "ScoreboardOptimisticService: Error in revert_changes: #{e.message}"
    false
  end

  # Get optimistic display values for JavaScript
  def optimistic_display_values(player_id)
    if @optimistic_scores && @optimistic_scores[player_id]
      {
        'main_score' => @optimistic_scores[player_id]['result'] + @optimistic_scores[player_id]['innings_redo'],
        'inning_score' => @optimistic_scores[player_id]['innings_redo']
      }
    else
      {
        'main_score' => current_score(player_id),
        'inning_score' => @table_monitor.data[player_id]['innings_redo_list']&.last&.to_i || 0
      }
    end
  end
end

