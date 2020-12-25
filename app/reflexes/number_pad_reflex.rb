# frozen_string_literal: true

class NumberPadReflex < ApplicationReflex
  # Add Reflex methods in this file.
  #
  # All Reflex instances expose the following properties:
  #
  #   - connection - the ActionCable connection
  #   - channel - the ActionCable channel
  #   - request - an ActionDispatch::Request proxy for the socket connection
  #   - session - the ActionDispatch::Session store for the current visitor
  #   - url - the URL of the page that triggered the reflex
  #   - element - a Hash like object that represents the HTML element that triggered the reflex
  #   - params - parameters from the element's closest form (if any)
  #
  # Example:
  #
  #   def example(argument=true)
  #     # Your logic here...
  #     # Any declared instance variables will be made available to the Rails controller and view.
  #   end
  #
  # Learn more at: https://docs.stimulusreflex.com


  (0..9).each do |i|
    define_method :"nnn_#{i}" do
      key(element.dataset[:id], i)
    end
  end

  def key(table_monitor_id, val)
    morph :nothing
    if TableMonitor::NNN == "db"
      table_monitor_id = element.dataset[:id]
      table_monitor = TableMonitor.find(table_monitor_id)
      table_monitor.update_columns(nnn: val == "c" ? 0 : (table_monitor.nnn || 0) * 10 + val)
      cable_ready["table-monitor-stream"].inner_html(
        selector: "#number_field_#{table_monitor_id}",
        html: table_monitor.nnn.to_s
      )
      cable_ready.broadcast
    else
      session_key = :"nnn_#{table_monitor_id}"
      session[session_key] = val == "c" ? 0 : (session[session_key] || 0) * 10 + val
      cable_ready["table-monitor-stream"].inner_html(
        selector: "#number_field_#{table_monitor_id}",
        html: session[session_key].to_s
      )
      cable_ready.broadcast
    end
  end

  def nnn_c
    key(element.dataset[:id], "c")
  end

  def nnn_enter
    morph :nothing
    table_monitor_id = element.dataset[:id]
    table_monitor = TableMonitor.find(table_monitor_id)
    table_monitor.reset_timer!

    if TableMonitor::NNN == "db"
      table_monitor.set_n_balls_to_current_players_inning(table_monitor.nnn)
    else
      session_key = :"nnn_#{table_monitor_id}"
      table_monitor.set_n_balls_to_current_players_inning(session[session_key].to_i)
    end
  end

  def outside
    morph :nothing
    table_monitor_id = element.dataset[:id]
    table_monitor = TableMonitor.find(table_monitor_id)
    table_monitor.touch
    key(table_monitor_id, "c")
  end

  def key_pressed
    morph :nothing
  end
end
