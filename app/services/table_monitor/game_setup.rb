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

  # Zweiter Klassenmethoden-Einstiegspunkt fuer assign_game-Logik.
  # Erhaelt ein Game-Objekt (game_p = party game parameter) und weist das Spiel dem TableMonitor zu.
  def self.assign(table_monitor:, game_participation:)
    instance = new(table_monitor: table_monitor)
    instance.perform_assign(game_participation)
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
