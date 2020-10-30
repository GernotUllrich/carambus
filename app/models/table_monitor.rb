class TableMonitor < ActiveRecord::Base

  cattr_accessor :allow_change_tables

  include AASM
  belongs_to :tournament_monitor
  belongs_to :game
  has_paper_trail

  serialize :data, Hash

  aasm :column => 'state' do
    state :new_table_monitor, initial: true, :after_enter => [:reset_table_monitor]
    state :ready
    state :playing_game, :after_enter => [:set_start_time], :after_exit => [:set_end_time]
    state :game_finished
    state :game_result_reported
    state :ready_for_new_game #previous game result still displayed here - and probably next players
    event :start_new_game do
      transitions from: [:ready, :ready_for_new_game, :playing_game, :game_result_reported, :game_finished], to: :playing_game, :after_enter => [:initialize_game]
    end
    event :result_accepted do
      transitions from: [:game_result_reported, :ready_for_new_game], to: :ready_for_new_game
    end
    event :event_game_finished do
      transitions from: :playing_game, to: :game_finished
    end
    event :event_game_result_reported do
      transitions from: :game_finished, to: :game_result_reported
    end
    event :we_re_ready do
      transitions from: [:new_table_monitor, :game_result_reported], to: :ready
    end
  end

  def set_start_time
    game.update_attributes(started_at: Time.now)
  end

  def set_end_time
    game.update_attributes(ended_at: Time.now)
  end

  def assign_game(game)
    self.allow_change_tables = tournament_monitor.allow_change_tables
    update_attributes(game_id: game.id)
    initialize_game
    start_new_game!
  end

  def initialize_game
    deep_merge_data! ({
        "playera" => {
            "result" => 0,
            "innings" => 0,
            "hs" => 0,
            "gd" => 0.0,
            "balls_goal" =>
                data["result"].andand["playera"].andand["balls_goal"] ||
                    self.balls_goal ||
                    tournament_monitor.andand.tournament.andand.handicap_tournier? && seeding_from("playera").balls_goal.presence ||
                    tournament_monitor.andand.balls_goal ||
                    tournament_monitor.andand.tournament.andand.balls_goal || 80,
            "innings_goal" =>
                self.balls_goal ||
                    tournament_monitor.andand.innings_goal ||
                    tournament_monitor.andand.tournament.andand.innings_goal ||
                    20
        },
        "playerb" => {
            "result" => 0,
            "innings" => 0,
            "hs" => 0,
            "gd" => 0.0,
            "balls_goal" =>
                data["result"].andand["playerb"].andand["balls_goal"] ||
                    self.balls_goal ||
                    tournament_monitor.andand.tournament.andand.handicap_tournier? && seeding_from("playerb").balls_goal.presence ||
                    tournament_monitor.andand.balls_goal ||
                    tournament_monitor.andand.tournament.andand.balls_goal || 80,
            "innings_goal" =>
                self.balls_goal ||
                    tournament_monitor.andand.innings_goal ||
                    tournament_monitor.andand.tournament.andand.innings_goal ||
                    20
        },
        "current_inning" => {
            "active_player" => "playera",
            "balls" => 0
        }
    })
    data
  end

  def display_name
    t_no = name.match(/table(\d+)/).andand[1]
    I18n.t("table_monitors.display_name", t_no: t_no)
  end

  def seeding_from(role)
    #TODO - puh can't this be easiere?
    game.game_participations.where(role: role).first.
        player.seedings.where(tournament_id: tournament_monitor.tournament_id).first
  end

  def add_n_balls_to_current_players_inning(n)
    @msg = nil
    if playing_game?
      data["current_inning"].andand["balls"] =
          (data["current_inning"].andand["balls"].to_i + n).to_s
      data["hist"] = data["hist"].to_s + ';' + "add#{n}"
      data_will_change!
      save
    else
      @msg = "Game Finished - no more inputs allowed"
      return nil
    end
  end

  def msg
    @msg
  end

  def set_n_balls_to_current_players_inning(n_balls)
    @msg = nil
    if playing_game?
      data["current_inning"].andand["balls"] = n_balls.to_s
      data["hist"] = data["hist"].to_s + ';' + "set#{n_balls}"
      data_will_change!
      save
    else
      @msg = "Game Finished - no more inputs allowed"
      return nil
    end
  end

  def terminate_current_inning
    @msg = nil
    if playing_game?
      current_role = data["current_inning"]["active_player"]
      n_balls = data.andand["current_inning"].andand["balls"].to_i
      data[current_role]["result"] += n_balls
      data[current_role]["innings"] += 1
      data[current_role]["hs"] = n_balls if n_balls > data[current_role]["hs"].to_i
      data[current_role]["gd"] = sprintf("%.2f", data[current_role]["result"].to_f / data[current_role]["innings"])
      data["current_inning"]["active_player"] = (current_role == "playera" ? "playerb" : "playera")
      data.andand["current_inning"].andand["balls"] = 0
      data_will_change!
      save
      if data["current_inning"]["active_player"] == "playera"
        evaluate_result
      end
    else
      @msg = "Game Finished - no more inputs allowed"
      return nil
    end
  end

  # table_monitor stores data based on playera..playerd
  # table_monitor published results for player1..player4 via player_map
  # game stores fullnames for playera..playerd for local display of results

  def xxx_get_result(player)
    #TODO REWORK - DATA FORMAT CHANGED
    if m = player.match(/^(?:player|spieler|p)(\d)$/i)
      return data["result"][rpm["player#{m[1]}"]]
    elsif m = player.match(/^(?:player|spieler|p)([a-d])$/i)
      return data["result"]["player#{m[1]}"]
    elsif player.is_a?(Player)
      (1..4) - each do |pn|
        if game.send(:"player#{pn}_id") == player.id
          return data["result"][rpm["player#{pn}"]]
        end
      end
    else
      # assume fullname or lastname or firstname (has to be uniq)
      possible_players = Player.joins(:seedings => :tournament).where(tournaments: {id: tournament.id}).
          where("(players.lastname||', '||players.firstname) ilike :search)", search: player.to_s)
      if possible_players.count == 1
        return get_result(possible_players.first)
      end
    end
    return nil
  end

  def xxx_put_result(player, result = {})
    #TODO REWORK - DATA FORMAT CHANGED
    if m = player.match(/^(?:player|spieler|p)(\d)$/i)
      return deep_merge_data!("result" => {rpm["player#{m[1]}"] => result.dup})
    elsif m = player.match(/^(?:player|spieler|p)([a-d])$/i)
      return deep_merge_data!("result" => {"player#{m[1]}" => result.dup})
    elsif player.is_a?(Player)
      (1..4) - each do |pn|
        if game.send(:"player#{pn}_id") == player.id
          return deep_merge_data!("result" => {rpm["player#{pn}"] => result.dup})
        end
      end
    else
      # assume fullname or lastname or firstname (has to be uniq)
      possible_players = Player.joins(:seedings => :tournament).where(tournaments: {id: tournament.id}).
          where("(players.lastname||', '||players.firstname) ilike :search)", search: player.to_s)
      if possible_players.count == 1
        return put_result(possible_players.first, result)
      end
    end
    return nil
  end

  def evaluate_result
    if playing_game?
      if end_result?
        event_game_finished!
        save!
        reload
        prepare_final_game_result
        event_game_result_reported!
        tournament_monitor.report_result(self)
      end
    end
  end

  def set_player_sequence(players)
    (a..d).each_with_index do |ab_seqno, ix|
      next if ix >= players.count
      data["player_map"]["player#{ab_seqno}"] = players[ix]
    end
  end

  def end_result?
    if tournament_monitor.tournament.handicap_tournier?
      if (data["playera"]["result"].to_i >= data["playera"]["balls_goal"].to_i ||
          data["playerb"]["result"].to_i >= data["playerb"]["balls_goal"].to_i) &&
          data["playera"]["innings"] == data["playerb"]["innings"]
        return true
      end
    elsif (data["playera"]["innings"].to_i >= data["playera"]["innings_goal"].to_i ||
        data["playera"]["innings"].to_i >= data["playera"]["innings_goal"].to_i) &&
        data["playera"]["innings"] == data["playerb"]["innings"]
      return true
    end
    return false
  end

  def deep_merge_data!(hash)
    h = data.dup
    h.deep_merge!(hash)
    self.data_will_change!
    self.data = JSON.parse(h.to_json)
    save!
  end

  def prepare_final_game_result

    game_ba_result = {
        "Gruppe" => game.group_no,
        "Partie" => game.seqno,

        "Spieler1" => game.game_participations.where(role: "playera").first.player.ba_id,
        "Spieler2" => game.game_participations.where(role: "playerb").first.player.ba_id,
        "Ergebnis1" => data["playera"]["result"].to_i,
        "Ergebnis2" => data["playerb"]["result"].to_i,
        "Aufnahmen1" => data["playera"]["innings"].to_i,
        "Aufnahmen2" => data["playerb"]["innings"].to_i,
        "Höchstserie1" => data["playera"]["hs"].to_i,
        "Höchstserie2" => data["playerb"]["hs"].to_i,
        "Tischnummer" => game.table_no
    }
    deep_merge_data!("ba_results" => game_ba_result)
  end

  def reset_table_monitor
    update_attributes(game_id: nil)
    we_re_ready!
  end
end
