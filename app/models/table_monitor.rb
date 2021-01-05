# == Schema Information
#
# Table name: table_monitors
#
#  id                    :bigint           not null, primary key
#  active_timer          :string
#  data                  :text
#  ip_address            :string
#  name                  :string
#  nnn                   :integer
#  state                 :string
#  timer_finish_at       :datetime
#  timer_halt_at         :datetime
#  timer_start_at        :datetime
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  game_id               :integer
#  next_game_id          :integer
#  table_id              :integer          not null
#  tournament_monitor_id :integer
#
# Foreign Keys
#
#  fk_rails_...  (game_id => games.id)
#  fk_rails_...  (tournament_monitor_id => tournament_monitors.id)
#
class TableMonitor < ApplicationRecord
  include CableReady::Broadcaster

  cattr_accessor :allow_change_tables


  include AASM
  belongs_to :tournament_monitor
  belongs_to :game, optional: true
  belongs_to :table
  has_paper_trail

  before_save :log_state_change

  NNN = "db"  #store nnn in database table_monitor

  def log_state_change
    if state_changed?
      Rails.logger.info "[TableMonitor] STATE_CHANGED [#{id}]: #{state_change[0]} -> #{state_change[1]}"
    end
  end

  serialize :data, Hash

  STATE_DISPLAY_NAMES = {
    "new_table_monitor" => "",
    "ready" => "Tournier Modus",
    "game_setup_started" => "Warm Up",
    "game_warmup_a_started" => "Warm Up A",
    "game_warmup_b_started" => "Warm Up B",
    "game_shootout_started" => "Ausstossen",
    "playing_game" => "",
    "game_finished" => "Partie beendet",
    "game_result_reported" => "Partie beendet",
    "ready_for_new_game" => "Partie beendet"
  }

  aasm :column => 'state' do
    state :new_table_monitor, initial: true, :after_enter => [:reset_table_monitor]
    state :ready
    state :game_setup_started
    state :game_warmup_a_started
    state :game_warmup_b_started
    state :game_shootout_started
    state :playing_game, :after_enter => [:set_start_time], :after_exit => [:set_end_time]
    state :game_finished
    state :game_result_reported
    state :ready_for_new_game #previous game result still displayed here - and probably next players
    event :start_new_game do
      transitions from: [:ready, :ready_for_new_game, :game_setup_started, :game_result_reported, :game_finished], to: :game_setup_started, :after_enter => [:initialize_game]
    end
    event :result_accepted do
      transitions from: [:game_result_reported, :ready_for_new_game], to: :ready_for_new_game
    end
    event :event_play_warm_up_a do
      transitions from: [:game_setup_started, :game_warmup_b_started, :game_warmup_a_started], to: :game_warmup_a_started
    end
    event :event_play_warm_up_b do
      transitions from: [:game_setup_started, :game_warmup_a_started, :game_warmup_b_started], to: :game_warmup_b_started
    end
    event :event_warmup_finished do
      transitions from: [:game_setup_started, :game_warmup_a_started, :game_warmup_b_started], to: :game_shootout_started
    end
    event :event_shootout_finished do
      transitions from: :game_shootout_started, to: :playing_game
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

  @numbers_mode = false

  def log_state_change
    if state_changed?
      Tournament.logger.info "[TableMonitor] STATE_CHANGED [#{id}]: #{state_change[0]} -> #{state_change[1]}"
    end
  end

  after_commit do

    TableMonitorLaterJob.perform_later(self)
    full_screen_html = ApplicationController.render(
      partial: "table_monitors/show",
      locals: { table_monitor: self, full_screen: true }
    )
    cable_ready["table-monitor-stream"].inner_html(
      selector: "#full_screen_table_monitor_#{id}",
      html: full_screen_html
    )
    cable_ready.broadcast
  end

  def numbers
    @numbers_mode = true
    full_screen_html = ApplicationController.render(
      partial: "table_monitors/show",
      locals: { table_monitor: self, full_screen: true }
    )
    cable_ready["table-monitor-stream"].inner_html(
      selector: "#full_screen_table_monitor_#{id}",
      html: full_screen_html
    )
    cable_ready.broadcast
  end

  def update_every_n_seconds(n)
    TableMonitorJob.perform_later(self, n)
  end

  def player_a_has_played_on_table_before
    false
  end

  def player_b_has_played_on_table_before
    false
  end

  def render_last_innings(n, role)
    show_innings = Array(data[role].andand["innings_list"])
    ret = show_innings.dup
    Array(data[role].andand["innings_redo_list"]).reverse.each_with_index do |i, ix|
      ret << "#{ix == 0 ? "<strong class=\"border-2 border-gray-500 p-1\">#{i}</strong>" : "#{i}"}"
    end
    return ret.length > n ?
             ("..." + ret[-n..-1].join("-")).html_safe :
             ret.join("-").html_safe
  end

  def setup_modal_should_be_open?
    game_setup_started? || game_warmup_a_started? || game_warmup_b_started?
  end

  def shootout_modal_should_be_open?
    game_shootout_started?
  end

  def numbers_modal_should_be_open?
    @numbers_mode
  end

  def get_progress_bar_status(n)
    time_counter = green_bars = 0
    finish = timer_finish_at
    start = timer_start_at
    if (finish.present? && timer_halt_at.present?)
      halted = Time.now - timer_halt_at
      finish = finish + halted
      start = start + halted
    end
    if (finish.present? && (Time.now < finish))
      delta_total = (finish - start).to_i
      delta_rest = (finish - Time.now).to_i
      units = active_timer =~ /min$/ ? "minutes" : "seconds"
      time_counter = (1.0 * delta_rest / 1.send(units)).ceil
      green_bars = [((1.0 * n * delta_rest) / delta_total).ceil, 18].min
    end
    return [time_counter, green_bars]
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
    save!
    start_new_game!
  end

  def initialize_game
    deep_merge_data! ({
      "playera" => {
        "result" => 0,
        "innings" => 0,
        "innings_list" => [],
        "innings_redo_list" => [],
        "hs" => 0,
        "gd" => 0.0,
        "balls_goal" =>
          data["result"].andand["playera"].andand["balls_goal"] ||
            tournament_monitor.andand.tournament.andand.handicap_tournier? && seeding_from("playera").balls_goal.presence ||
            tournament_monitor.andand.balls_goal ||
            tournament_monitor.andand.tournament.andand.balls_goal || 80,
        "innings_goal" =>
          tournament_monitor.andand.innings_goal ||
            tournament_monitor.andand.tournament.andand.innings_goal ||
            20
      },
      "playerb" => {
        "result" => 0,
        "innings" => 0,
        "innings_list" => [],
        "innings_redo_list" => [],
        "hs" => 0,
        "gd" => 0.0,
        "balls_goal" =>
          data["result"].andand["playerb"].andand["balls_goal"] ||
            tournament_monitor.andand.tournament.andand.handicap_tournier? && seeding_from("playerb").balls_goal.presence ||
            tournament_monitor.andand.balls_goal ||
            tournament_monitor.andand.tournament.andand.balls_goal || 80,
        "innings_goal" =>
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
      player.seedings.where("seedings.id >= #{Seeding::MIN_ID}").where(tournament_id: tournament_monitor.tournament_id).first
  end

  def add_n_balls_to_current_players_inning(n)
    begin
      @msg = nil
      if playing_game?
        current_role = data["current_inning"]["active_player"]
        data[current_role]["innings_redo_list"] = [0] if data[current_role]["innings_redo_list"].empty?
        to_play = data[current_role].andand["balls_goal"].to_i - (data[current_role].andand["result"].to_i + data[current_role]["innings_redo_list"][-1].to_i)
        add = [n, to_play].min
        data[current_role]["innings_redo_list"][-1] = [(data[current_role]["innings_redo_list"][-1].to_i + add), 0].max
        if add == to_play
          data_will_change!
          save
          terminate_current_inning
        else
          #data[current_role]["innings_redo_list"].pop if Array(data[current_role]["innings_redo_list"]).last.to_i > 10000
          data_will_change!
          save
        end
      else
        @msg = "Game Finished - no more inputs allowed"
        return nil
      end
    rescue Exception => e
      Tournament.logger.info "#{e}, #{e.backtrace.join("\n")}"
    end
  end

  def reset_timer!
    begin
      update_attributes(
        active_timer: nil,
        timer_start_at: nil,
        timer_finish_at: nil,
        timer_halt_at: nil
      )
    rescue Exception => e
      Tournament.logger.info "#{e}, #{e.backtrace.join("\n")}"
    end
  end

  def msg
    @msg
  end

  def set_n_balls_to_current_players_inning(n_balls)
    @msg = nil
    if playing_game?
      current_role = data["current_inning"]["active_player"]
      data[current_role]["innings_redo_list"] = [0] if data[current_role]["innings_redo_list"].empty?
      to_play = data[current_role].andand["balls_goal"].to_i - (data[current_role].andand["result"].to_i)
      set = [n_balls, to_play].min
      data[current_role]["innings_redo_list"][-1] = set
      data_will_change!
      save
      update_columns(nnn: nil)
      if set == to_play
        terminate_current_inning
      end
    else
      @msg = "Game Finished - no more inputs allowed"
      return nil
    end
  end

  def terminate_current_inning
    begin
      @msg = nil
      if playing_game?
        current_role = data["current_inning"]["active_player"]
        n_balls = Array(data[current_role]["innings_redo_list"]).pop.to_i
        data[current_role]["innings_list"] ||= []
        data[current_role]["innings_redo_list"] ||= []
        data[current_role]["innings_list"] << n_balls
        data[current_role]["result"] = data[current_role]["innings_list"].sum
        data[current_role]["innings"] += 1
        data[current_role]["hs"] = n_balls if n_balls > data[current_role]["hs"].to_i
        data[current_role]["gd"] = sprintf("%.2f", data[current_role]["result"].to_f / data[current_role]["innings"])
        other_player = current_role == "playera" ? "playerb" : "playera"
        data["current_inning"]["active_player"] = other_player
        data[other_player]["innings_redo_list"] = [0] if data[current_role]["innings_redo_list"].empty?
        data_will_change!
        save
        if data["current_inning"]["active_player"] == "playera"
          evaluate_result
        end
      else
        @msg = "Game Finished - no more inputs allowed"
        return nil
      end
    rescue Exception => e
      Tournament.logger.info "#{e}, #{e.backtrace.join("\n")}"
    end
  end

  def follow_up?
    data.present? &&
      ((data["current_inning"]["active_player"] == "playerb") && (data["playera"]["result"].to_i >= data["playera"].andand["balls_goal"].to_i))
  end

  def undo
    begin
      if playing_game?
        current_role = data["current_inning"]["active_player"]
        the_other_player = (current_role == "playera" ? "playerb" : "playera")
        if data[the_other_player]["innings"] > 0
          data[the_other_player]["innings_redo_list"] << data[the_other_player]["innings_list"].pop
          data[the_other_player]["innings"] -= 1
          data[the_other_player]["result"] = data[the_other_player]["innings_list"].sum
          data[the_other_player]["hs"] = data[the_other_player]["innings_list"].max
          data[the_other_player]["gd"] = sprintf("%.2f", data[the_other_player]["result"].to_f / data[current_role]["innings"])
          data["current_inning"]["active_player"] = the_other_player
        end
        data_will_change!
        save
      else
        @msg = "Game Finished - no more inputs allowed"
        return nil
      end
    rescue Exception => e
      Tournament.logger.info "#{e}, #{e.backtrace.join("\n")}"
    end
  end

  def evaluate_result
    if playing_game?
      if end_result?
        event_game_finished!
        save!
        reload
        prepare_final_game_result
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
    if (data["playera"]["result"].to_i >= data["playera"]["balls_goal"].to_i ||
      data["playerb"]["result"].to_i >= data["playerb"]["balls_goal"].to_i) &&
      data["playera"]["innings"] == data["playerb"]["innings"]
      return true
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
