module TableMonitorsHelper
  def ranking_table(hash, opts = {})
    rankings = TournamentMonitor.ranking(hash, opts)
    rankings = rankings.reverse if opts[:reverse]
    lines = rankings.map do |player, results|
      "<tr>" + "#{"<td>#{results["rank"]}</td>" if opts[:order].include?(:rank)}" + "<td>#{Player[player].lastname}</td><td>#{results["points"]}</td><td>#{results["result"]}</td><td>#{results["innings"]}</td><td>#{results["hs"]}</td><td>#{results["gd"]}</td><td>#{results["bed"]}</td>
</tr>"
    end.join("\n")
    return ("
      <div class=\"flex space-x-20 p-4 bg-white dark:bg-black\"><table><thead><tr>" + "#{"<th>Rank</th>" if opts[:order].include?(:rank)}" + "<th>Name</th><th>Points</th><th>Result</th><th>Innings</th><th>HS</th><th>GD</th><th>BED</th></tr></thead><tbody></tbody>#{lines.html_safe}</table></div>").html_safe
  end

  def evaluate_panel_and_current(table_monitor)
    element_to_panel_state = {
      "undo" => "inputs",
      "minus_one" => "inputs",
      "minus_ten" => "inputs",
      "next_step" => "inputs",
      "add_ten" => "inputs",
      "add_one" => "inputs",
      "numbers" => "inputs",
      "pause" => "timer",
      "play" => "timer",
      "stop" => "timer",
      "pointer_mode" => "pointer_mode",
      "nnn_1" => "numbers",
      "nnn_2" => "numbers",
      "nnn_3" => "numbers",
      "nnn_4" => "numbers",
      "nnn_5" => "numbers",
      "nnn_6" => "numbers",
      "nnn_7" => "numbers",
      "nnn_8" => "numbers",
      "nnn_9" => "numbers",
      "nnn_0" => "numbers",
      "nnn_c" => "numbers",
      "nnn_enter" => "numbers",
      "start_game" => "shootout",
      "change" => "shootout",
      "continue" => "setup",
      "practice_a" => "setup",
      "practice_b" => "setup",
    }
    panel_state = table_monitor.panel_state
    current_element = table_monitor.current_element
    panel_state = "setup" if table_monitor.setup_modal_should_be_open?
    panel_state = "numbers" if table_monitor.numbers_modal_should_be_open?
    panel_state = "shootout" if table_monitor.shootout_modal_should_be_open?
    if panel_state.present?
      unless current_element.present? && current_element == element_to_panel_state[current_element]
        current_element = TableMonitor::DEFAULT_ENTRY[panel_state]
        if panel_state == "timer"
          current_element = (table_monitor.timer_finish_at.present? && table_monitor.timer_halt_at.blank?) ? "pause" : "play"
        end
      end
    else
      panel_state = current_element = "pointer_mode"
    end
    return [panel_state, current_element]
  end
end
