# frozen_string_literal: true

# TableMonitor::ScoreEngine
#
# Pure hash mutation logic for score computation. Receives the live data Hash
# reference from TableMonitor and mutates it in place — no ActiveRecord writes,
# no AASM events, no real-time broadcasts.
#
# State checks (playing?, set_over?) remain in TableMonitor. ScoreEngine assumes
# it is called in the correct AASM state.
#
# Signal return values:
#   :goal_reached      — player reached their balls_goal (caller calls terminate_current_inning)
#   :inning_terminated — inning was terminated inside the method
#   nil                — normal mutation, no lifecycle action needed
class TableMonitor::ScoreEngine
    def initialize(data, discipline: nil)
      @data = data
      @discipline = discipline
    end

    # -------------------------------------------------------------------------
    # Score input methods
    # -------------------------------------------------------------------------

    # Add n_balls to the active (or specified) player's current inning.
    # Returns :goal_reached when the player's result reaches balls_goal so the
    # caller (TableMonitor) can call terminate_current_inning.
    # Returns nil otherwise.
    def add_n_balls(n_balls, player = nil, skip_snooker_state_update: false)
      if discipline == "Biathlon"
        balls_goal_3b = 15
        data["biathlon_phase"] ||= "3b"
      end
      n_balls_left = data["balls_on_table"].to_i - n_balls
      if [1, 0].include?(n_balls_left)
        current_role = data["current_inning"]["active_player"]
        to_play = if data[current_role].andand["balls_goal"].to_i <= 0
                    99_999
                  else
                    data[current_role].andand["balls_goal"].to_i -
                      (data[current_role].andand["result"].to_i +
                        data[current_role]["innings_redo_list"][-1].to_i)
                  end
        if n_balls <= to_play || data["allow_overflow"].present?
          data["balls_counter_stack"] << data["balls_counter"].to_i
          data["balls_counter"] += 14 + (1 - n_balls_left)
        end
      end

      @msg = nil

      if player.present?
        current_role = player.presence
        other_player = current_role == "playera" ? "playerb" : "playera"
        init_lists(other_player)
        if data["current_inning"]["active_player"] != player
          data[other_player]["innings"] += 1
          data[other_player]["innings_list"] << 0
          data[other_player]["innings_foul_list"] << 0
        end
      else
        current_role = data["current_inning"]["active_player"]
      end
      init_lists(current_role)
      to_play = if data[current_role].andand["balls_goal"].to_i <= 0
                  99_999
                else
                  data[current_role].andand["balls_goal"].to_i - (data[current_role].andand["result"].to_i +
                    data[current_role]["innings_redo_list"][-1].to_i)
                end
      if data["biathlon_phase"] == "3b"
        to_play_3b = balls_goal_3b - (data[current_role].andand["result"].to_i +
          data[current_role]["innings_redo_list"][-1].to_i)
      end
      if data["biathlon_phase"] != "3b" || n_balls <= to_play_3b
        current_inning_value = data[current_role]["innings_redo_list"][-1].to_i

        should_process_input = if data["allow_overflow"].present?
                                 to_play.positive?
                               elsif n_balls.positive?
                                 n_balls <= to_play && to_play.positive?
                               elsif n_balls.negative?
                                 allow_negative_scores? || (current_inning_value + n_balls) >= 0
                               else
                                 false
                               end

        if should_process_input
          if data["biathlon_phase"] == "3b"
            add = if data["allow_overflow"].present?
                    n_balls
                  else
                    [n_balls, to_play_3b].min
                  end
            data[current_role]["innings_redo_list"][-1] =
              [(data[current_role]["innings_redo_list"][-1].to_i + add.to_i), 0].max
            recompute_result(current_role)
            Rails.logger.debug { "add_n_balls: Processing Biathlon 3b input (n_balls=#{n_balls}, add=#{add})" }
            if (data[current_role]["innings_list"]&.sum.to_i +
              data[current_role]["innings_redo_list"][-1].to_i) == balls_goal_3b
              other_player = current_role == "playera" ? "playerb" : "playera"
              data["biathlon_phase"] = "5k"
              Array(data[current_role]["innings_list"]).each_with_index do |val, ix|
                data[current_role]["innings_list"][ix] = val.to_i * 6
              end
              data[current_role]["result"] = data[current_role]["result"].to_i * 6
              data[current_role]["innings_redo_list"][-1] = data[current_role]["innings_redo_list"][-1].to_i * 6
              Array(data[other_player]["innings_list"]).each_with_index do |val, ix|
                data[other_player]["innings_list"][ix] = val.to_i * 6
              end
              data[other_player]["result"] = data[other_player]["result"] * 6
              if data[other_player]["innings_redo_list"].present?
                data[other_player]["innings_redo_list"][-1] =
                  data[other_player]["innings_redo_list"][-1].to_i * 6
              end
              data[current_role]["result_3b"] =
                (data[current_role]["innings_list"]&.sum.to_i + data[current_role]["innings_redo_list"][-1].to_i) / 6
              data[other_player]["result_3b"] =
                (data[other_player]["innings_list"]&.sum.to_i + data[other_player]["innings_redo_list"][-1].to_i) / 6
              data[current_role]["innings_3b"] = data[current_role]["innings"].to_i
              data[other_player]["innings_3b"] = data[other_player]["innings"].to_i
            end
          else
            Rails.logger.debug do
              "add_n_balls: Processing input (n_balls=#{n_balls}, to_play=#{to_play}, allow_overflow=#{data["allow_overflow"].inspect})"
            end
            # Phase 38.5: signed-add per input. The BK-2plus / BK-2kombi DZ-Phase
            # rule (net-negative inning transferred to opponent) is enforced at
            # inning close in terminate_inning_data — NOT per input. Per-input
            # the shooter sees their running inning total (incl. negatives) in
            # the corner display.
            add = if data["allow_overflow"].present?
                    n_balls.positive? ? [n_balls, to_play].min : n_balls
                  else
                    n_balls
                  end
            data[current_role]["fouls_1"] = 0
            new_value = data[current_role]["innings_redo_list"][-1].to_i + add.to_i
            data[current_role]["innings_redo_list"][-1] =
              allow_negative_scores? ? new_value : [new_value, 0].max
            recompute_result(current_role)

            if data["free_game_form"] == "snooker" && !skip_snooker_state_update
              update_snooker_state(n_balls)
              data[current_role]["break_balls_redo_list"] ||= []
              data[current_role]["break_balls_redo_list"] = [[]] if data[current_role]["break_balls_redo_list"].empty?
              data[current_role]["break_balls_redo_list"][-1] ||= []
              data[current_role]["break_balls_redo_list"][-1] =
                Array(data[current_role]["break_balls_redo_list"][-1]) + [n_balls]

              data.delete("last_foul")

              snooker_state = data["snooker_state"] || {}
              reds_remaining = snooker_state["reds_remaining"].to_i
              colors_sequence = snooker_state["colors_sequence"] || []

              if reds_remaining <= 0 && colors_sequence.empty?
                Rails.logger.info "[add_n_balls] Snooker: All balls potted, setting frame_complete flag"
                data["snooker_frame_complete"] = true
                return :snooker_frame_complete
              end
            end
          end

          if add == to_play
            Rails.logger.debug { "add_n_balls: add == to_play (terminating inning)" }
            return :goal_reached
          else
            Rails.logger.debug { "add_n_balls: add != to_play (#{add} != #{to_play})" }
          end
        end
      else
        @msg = "Game Finished - no more inputs allowed"
        return nil
      end

      nil
    rescue StandardError => e
      Rails.logger.error "ERROR add_n_balls: #{e}, #{e.backtrace&.join("\n")}"
      raise StandardError
    end

    # Set the current inning score to exactly n_balls for the active player.
    # Returns :goal_reached when the player's score reaches balls_goal.
    # Returns nil otherwise.
    def set_n_balls(n_balls, change_to_pointer_mode = false)
      Rails.logger.debug { "set_n_balls: #{n_balls}, change_to_pointer_mode=#{change_to_pointer_mode}" }
      if discipline == "Biathlon"
        balls_goal_3b = 15
        data["biathlon_phase"] ||= "3b"
      end
      @msg = nil

      current_role = data["current_inning"]["active_player"]
      init_lists(current_role)
      to_play = data[current_role].andand["balls_goal"].to_i <= 0 ? 99_999 : data[current_role].andand["balls_goal"].to_i - data[current_role].andand["result"].to_i
      if n_balls <= to_play || data["allow_overflow"].present?
        Rails.logger.debug { "set_n_balls: n_balls <= to_play || data[\"allow_overflow\"].present?" }
        set = [n_balls, to_play].min
        data[current_role]["innings_redo_list"][-1] = set
        to_play_3b = balls_goal_3b - data[current_role].andand["result"].to_i if data["biathlon_phase"] == "3b"
        if data["biathlon_phase"] != "3b" || n_balls <= to_play_3b
          if set == to_play
            Rails.logger.debug { "set_n_balls: set == to_play" }
            return :goal_reached
          else
            Rails.logger.debug { "set_n_balls: set != to_play" }
          end

          to_play_3b = balls_goal_3b - data[current_role].andand["result"].to_i if data["biathlon_phase"] == "3b"
          if data["biathlon_phase"] != "3b" || n_balls <= to_play_3b
            if n_balls <= to_play || data["allow_overflow"].present?
              if data["biathlon_phase"] == "3b"
                add_3b = [n_balls, to_play_3b].min
                add = add_3b
                data[current_role]["fouls_1"] = 0
                data[current_role]["innings_redo_list"][-1] = add_3b
                recompute_result(current_role)
                Rails.logger.debug { "set_n_balls (biathlon 3b): n_balls <= to_play || allow_overflow" }
                if (data[current_role]["innings_list"]&.sum.to_i + data[current_role]["innings_redo_list"][-1].to_i) == balls_goal_3b
                  other_player = current_role == "playera" ? "playerb" : "playera"
                  data["biathlon_phase"] = "5k"
                  Array(data[current_role]["innings_list"]).each_with_index do |val, ix|
                    data[current_role]["innings_list"][ix] = val.to_i * 6
                  end
                  data[current_role]["result"] = data[current_role]["result"].to_i * 6
                  data[current_role]["innings_redo_list"][-1] = data[current_role]["innings_redo_list"][-1].to_i * 6
                  Array(data[other_player]["innings_list"]).each_with_index do |val, ix|
                    data[other_player]["innings_list"][ix] = val.to_i * 6
                  end
                  data[other_player]["result"] = data[other_player]["result"].to_i * 6
                  data[other_player]["innings_redo_list"][-1] = data[other_player]["innings_redo_list"][-1].to_i * 6
                  data[current_role]["result_3b"] =
                    (data[current_role]["innings_list"]&.sum.to_i + data[current_role]["innings_redo_list"][-1].to_i) / 6
                  data[other_player]["result_3b"] =
                    (data[other_player]["innings_list"]&.sum.to_i + data[other_player]["innings_redo_list"][-1].to_i) / 6
                  data[current_role]["innings_3b"] = data[current_role]["innings"].to_i
                  data[other_player]["innings_3b"] = data[other_player]["innings"].to_i
                end
              else
                Rails.logger.debug { "set_n_balls: n_balls <= to_play || allow_overflow" }
                add = [n_balls, to_play].min
                data[current_role]["fouls_1"] = 0
                data[current_role]["innings_redo_list"][-1] = [add, 0].max
                recompute_result(current_role)
              end
              if add == to_play
                Rails.logger.debug { "set_n_balls: add == to_play" }
                return :goal_reached
              else
                Rails.logger.debug { "set_n_balls: add != to_play" }
              end
            end
          else
            @msg = "Game Finished - no more inputs allowed"
            return nil
          end
        end
      end

      nil
    rescue StandardError => e
      Rails.logger.error "ERROR set_n_balls: #{e}, #{e.backtrace&.join("\n")}"
      raise StandardError unless Rails.env == "production"
    end

    # Record a 1-point foul. Decrements the foul list, tracks fouls_1.
    # Returns :goal_reached (foul caused inning end) or nil.
    def foul_one
      current_role = data["current_inning"]["active_player"]
      init_lists(current_role)
      data[current_role]["innings_foul_redo_list"][-1] = data[current_role]["innings_foul_redo_list"][-1].to_i - 1
      data[current_role]["fouls_1"] = data[current_role]["fouls_1"].to_i + 1
      recompute_result(current_role)
      if data[current_role]["fouls_1"] > 2
        data[current_role]["fouls_1"] = 0
        data[current_role]["innings_foul_redo_list"][-1] = data[current_role]["innings_foul_redo_list"][-1].to_i - 15
        data["extra_balls"] = data["extra_balls"].to_i + (15 - data["balls_on_table"].to_i)
        recompute_result(current_role)
        # Heavy foul — no inning termination signal (TM stays in playing state)
        nil
      else
        :inning_terminated
      end
    rescue StandardError => e
      Rails.logger.error "ERROR foul_one: #{e}, #{e.backtrace&.join("\n")}"
      raise StandardError
    end

    # Record a 2-point foul. Decrements by two and terminates the inning.
    # Returns :inning_terminated.
    def foul_two
      current_role = data["current_inning"]["active_player"]
      init_lists(current_role)
      data[current_role]["innings_foul_redo_list"][-1] = data[current_role]["innings_foul_redo_list"][-1] - 2
      innings_sum = data[current_role]["innings_list"]&.sum.to_i
      data[current_role]["result"] =
        innings_sum + data[current_role]["innings_foul_list"].to_a.sum +
        data[current_role]["innings_foul_redo_list"].to_a.sum
      :inning_terminated
    rescue StandardError => e
      Rails.logger.error "ERROR foul_two: #{e}, #{e.backtrace&.join("\n")}"
      raise StandardError
    end

    # Calculate balls to add from balls remaining on table.
    # Delegates to add_n_balls.
    def balls_left(n_balls_left)
      Rails.logger.debug { "balls_left(#{n_balls_left})" }
      balls_added = data["balls_on_table"].to_i - n_balls_left
      add_n_balls(balls_added)
    rescue StandardError => e
      Rails.logger.error "ERROR balls_left: #{e}, #{e.backtrace&.join("\n")}"
      raise StandardError
    end

    # -------------------------------------------------------------------------
    # Result computation
    # -------------------------------------------------------------------------

    # Recompute the result for current_role from innings_list.
    # Also updates balls_on_table.
    def recompute_result(current_role)
      innings_sum = data[current_role]["innings_list"]&.sum.to_i
      other_player = current_role == "playera" ? "playerb" : "playera"
      other_innings_sum = data[other_player]["innings_list"]&.sum.to_i
      current_redo = data[current_role]["innings_redo_list"]&.last.to_i
      other_redo = data[other_player]["innings_redo_list"]&.last.to_i
      total_sum = innings_sum + other_innings_sum + current_redo + other_redo - data["extra_balls"].to_i
      data["balls_on_table"] = 15 - ((total_sum % 14).zero? ? 0 : total_sum % 14)
      data[current_role]["result"] = if data["free_game_form"] == "snooker"
                                       innings_sum + data[current_role]["innings_foul_list"].to_a.sum
                                     else
                                       innings_sum + data[current_role]["innings_foul_list"].to_a.sum +
                                         data[current_role]["innings_foul_redo_list"].to_a.sum
                                     end
    rescue StandardError => e
      Rails.logger.error "ERROR recompute_result: #{e}, #{e.backtrace&.join("\n")}"
      raise StandardError
    end

    # Initialize innings list structures for the given player role.
    def init_lists(current_role)
      data[current_role]["innings_list"] ||= []
      data[current_role]["innings_foul_list"] ||= []
      data[current_role]["innings_redo_list"] = [0] if data[current_role]["innings_redo_list"].blank?
      return unless data[current_role]["innings_foul_redo_list"].blank?

      data[current_role]["innings_foul_redo_list"] = [0]

      return unless data["free_game_form"] == "snooker"

      data[current_role]["break_balls_redo_list"] ||= []
      data[current_role]["break_balls_redo_list"] = [[]] if data[current_role]["break_balls_redo_list"].empty?
      data[current_role]["break_balls_list"] ||= []
      data[current_role]["break_fouls_list"] ||= []
    end

    # -------------------------------------------------------------------------
    # Undo/Redo (non-PaperTrail hash branches only)
    # -------------------------------------------------------------------------

    # Undo the last hash-based action (non-PaperTrail disciplines only).
    # PaperTrail branches (14.1 endlos, set_over, simple_set_game) stay in TM.
    # Returns nil — caller handles save.
    def undo_hash
      current_role = data["current_inning"]["active_player"]
      the_other_player = (current_role == "playera" ? "playerb" : "playera")

      if data[current_role]["innings_redo_list"].andand[-1].to_i.positive?
        if data["free_game_form"] == "snooker"
          undo_snooker_ball(current_role)
        else
          current_break = data[current_role]["innings_redo_list"][-1].to_i
          data[current_role]["innings_redo_list"][-1] = [current_break - 1, 0].max
          recompute_result(current_role)
        end
      elsif data["free_game_form"] == "snooker" && data[the_other_player]["innings_redo_list"].andand[-1].to_i.positive?
        undo_snooker_ball(the_other_player)
        data["current_inning"]["active_player"] = the_other_player
      elsif data[the_other_player]["innings"].to_i.positive?
        if data[the_other_player]["innings_list"].present?
          arr = Array(data[the_other_player]["innings_list"])
          data[the_other_player]["innings_redo_list"] << arr.pop.to_i if arr.present?
        end
        if data["free_game_form"] == "snooker"
          if data[the_other_player]["break_balls_list"].present?
            last_break_balls = data[the_other_player]["break_balls_list"].pop
            data[the_other_player]["break_balls_redo_list"] ||= []
            data[the_other_player]["break_balls_redo_list"] << (last_break_balls || [])
          end
          recalculate_snooker_state_from_protocol
          if data[the_other_player]["break_balls_redo_list"]&.[](-1)&.any?
            data["snooker_state"]["last_potted_ball"] = data[the_other_player]["break_balls_redo_list"][-1].last
          end
          data[the_other_player]["innings"] -= 1
          recompute_result(the_other_player)
          data[the_other_player]["hs"] = data[the_other_player]["innings_list"]&.max.to_i
          if data[the_other_player]["innings"].to_i.positive?
            data[the_other_player]["gd"] =
              format("%.2f",
                     data[the_other_player]["result"].to_f / data[the_other_player]["innings"].to_i)
          end
        else
          data[the_other_player]["innings"] -= 1
          data[the_other_player]["result"] = data[the_other_player]["innings_list"]&.sum.to_i
          data[the_other_player]["hs"] = data[the_other_player]["innings_list"]&.max.to_i
          data[the_other_player]["gd"] =
            format("%.2f", data[the_other_player]["result"].to_f / data[the_other_player]["innings"].to_i)
        end
        data["current_inning"]["active_player"] = the_other_player
      end

      nil
    end

    # Redo the last undone action (non-PaperTrail disciplines only).
    # PaperTrail version traversal stays in TM.
    # Returns :inning_terminated if there was a current inning with points.
    def redo_hash
      current_role = data["current_inning"]["active_player"]
      innings_redo = Array(data[current_role]["innings_redo_list"]).last.to_i
      return nil unless innings_redo.positive?

      data[current_role]["innings_list"] ||= []
      data[current_role]["innings_list"] << innings_redo
      data[current_role]["innings_redo_list"][-1] = 0
      data[current_role]["innings"] = (data[current_role]["innings"].to_i + 1)
      recompute_result(current_role)
      :inning_terminated
    end

    # -------------------------------------------------------------------------
    # HTML rendering
    # -------------------------------------------------------------------------

    # Returns an HTML table string of innings for the given role.
    def render_innings_list(role)
      return "".html_safe if role.nil? || !data.key?(role)

      innings = data[role]["innings"].to_i
      cols = [(innings / 15.0).ceil, 2].max
      show_innings = Array(data[role].andand["innings_list"])
      show_fouls = Array(data[role].andand["innings_foul_list"])
      ret = ["<style>
    table, th, td {
        border: 1px solid black;
        border-collapse: collapse;
    }

    .space-above {
        margin-top: 15px;
    }

    th, td {
    }
    </style><table class=\"tracking-wide\"><thead><tr>"]
      (1..cols).each do |_icol|
        ret << "<th>Aufn</th><th>Pkt</th>#{
        "<th>Foul</th>" if data["playera"].andand["discipline"] == "14.1 endlos"}<th>∑</th>"
      end
      ret << "</tr></thead><tbody>"
      sum = 0
      sums = []
      show_innings.each_with_index do |inning, ix|
        sum += inning + show_fouls[ix]
        sums[ix] = sum
      end
      15.times do |ix|
        ret << "<tr>"
        (1..cols).each_with_index do |_col, icol|
          ret << "<td><span class=\"sm:text-xs lg:text-lg sm:px-2 lg:px-4\">#{ix + 1 + (icol * 15)}</span></td>
