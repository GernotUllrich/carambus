# == Schema Information
#
# Table name: tournament_monitors
#
#  id            :bigint           not null, primary key
#  balls_goal    :integer
#  data          :text
#  innings_goal  :integer
#  state         :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  tournament_id :integer
#
# Foreign Keys
#
#  fk_rails_...  (tournament_id => tournaments.id)
#
class TournamentMonitor < ApplicationRecord
  cattr_accessor :current_admin
  cattr_accessor :allow_change_tables

  include AASM
  has_paper_trail

  belongs_to :tournament
  has_many :table_monitors, :dependent => :nullify

  serialize :data, Hash

  before_save :log_state_change

  def log_state_change
    if state_changed?
      Tournament.logger.info "[TournamentMonitor] STATE_CHANGED [#{id}]: #{state_change[0]} -> #{state_change[1]}"
    end
  end

  aasm :column => 'state' do
    state :new_tournament_monitor, initial: true, :after_enter => [:reset_tournament_monitor]
    state :playing_groups, before_enter: :debug_log
    #state :evaluating_results, before_enter: :debug_log, :after_enter => [:populate_tables]
    state :playing_finals, before_enter: :debug_log
    state :tournament_finished
    state :publish_results
    state :closed
    before_all_events :before_all_events
    event :start_playing_groups do
      transitions from: [:new_tournament_monitor, :playing_groups], to: :playing_groups
    end
    event :start_playing_finals do
      transitions from: [:new_tournament_monitor, :playing_groups, :playing_finals], to: :playing_finals
    end
    event :report_game_result do
      #TODO transitions from: :playing_groups,
    end

    event :end_of_tournament do
      transitions to: :closed
    end
  end

  # def initialize(attributes = nil, options = nil)
  #   super
  # end

  def deep_merge_data!(hash)
    h = data.dup
    h.deep_merge!(hash)
    self.data = JSON.parse(h.to_json)
    save!
  end

  def debug_log
    self
  end

  def current_round
    data["current_round"].presence || 0
  end

  def set_current_round!(round)
    data_will_change!
    data["current_round"] = round
    update_attributes(data: data)
  end

  def incr_current_round!
    data_will_change!
    data["current_round"] = current_round + 1
    update_attributes(data: data)
  end

  def decr_current_round!
    data_will_change!
    data["current_round"] = current_round - 1
    update_attributes(data: data)
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
    game.deep_merge_data!("ba_results" => table_monitor.data["ba_results"])
  end

  def all_table_monitors_finished?
    !(table_monitors.map(&:state) & ["game_setup_started", "game_warmup_a_started", "game_warmup_b_started", "game_shootout_started", "playing_game", "game_finished", "game_show_result"]).present?
  end

  def finalize_round
    #TableMonitor e.g.
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
    #finalize gameParticipation data
    #
    # "results": {
    #     "Gr.": "Satz 1",
    #     "Ergebnis": 50,
    #     "Aufnahme": 32,
    #     "GD": 1.56,
    #     "HS": 6
    # }
    table_monitors.each do |tabmon|
      game = tabmon.game
      if game.present?
        update_game_participations(tabmon)
        tabmon.result_accepted!
      end
    end
    accumulate_results
  end

  def update_game_participations(tabmon)
    game = tabmon.game
    rank = {}
    points = {}
    ("a".."b").each do |c|
      rank["player#{c}"] = tabmon.data["player#{c}"]["result"].to_i
    end
    points["playera"] = rank["playera"] > rank["playerb"] ? 2 : (rank["playera"] < rank["playerb"] ? 0 : 1)
    points["playerb"] = rank["playerb"] > rank["playera"] ? 2 : (rank["playerb"] < rank["playera"] ? 0 : 1)
    ("a".."b").each do |c|
      gp = game.game_participations.where(role: "player#{c}").first
      result = tabmon.data["player#{c}"]["result"].to_i
      innings = tabmon.data["player#{c}"]["innings"].to_i
      gd = sprintf("%.2f", tabmon.data["player#{c}"]["result"].to_f / tabmon.data["player#{c}"]["innings"].to_i).to_f
      hs = tabmon.data["player#{c}"]["hs"].to_i
      results = {
        "Gr.": game.gname,
        "Ergebnis": result,
        "Aufnahme": innings,
        "GD": gd,
        "HS": hs,
        "gp_id": gp.id
      }
      gp.deep_merge_data!("results" => results)
      gp.update_attributes(points: points["player#{c}"], result: result, innings: innings, gd: gd, hs: hs)
      Tournament.logger.info("RESULT #{game.gname} points: #{points["player#{c}"]}, result: #{result}, innings: #{innings}, gd: #{gd}, hs: #{hs}")
    end
  end

  def accumulate_results
    rankings = {
      "total" => {},
      "groups" => {
        "total" => {},
        "group1" => {},
        "group2" => {},
        "group3" => {},
        "group4" => {},
        "group5" => {},
        "group6" => {},
        "group7" => {},
        "group8" => {},
      },
      "endgames" => {
        "total" => {},
        "groups" => {
          "total" => {},
          "fg1" => {},
          "fg2" => {},
          "fg3" => {},
          "fg4" => {},
        },
        "af" => {},
        "af1" => {},
        "af2" => {},
        "af3" => {},
        "af4" => {},
        "af5" => {},
        "af6" => {},
        "af7" => {},
        "af8" => {},

        "qf" => {},
        "qf1" => {},
        "qf2" => {},
        "qf3" => {},
        "qf4" => {},

        "hf" => {},
        "hf1" => {},
        "hf2" => {},

        "fin" => {},

        "p<3-4>" => {},
        "p<5-6>" => {},
        "p<7-8>" => {},

        "p<5-8>" => {},
        "p<5-8>.1" => {},
        "p<5-8>.2" => {},
      }
    }
    GameParticipation.joins(:game => :tournament).where(tournaments: { id: tournament_id }).each do |gp|
      game = gp.game
      results = gp.data["results"]
      if results.present?
        if m = game.gname.match(/^group(\d+):(\d+)-(\d+)(?:\/(\d+))?$/)
          group_no = m[1]
          add_result_to(gp, rankings["total"])
          add_result_to(gp, rankings["groups"]["total"])
          add_result_to(gp, rankings["groups"]["group#{group_no}"])
        elsif m = game.gname.match(/^fg(\d+):(\d+)-(\d+)$/)
          group_no = m[1]
          add_result_to(gp, rankings["total"])
          add_result_to(gp, rankings["endgames"]["total"])
          add_result_to(gp, rankings["endgames"]["groups"]["total"])
          add_result_to(gp, rankings["endgames"]["groups"]["fg#{group_no}"])
        elsif m = game.gname.match(/^(af|qf|hf|fin|p<(?:\d+)(?:\.\.|-)(?:\d+)>)(\d+)?$/)
          level = m[1]
          group_no = m[2]
          add_result_to(gp, rankings["total"])
          add_result_to(gp, rankings["endgames"]["total"])
          add_result_to(gp, rankings["endgames"]["#{level}"])
          add_result_to(gp, rankings["endgames"]["#{level}#{group_no}"])
        end
      end
    end
    data_will_change!
    data["rankings"] = rankings
    save!
  end

  def add_result_to(gp, hash)
    results = gp.data["results"]
    player_id = gp.player_id
    hash[player_id] ||= {
      "points" => 0,
      "result" => 0,
      "innings" => 0,
      "hs" => 0,
      "bed" => 0,
      "gd" => 0
    }
    hash[player_id]["points"] += gp.points
    hash[player_id]["result"] += gp.result
    hash[player_id]["innings"] += gp.innings
    hash[player_id]["bed"] = gp.gd if (gp.gd > hash[player_id]["bed"])
    hash[player_id]["hs"] = gp.hs if (gp.hs > hash[player_id]["hs"])
    hash[player_id]["gd"] = sprintf("%.2f", hash[player_id]["result"].to_f / hash[player_id]["innings"]).to_f
  end

  def report_result(table_monitor)
    table_monitor.event_game_result_reported!
    finalize_game_result(table_monitor)
    accumulate_results
    if all_table_monitors_finished?
      finalize_round
      incr_current_round!
      populate_tables
      if group_phase_finished?
        if finals_finished?
          decr_current_round!
          update_ranking
          write_finale_csv_for_upload
          end_of_tournament!
          tournament.finish_tournament!
          tournament.have_results_published!
        else
          start_playing_finals!
        end
      else
        start_playing_groups!
      end
      TournamentMonitorUpdateResultsJob.perform_later(self)
    end

  end

  def update_ranking
    rankings = data["rankings"]
    executor_params = JSON.parse(tournament.tournament_plan.executor_params)
    rk_rules = executor_params["RK"]
    rk_rules.each_with_index do |rule, ix|
      player_id = player_id_from_ranking(rule)
      rankings["total"][player_id.to_s]["rank"] = ix + 1
      tournament.seedings.where(seedings: { player_id: player_id }).first.andand.update_attributes(rank: ix + 1)
    end
    data_will_change!
    data["rankings"] = rankings
    save!
  end

  def group_phase_finished?
    n_group_games = tournament.games.where("games.id >= #{Game::MIN_ID}").where("gname ilike 'group%'").count
    n_group_games_done = tournament.games.where("games.id >= #{Game::MIN_ID}").where("gname ilike 'group%'").where.not(ended_at: nil).count
    n_group_games == n_group_games_done
  end

  def write_finale_csv_for_upload
    # Gruppe;Partie;Spieler1;Spieler2;Ergebnis1;Ergebnis2;Aufnahmen1;Aufnahmen2;Höchstserie1;Höchstserie2;Tischnummer;Start;Ende
    # Hauptrunde;1;98765;95678;100;85;24;23;16;9;1;11:30:45;12:17:51
    game_data = []
    tournament.games.where("games.id >= #{Game::MIN_ID}").each do |game|
      gruppe = "#{game.gname =~ /^group/ ? "Gruppe" : game.gname}#{" #{game.group_no}" if game.group_no.present?}"
      partie = game.seqno
      gp1 = game.game_participations.where(role: "playera").first
      gp2 = game.game_participations.where(role: "playerb").first
      started = game.started_at.strftime("%R")
      ended = game.ended_at.strftime("%R")
      game_data << "#{gruppe};#{partie};#{gp1.player.ba_id};#{gp2.player.ba_id};#{gp1.result};#{gp2.result};#{gp1.innings};#{gp2.innings};#{gp1.hs};#{gp2.hs};#{game.table_no};#{started};#{ended}"
    end
    f = File.new("#{Rails.root}/tmp/result-#{tournament.ba_id}.csv", "w")
    f.write(game_data.join("\n"))
    f.close
    NotifierMailer.result(tournament, current_admin.email, "Turnierergebnisse - #{tournament.title}", "result-#{tournament.ba_id}.csv", "#{Rails.root}/tmp/result-#{tournament.ba_id}.csv").deliver
  end

  def finals_finished?
    n_games = tournament.games.where("games.id >= #{Game::MIN_ID}").count
    n_games_done = tournament.games.where("games.id >= #{Game::MIN_ID}").where.not(ended_at: nil).count
    n_games == n_games_done
  end

  def table_monitors_ready_and_populated
    Tournament.logger.info "[tmon-table_monitors_ready_and_populated]..."
    res = table_monitors_ready? && table_monitors_populated?
    Tournament.logger.info "returns #{res}...[tmon-table_monitors_ready_and_populated]"
    return res
  end

  def table_monitors_ready?
    Tournament.logger.info "[tmon-table_monitors_ready]..."
    res = table_monitors.inject(true) { |memo, tm| memo = memo && tm.ready? || tm.ready_for_new_game? || tm.playing_game?; memo }
    Tournament.logger.info "returns #{res}...[tmon-table_monitors_ready]"
    return res
  end

  def table_monitors_populated?
    Tournament.logger.info "[tmon-table_monitors_populated]..."
    ret = true
    placements = data[:placements]
    placements.to_a.each do |round_no, game_hash|
      next unless "round#{current_round}" == round_no
      game_hash.to_a.each do |table_no, game_id|
        tm = table_monitors.find_by_name(table_no)
        ret = ret && (tm.game_id == game_id)
      end
    end
    Tournament.logger.info "returns #{ret}...[tmon-table_monitors_populated]"
    ret
  end

  def reset_tournament_monitor

    Tournament.logger.info "[tmon-reset_tournament_monitor]..."
    tournament.games.where("games.id >= #{Game::MIN_ID}").destroy_all
    table_monitors.destroy_all
    unless new_record?
      update(data: {})
    end
    @tournament_plan ||= tournament.tournament_plan
    initialize_table_monitors
    @groups = TournamentMonitor.distribute_to_group(tournament.seedings.where("seedings.id >= #{Seeding::MIN_ID}").map(&:player_id), @tournament_plan.ngroups)
    @placements = {}
    set_current_round!(1)
    deep_merge_data!("groups" => @groups)
    deep_merge_data!("placements" => @placements)
    executor_params = JSON.parse(@tournament_plan.executor_params)
    executor_params.keys.each do |k|
      if m = k.match(/g(\d+)/)
        group_no = m[1].to_i
        if @groups["group#{group_no}"].count != executor_params[k]["pl"].to_i
          return { "ERROR" => "Group Count Mismatch: group#{group_no}, #{@groups["group#{group_no}"].count} vs. #{executor_params[k]["pl"].to_i} from executor_params" }
        end
        repeats = executor_params[k]["rp"].presence || 1
        (1..repeats).each do |rp|
          if executor_params[k]["rs"] =~ /^eae/
            (1..@groups["group#{group_no}"].count).to_a.permutation(2).to_a.select { |v1, v2| v1 < v2 }.each_with_index do |a, ix|
              i1, i2 = a
              Tournament.logger.info "NEW GAME #{} group#{group_no}:#{i1}-#{i2}#{"/#{rp}" if repeats > 1}"
              game = tournament.games.create(gname: "group#{group_no}:#{i1}-#{i2}#{"/#{rp}" if repeats > 1}", group_no: group_no)
              game.game_participations.create(player_id: @groups["group#{group_no}"][i1 - 1], role: "playera")
              game.game_participations.create(player_id: @groups["group#{group_no}"][i2 - 1], role: "playerb")

            end
          end
        end
      end
    end
    populate_tables
    reload
    tournament.reload.signal_tournament_monitors_ready!
    start_playing_groups!
    Tournament.logger.info "...[tmon-reset_tournament_monitor] tournament.state: #{tournament.state} tournament_monitor.state: #{state}"
  end

  def initialize_table_monitors
    Tournament.logger.info "[tmon-initialize_table_monitors]..."
    save!
    table_ids = tournament.data[:table_ids]
    (1..tournament.tournament_plan.tables).each do |t_no|
      table_monitor = self.reload.table_monitors.find_or_create_by!(name: "table#{t_no}", table_id: table_ids[t_no - 1])
    end
    reload
    Tournament.logger.info "state:#{state}...[tmon-initialize_table_monitors]"
  end

  def populate_tables
    Tournament.logger.info "[tmon-populate_tables]..."
    self.allow_change_tables = false
    executor_params = JSON.parse(tournament.tournament_plan.executor_params)
    @placements = data["placements"].presence || {}
    ordered_table_nos = nil
    admin_table_nos = nil
    executor_params.keys.each do |k|
      if m = k.match(/g(\d+)/)
        Tournament.logger.info "+++001 k,v = [#{k} => #{executor_params[k].inspect}]"
        group_no = m[1].to_i
        #apply table/round_rules
        if executor_params[k]["sq"]["r#{current_round}"].blank?
          Tournament.logger.info "+++002 k,v = [#{k} => #{executor_params[k].inspect}] [k][\"sq\"][\"r#{current_round}\"] is blank"
          if executor_params[k]["rs"].to_s == "eae_pg"
            Tournament.logger.info "+++003 k,v = [#{k} => #{executor_params[k].inspect}] params[k][\"rs\"] == \"eae_pg\""
            if current_round == 2
              Tournament.logger.info "+++004 k,v = [#{k} => #{executor_params[k].inspect}] current_round == 2"
              #if winner on both tables
              winner = GameParticipation.joins(:game => :tournament).where(tournaments: { id: tournament.id }).where(games: { round_no: 1, group_no: group_no }).order("points desc, game_id asc")
              table_from_winner = winner.where(points: 2).count == 2
              winner_arr = winner.to_a
              #player1 = winner in first_game
              winner1 = winner_arr[0].player_id
              table_nos = tournament.games.where("games.id >= #{Game::MIN_ID}").where(games: { round_no: 1, group_no: group_no }).map(&:table_no).shuffle
              if table_from_winner
                # winner stays on table
                t_no = winner_arr[0].game.table_no
                Tournament.logger.info "+++006 k,v = [#{k} => #{executor_params[k].inspect}] table from winner t_no = #{t_no} winner1 = #{Player[winner1].fullname} [#{winner1}]"
              else
                t_no = table_nos.shift
                Tournament.logger.info "+++007 k,v = [#{k} => #{executor_params[k].inspect}] t_no = #{t_no}"
              end
              r_no = current_round
              seqno1 = tournament.tournament_monitor.data["groups"]["group#{group_no}"].index(winner1) + 1
              looser2 = winner_arr[3].player_id
              seqno2 = tournament.tournament_monitor.data["groups"]["group#{group_no}"].index(looser2) + 1
              gname = "group#{group_no}:#{[seqno1, seqno2].sort.map(&:to_s).join("-")}"
              game = tournament.games.where("games.id >= #{Game::MIN_ID}").find_by_gname(gname)
              Tournament.logger.info "+++008 do_placement(game = #{game.gname}, r_no = #{r_no}, t_no = #{t_no})"
              do_placement(game, r_no, t_no)
              winner2 = winner_arr[1].player_id
              if table_from_winner
                t_no = winner_arr[1].game.table_no
                Tournament.logger.info "+++009 k,v = [#{k} => #{executor_params[k].inspect}] table from winner t_no = #{t_no} winner2 = #{Player[winner2].fullname} [#{winner2}]"
              else
                t_no = table_nos.shift
                Tournament.logger.info "+++010 k,v = [#{k} => #{executor_params[k].inspect}] t_no = #{t_no}"
              end
              r_no = current_round
              seqno1 = tournament.tournament_monitor.data["groups"]["group#{group_no}"].index(winner2) + 1
              looser1 = winner_arr[2].player_id
              seqno2 = tournament.tournament_monitor.data["groups"]["group#{group_no}"].index(looser1) + 1
              gname = "group#{group_no}:#{[seqno1, seqno2].sort.map(&:to_s).join("-")}"
              game = tournament.games.where("games.id >= #{Game::MIN_ID}").find_by_gname(gname)
              Tournament.logger.info "+++011 do_placement(game = #{game.gname}, r_no = #{r_no}, t_no = #{t_no})"
              do_placement(game, r_no, t_no)
            elsif current_round == 3
              Tournament.logger.info "+++012 current_round = 3"
              winner = GameParticipation.joins(:game => :tournament).where(tournaments: { id: tournament.id }).where(games: { round_no: 2, group_no: group_no }).order("gd desc")
              winner_arr = winner.to_a
              table_from_winner = winner_arr[0].gd != winner_arr[1].gd
              winner1 = winner_arr[0].player_id
              table_nos = tournament.games.where("games.id >= #{Game::MIN_ID}").where(games: { round_no: 2, group_no: group_no }).map(&:table_no).shuffle
              if table_from_winner
                t_no = winner_arr[0].game.table_no
                table_nos = table_nos - [t_no]
                Tournament.logger.info "+++012A k,v = [#{k} => #{executor_params[k].inspect}] table from winner t_no = #{t_no} winner1 = #{Player[winner1].fullname} [#{winner1}]"
              else
                t_no = table_nos.shift
                Tournament.logger.info "+++012B k,v = [#{k} => #{executor_params[k].inspect}] t_no = #{t_no}"
              end
              r_no = current_round
              seqno = tournament.tournament_monitor.data["groups"]["group#{group_no}"].index(winner1) + 1
              game = tournament.games.where("games.id >= #{Game::MIN_ID}").where(games: { round_no: nil, group_no: group_no }).where("gname ilike '%:#{seqno}-%' or gname ilike '%-#{seqno}'").first
              Tournament.logger.info "+++013 do_placement(game = #{game.attributes.inspect}, r_no = #{r_no}, t_no = #{t_no})"
              do_placement(game, r_no, t_no)
              t_no = table_nos.shift
              game = tournament.games.where("games.id >= #{Game::MIN_ID}").where(games: { round_no: nil, group_no: group_no }).first
              Tournament.logger.info "+++014 do_placement(game = #{game.attributes.inspect}, r_no = #{r_no}, t_no = #{t_no})"
              do_placement(game, r_no, t_no)
            end
          end
        end
        executor_params[k]["sq"].to_a.each do |round_no, h1|
          r_no = round_no.match(/r(\d+)/)[1].andand.to_i
          if (r_no == current_round)
            Tournament.logger.info "+++020 k,v = [#{k} => #{executor_params[k].inspect}] t_no = #{r_no}"
            executor_params[k]["sq"][round_no].to_a.each do |table_no, val|
              t_no = table_no.match(/t(\d+)/)[1].andand.to_i
              if m = val.match(/(\d+)-(\d+)/)
                game = tournament.games.where("games.id >= #{Game::MIN_ID}").find_by_gname("group#{group_no}:#{val}")
              end
              Tournament.logger.info "+++015 do_placement(game = #{game.gname}, r_no = #{r_no}, t_no = #{t_no})"
              do_placement(game, r_no, t_no)
            end
          end
        end
      elsif k.match(/(?:hf|af|qf|fin|p<(?:\d+)(?:\.\.|-)(?:\d+)>)(\d+)?/)
        r_no = executor_params[k].keys.select { |kk| kk =~ /r\d+/ }.first.match(/r(\d+)/)[1].to_i
        if (current_round == r_no)
          tno_str, players = executor_params[k]["r#{r_no}"].to_a[0]
          if mm = tno_str.match(/t(\d+)/)
            t_no = mm[1]
          elsif mm = tno_str.match(/t-rand-(\d+)-(\d+)/)
            ordered_table_nos ||= (mm[1].to_i..mm[2].to_i).to_a.shuffle
            t_no = ordered_table_nos.pop
          elsif mm = tno_str.match(/t-admin-(\d+)-(\d+)/)
            admin_table_nos ||= (mm[1].to_i..mm[2].to_i).to_a
            t_no = admin_table_nos.shift
            self.allow_change_tables = true
          end
          Tournament.logger.info "+++012A k,v = [#{k} => #{executor_params[k].inspect}] find or create game #{k}"
          game = tournament.games.where("games.id >= #{Game::MIN_ID}").find_or_create_by(gname: k)
          game.game_participations = []
          game.save
          ('a'..'b').each_with_index do |pl_no, ix|
            rule_str = players[ix]
            player_id = player_id_from_ranking(rule_str)
            game.game_participations.find_or_create_by(player_id: player_id, role: "player#{pl_no}")
          end
          Tournament.logger.info "+++016 do_placement(game = #{game.attributes.inspect}, r_no = #{r_no}, t_no = #{t_no})"
          do_placement(game, r_no, t_no)
        end
      elsif k == "RK"
      else
        #TournamentPlan Error
        Kernel.exit(333)
      end
    end
    deep_merge_data!("placements" => @placements)
    Tournament.logger.info "[tmon-populate_tables] placements: #{@placements.inspect}"
    Tournament.logger.info "...[tmon-populate_tables]"
  end

  def do_placement(game, r_no, t_no)
    if (current_round == r_no && game.present? && @placements["round#{r_no}"].andand["table#{t_no}"].blank?)
      seqno = game.seqno.to_i > 0 ? game.seqno : next_seqno
      game.update_attributes(round_no: r_no, table_no: t_no, seqno: seqno)
      @placements["round#{r_no}"] ||= {}
      @placements["round#{r_no}"]["table#{t_no}"] = game.id
      Tournament.logger.info "DO PLACEMENT round=#{r_no} table#{t_no} assign_game(#{game.gname})"
      table_monitors.find_by_name("table#{t_no}").andand.assign_game(game)
    end
  end

  def self.ranking(hash, opts = {})
    lines = hash.to_a.sort_by do |player, results|
      val = 0
      opts[:order].each do |k|
        val = val * 1000.0 + results[k.to_s].to_f
      end
      val
    end.reverse
  end

  def player_id_from_ranking(rule_str)
    begin
      g_no, game_no, rk_no = rule_str.match(/^(?:(?:fg|g)(\d+)|hf|af|qf|fin|p<(?:\d+)(?:\.\.|-)(?:\d+)>)(\d+)?\.rk(\d)$/)[1..3]
      if g_no.present?
        if rule_str.match(/^fg/)
          TournamentMonitor.ranking(data["rankings"]["endgames"]["group#{g_no}"], order: [:points, :gd])[rk_no.to_i - 1].andand[0]
        elsif rule_str.match(/^g/)
          TournamentMonitor.ranking(data["rankings"]["groups"]["group#{g_no}"], order: [:points, :gd])[rk_no.to_i - 1].andand[0]
        end
      else
        m = rule_str.match(/^(hf|af|qf|fin|p<(?:\d+)(?:-|\.\.)(?:\d+)>)(\d+)?/)
        TournamentMonitor.ranking(data["rankings"]["endgames"]["#{m[1]}#{m[2]}"], order: [:points, :gd])[rk_no.to_i - 1].andand[0]
      end
    rescue Exception => e
      Tournament.logger.info "player_id_from_ranking(#{rule_str}) #{e} #{e.backtrace.join("\n")}"
    end
  end

  def next_seqno
    #select max(seqno) from tournament.games
    tournament.games.where("games.id >= #{Game::MIN_ID}").where.not(seqno: nil).map(&:seqno).max.to_i + 1
  end

  def self.distribute_to_group(players, ngroups)
    groups = {}
    (1..ngroups).each do |group_no|
      groups["group#{group_no}"] = []
    end
    group_ix = 1
    direction_right = true
    players.each do |player|
      groups["group#{group_ix}"] << player
      if direction_right
        group_ix += 1
        if group_ix > ngroups
          direction_right = false
          group_ix = ngroups
        end
      else
        group_ix -= 1
        if group_ix <= 0
          direction_right = true
          group_ix = 1
        end
      end
    end
    return groups
  end

  private

  def before_all_events
    Tournament.logger.info "[tournament_monitor] #{aasm.current_event.inspect}"
  end
end
