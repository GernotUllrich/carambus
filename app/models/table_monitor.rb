class TableMonitor < ActiveRecord::Base
  include AASM
  belongs_to :tournament_monitor
  belongs_to :game
  has_paper_trail

  serialize :data, Hash

  aasm :column => 'state' do
    state :new_table_monitor, initial: true, :after_enter => [:reset_table_monitor]
    state :ready
    state :playing_game
    state :game_finished
    state :game_result_reported
    event :start_new_game do
      transitions from: [:ready], to: :playing_game, :after_enter => :initialize_game
    end
    event :result_accepted do
      transitions from: [:game_result_reported], to: :ready
    end
    event :we_re_ready do
      transitions from: :new_table_monitor, to: :ready
    end
  end

  def assign_game(game)
    update_attributes(game_id: game.id)
    start_new_game!
  end

  def initialize_game
    merge_data! ({
        "result" => {
            "current_inning" => {
                "active_player" => "playera",
                "balls" => 0
            }
        }
    })
    data
  end

  # table_monitor stores data based on playera..playerd
  # table_monitor published results for player1..player4 via player_map
  # game stores fullnames for playera..playerd for local display of results

  def get_result(player)
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

  def put_result(player, result = {})

    if m = player.match(/^(?:player|spieler|p)(\d)$/i)
      return merge_data!("result" => {rpm["player#{m[1]}"] => result.dup})
    elsif m = player.match(/^(?:player|spieler|p)([a-d])$/i)
      return merge_data!("result" => {"player#{m[1]}" => result.dup})
    elsif player.is_a?(Player)
      (1..4) - each do |pn|
        if game.send(:"player#{pn}_id") == player.id
          return merge_data!("result" => {rpm["player#{pn}"] => result.dup})
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

  def publish_result(data)
    if playing_game?
      update_game_data(data)
      if end_result?
        prepare_final_game_result
        game_finished!
        tournament_monitor.report_result(self)
        game_result_reported!
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
      if (data["result"]["playera"]["balls"].to_i >= seeding_from_player("playera").ball_goal ||
          data["result"]["playerb"]["balls"].to_i >= seeding_from_player("playerb").ball_goal)
        return true
      end
    elsif (data["result"]["playera"]["inning_balls"].count >= tournament.innings_goal ||
        data["result"]["playerb"]["inning_balls"].count >= tournament.innings_goal ||
        data["result"]["playera"]["balls"].to_i >= tournament.balls_goal ||
        data["result"]["playerb"]["balls"].to_i >= tournament.balls_goal)
      return true
    end
    return false
  end

  def merge_data!(hash)
    h = data.dup
    h.merge!(hash)
    self.data = h
    save!
  end

  def prepare_final_game_result
    rpm = Hash[data["player_map"].to_a.map { |k, v| [v, k] }]
    game_ba_result = {
        "Gruppe" => group_no,
        "Partie" => seqno,
        "Spieler1" => Player[data["player_map"]["playera"]].ba_id,
        "Spieler2" => Player[data["player_map"]["playerb"]].ba_id,
        "Ergebnis1" => data["result"][rpm["player1"]]["balls"].to_i,
        "Ergebnis2" => data["result"][rpm["player2"]]["balls"].to_i,
        "Aufnahmen1" => data["result"][rpm["player1"]]["innings"].to_i,
        "Aufnahmen2" => data["result"][rpm["player2"]]["innings"].to_i,
        "Höchstserie1" => data["result"][rpm["player1"]]["hs"].to_i,
        "Höchstserie2" => data["result"][rpm["player2"]]["hs"].to_i,
        "Tischnummer" => table_no
    }
    merge_data!("ba_results" => game_ba_result)
  end

  def reset_table_monitor
    update_attributes(game_id: nil)
    we_re_ready!
  end
end