<td><span class=\"sm:text-xs lg:text-lg sm:px-2 lg:px-4\">\
#{(ix + (icol * 15)) == sums.length ? "GD" : show_innings[ix + (icol * 15)]}</span></td>
#{
          if data["playera"].andand["discipline"] == "14.1 endlos"
            "<td><span class=\"sm:text-xs lg:text-lg sm:px-2 lg:px-4\">\
#{show_fouls[ix + (icol * 15)] unless (ix + (icol * 15)) == sums.length}</span></td>"
          end}
<td><span class=\"sm:text-xs lg:text-lg sm:px-2 lg:px-4\">#{
          if (ix + (icol * 15)) == sums.length
            format("%0.2f", sums.last.to_i / innings.to_f)
          elsif (ix + (icol * 15)) == sums.length - 1
            "<strong class=\"text-3vw\">#{sums[ix + (icol * 15)]}</strong>"
          else
            sums[ix + (icol * 15)]
          end}</span></td>"
        end
        ret << "</tr>"
      end
      ret << "</tbody></table>"
      ret.join("\n").html_safe
    rescue StandardError => e
      Rails.logger.error "ERROR render_innings_list: #{e}, #{e.backtrace&.join("\n")}"
      raise StandardError unless Rails.env == "production"
    end

    # Returns an HTML string of the last last_n innings for the given role.
    def render_last_innings(last_n, role)
      return "".html_safe if role.nil? || !data.key?(role)

      player_ix = role == "playera" ? 1 : 2
      show_innings = Array(data[role].andand["innings_list"])
      show_innings_fouls = Array(data[role].andand["innings_foul_list"])
      prefix = ""
      if data["sets_to_play"].to_i > 1
        Array(data["sets"]).each_with_index do |set, ix|
          # Phase 38.4 R5-4: Satzergebnis von der innings_list mit "; " trennen,
          # innings_list-Einträge bleiben mit ", " — visuell klare Trennung.
          # Quick-260502-0ok: "*" markiert Satz-Gewinner aus Sicht dieses Spielers.
          # Bei Ergebnis-Gleichstand entscheidet TiebreakWinner (nil → kein Stern).
          e1 = set["Ergebnis1"].to_i
          e2 = set["Ergebnis2"].to_i
          tw = set["TiebreakWinner"].to_i # nil.to_i == 0 → no marker either side
          won_this_player =
            if e1 == e2
              tw == player_ix
            else
              (player_ix == 1 ? e1 > e2 : e2 > e1)
            end
          star = won_this_player ? "*" : ""
          prefix += "S#{ix + 1}: #{set["Ergebnis#{player_ix}"]}#{star}; "
        end
      end
      ret = []
      show_innings.each_with_index do |inning_value, ix|
        foul = show_innings_fouls[ix].to_i
        ret << if foul.zero?
                 inning_value.to_s
               else
                 "#{inning_value},F#{foul}"
               end
      end
      Array(data[role].andand["innings_redo_list"]).reverse.each_with_index do |inning_value, ix|
        ret << if ix.zero?
                 "<strong class=\"border-4 border-solid border-gray-400 p-1\">#{inning_value}</strong>"
               else
                 "<span class=\"text-[0.7em]\">#{inning_value}</span>"
               end
      end
      ret = ret.map.with_index do |item, idx|
        if idx < show_innings.length && !item.include?("<")
          "<span class=\"text-[0.7em]\">#{item}</span>"
        else
          item
        end
      end
      if ret.length > last_n
        "#{prefix}...#{ret[-last_n..].join(", ")}".html_safe
      else
        (prefix.to_s + ret.join(", ")).html_safe
      end
    rescue StandardError => e
      Rails.logger.error "ERROR render_last_innings: #{e.class}: #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace&.first(10)&.join("\n")}"
      raise StandardError, "render_last_innings failed: #{e.message}" unless Rails.env == "production"
    end

    # -------------------------------------------------------------------------
    # Innings history (pure hash query)
    # -------------------------------------------------------------------------

    # Returns structured innings data for the protocol display.
    # Accepts an optional gps array for player name resolution (AR objects — caller
    # passes them to keep ScoreEngine free of AR dependencies).
    def innings_history(gps: [])
      innings_list_a = Array(data.dig("playera", "innings_list"))
      innings_redo_a = Array(data.dig("playera", "innings_redo_list"))
      innings_redo_a = [0] if innings_redo_a.empty?

      innings_list_b = Array(data.dig("playerb", "innings_list"))
      innings_redo_b = Array(data.dig("playerb", "innings_redo_list"))
      innings_redo_b = [0] if innings_redo_b.empty?

      active_player = data.dig("current_inning", "active_player")

      completed_innings = [innings_list_a.length, innings_list_b.length].min
      num_rows = [completed_innings + 1, 1].max

      innings_a = []
      innings_b = []

      (0...num_rows).each do |i|
        innings_a << if i < innings_list_a.length
                       innings_list_a[i]
                     elsif i == innings_list_a.length && (active_player == "playera" || data.dig("playera",
                                                                                                 "innings").to_i > innings_list_a.length)
                       innings_redo_a[0] || 0
                     else
                       nil
                     end

        innings_b << if i < innings_list_b.length
                       innings_list_b[i]
                     elsif i == innings_list_b.length && (active_player == "playerb" || data.dig("playerb",
                                                                                                 "innings").to_i > innings_list_b.length)
                       innings_redo_b[0] || 0
                     else
                       nil
                     end
      end

      totals_a = []
      totals_b = []
      sum_a = 0
      sum_b = 0
      innings_a.each do |points|
        if points.nil?
          totals_a << nil
        else
          sum_a += points.to_i
          totals_a << sum_a
        end
      end
      innings_b.each do |points|
        if points.nil?
          totals_b << nil
        else
          sum_b += points.to_i
          totals_b << sum_b
        end
      end

      break_balls_a = []
      break_balls_b = []
      break_fouls_a = []
      break_fouls_b = []

      if data["free_game_form"] == "snooker"
        break_balls_list_a = Array(data.dig("playera", "break_balls_list"))
        break_balls_list_b = Array(data.dig("playerb", "break_balls_list"))
        break_fouls_list_a = Array(data.dig("playera", "break_fouls_list"))
        break_fouls_list_b = Array(data.dig("playerb", "break_fouls_list"))
        break_balls_redo_a = Array(data.dig("playera", "break_balls_redo_list")).last || []
        break_balls_redo_b = Array(data.dig("playerb", "break_balls_redo_list")).last || []

        (0...num_rows).each do |i|
          break_balls_a << (if i < break_balls_list_a.length
                              break_balls_list_a[i]
                            else
                              (i == break_balls_list_a.length && active_player == "playera" ? break_balls_redo_a : nil)
                            end)
          break_balls_b << (if i < break_balls_list_b.length
                              break_balls_list_b[i]
                            else
                              (i == break_balls_list_b.length && active_player == "playerb" ? break_balls_redo_b : nil)
                            end)
          break_fouls_a << (i < break_fouls_list_a.length ? break_fouls_list_a[i] : nil)
          break_fouls_b << (i < break_fouls_list_b.length ? break_fouls_list_b[i] : nil)
        end
      end

      result = {
        player_a: {
          name: gps[0].respond_to?(:player) ? gps[0]&.player&.fullname || "Spieler A" : "Spieler A",
          shortname: gps[0].respond_to?(:player) ? gps[0]&.player&.shortname || "Spieler A" : "Spieler A",
          innings: innings_a,
          totals: totals_a,
          result: data.dig("playera", "result").to_i,
          innings_count: data.dig("playera", "innings").to_i
        },
        player_b: {
          name: gps[1].respond_to?(:player) ? gps[1]&.player&.fullname || "Spieler B" : "Spieler B",
          shortname: gps[1].respond_to?(:player) ? gps[1]&.player&.shortname || "Spieler B" : "Spieler B",
          innings: innings_b,
          totals: totals_b,
          result: data.dig("playerb", "result").to_i,
          innings_count: data.dig("playerb", "innings").to_i
        },
        current_inning: {
          number: num_rows,
          active_player: data.dig("current_inning", "active_player")
        },
        discipline: data.dig("playera", "discipline"),
        balls_goal: data.dig("playera", "balls_goal").to_i
      }

      if data["free_game_form"] == "snooker"
        result[:player_a][:break_balls] = break_balls_a
        result[:player_a][:break_fouls] = break_fouls_a
        result[:player_b][:break_balls] = break_balls_b
        result[:player_b][:break_fouls] = break_fouls_b
      end

      result
    rescue StandardError => e
      Rails.logger.error "ERROR innings_history: #{e}, #{e.backtrace&.join("\n")}"
      {
        player_a: { name: "Spieler A", innings: [], totals: [], result: 0, innings_count: 0 },
        player_b: { name: "Spieler B", innings: [], totals: [], result: 0, innings_count: 0 },
        current_inning: { number: 1, active_player: "playera" },
        discipline: "",
        balls_goal: 0
      }
    end

    # -------------------------------------------------------------------------
    # Innings manipulation (from GameProtocolReflex)
    # -------------------------------------------------------------------------

    # Update innings history from protocol modal input.
    # Caller handles persistence after this returns { success: true }.
    def update_innings_history(innings_params, playing_or_set_over: true)
      return { success: false, error: "Not in playing state" } unless playing_or_set_over

      new_playera_innings = innings_params["playera"] || []
      new_playerb_innings = innings_params["playerb"] || []

      unless allow_negative_scores?
        if new_playera_innings.any? { |v| v.to_i.negative? } || new_playerb_innings.any? { |v| v.to_i.negative? }
          return { success: false, error: "Negative Punktzahlen sind nicht erlaubt" }
        end
      end

      innings_a = new_playera_innings.map(&:to_i)
      innings_b = new_playerb_innings.map(&:to_i)

      current_rows = [data.dig("playera", "innings").to_i, data.dig("playerb", "innings").to_i].max

      current_list_a = data.dig("playera", "innings_list") || []
      current_redo_a = data.dig("playera", "innings_redo_list") || [0]
      current_list_b = data.dig("playerb", "innings_list") || []
      current_redo_b = data.dig("playerb", "innings_redo_list") || [0]
      active_player = data.dig("current_inning", "active_player")

      actual_rows_a = current_list_a.length + (current_redo_a[0] != 0 || active_player == "playera" ? 1 : 0)
      actual_rows_b = current_list_b.length + (current_redo_b[0] != 0 || active_player == "playerb" ? 1 : 0)

      new_rows_a = innings_a.length
      new_rows_b = innings_b.length

      if new_rows_a > actual_rows_a
        while innings_a.last.zero? && new_rows_a > actual_rows_a
          innings_a.pop
          new_rows_a -= 1
        end
      end

      if new_rows_b > actual_rows_b
        while innings_b.last.zero? && new_rows_b > actual_rows_b
          innings_b.pop
          new_rows_b -= 1
        end
      end

      new_rows = [new_rows_a, new_rows_b].max

      if new_rows != current_rows
        data["playera"]["innings"] = new_rows
        data["playerb"]["innings"] = new_rows
      end

      current_innings_a = data["playera"]["innings"]
      current_innings_b = data["playerb"]["innings"]

      if innings_a.length >= current_innings_a && current_innings_a.positive?
        data["playera"]["innings_list"] = innings_a[0...(current_innings_a - 1)]
        data["playera"]["innings_redo_list"] = [innings_a[current_innings_a - 1] || 0]
      elsif innings_a.length < current_innings_a
        data["playera"]["innings_list"] = innings_a[0...(current_innings_a - 1)] || []
        data["playera"]["innings_redo_list"] = [innings_a[current_innings_a - 1] || 0]
      else
        data["playera"]["innings_list"] = []
        data["playera"]["innings_redo_list"] = innings_a.empty? ? [0] : [innings_a[0]]
      end

      data["playera"]["result"] = innings_a.sum
      data["playera"]["hs"] = innings_a.max || 0
      data["playera"]["gd"] = if current_innings_a.positive?
                                format("%.3f", data["playera"]["result"].to_f / current_innings_a)
                              else
                                0.0
                              end

      target_length_a = [data["playera"]["innings_list"].length, 0].max
      current_fouls_a = (data["playera"]["innings_foul_list"] || [])[0...target_length_a]
      data["playera"]["innings_foul_list"] =
        current_fouls_a + Array.new([target_length_a - current_fouls_a.length, 0].max, 0)
      data["playera"]["innings_foul_redo_list"] = [0]

      if innings_b.length >= current_innings_b && current_innings_b.positive?
        data["playerb"]["innings_list"] = innings_b[0...(current_innings_b - 1)]
        data["playerb"]["innings_redo_list"] = [innings_b[current_innings_b - 1] || 0]
      elsif innings_b.length < current_innings_b
        data["playerb"]["innings_list"] = innings_b[0...(current_innings_b - 1)] || []
        data["playerb"]["innings_redo_list"] = [innings_b[current_innings_b - 1] || 0]
      else
        data["playerb"]["innings_list"] = []
        data["playerb"]["innings_redo_list"] = innings_b.empty? ? [0] : [innings_b[0]]
      end

      data["playerb"]["result"] = innings_b.sum
      data["playerb"]["hs"] = innings_b.max || 0
      data["playerb"]["gd"] = if current_innings_b.positive?
                                format("%.3f", data["playerb"]["result"].to_f / current_innings_b)
                              else
                                0.0
                              end

      target_length_b = [data["playerb"]["innings_list"].length, 0].max
      current_fouls_b = (data["playerb"]["innings_foul_list"] || [])[0...target_length_b]
      data["playerb"]["innings_foul_list"] =
        current_fouls_b + Array.new([target_length_b - current_fouls_b.length, 0].max, 0)
      data["playerb"]["innings_foul_redo_list"] = [0]

      { success: true }
    rescue StandardError => e
      Rails.logger.error "ERROR update_innings_history: #{e}, #{e.backtrace&.join("\n")}"
      { success: false, error: e.message }
    end

    # Increment points for a specific inning index and player.
    # Caller handles persistence after.
    def increment_inning_points(inning_index, player)
      innings_list = Array(data[player]["innings_list"])
      innings_redo_list = Array(data[player]["innings_redo_list"])
      innings_redo_list = [0] if innings_redo_list.empty?

      if inning_index < innings_list.length
        innings_list[inning_index] = (innings_list[inning_index] || 0) + 1
      elsif inning_index == innings_list.length
        innings_redo_list[0] = (innings_redo_list[0] || 0) + 1
      else
        return
      end

      data[player]["innings_list"] = innings_list
      data[player]["innings_redo_list"] = innings_redo_list

      recalculate_player_stats(player)
    end

    # Decrement points for a specific inning index and player (floor at 0).
    def decrement_inning_points(inning_index, player)
      innings_list = Array(data[player]["innings_list"])
      innings_redo_list = Array(data[player]["innings_redo_list"])
      innings_redo_list = [0] if innings_redo_list.empty?

      if inning_index < innings_list.length
        innings_list[inning_index] = [(innings_list[inning_index] || 0) - 1, 0].max
      elsif inning_index == innings_list.length
        innings_redo_list[0] = [(innings_redo_list[0] || 0) - 1, 0].max
      else
        return
      end

      data[player]["innings_list"] = innings_list
      data[player]["innings_redo_list"] = innings_redo_list

      recalculate_player_stats(player)
    end

    # Delete an inning (only when both players have 0 for that inning).
    # Returns { success: true/false, error: "..." }.
    # Caller handles persistence on success.
    def delete_inning(inning_index, playing_or_set_over: true)
      return { success: false, error: "Not in playing state" } unless playing_or_set_over

      innings_list_a = Array(data.dig("playera", "innings_list"))
      innings_list_b = Array(data.dig("playerb", "innings_list"))

      original_length_a = innings_list_a.length
      original_length_b = innings_list_b.length

      max_list_length = [original_length_a, original_length_b].max
      if inning_index >= max_list_length
        return { success: false, error: "Die laufende Aufnahme kann nicht gelöscht werden" }
      end

      value_a = innings_list_a[inning_index] || 0
      value_b = innings_list_b[inning_index] || 0

      return { success: false, error: "Nur Zeilen mit 0:0 können gelöscht werden" } if value_a != 0 || value_b != 0

      innings_list_a.delete_at(inning_index) if inning_index < original_length_a
      innings_list_b.delete_at(inning_index) if inning_index < original_length_b

      data["playera"]["innings_list"] = innings_list_a
      data["playerb"]["innings_list"] = innings_list_b

      data["playera"]["innings"] = [data["playera"]["innings"].to_i - 1, 1].max if inning_index < original_length_a
      data["playerb"]["innings"] = [data["playerb"]["innings"].to_i - 1, 1].max if inning_index < original_length_b

      recalculate_player_stats("playera", save_now: false)
      recalculate_player_stats("playerb", save_now: false)

      { success: true }
    rescue StandardError => e
      Rails.logger.error "ERROR delete_inning: #{e.message}"
      { success: false, error: e.message }
    end

    # Insert an empty inning before the given index for BOTH players.
    # Caller handles persistence after.
    def insert_inning(before_index, playing_or_set_over: true)
      return unless playing_or_set_over

      innings_list_a = Array(data.dig("playera", "innings_list"))
      innings_redo_a = Array(data.dig("playera", "innings_redo_list"))
      innings_redo_a = [0] if innings_redo_a.empty?

      innings_list_b = Array(data.dig("playerb", "innings_list"))
      innings_redo_b = Array(data.dig("playerb", "innings_redo_list"))
      innings_redo_b = [0] if innings_redo_b.empty?

      full_a = innings_list_a + innings_redo_a
      full_b = innings_list_b + innings_redo_b

      full_a.insert(before_index, 0)
      full_b.insert(before_index, 0)

      data["playera"]["innings"] = (data["playera"]["innings"].to_i + 1)
      data["playerb"]["innings"] = (data["playerb"]["innings"].to_i + 1)

      if full_a.length > 1
        data["playera"]["innings_list"] = full_a[0...-1]
        data["playera"]["innings_redo_list"] = [full_a.last]
      else
        data["playera"]["innings_list"] = []
        data["playera"]["innings_redo_list"] = [full_a.first || 0]
      end

      if full_b.length > 1
        data["playerb"]["innings_list"] = full_b[0...-1]
        data["playerb"]["innings_redo_list"] = [full_b.last]
      else
        data["playerb"]["innings_list"] = []
        data["playerb"]["innings_redo_list"] = [full_b.first || 0]
      end

      recalculate_player_stats("playera", save_now: false)
      recalculate_player_stats("playerb", save_now: false)
    end

    # Recalculate result, hs, gd for a player from the current innings data.
    # Pass save_now: false to defer the save (caller handles it).
    def recalculate_player_stats(player, save_now: false) # rubocop:disable Lint/UnusedMethodArgument
      innings_list = Array(data[player]["innings_list"])
      innings_redo_list = Array(data[player]["innings_redo_list"])
      innings_redo_list = [0] if innings_redo_list.empty?
      current_innings = data[player]["innings"].to_i

      data[player]["result"] = innings_list.compact.sum

      all_innings = innings_list + innings_redo_list
      data[player]["hs"] = all_innings.compact.max || 0

      total_points = all_innings.compact.sum
      data[player]["gd"] = if current_innings.positive?
                             format("%.3f", total_points.to_f / current_innings)
                           else
                             0.0
                           end
    end

    # Update innings data for a player from a complete innings array.
    # Caller handles persistence after.
    def update_player_innings_data(player, innings_array)
      current_innings = data[player]["innings"].to_i

      if current_innings.positive? && innings_array.length >= current_innings
        data[player]["innings_list"] = innings_array[0...(current_innings - 1)]
        data[player]["innings_redo_list"] = [innings_array[current_innings - 1] || 0]
      else
        data[player]["innings_list"] = []
        data[player]["innings_redo_list"] = [innings_array.first || 0]
      end

      data[player]["result"] = data[player]["innings_list"].compact.sum

      data[player]["hs"] = innings_array.compact.max || 0

      total_points = innings_array.compact.sum
      data[player]["gd"] = if current_innings.positive?
                             format("%.3f", total_points.to_f / current_innings)
                           else
                             0.0
                           end
    end

    # Calculate running totals (cumulative sums) for a player's completed innings.
    def calculate_running_totals(player_id)
      innings = data.dig(player_id, "innings_list") || []
      totals = []
      sum = 0
      innings.each do |points|
        sum += points.to_i
        totals << sum
      end
      totals
    end

    # -------------------------------------------------------------------------
    # Snooker methods
    # -------------------------------------------------------------------------

    # Returns the initial number of red balls for snooker (6, 10, or 15).
    def initial_red_balls
      return 15 unless data["free_game_form"] == "snooker"

      value = data["initial_red_balls"].to_i
      if [6, 10, 15].include?(value)
        value
      else
        15
      end
    end

    # Updates snooker game state when a ball is potted.
    def update_snooker_state(ball_value)
      return unless data["free_game_form"] == "snooker"

      initial_reds = initial_red_balls
      data["snooker_state"] ||= {
        "reds_remaining" => initial_reds,
        "last_potted_ball" => nil,
        "free_ball_active" => false,
        "colors_sequence" => [2, 3, 4, 5, 6, 7]
      }

      state = data["snooker_state"]

      free_ball_was_active = state["free_ball_active"] || false

      state["free_ball_active"] = false if free_ball_was_active

      if ball_value == 1
        current_reds = state["reds_remaining"].to_i
        state["reds_remaining"] = [current_reds - 1, 0].max
        state["last_potted_ball"] = 1
      elsif ball_value.between?(2, 7)
        state["last_potted_ball"] = ball_value

        if state["reds_remaining"].to_i <= 0
          state["colors_sequence"] = state["colors_sequence"].reject { |c| c == ball_value }
        end
      end
    rescue StandardError => e
      Rails.logger.error "ERROR update_snooker_state: #{e}, #{e.backtrace&.join("\n")}"
    end

    # Undo the last potted ball for a snooker player.
    def undo_snooker_ball(player_role)
      return unless data["free_game_form"] == "snooker"

      data[player_role]["break_balls_redo_list"] ||= [[]]

      current_break_balls = data[player_role]["break_balls_redo_list"][-1] || []

      if current_break_balls.any?
        current_break_balls.pop

        new_score = current_break_balls.sum
        data[player_role]["innings_redo_list"][-1] = new_score

        recalculate_snooker_state_from_protocol

        if current_break_balls.any?
          data["snooker_state"]["last_potted_ball"] = current_break_balls.last
        else
          other_player = (player_role == "playera" ? "playerb" : "playera")
          other_break_balls = data[other_player]["break_balls_redo_list"]&.[](-1) || []
          if other_break_balls.any?
            data["snooker_state"]["last_potted_ball"] = other_break_balls.last
          elsif data[player_role]["break_balls_list"]&.any?
            last_completed = data[player_role]["break_balls_list"].last
            data["snooker_state"]["last_potted_ball"] = last_completed.last if last_completed&.any?
          elsif data[other_player]["break_balls_list"]&.any?
            last_completed = data[other_player]["break_balls_list"].last
            data["snooker_state"]["last_potted_ball"] = last_completed.last if last_completed&.any?
          else
            data["snooker_state"]["last_potted_ball"] = nil
          end
        end
      end

      recompute_result(player_role)
    end

    # Recalculate snooker state (reds_remaining, colors_sequence) from protocol.
    def recalculate_snooker_state_from_protocol
      return unless data["free_game_form"] == "snooker"
      return unless data["snooker_state"].present?

      initial_reds = initial_red_balls
      all_potted_balls = []

      %w[playera playerb].each do |player|
        if data[player]["break_balls_list"].present?
          data[player]["break_balls_list"].each do |break_balls|
            all_potted_balls += Array(break_balls) if break_balls.present?
          end
        end
        if data[player]["break_balls_redo_list"].present? && data[player]["break_balls_redo_list"][-1].present?
          all_potted_balls += Array(data[player]["break_balls_redo_list"][-1])
        end
      end

      reds_potted = all_potted_balls.count(1)
      data["snooker_state"]["reds_remaining"] = [initial_reds - reds_potted, 0].max

      if data["snooker_state"]["reds_remaining"] <= 0
        all_colors = [2, 3, 4, 5, 6, 7]
        temp_reds = initial_reds
        all_potted_balls.each do |ball|
          if temp_reds.positive?
            temp_reds -= 1 if ball == 1
          elsif ball.between?(2, 7)
            all_colors.delete(ball)
          end
        end
        data["snooker_state"]["colors_sequence"] = all_colors
      else
        data["snooker_state"]["colors_sequence"] = [2, 3, 4, 5, 6, 7]
      end
    end

    # Determines which balls are "on" (playable) in snooker according to rules.
    # Returns a Hash with ball values 1-7 as keys and :on, :addable, or :off.
    def snooker_balls_on
      return {} unless data["free_game_form"] == "snooker"

      initial_reds = initial_red_balls
      data["snooker_state"] ||= {
        "reds_remaining" => initial_reds,
        "last_potted_ball" => nil,
        "free_ball_active" => false,
        "colors_sequence" => [2, 3, 4, 5, 6, 7]
      }

      state = data["snooker_state"]
      reds_remaining = state["reds_remaining"] || initial_reds
      last_potted = state["last_potted_ball"]
      free_ball_active = state["free_ball_active"] || false
      colors_sequence = state["colors_sequence"] || [2, 3, 4, 5, 6, 7]

      return { 1 => :on, 2 => :on, 3 => :on, 4 => :on, 5 => :on, 6 => :on, 7 => :on } if free_ball_active

      if reds_remaining <= 0
        next_color = colors_sequence.first
        return { 1 => :off, 2 => :on, 3 => :on, 4 => :on, 5 => :on, 6 => :on, 7 => :on } if next_color.nil?

        result = {}
        (1..7).each do |ball|
          result[ball] = ball == next_color ? :on : :off
        end
        return result
      end

      if last_potted == 1
        if reds_remaining.positive?
          { 1 => :addable, 2 => :on, 3 => :on, 4 => :on, 5 => :on, 6 => :on, 7 => :on }
        else
          next_color = colors_sequence.first
          if next_color.nil?
            { 1 => :off, 2 => :off, 3 => :off, 4 => :off, 5 => :off, 6 => :off, 7 => :off }
          else
            result = {}
            (1..7).each do |ball|
              result[ball] = ball == next_color ? :on : :off
            end
            result
          end
        end
      elsif last_potted && last_potted >= 2 && last_potted <= 7
        if reds_remaining.positive?
          { 1 => :on, 2 => :off, 3 => :off, 4 => :off, 5 => :off, 6 => :off, 7 => :off }
        else
          next_color = colors_sequence.first
          if next_color.nil?
            { 1 => :off, 2 => :off, 3 => :off, 4 => :off, 5 => :off, 6 => :off, 7 => :off }
          else
            result = {}
            (1..7).each do |ball|
              result[ball] = ball == next_color ? :on : :off
            end
            result
          end
        end
      elsif reds_remaining.positive?
        { 1 => :on, 2 => :off, 3 => :off, 4 => :off, 5 => :off, 6 => :off, 7 => :off }
      else
        next_color = colors_sequence.first
        if next_color.nil?
          { 1 => :off, 2 => :off, 3 => :off, 4 => :off, 5 => :off, 6 => :off, 7 => :off }
        else
          result = {}
          (1..7).each do |ball|
            result[ball] = ball == next_color ? :on : :off
          end
          result
        end
      end
    rescue StandardError => e
      Rails.logger.error "ERROR snooker_balls_on: #{e}, #{e.backtrace&.join("\n")}"
      { 1 => :on, 2 => :on, 3 => :on, 4 => :on, 5 => :on, 6 => :on, 7 => :on }
    end

    # Calculate remaining points on the table in a Snooker frame.
    def snooker_remaining_points
      return 0 unless data["free_game_form"] == "snooker"

      state = data["snooker_state"] || {}
      reds_remaining = state["reds_remaining"].to_i
      colors_sequence = state["colors_sequence"] || [2, 3, 4, 5, 6, 7]

      color_points = colors_sequence.sum

      if reds_remaining.positive?
        (reds_remaining * 1) + 27
      else
        color_points
      end
    rescue StandardError => e
      Rails.logger.error "ERROR snooker_remaining_points: #{e}, #{e.backtrace&.join("\n")}"
      0
    end

    # Mutate the data hash for terminate_current_inning.
    # Handles fouls reset, innings append, snooker state, biathlon phase, active player switch.
    # Returns :game_finished when the innings_goal has been reached or the state is not playing.
    # Returns :ok on success so the caller (TableMonitor) can persist and call evaluate_result.
    def terminate_inning_data(player, playing:)
      current_role = player.presence || data["current_inning"]["active_player"]
      unless playing && (data["innings_goal"].to_i.zero? || data[current_role]["innings"].to_i < data["innings_goal"].to_i)
        return :game_finished
      end

      if data[current_role]["fouls_1"].to_i > 2
        data[current_role]["fouls_1"] = 0
        data[current_role]["innings_foul_redo_list"][-1] = data[current_role]["innings_foul_redo_list"][-1].to_i - 15
      end
      n_balls = Array(data[current_role]["innings_redo_list"]).pop.to_i
      n_fouls = Array(data[current_role]["innings_foul_redo_list"]).pop.to_i

      # Phase 38.5: BK-2plus / BK-2kombi DZ-Phase rule. If the shooter's inning
      # closes net-negative AND the discipline credits negatives to the opponent,
      # transfer the absolute value to the opponent's current inning and seal the
      # shooter's inning at 0. For BK-2 / BK-2kombi SP-Phase, signed-negative
      # innings remain on the shooter (no transfer).
      if n_balls.negative? && bk_credit_negative_to_opponent?
        other_role = (current_role == "playera") ? "playerb" : "playera"
        init_lists(other_role)
        data[other_role]["innings_redo_list"][-1] =
          data[other_role]["innings_redo_list"][-1].to_i + n_balls.abs
        recompute_result(other_role)
        n_balls = 0
      end

      data["balls_counter_stack"] << data["balls_counter"].to_i if n_balls != 0
      data["balls_counter"] -= n_balls
      init_lists(current_role)
      data[current_role]["innings_list"] << n_balls
      data[current_role]["innings_foul_list"] << n_fouls

      # Store break balls and foul info for snooker protocol
      if data["free_game_form"] == "snooker"
        break_balls = Array(data[current_role]["break_balls_redo_list"]).pop || []
        data[current_role]["break_balls_list"] ||= []
        data[current_role]["break_balls_list"] << break_balls

        data[current_role]["break_fouls_list"] ||= []

        last_foul = data["last_foul"]
        made_foul = last_foul && last_foul["fouling_player"] == current_role
        pending_foul = data[current_role]["pending_foul"]

        if made_foul
          data[current_role]["break_fouls_list"] << last_foul
        elsif pending_foul
          data[current_role]["break_fouls_list"] << pending_foul
          data[current_role].delete("pending_foul")
        else
          data[current_role]["break_fouls_list"] << nil
        end
      end

      recompute_result(current_role)
      if data["innings_goal"].to_i.zero? || data[current_role]["innings"].to_i < data["innings_goal"].to_i
        data[current_role]["innings"] += 1
      end
      data[current_role]["hs"] = n_balls if n_balls > data[current_role]["hs"].to_i
      data[current_role]["gd"] =
        format("%.2f", data[current_role]["result"].to_f / data[current_role].andand["innings"].to_i)

      if data["free_game_form"] == "snooker" && data["snooker_state"].present?
        data["snooker_state"]["last_potted_ball"] = nil
      end

      if discipline == "Biathlon" && current_role == "playerb"
        innings_goal_3b = 30
        if data["biathlon_phase"] == "3b" && discipline == "Biathlon" && data[current_role]["innings"] == innings_goal_3b
          data["biathlon_phase"] = "5k"
          other_player = current_role == "playera" ? "playerb" : "playera"
          Array(data[current_role]["innings_list"]).each_with_index do |val, ix|
            data[current_role]["innings_list"][ix] = val * 6
          end
          data[current_role]["result"] = data[current_role]["result"] * 6
          data[current_role]["innings_redo_list"][-1] = data[current_role]["innings_redo_list"][-1] * 6
          Array(data[other_player]["innings_list"]).each_with_index do |val, ix|
            data[other_player]["innings_list"][ix] = val * 6
          end
          data[other_player]["result"] = data[other_player]["result"] * 6
          if data[other_player]["innings_redo_list"].present?
            data[other_player]["innings_redo_list"][-1] = data[other_player]["innings_redo_list"][-1] * 6
          end
          data[current_role]["result_3b"] =
            (data[current_role]["innings_list"]&.sum.to_i + data[current_role]["innings_redo_list"][-1].to_i) / 6
          data[other_player]["result_3b"] =
            (data[other_player]["innings_list"]&.sum.to_i + data[other_player]["innings_redo_list"][-1].to_i) / 6
          data[current_role]["innings_3b"] = data[current_role]["innings"].to_i
          data[other_player]["innings_3b"] = data[other_player]["innings"].to_i
        end
      end

      other_player = current_role == "playera" ? "playerb" : "playera"
      data["current_inning"]["active_player"] = other_player
      data[other_player]["innings_redo_list"] = [0] if data[current_role]["innings_redo_list"]&.blank?

      :ok
    end

    # Phase 38.5 D-09: data-driven predicate. Reads the resolver-baked value from
    # TableMonitor.data["allow_negative_score_input"] (written at start_game and
    # at each set boundary by BkParamResolver.bake!). Fallback false (D-04) when
    # key is missing — preserves Karambol/Snooker/Pool default behaviour exactly.
    #
    # Replaces the Phase 38.1 free_game_form-string-equality body — that body
    # missed BK-2/BK50/BK100 (latent bug D-12, fixed by this rewrite + D-08 seed).
    def allow_negative_scores?
      !!data["allow_negative_score_input"]
    end

    # Phase 38.5 D-09: data-driven predicate. Reads the resolver-baked value from
    # TableMonitor.data["negative_credits_opponent"] (written at start_game and
    # at each set boundary by BkParamResolver.bake!). Fallback false (D-04).
    #
    # When TRUE: a negative input from a player is credited (positively) to the
    # OPPONENT, with the shooter's score unchanged.
    # When FALSE: signed-add to the shooter's own score (legacy karambol behaviour).
    #
    # Replaces the Phase 38.1 free_game_form-string-equality body — that body
    # missed the BK-2kombi DZ-Phase (latent bug D-11, fixed by this rewrite +
    # the resolver writing effective_discipline=bk_2plus → negative_credits_opponent=true
    # for BK-2kombi DZ sets).
    def bk_credit_negative_to_opponent?
      !!data["negative_credits_opponent"]
    end

    private

    attr_reader :data, :discipline
end
