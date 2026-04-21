# frozen_string_literal: true

# Kapselt die gesamte start_game-Logik aus TableMonitor in einen eigenstaendigen Service.
# Verantwortlichkeiten:
#   - Game- und GameParticipation-Datensaetze anlegen (neues Spiel oder bestehendes Party-Spiel)
#   - Result-Hash aufbauen und via deep_merge_data! in das Modell schreiben
#   - initialize_game auf dem Modell aufrufen (Spielstatus initialisieren)
#   - suppress_broadcast sicherstellen (ensure-Block garantiert Reset auch bei Ausnahmen)
#   - Genau einen TableMonitorJob am Ende einreihen
#
# Zweiter Einstiegspunkt: .assign(table_monitor:, game_participation:) fuer assign_game-Logik.
#
# Verwendung:
#   TableMonitor::GameSetup.call(table_monitor: tm, options: params)
#   TableMonitor::GameSetup.assign(table_monitor: tm, game_participation: gp)
class TableMonitor::GameSetup < ApplicationService
  def initialize(kwargs = {})
    @tm = kwargs[:table_monitor]
    @options = HashWithIndifferentAccess.new(kwargs[:options] || {})
  end

  # Setzt suppress_broadcast vor Batch-Saves und garantiert Reset im ensure-Block.
  def call
    @tm.suppress_broadcast = true
    perform_start_game
    true
  ensure
    @tm.suppress_broadcast = false
  end

  # Initialisiert den Spielstatus in data fuer eine neue Partie.
  # Enthaelt den extrahierten Body aus TableMonitor#initialize_game.
  # Aufgerufen via TableMonitor#initialize_game (thin delegation wrapper).
  def self.initialize_game(table_monitor:)
    tm = table_monitor
    Rails.logger.debug { "--------------------->>> initialize_game <<<------------------------------------------" }
    Rails.logger.debug { "+++ 7 - m6[#{tm.id}]table_monitor#initialize_game" }
    current_kickoff_player = "playera"
    tm.copy_from = nil

    # Werte die aus do_placement kommen sollen NICHT überschrieben werden
    existing_innings_goal = tm.data["innings_goal"]
    existing_balls_goal_a = tm.data.dig("playera", "balls_goal")
    existing_balls_goal_b = tm.data.dig("playerb", "balls_goal")

    Rails.logger.info "===== initialize_game DEBUG ====="
    Rails.logger.info "BEFORE deep_merge: data['innings_goal'] = #{tm.data['innings_goal'].inspect}"
    Rails.logger.info "BEFORE deep_merge: data['playera']&.[]('balls_goal') = #{tm.data.dig('playera', 'balls_goal').inspect}"
    Rails.logger.info "BEFORE deep_merge: data['playerb']&.[]('balls_goal') = #{tm.data.dig('playerb', 'balls_goal').inspect}"
    Rails.logger.info "existing_innings_goal = #{existing_innings_goal.inspect}"
    Rails.logger.info "existing_balls_goal_a = #{existing_balls_goal_a.inspect}"
    Rails.logger.info "existing_balls_goal_b = #{existing_balls_goal_b.inspect}"
    Rails.logger.info "tournament_monitor.innings_goal = #{tm.tournament_monitor&.innings_goal.inspect}"

    # Initialize initial_red_balls for snooker (default 15)
    initial_reds = if tm.tournament_monitor.is_a?(PartyMonitor) && tm.game.data["free_game_form"] == "snooker"
                     tm.game.data["initial_red_balls"] || 15
                   elsif tm.data["free_game_form"] == "snooker"
                     tm.data["initial_red_balls"] || 15
                   else
                     15
                   end
    # Ensure valid value (6, 10, or 15)
    initial_reds = [6, 10, 15].include?(initial_reds.to_i) ? initial_reds.to_i : 15

    tm.deep_merge_data!({
                          "free_game_form" => tm.tournament_monitor.is_a?(PartyMonitor) ? tm.game.data["free_game_form"] : nil,
                          "initial_red_balls" => initial_reds,
                          "balls_on_table" => 15,
                          "balls_counter" => 15,
                          "balls_counter_stack" => [],
                          "extra_balls" => 0,
                          "current_kickoff_player" => current_kickoff_player,
                          "current_left_player" => current_kickoff_player,
                          "current_left_color" => "white",
                          "biathlon_phase" => if tm.tournament_monitor&.tournament.is_a?(Tournament) &&
                            tm.tournament_monitor&.tournament&.discipline&.name == "Biathlon"
                                                "3b"
                                              else
                                                nil
                                              end,
                          "allow_overflow" => if tm.tournament_monitor.is_a?(PartyMonitor)
                                                tm.game.data["allow_overflow"]
                                              else
                                                tm.tournament_monitor&.allow_overflow
                                              end,
                          "kickoff_switches_with" => (
                            if tm.tournament_monitor.is_a?(PartyMonitor)
                              tm.game.data["kickoff_switches_with"]
                            else
                              tm.tournament_monitor&.kickoff_switches_with ||
                                tm.tournament_monitor&.tournament&.kickoff_switches_with
                            end).presence || "set",
                          "allow_follow_up" => if tm.tournament_monitor.is_a?(PartyMonitor)
                                                  tm.game.data["allow_follow_up"]
                                                else
                                                  tm.tournament_monitor&.allow_follow_up ||
                                                    tm.tournament_monitor&.tournament&.allow_follow_up
                                                end,
                          "sets_to_win" => if tm.tournament_monitor.is_a?(PartyMonitor)
                                             tm.game.data["sets_to_win"]
                                           else
                                             tm.tournament_monitor&.sets_to_win ||
                                               tm.tournament_monitor&.tournament&.sets_to_win
                                           end,
                          "sets_to_play" => if tm.tournament_monitor.is_a?(PartyMonitor)
                                              tm.game.data["sets_to_play"]
                                            else
                                              tm.tournament_monitor&.sets_to_play ||
                                                tm.tournament_monitor&.tournament&.sets_to_play
                                            end,
                          "team_size" => if tm.tournament_monitor.is_a?(PartyMonitor)
                                           tm.game.data["team_size"]
                                         else
                                           (tm.tournament_monitor&.team_size ||
                                             tm.tournament_monitor&.tournament&.team_size).presence || 1
                                         end,
                          "innings_goal" => if tm.tournament_monitor.is_a?(PartyMonitor)
                                              tm.game.data["innings_goal"]
                                            else
                                              # PRIORITÄT: Bereits in data gesetzt (aus do_placement) > tournament_monitor > tournament
                                              existing_innings_goal ||
                                                tm.tournament_monitor&.innings_goal ||
                                                tm.tournament_monitor&.tournament&.innings_goal ||
                                                tm.tournament_monitor&.tournament&.data.andand[:innings_goal]
                                            end,
                          "playera" => {
                            "result" => 0,
                            "innings" => 0,
                            "fouls_1" => 0,
                            "innings_list" => [],
                            "innings_redo_list" => [],
                            "result_3b" => 0,
                            "hs" => 0,
                            "discipline" => if tm.tournament_monitor&.tournament.is_a?(Tournament)
                                              tm.tournament_monitor&.tournament&.discipline&.name
                                            else
                                              nil
                                            end,
                            "gd" => 0.0,
                            "balls_goal" => if tm.tournament_monitor.is_a?(PartyMonitor)
                                              tm.game.data["balls_goal_a"]
                                            else
                                              # PRIORITÄT: Bereits in data gesetzt (aus do_placement) > handicap > tournament_monitor > tournament
                                              existing_balls_goal_a ||
                                                (tm.tournament_monitor&.tournament&.handicap_tournier? &&
                                                  tm.seeding_from("playera").balls_goal.presence) ||
                                                tm.tournament_monitor&.balls_goal ||
                                                tm.tournament_monitor&.tournament&.balls_goal ||
                                                tm.tournament_monitor&.tournament&.data.andand[:balls_goal]
                                            end,
                            "tc" => if tm.tournament_monitor.is_a?(PartyMonitor)
                                       tm.game.data["timeouts"]
                                     else
                                       tm.tournament_monitor&.timeouts ||
                                         tm.tournament_monitor&.tournament&.timeouts ||
                                         tm.tournament_monitor&.tournament&.data.andand[:timeouts] ||
                                         0
                                     end
                          },
                          "playerb" => {
                            "result" => 0,
                            "innings" => 0,
                            "fouls_1" => 0,
                            "innings_list" => [],
                            "innings_redo_list" => [],
                            "result_3b" => 0,
                            "hs" => 0,
                            "discipline" => if tm.tournament_monitor&.tournament.is_a?(Tournament)
                                              tm.tournament_monitor&.tournament&.discipline&.name
                                            else
                                              nil
                                            end,
                            "gd" => 0.0,
                            "balls_goal" => if tm.tournament_monitor.is_a?(PartyMonitor)
                                              tm.game.data["balls_goal_a"]
                                            else
                                              # PRIORITÄT: Bereits in data gesetzt (aus do_placement) > handicap > tournament_monitor > tournament
                                              existing_balls_goal_b ||
                                                (tm.tournament_monitor&.tournament&.handicap_tournier? &&
                                                  tm.seeding_from("playerb").balls_goal.presence) ||
                                                tm.tournament_monitor&.balls_goal ||
                                                tm.tournament_monitor&.tournament&.balls_goal ||
                                                tm.tournament_monitor&.tournament&.data.andand[:balls_goal]
                                            end,
                            "tc" => if tm.tournament_monitor.is_a?(PartyMonitor)
                                       tm.game.data["timeouts"]
                                     else
                                       tm.tournament_monitor&.timeouts ||
                                         tm.tournament_monitor&.tournament&.timeouts ||
                                         tm.tournament_monitor&.tournament&.data.andand["timeouts"] ||
                                         0
                                     end
                          },
                          "current_inning" => {
                            "active_player" => current_kickoff_player,
                            "balls" => 0
                          }
                        })

    Rails.logger.info "AFTER deep_merge: data['innings_goal'] = #{tm.data['innings_goal'].inspect}"
    Rails.logger.info "AFTER deep_merge: data['playera']&.[]('balls_goal') = #{tm.data.dig('playera', 'balls_goal').inspect}"
    Rails.logger.info "AFTER deep_merge: data['playerb']&.[]('balls_goal') = #{tm.data.dig('playerb', 'balls_goal').inspect}"
    Rails.logger.info "===== initialize_game DEBUG END ====="

    # Initialize snooker state for first frame if this is a snooker game
    if tm.data["free_game_form"] == "snooker"
      tm.deep_merge_data!({
        "snooker_state" => {
          "reds_remaining" => initial_reds,
          "last_potted_ball" => nil,
          "free_ball_active" => false,
          "colors_sequence" => [2, 3, 4, 5, 6, 7]
        },
        "snooker_frame_complete" => false
      })
    end

    tm.data.except!("ba_results", "sets")
  rescue StandardError => e
    Rails.logger.error "ERROR: m6[#{tm.id}]#{e}, #{e.backtrace&.join("\n")}"
    raise StandardError
  end

  # Zweiter Klassenmethoden-Einstiegspunkt fuer assign_game-Logik.
  # Erhaelt ein Game-Objekt (game_p = party game parameter) und weist das Spiel dem TableMonitor zu.
  #
  # Setzt analog zu #call suppress_broadcast vor den Batch-Saves und garantiert
  # Reset im ensure-Block. Ohne das triggert der save! in perform_assign den
  # after_update_commit-Scoreboard-Pfad (nur auf Local Servern aktiv) mitten im
  # Setup — das produziert einen redundanten Broadcast und kann in Tests die
  # OptionsPresenter-Pipeline ohne komplettes Table-Setup explodieren lassen.
  def self.assign(table_monitor:, game_participation:)
    instance = new(table_monitor: table_monitor)
    table_monitor.suppress_broadcast = true
    instance.perform_assign(game_participation)
  ensure
    table_monitor.suppress_broadcast = false
  end

  def perform_assign(game_p)
    Rails.logger.debug { "--------------GameSetup#perform_assign(#{game_p.id}) <<<" }
    @tm.allow_change_tables = @tm.tournament_monitor&.allow_change_tables
    tmp_results = game_p.deep_delete!("tmp_results")
    if tmp_results.andand["state"].present?
      state = tmp_results.delete("state")
      @tm.deep_merge_data!(tmp_results)
      @tm.assign_attributes(game_id: game_p.id, state:)
      @tm.save!
    else
      @tm.assign_attributes(game_id: game_p.id, state: "ready")
      @tm.save!
      @tm.reload
      @tm.initialize_game
      @tm.save!
      if %i[ready ready_for_new_match warmup final_match_score
            final_set_score].include?(@tm.state.to_sym)
        @tm.assign_attributes(ip_address: Time.now.to_i.to_s)
        @tm.start_new_match!
        @tm.finish_warmup! if /shootout/i.match?(game_p.data["player_a"].andand["discipline"])
      end
    end
  rescue StandardError => e
    Rails.logger.error "ERROR: GameSetup#perform_assign[#{@tm.id}]#{e}, #{e.backtrace&.join("\n")}"
    raise
  end

  private

  # Haupt-Ablauf: entspricht dem extrahierten start_game-Body.
  def perform_start_game
    Rails.logger.debug { "--------------GameSetup#perform_start_game(#{@options.inspect}) <<<" }

    existing_party_game = @tm.game if @tm.game.present? && @tm.game.tournament_type.present?

    if existing_party_game.present?
      setup_existing_party_game(existing_party_game)
    else
      create_new_game
    end

    @tm.game.save

    result = build_result_hash
    result["sets_to_win"] = 8 if /shootout/i.match?(@options["discipline_a"])

    @tm.initialize_game
    @tm.deep_merge_data!(result)
    @tm.copy_from = nil
    @tm.save!

    # Callbacks wieder aktivieren und genau einen Job einreihen
    @tm.suppress_broadcast = false
    TableMonitorJob.perform_later(@tm.id, "table_scores")

    @tm.finish_warmup! if @options["discipline_a"] =~ /shootout/i && @tm.may_finish_warmup?
  rescue StandardError => e
    Rails.logger.error "ERROR: GameSetup#perform_start_game[#{@tm.id}]#{e}, #{e.backtrace&.join("\n")}"
    raise
  end

  # Zweig: bestehendes Party-/Turnierspiel verwenden (game.tournament_type present)
  def setup_existing_party_game(existing_game)
    @game = existing_game
    Rails.logger.debug { "Using existing #{@game.tournament_type} game #{@game.id} for table monitor #{@tm.id}" }

    players = Player.where(id: @options["player_a_id"]).order(:dbu_nr).to_a
    team = Player.team_from_players(players)
    gp_a = @game.game_participations.find_or_initialize_by(role: "playera")
    gp_a.update!(player: team)

    players = Player.where(id: @options["player_b_id"]).order(:dbu_nr).to_a
    team = Player.team_from_players(players)
    gp_b = @game.game_participations.find_or_initialize_by(role: "playerb")
    gp_b.update!(player: team)

    # Damit @tm.game den richtigen Wert zurueckgibt
    @tm.game = @game
  end

  # Zweig: neues Game und GameParticipation-Datensaetze anlegen
  def create_new_game
    if @tm.game.present?
      existing_game_id = @tm.game.id
      @tm.game.update(table_monitor: nil)
      Rails.logger.debug { "Unlinked existing game #{existing_game_id} from table monitor #{@tm.id}" }
    end

    @game = Game.new(table_monitor: @tm)
    @tm.reload
    @game.update(data: {})

    players = Player.where(id: @options["player_a_id"]).order(:dbu_nr).to_a
    team = Player.team_from_players(players)
    GameParticipation.create!(
      game_id: @game.id, player: team, role: "playera"
    )
    @game.save

    players = Player.where(id: @options["player_b_id"]).order(:dbu_nr).to_a
    team = Player.team_from_players(players)
    GameParticipation.create!(
      game_id: @game.id, player: team, role: "playerb"
    )

    @tm.game = @game
  end

  # Baut den Result-Hash aus den Optionen auf (extrahiert aus start_game Zeilen 2052-2112).
  def build_result_hash
    kickoff_switches_with = @options["kickoff_switches_with"].presence || "set"
    color_remains_with_set = @options["color_remains_with_set"]
    fixed_display_left = @options["fixed_display_left"]

    {
      "free_game_form" => @options["free_game_form"],
      "first_break_choice" => @options["first_break_choice"],
      "extra_balls" => 0,
      "balls_on_table" => (@options["balls_on_table"].presence || 15).to_i,
      "initial_red_balls" => (@options["initial_red_balls"].presence || 15).to_i,
      "warntime" => @options["warntime"].to_i,
      "gametime" => @options["gametime"].to_i,
      "timeouts" => @options["timeouts"].to_i,
      "timeout" => @options["timeout"].to_i,
      "sets_to_play" => @options["sets_to_play"].to_i,
      "sets_to_win" => @options["sets_to_win"].to_i,
      "kickoff_switches_with" => kickoff_switches_with,
      "allow_follow_up" => @options["allow_follow_up"],
      "color_remains_with_set" => color_remains_with_set,
      "allow_overflow" => @options["allow_overflow"],
      "fixed_display_left" => fixed_display_left,
      "current_kickoff_player" => "playera",
      "current_left_player" => fixed_display_left.present? ? fixed_display_left : "playera",
      "current_left_color" => fixed_display_left == "playerb" ? "yellow" : "white",
      "innings_goal" => @options["innings_goal"],
      "playera" => {
        "balls_goal" => if @options["free_game_form"] == "pool"
                          @options["discipline_a"] == "14.1 endlos" ? @options["balls_goal_a"] : 1
                        else
                          @options["balls_goal_a"]
                        end,
        "tc" => @options["timeouts"].to_i,
        "discipline" => @options["discipline_a"],
        "result" => 0,
        "fouls_1" => 0,
        "innings" => 0,
        "innings_list" => [],
        "innings_foul_list" => [],
        "innings_redo_list" => [],
        "innings_foul_redo_list" => [],
        "hs" => 0,
        "gd" => "0.00"
      },
      "playerb" => {
        "balls_goal" => if @options["free_game_form"] == "pool"
                          @options["discipline_b"] == "14.1 endlos" ? @options["balls_goal_b"] : 1
                        else
                          @options["balls_goal_b"]
                        end,
        "tc" => @options["timeouts"].to_i,
        "discipline" => @options["discipline_b"],
        "result" => 0,
        "fouls_1" => 0,
        "innings" => 0,
        "innings_list" => [],
        "innings_foul_list" => [],
        "innings_redo_list" => [],
        "innings_foul_redo_list" => [],
        "hs" => 0,
        "gd" => "0.00"
      }
    }
  end

  # Setzt die Spieler-Reihenfolge in data["player_map"] (extrahiert aus set_player_sequence).
  # Nur intern verwendet — der TableMonitor ruft dies ggf. direkt auf.
  def set_player_sequence(players)
    Rails.logger.debug { "--------------GameSetup#set_player_sequence#{players.inspect} <<<" }
    (@tm.a..@tm.d).each_with_index do |ab_seqno, ix|
      next if ix >= players.count

      @tm.data["player_map"]["player#{ab_seqno}"] = players[ix]
    end
  rescue StandardError => e
    Rails.logger.error "ERROR: GameSetup#set_player_sequence #{e}, #{e.backtrace&.join("\n")}"
    raise
  end
end
