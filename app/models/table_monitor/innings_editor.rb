# frozen_string_literal: true

# TableMonitor::InningsEditor
#
# Orchestration-only collaborator for the Game-Protocol innings-history cluster.
# Receives a TableMonitor instance and carries the thin glue that used to live in
# TableMonitor (Z.1969–2064): AASM state guard (playing? || set_over?),
# data_will_change! / save! persistence, and the rescue-fallback contract.
#
# The scoring logic itself stays in TableMonitor::ScoreEngine — every method here
# delegates to @table_monitor.score_engine. Behaviour is preserved bit-for-bit
# (incl. the guard messages, the rescue result shapes and the truthy logger
# return of increment/decrement/insert), pinned by
# test/models/table_monitor/innings_history_characterization_test.rb.
class TableMonitor::InningsEditor
  def initialize(table_monitor)
    @table_monitor = table_monitor
  end

  # Game Protocol Modal - Get innings history for both players
  def innings_history
    gps = @table_monitor.game&.game_participations&.order(:role).to_a
    @table_monitor.score_engine.innings_history(gps: gps)
  rescue => e
    Rails.logger.error "ERROR: m6[#{@table_monitor.id}]#{e}, #{e.backtrace&.join("\n")}"
    {
      player_a: {name: "Spieler A", innings: [], totals: [], result: 0, innings_count: 0},
      player_b: {name: "Spieler B", innings: [], totals: [], result: 0, innings_count: 0},
      current_inning: {number: 1, active_player: "playera"},
      discipline: "",
      balls_goal: 0
    }
  end

  # Update innings history from game protocol modal
  def update_innings_history(innings_params)
    Rails.logger.debug do
      "-----------m6[#{@table_monitor.id}]---------->>> update_innings_history <<<------------------------------------------"
    end
    result = @table_monitor.score_engine.update_innings_history(innings_params, playing_or_set_over: @table_monitor.playing? || @table_monitor.set_over?)
    return result unless result[:success]

    @table_monitor.data_will_change!
    @table_monitor.save!
    result
  rescue => e
    Rails.logger.error "ERROR: m6[#{@table_monitor.id}]#{e}, #{e.backtrace&.join("\n")}"
    {success: false, error: e.message}
  end

  # Increment points for a specific inning and player
  def increment_inning_points(inning_index, player)
    return unless @table_monitor.playing? || @table_monitor.set_over?

    @table_monitor.score_engine.increment_inning_points(inning_index, player)
    @table_monitor.data_will_change!
    @table_monitor.save!
  rescue => e
    Rails.logger.error "ERROR: m6[#{@table_monitor.id}]#{e}, #{e.backtrace&.join("\n")}"
  end

  # Decrement points for a specific inning and player
  def decrement_inning_points(inning_index, player)
    return unless @table_monitor.playing? || @table_monitor.set_over?

    @table_monitor.score_engine.decrement_inning_points(inning_index, player)
    @table_monitor.data_will_change!
    @table_monitor.save!
  rescue => e
    Rails.logger.error "ERROR: m6[#{@table_monitor.id}]#{e}, #{e.backtrace&.join("\n")}"
  end

  # Delete an inning (only if both players have 0 points AND not the current inning)
  def delete_inning(inning_index)
    return {success: false, error: "Not in playing state"} unless @table_monitor.playing? || @table_monitor.set_over?

    result = @table_monitor.score_engine.delete_inning(inning_index, playing_or_set_over: true)
    return result unless result[:success]

    @table_monitor.data_will_change!
    @table_monitor.save!
    result
  rescue => e
    Rails.logger.error "ERROR: m6[#{@table_monitor.id}]#{e}, #{e.backtrace&.join("\n")}"
    {success: false, error: e.message}
  end

  # Insert an empty inning before the specified index for BOTH players
  def insert_inning(before_index)
    return unless @table_monitor.playing? || @table_monitor.set_over?

    @table_monitor.score_engine.insert_inning(before_index, playing_or_set_over: true)
    @table_monitor.data_will_change!
    @table_monitor.save!
  rescue => e
    Rails.logger.error "ERROR: m6[#{@table_monitor.id}]#{e}, #{e.backtrace&.join("\n")}"
  end

  # Update innings data for a player from a complete innings array
  def update_player_innings_data(player, innings_array)
    @table_monitor.score_engine.update_player_innings_data(player, innings_array)
    @table_monitor.data_will_change!
    @table_monitor.save!
  rescue => e
    Rails.logger.error "ERROR: m6[#{@table_monitor.id}]#{e}, #{e.backtrace&.join("\n")}"
  end

  # Calculate running totals for a player's innings
  def calculate_running_totals(player_id)
    @table_monitor.score_engine.calculate_running_totals(player_id)
  end
end
