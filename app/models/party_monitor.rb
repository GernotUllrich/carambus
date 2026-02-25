# == Schema Information
#
# Table name: party_monitors
#
#  id                             :bigint           not null, primary key
#  allow_follow_up                :boolean          default(TRUE), not null
#  color_remains_with_set         :boolean          default(TRUE), not null
#  data                           :text
#  ended_at                       :datetime
#  fixed_display_left             :string
#  kickoff_switches_with          :string
#  sets_to_play                   :integer          default(1), not null
#  sets_to_win                    :integer          default(1), not null
#  started_at                     :datetime
#  state                          :string
#  team_size                      :integer          default(1), not null
#  time_out_stoke_preparation_sec :integer          default(45)
#  time_out_warm_up_first_min     :integer          default(5)
#  time_out_warm_up_follow_up_min :integer          default(3)
#  timeout                        :integer          default(0), not null
#  timeouts                       :integer
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  party_id                       :integer
#
class PartyMonitor < ApplicationRecord
  include ApiProtector # (usage forbidden from api server)
  include AASM

  belongs_to :party, class_name: "Party", optional: true
  has_many :table_monitors, as: :tournament_monitor, class_name: "TableMonitor", dependent: :nullify

  alias tournament party
  serialize :data, coder: JSON, type: Hash
  cattr_accessor :allow_change_tables

  before_save :log_state_change
  before_save :set_paper_trail_whodunnit

  DEBUG = Rails.env != "production"

  # Broadcast changes in realtime with Hotwire
  after_create_commit lambda {
                        broadcast_prepend_later_to :party_monitors, partial: "party_monitors/index",
                                                                    locals: { party_monitor: self }
                      }
  # after_update_commit -> {
  #   broadcast_replace_later_to self
  # }
  after_destroy_commit -> { broadcast_remove_to :party_monitors, target: dom_id(self, :index) }

  aasm column: "state" do
    state :seeding_mode, initial: true, after_enter: [:reset_party_monitor]
    state :table_definition_mode
    state :next_round_seeding_mode
    state :ready_for_next_round
    state :playing_round
    state :round_result_checking_mode
    state :party_result_checking_mode
    state :party_result_reporting_mode
    state :closed
    before_all_events :before_all_events
    event :prepare_next_round do
      transitions from: %i[seeding_mode round_result_checking_mode], to: :table_definition_mode
    end
    event :enter_next_round_seeding do
      transitions from: [:table_definition_mode], to: :next_round_seeding_mode
    end
    event :finish_round_seeding_mode do
      transitions from: :next_round_seeding_mode, to: :ready_for_next_round
    end
    event :start_round do
      transitions from: %i[ready_for_next_round], to: :playing_round
    end
    event :finish_round do
      transitions from: %i[playing_round], to: :round_result_checking_mode
    end
    event :finish_party do
      transitions from: %i[round_result_checking_mode], to: :party_result_checking_mode
    end
    event :close_party do
      transitions from: %i[party_result_checking_mode], to: :closed
    end

    event :end_of_party do
      transitions to: :closed
    end
  end

  def fixed_display_left?
    "playera"
  end

  def log_state_change
    return unless state_changed?
    return unless DEBUG

    Tournament.logger.info "[PartyMonitor] STATE_CHANGED [#{id}]: #{state_change[0]} -> #{state_change[1]}"
    Rails.logger.info "[PartyMonitor] STATE_CHANGED [#{id}]: #{state_change[0]} -> #{state_change[1]}" if DEBUG
  end

  def data
    HashWithIndifferentAccess.new(read_attribute(:data))
  end

  def data=(val)
    write_attribute(:data, val.to_hash)
  end

  def reset_party_monitor
    return nil if party.blank?

    Rails.logger.info "[pmon-reset_party_monitor]..."
    update(
      sets_to_play: tournament.andand.sets_to_play.presence || 1,
      sets_to_win: tournament.andand.sets_to_win.presence || 1,
      team_size: tournament.andand.team_size.presence || 1,
      kickoff_switches_with: tournament.andand.kickoff_switches_with || "set",
      allow_follow_up: tournament.andand.allow_follow_up,
      fixed_display_left: tournament.andand.fixed_display_left,
      color_remains_with_set: tournament.andand.color_remains_with_set
    )
    # TODO: initialize all PartyMonitor attributes
    party.games.where("games.id >= #{Game::MIN_ID}").destroy_all
    party.seedings.where("id > #{Game::MIN_ID}").destroy_all
    update(data: {}) unless new_record?
    @league ||= party.league
    @game_plan ||= @league.game_plan
    initialize_table_monitors if @game_plan.present? && !party.manual_assignment
    self.data = data.presence || @game_plan&.data.dup
    data_will_change!
    self.state = "seeding_mode"
    save!
  end

  def initialize_table_monitors
    Rails.logger.info "[pmon-initialize_table_monitors]..."
    save!
    table_ids = Array(data["table_ids"].andand.map(&:to_i))
    if table_ids.present?
      (1..[party.game_plan.andand.tables.to_i, table_ids.count].min).each do |t_no|
        table = Table.find(table_ids[t_no - 1])
        table_monitor = table.table_monitor || table.table_monitor!
        table_monitor.reset_table_monitor if table_monitor.andand.game.present?
        table_monitor.update(tournament_monitor: self) # polymorhic association as party_ or tournament_monitor
      end
      reload
    else
      Rails.logger.info "state:#{state}...[ptmon-initialize_table_monitors] NO TABLES"
    end
    Rails.logger.info "state:#{state}...[pmon-initialize_table_monitors]"
  end

  def do_placement(new_game, r_no, t_no, row = nil, row_nr = nil)
    try do
      @placements ||= data["placements"].presence
      @placement_candidates ||= data["placement_candidates"].presence
      @placements ||= {}
      @placement_candidates ||= []
      @placements_done = @placements.keys.map do |k|
        @placements[k]
      end.flatten.first.andand.values.to_a.flatten
      info = "+++ 8a - tournament_monitor#do_placement new_game, r_no, t_no: #{new_game.attributes.inspect}, #{r_no}, #{t_no}"
      Rails.logger.info info
      if !@placements_done.include?(new_game.id) || new_game.data.blank? || new_game.data.keys == ["tmp_results"]
        info = "+++ 8b - tournament_monitor#do_placement"
        Rails.logger.info info
        table_ids = data["table_ids"][r_no - 1]
        if t_no.to_i > 0 &&
           ((current_round == r_no &&
             new_game.present? &&
             @placements.andand["round#{r_no}"].andand["table#{t_no}"].blank?) || tournament.continuous_placements)

          seqno = new_game.seqno.to_i.positive? ? new_game.seqno : next_seqno
          new_game.update(round_no: r_no.to_i, table_no: t_no, seqno: seqno)
          @placements ||= {}
          @placements["round#{r_no}"] ||= {}
          @placements["round#{r_no}"]["table#{t_no}"] ||= []
          @placements["round#{r_no}"]["table#{t_no}"].push(new_game.id)
          Tournament.logger.info "DO PLACEMENT round=#{r_no} table#{t_no} assign_game(#{new_game.gname})" if DEBUG

          @table = Table.find(table_ids[t_no - 1])
          @table_monitor = @table.table_monitor || @table.table_monitor!
          old_game = @table_monitor.game
          if old_game.present?
            # noinspection RubyResolve
            @table_monitor.data_will_change!
            info = "+++ 8c - tournament_monitor#do_placement - save current game"
            Rails.logger.info info
            tmp_results = {}
            tmp_results["playera"] = @table_monitor.deep_delete!("playera", false)
            tmp_results["playerb"] = @table_monitor.deep_delete!("playerb", false)
            tmp_results["current_inning"] = @table_monitor.deep_delete!("current_inning", false)
            if @table_monitor.data["ba_results"].present?
              tmp_results["ba_results"] =
                @table_monitor.deep_delete!("ba_results", false)
            end
            tmp_results["state"] = @table_monitor.state
            old_game.deep_merge_data!("tmp_results" => tmp_results)
            old_game.save!
            # noinspection RubyResolve
            @table_monitor.data_will_change!
            @table_monitor.state = "ready"
            @table_monitor.game_id = nil
            @table_monitor.save!
          end
          @table_monitor.deep_merge_data!(
            row: row.andand.dup,
            row_nr: row_nr,
            t_no: t_no,
            sets_to_play: sets_to_play,
            sets_to_win: new_game.data["sets_to_win"],
            team_size: team_size,
            kickoff_switches_with: new_game.data["kickoff_switches_with"],
            allow_follow_up: allow_follow_up,
            fixed_display_left: fixed_display_left,
            color_remains_with_set: color_remains_with_set
          )

          @table_monitor.assign_attributes(tournament_monitor: self)
          @table_monitor.andand.assign_game(new_game.reload)
        elsif tournament.continuous_placements?
          @placement_candidates.push(new_game.id)
        else
          info = "+++ 8a - tournament_monitor#do_placement FAILED new_game.data: #{new_game.data.inspect}, @placements: #{@placements.inspect}, new_game: #{new_game.andand.attributes.inspect}, current_round: #{current_round}"
          Rails.logger.info info
        end
        @table_monitor.save
        @bg_color = "#1B0909"
      end
    rescue StandardError => e
      Rails.logger.info "StandardError #{e}, #{e.backtrace.to_a.join("\n")}"
      raise StandardError unless Rails.env == "production"

      raise ActiveRecord::Rollback
    end
  end

  def deep_merge_data!(hash)
    h = data.dup
    h.deep_merge!(hash)
    self.data = JSON.parse(h.to_json)
    # save!
  end

  # TODO: duplicate code from TournamentMonitor
  def current_round
    data["current_round"].presence || 1
  end

  def current_round!(round)
    data_will_change!
    deep_merge_data!(current_round: round)
    save
  end

  def incr_current_round!
    data_will_change!
    deep_merge_data!(current_round: current_round + 1)
    save
  end

  def decr_current_round!
    data_will_change!
    deep_merge_data!(current_round: current_round - 1)
    save
  end

  def states
    aasm.states
  end

  def events
    aasm.events
  end

  def report_result(table_monitor)
    TournamentMonitor.transaction do
      try do
        # noinspection RubyResolve
        # Tournament.logger.info "[tournament_monitor#report_result] #{caller[0..4].select{|s| s.include?("/app/").join("\n")}" if table_monitor.may_finish_match?
        table_monitor.finish_match! if table_monitor.may_finish_match?
        finalize_game_result(table_monitor)
        accumulate_results
        reload
        if all_table_monitors_finished? # || tournament.manual_assignment || tournament.continuous_placements
          finalize_round # unless tournament.manual_assignment

          # incr_current_round! unless tournament.manual_assignment || tournament.continuous_placements
          # populate_tables unless tournament.manual_assignment
          # if group_phase_finished?
          #   if finals_finished?
          #     decr_current_round!
          #     update_ranking
          #     write_finale_csv_for_upload
          #     # noinspection RubyResolve
          #     end_of_tournament!
          #     # noinspection RubyResolve
          #     tournament.finish_tournament!
          #     # noinspection RubyResolve
          #     tournament.have_results_published!
          #     #tournament.tournament_monitor.andand.table_monitors.andand.destroy_all
          #   else
          #     # noinspection RubyResolve
          #     start_playing_finals!
          #   end
          # else
          #   # noinspection RubyResolve
          #   start_playing_groups!
          # end

          TournamentMonitorUpdateResultsJob.perform_later(self)
        end
      rescue StandardError => e
        Rails.logger.info "StandardError #{e}, #{e.backtrace.to_a.join("\n")}"
        raise StandardError unless Rails.env == "production"

        raise ActiveRecord::Rollback
      end
    end
  end

  def finalize_round
    # TableMonitor e.g.
    # {
    #   "playera": {
    #     "result": 21,
    #     "innings": [1,0,3,2,2,0,13]
    #     "innings_count": 7,
    #     "hs": 10,
    #     "gd": "3.00",
    #     "balls_goal": 11,
    #     "innings_goal": 20
    #   },
    #   "playerb": {
    #     "result": 30,
    #     "innings": [10,0,3,2,2,0,13]
    #     "innings_count": 7,
    #     "hs": 20,
    #     "gd": "4.29",
    #     "balls_goal": 80,
    #     "innings_goal": 20
    #   },
    #   "current_inning": {
    #     "active_player": "playera",
    #     "balls": 0
    #   },
    # }
    # finalize gameParticipation data
    #
    # "results": {
    #     "Gr.": "Satz 1",
    #     "Ergebnis": 50,
    #     "Aufnahme": 32,
    #     "GD": 1.56,
    #     "HS": 6
    # }
    table_monitors.joins(:game).each do |tabmon|
      game = tabmon.game
      next unless game.present? && game.data.present?

      update_game_participations(tabmon)
      # noinspection RubyResolve
      tabmon.close_match!
    end
    accumulate_results
  end

  def finalize_game_result(table_monitor)
    # "ba_results": {
    #     "Gruppe": null,
    #     "Partie": 16,
    #     "Spieler1": 228105,
    #     "Spieler2": 353803,
    #     "Ergebnis1": 0,
    #     "Ergebnis2": 0,
    #     "Aufnahmen1": 20,
    #     "Aufnahmen2": 20,
    #     "Höchstserie1": 0,
    #     "Höchstserie2": 0,
    #     "Tischnummer": 2
    # }
    game = table_monitor.game
    game.deep_merge_data!({
      "ba_results" => table_monitor.data["ba_results"],
      "playera" => table_monitor.data["playera"],
      "playerb" => table_monitor.data["playerb"],
      "balls_counter_stack" => table_monitor.data["balls_counter_stack"].presence
    }.compact)
    game.save!
    if tournament.manual_assignment || tournament.continuous_placements
      update_game_participations(table_monitor)
      # noinspection RubyResolve
      table_monitor.close_match!
      args = { game_id: nil, prev_game_id: game.id, prev_data: table_monitor.data.dup, prev_tournament_monitor: self }
      args[:tournament_monitor] = nil unless tournament.continuous_placements
      table_monitor.update(args)
      data_will_change!
      save!
    end
  rescue StandardError => e
    Rails.logger.info "ERROR: #{e}, #{e.backtrace.join("\n")}" if DEBUG
    raise StandardError unless Rails.env == "production"
  end

  # duplicate of tournament_monitor#accumulate_results
  #
  def accumulate_results
    rankings = {
      "tmp_result" => {
        "game_points" => [0, 0],
        "match_points" => [0, 0]
      },
      "total" => {},
      "groups" => {
        "total" => {}
      },
      "endgames" => {
        "total" => {},
        "groups" => {
          "total" => {}
        }
      }
    }
    party.reload.games.where("games.id >= ?", Seeding::MIN_ID).map(&:game_participations).flatten.each do |gp|
      # GameParticipation.joins(game: :tournament).where("games.id >= ?", Seeding::MIN_ID).where(tournaments: { id: tournament.id }).each do |gp|
      game = gp.game
      results = gp.data["results"]
      if results.present?
        if (m = game.gname.match(%r{^group(\d+):(\d+)-(\d+)(?:/(\d+))?$}))
          group_no = m[1]
          add_result_to(gp, rankings["total"])
          add_result_to(gp, rankings["groups"]["total"])
          rankings["groups"]["group#{group_no}"] ||= {}
          add_result_to(gp, rankings["groups"]["group#{group_no}"])
        elsif (m = game.gname.match(/^fg(\d+):(\d+)-(\d+)$/))
          group_no = m[1]
          add_result_to(gp, rankings["total"])
          add_result_to(gp, rankings["endgames"]["total"])
          add_result_to(gp, rankings["endgames"]["groups"]["total"])
          rankings["endgames"]["groups"]["fg#{group_no}"] ||= {}
          add_result_to(gp, rankings["endgames"]["groups"]["fg#{group_no}"])
        elsif (m = game.gname.match(/^(64f|32f|16f|8f|af|qf|vf|hf|fin|p<\d+(?:\.\.|-)\d+>)(\d+)?$/))
          level = m[1]
          group_no = m[2]
          add_result_to(gp, rankings["total"])
          add_result_to(gp, rankings["endgames"]["total"])
          rankings["endgames"][level.to_s] ||= {}
          add_result_to(gp, rankings["endgames"][level.to_s])
          rankings["endgames"]["#{level}#{group_no}"] ||= {} if group_no.present?
          add_result_to(gp, rankings["endgames"]["#{level}#{group_no}"]) if group_no.present?
        end
      end
    end
    data_will_change!
    data["rankings"] = rankings
    save!
  end

  def update_game_participations(tabmon)
    game = tabmon.game
    sets = nil
    sets_to_play = get_attribute_by_gname(game.gname, "sets")
    game_points = HashWithIndifferentAccess.new(get_game_plan_attribute_by_gname(game.gname, "game_points"))
    rank = {}
    points = {}
    if sets_to_play > 1
      ("a".."b").each do |c|
        rank["player#{c}"] = tabmon.data["ba_results"]["Sets#{c == "a" ? 1 : 2}"]
      end
    else
      ("a".."b").each do |c|
        rank["player#{c}"] =
          tabmon.data["player#{c}"]["result"].to_f / tabmon.data["player#{c}"]["balls_goal"].to_f * 100.0
      end
    end
    points["playera"] = if rank["playera"] > rank["playerb"]
                          game_points["win"]
                        else
                          (rank["playera"] < rank["playerb"] ? game_points["lost"] : game_points["draw"])
                        end
    points["playerb"] = if rank["playerb"] > rank["playera"]
                          game_points["win"]
                        else
                          (rank["playerb"] < rank["playera"] ? game_points["lost"] : game_points["draw"])
                        end
    ("a".."b").each do |c|
      gp = game.game_participations.where(role: "player#{c}").first
      if sets_to_play > 1
        n = c == "a" ? 1 : 2
        result = tabmon.data["ba_results"]["Ergebnis#{n}"].to_i
        innings = tabmon.data["ba_results"]["Aufnahmen#{n}"].to_i
        gd = format("%.2f", result.to_f / innings).to_f
        hs = tabmon.data["ba_results"]["Höchstserie#{n}"].to_i
        sets = tabmon.data["ba_results"]["Sets#{n}"].to_i
        results = {
          "Gr.": game.gname,
          Ergebnis: result,
          Aufnahme: innings,
          GD: gd,
          HS: hs,
          Sets: sets,
          gp_id: gp.id
        }
      else
        result = tabmon.data["player#{c}"]["result"].to_i
        innings = tabmon.data["player#{c}"]["innings"].to_i
        bg = tabmon.data["player#{c}"]["balls_goal"].to_i
        bg_p = format("%.2f",
                      100.0 * tabmon.data["player#{c}"]["result"].to_f / tabmon.data["player#{c}"]["balls_goal"].to_i).to_f
        gd = format("%.2f", tabmon.data["player#{c}"]["result"].to_f / tabmon.data["player#{c}"]["innings"].to_i).to_f
        hs = tabmon.data["player#{c}"]["hs"].to_i
        results = {
          "Gr.": game.gname,
          Ergebnis: result,
          Aufnahme: innings,
          GD: gd,
          HS: hs,
          gp_id: gp.id,
          Sets: 1,
          BG: bg,
          BG_P: bg_p
        }
      end
      gp.deep_merge_data!("results" => results)
      gp.update(points: points["player#{c}"], result: result, innings: innings, gd: gd, hs: hs, sets: sets)
      if DEBUG
        Tournament.logger.info("RESULT #{game.gname} points: #{points["player#{c}"]}, result: #{result}, innings: #{innings}, gd: #{gd}, hs: #{hs}, sets: #{sets}")
      end
    end
  end

  # TODO: duplicate from tournament_monitor#all_table_monitors_finished?
  def all_table_monitors_finished?
    !(
      table_monitors.joins(:game).map(&:state) & %w[warmup warmup_a warmup_b
                                                    match_shootout playing final_set_score set_over]
    ).present?
  end

  # TODO: room for optimization!
  def get_attribute_by_gname(gname, key_)
    key = key_.to_sym
    seqno = gname.split("-")[0].to_i
    type = gname.split("-").drop(1).join("-")
    ix = data["rows"].find_index { |row| row["seqno"] == seqno && row["type"] == type }
    ix.present? ? data["rows"][ix][key] : nil
  rescue StandardError => e
    Rails.logger.info "ERROR: #{e}, #{e.backtrace.join("\n")}" if DEBUG
    raise StandardError unless Rails.env == "production"
  end

  # TODO: room for optimization!
  def get_game_plan_attribute_by_gname(gname, key_)
    key = key_.to_sym
    seqno = gname.split("-")[0].to_i
    type = gname.split("-").drop(1).join("-")
    data = party.league.game_plan.data
    ix = data["rows"].find_index { |row| row[:seqno] == seqno && row[:type] == type }
    ix.present? ? data["rows"][ix][key] : nil
  end

  private

  def before_all_events
    Rails.logger.info "[party_monitor] #{aasm.current_event.inspect}"
  end
end
