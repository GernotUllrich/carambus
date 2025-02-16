class RenameTableMonitorStates < ActiveRecord::Migration[7.0]
  def up
    TableMonitor.where(state: "new_table_monitor").update_all(state: "new")
    TableMonitor.where(state: "game_warmup_started").update_all(state: "warmup")
    TableMonitor.where(state: "game_warmup_a_started").update_all(state: "warmup_a")
    TableMonitor.where(state: "game_warmup_b_started").update_all(state: "warmup_b")
    TableMonitor.where(state: "game_shootout_started").update_all(state: "match_shootout")
    TableMonitor.where(state: "playing_game").update_all(state: "playing")
    TableMonitor.where(state: "game_show_result").update_all(state: "set_over")
    TableMonitor.where(state: "game_finished").update_all(state: "final_set_score")
    TableMonitor.where(state: "game_result_reported").update_all(state: "final_match_score")
    TableMonitor.where(state: "ready_for_new_game").update_all(state: "ready_for_new_match")
  end

  def down
    TableMonitor.where(state: "new").update_all(state: "new_table_monitor")
    TableMonitor.where(state: "warmup").update_all(state: "game_warmup_started")
    TableMonitor.where(state: "warmup_a").update_all(state: "game_warmup_a_started")
    TableMonitor.where(state: "warmup_b").update_all(state: "game_warmup_b_started")
    TableMonitor.where(state: "match_shootout").update_all(state: "game_shootout_started")
    TableMonitor.where(state: "playing").update_all(state: "playing_game")
    TableMonitor.where(state: "set_over").update_all(state: "game_show_result")
    TableMonitor.where(state: "final_set_score").update_all(state: "game_finished")
    TableMonitor.where(state: "final_match_score").update_all(state: "game_result_reported")
    TableMonitor.where(state: "ready_for_new_match").update_all(state: "ready_for_new_game")
  end
end
