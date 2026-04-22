# frozen_string_literal: true

# TableMonitor::OptionsPresenter
#
# Read-only view-data builder. Receives a TableMonitor instance and locale,
# returns the options hash used by scoreboard views and TableMonitorJob.
# No ActiveRecord writes, no class-level state mutations.
#
# After calling .call, the following readers are available for the
# thin wrapper to assign cattr values:
#   - gps (GameParticipation array)
#   - location (Table location)
#   - show_tournament (Tournament or Party)
#   - my_table (Table)
class TableMonitor::OptionsPresenter
    attr_reader :gps, :location, :show_tournament, :my_table

    def initialize(table_monitor, locale:)
      @tm = table_monitor
      @locale = locale
    end

    def call
      I18n.with_locale(@locale) do
        build_options
      end
    end

    private

    def build_options
      show_game = @tm.game.present? ? @tm.game : @tm.prev_game
      show_data = @tm.game.present? ? @tm.data : @tm.prev_data
      show_tournament_monitor = @tm.game.present? ? @tm.tournament_monitor : @tm.prev_tournament_monitor
      @gps = show_game&.game_participations&.order(:role).to_a
      options = HashWithIndifferentAccess.new(
        showing_prev_game: @tm.game.blank?,
        free_game_form: show_data["free_game_form"],
        first_break_choice: show_data["first_break_choice"],
        balls_on_table: show_data["balls_on_table"],
        balls_counter: show_data["balls_counter"],
        extra_balls: show_data["extra_balls"],
        warntime: show_data["warntime"],
        gametime: show_data["gametime"],
        team_size: show_data["team_size"],
        redo_sets: show_data["redo_sets"],
        id: @tm.id,
        name: @tm.name,
        game_name: show_game&.display_gname,
        tournament_title: show_tournament_monitor&.tournament&.title,
        current_round: show_tournament_monitor&.current_round,
        timeout: if show_tournament_monitor.is_a?(PartyMonitor)
                   nil
                 else
                   show_tournament_monitor&.timeout || show_data["timeout"].to_i
                 end,
        timeouts: if show_tournament_monitor.is_a?(PartyMonitor)
                    nil
                  else
                    show_tournament_monitor&.timeouts || show_data["timeouts"].to_i
                  end,
        innings_goal: show_data["innings_goal"].presence.to_i,
        active_timer: show_tournament_monitor.is_a?(PartyMonitor) ? nil : @tm.active_timer,
        start_at: show_tournament_monitor.is_a?(PartyMonitor) ? nil : @tm.timer_start_at,
        finish_at: show_tournament_monitor.is_a?(PartyMonitor) ? nil : @tm.timer_finish_at,
        current_sets_a: show_data["ba_results"].andand["Sets1"].to_i,
        current_sets_b: show_data["ba_results"].andand["Sets2"].to_i,
        current_kickoff_player: show_data["current_kickoff_player"].presence || "playera",
        current_left_player: show_data["current_left_player"].presence || "playera",
        current_right_player: if (show_data["current_left_player"].presence || "playera") == "playera"
                                "playerb"
                              else
                                "playera"
                              end,
        current_left_color: show_data["current_left_color"].presence || "white",
        current_right_color: if (show_data["current_left_color"].presence || "white") == "white"
                               "yellow"
                             else
                               "white"
                             end,
        sets_to_play: show_data["sets_to_play"],
        sets_to_win: show_data["sets_to_win"],
        kickoff_switches_with: show_data["kickoff_switches_with"].presence || "set",
        color_remains_with_set: show_data["color_remains_with_set"],
        allow_overflow: show_data["allow_overflow"],
        allow_follow_up: show_data["allow_follow_up"],
        balls_counter_stack: show_data["balls_counter_stack"],
        fixed_display_left: show_data["fixed_display_left"],
        player_a_active: @tm.playing? &&
          (show_data["current_inning"].andand["active_player"] == @gps[0]&.role),
        player_b_active: @tm.playing? &&
          (show_data["current_inning"].andand["active_player"] == @gps[1]&.role),
        player_a: {
          logo: (@gps[0]&.player&.club&.logo unless @gps[0]&.player&.guest?) || @gps[0]&.player&.logo,
          lastname: @gps[0]&.player&.lastname || "Spieler A",
          shortname: @gps[0]&.player&.shortname || "Spieler A",
          firstname_short: if @gps[0]&.player&.firstname.present?
                             "#{@gps[0]&.player&.firstname&.gsub(
                               "Dr. ", ""
                             )&.[](0)}. "
                           else
                             ""
                           end,
          firstname: @gps[0]&.player&.firstname,
          fullname: if show_tournament_monitor&.id.present? ||
            @gps[0]&.player.is_a?(Team)
                      @gps[0]&.player&.fullname
                    elsif @gps[0]&.player&.guest?
                      @gps[0]&.player&.fullname
                    else
                      @gps[0]&.player&.simple_firstname.presence || @gps[0]&.player&.lastname
                    end,
          balls_goal: show_data[@gps[0].andand.role].andand["balls_goal"].presence.to_i,
          fouls_1: show_data[@gps[0]&.role].andand["fouls_1"],
          discipline: show_data[@gps[0]&.role].andand["discipline"] ||
            (show_tournament_monitor&.tournament.is_a?(Tournament) &&
              show_tournament_monitor&.tournament&.discipline&.name),
          result: show_data[@gps[0]&.role].andand["result"].to_i,
          hs: show_data[@gps[0]&.role].andand["hs"].to_i,
          gd: show_data[@gps[0]&.role].andand["gd"],
          innings: show_data[@gps[0]&.role].andand["innings"].to_i,
          tc: show_data[@gps[0]&.role].andand["tc"].to_i
        },
        player_b: {
          logo: (@gps[1]&.player&.club&.logo unless @gps[1]&.player&.guest?) || @gps[1]&.player&.logo,
          lastname: @gps[1]&.player&.lastname || "Spieler B",
          shortname: @gps[1]&.player&.shortname || "Spieler B",
          firstname_short: if @gps[1]&.player&.firstname.present?
                             "#{@gps[1]&.player&.firstname&.gsub(
                               "Dr. ", ""
                             )&.andand&.[](0)}. "
                           else
                             ""
                           end,
          firstname: @gps[1]&.player&.firstname,
          fullname: if show_tournament_monitor&.id.present? ||
            @gps[1]&.player.is_a?(Team)
                      @gps[1]&.player&.fullname
                    elsif @gps[1]&.player&.guest?
                      @gps[1]&.player&.fullname
                    else
                      @gps[1]&.player&.simple_firstname.presence || @gps[1]&.player&.lastname
                    end,
          balls_goal: show_data[@gps[1]&.role].andand["balls_goal"].presence.to_i,
          fouls_1: show_data[@gps[1]&.role].andand["fouls_1"],
          discipline: show_data[@gps[1]&.role].andand["discipline"] ||
            (show_tournament_monitor&.tournament.is_a?(Tournament) &&
              show_tournament_monitor&.tournament&.discipline&.name),
          result: show_data[@gps[1]&.role].andand["result"].to_i,
          hs: show_data[@gps[1]&.role].andand["hs"].to_i,
          gd: show_data[@gps[1]&.role].andand["gd"],
          innings: show_data[@gps[1]&.role].andand["innings"].to_i,
          tc: show_data[@gps[1]&.role].andand["tc"].to_i
        },
        current_inning: {
          balls: show_data["current_inning"].andand["balls"].to_i,
          active_player: show_data["current_inning"].andand["active_player"]
        }
      ).stringify_keys

      disambiguate_player_names!(options, @gps, show_tournament_monitor)

      # table kann im Zuge von Detach/Delete-Flows oder in isolierten Tests
      # fehlen — dann existieren weder Location noch Scoreboard-Kontext.
      @location = @tm.table&.location
      @show_tournament = if @tm.tournament_monitor.is_a?(PartyMonitor)
                           @tm.tournament_monitor&.party
                         else
                           @tm.tournament_monitor&.tournament
                         end
      @my_table = @tm.table

      options
    end

    # Für Trainings- und freie Spiele (ohne Turnier-Monitor) die Spielernamen so
    # kürzen, dass sie sich eindeutig unterscheiden:
    # Beispiel: "Andreas Meissner" vs. "Andreas Mertens" =>
    # "Andreas Mei." und "Andreas Mer."
    def disambiguate_player_names!(options, gps, show_tournament_monitor)
      return unless show_tournament_monitor.blank? &&
                    gps&.size.to_i >= 2 &&
                    gps[0]&.player.is_a?(Player) &&
                    gps[1]&.player.is_a?(Player)

      p1 = gps[0].player
      p2 = gps[1].player

      fn1 = p1.simple_firstname.presence || p1.firstname
      fn2 = p2.simple_firstname.presence || p2.firstname
      ln1 = p1.lastname.to_s
      ln2 = p2.lastname.to_s

      # Nur eingreifen, wenn beide einen Vornamen und Nachnamen haben und
      # die (vereinfachten) Vornamen gleich sind.
      return unless fn1.present? && fn2.present? && ln1.present? && ln2.present? && fn1 == fn2 && ln1 != ln2

      max_len = [ln1.length, ln2.length].max
      prefix_len = 1

      # Finde die kleinste Präfix-Länge, bei der sich die Nachnamen unterscheiden
      prefix_len += 1 while prefix_len < max_len && ln1[0, prefix_len].casecmp?(ln2[0, prefix_len])

      # Wenn sich auch nach Durchlauf des Loops nichts unterscheidet, lassen wir die
      # bisherige Logik unverändert (extremer Sonderfall, z.B. exakt gleicher Name).
      return if ln1[0, prefix_len].casecmp?(ln2[0, prefix_len])

      options[:player_a][:fullname] = "#{fn1} #{ln1[0, prefix_len]}."
      options[:player_b][:fullname] = "#{fn2} #{ln2[0, prefix_len]}."
    end
end
