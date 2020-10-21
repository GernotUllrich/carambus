class TournamentMonitor < ActiveRecord::Base
  include AASM
  has_paper_trail

  belongs_to :tournament
  has_many :table_monitors, :dependent => :destroy

  serialize :data, Hash

  aasm :column => 'state' do
    state :new_tournament_monitor, initial: true, :after_enter => [:reset_tournament_monitor]
    state :playing_groups
    state :evaluating_results, :after_enter => [:populate_tables]
    state :playing_finals
    state :tournament_finished
    state :publish_results
    state :closed
    before_all_events :before_all_events
    event :start_playing_groups do
      transitions from: [:new_tournament_monitor, :playing_groups], to: :playing_groups, guard: :table_monitors_ready_and_populated
    end
    event :report_game_result do
      #TODO transitions from: :playing_groups,
    end
  end

  # def initialize(attributes = nil, options = nil)
  #   super
  # end

  def merge_data!(hash)
    h = data.dup
    h.merge!(hash)
    self.data = h
    save!
  end

  def report_result(table_monitor)
    report_game_result!
    if all_table_monitors_finished?
      finalize_round
      @current_round += 1
      merge_data!(current_round: @current_round)
      populate_tables
      if group_phase_finished?
        if finals_finished?
          end_of_tournament!
        else
          start_playing_finals!
        end
      else
        start_playing_groups!
      end
    end

  end

  def table_monitors_ready_and_populated
    Tournament.logger.info "[tmon-table_monitors_ready_and_populated]..."
    res = table_monitors_ready? && table_monitors_populated?
    Tournament.logger.info "returns #{res}...[tmon-table_monitors_ready_and_populated]"
    return res
  end

  def table_monitors_ready?
    Tournament.logger.info "[tmon-table_monitors_ready]..."
    res = table_monitors.inject(true) { |memo, tm| memo = memo && tm.ready? || tm.playing_game?; memo }
    Tournament.logger.info "returns #{res}...[tmon-table_monitors_ready]"
    return res
  end

  def table_monitors_populated?
    Tournament.logger.info "[tmon-table_monitors_populated]..."
    ret = true
    @current_round = data[:current_round]
    placements = data[:placements]
    placements.to_a.each do |round_no, game_hash|
      next unless "round#{@current_round}" == round_no
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

    table_monitors.destroy_all
    update_attributes(data: {})
    @tournament_plan ||= tournament.tournament_plan
    initialize_table_monitors
    @groups = TournamentMonitor.distribute_to_group(tournament.seedings.map(&:player_id), @tournament_plan.ngroups)
    @placements = {}
    @current_round = 1
    merge_data!(groups: @groups)
    merge_data!(current_round: @current_round)
    merge_data!(placements: @placements)
    executor_params = JSON.parse(@tournament_plan.executor_params)
    game_seqno = 0
    executor_params.keys.each do |k|
      if m = k.match(/g(\d+)/)
        group_no = m[1].to_i
        if @groups["group#{group_no}"].count != executor_params[k]["pl"].to_i
          return {"ERROR" => "Group Count Mismatch: group#{group_no}, #{@groups["group#{group_no}"].count} vs. #{executor_params[k]["pl"].to_i} from executor_params"}
        end
        if executor_params[k]["rs"] =~ /^eae/
          (1..@groups["group#{group_no}"].count).to_a.permutation(2).to_a.select { |v1, v2| v1 < v2 }.each_with_index do |a, ix|
            i1, i2 = a
            game_seqno += 1
            game = tournament.games.create(gname: "group#{group_no}:#{i1}-#{i2}", seqno: game_seqno)
            game.game_participations.create(player_id: @groups["group#{group_no}"][i1 - 1], role: "playera")
            game.game_participations.create(player_id: @groups["group#{group_no}"][i2 - 1], role: "playerb")

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
    (1..tournament.tournament_plan.tables).each do |t_no|
      self.reload.table_monitors.find_or_create_by!(name: "table#{t_no}").id
    end
    reload
    Tournament.logger.info "state:#{state}...[tmon-initialize_table_monitors]"
  end

  def populate_tables
    Tournament.logger.info "[tmon-populate_tables]..."
    #collect results from tables
    table_monitors.all.each do |tabmon|

    end

    executor_params = JSON.parse(@tournament_plan.executor_params)
    @placements = {}
    executor_params.keys.each do |k|
      if m = k.match(/g(\d+)/)
        group_no = m[1].to_i
        #apply table/round_rules
        executor_params[k]["sq"].to_a.each do |round_no, h1|
          r_no = round_no.match(/r(\d+)/)[1].andand.to_i
          executor_params[k]["sq"][round_no].to_a.each do |table_no, val|
            t_no = table_no.match(/t(\d+)/)[1].andand.to_i
            if m = val.match(/(\d+)-(\d+)/)
              game = Game.find_by_gname("group#{group_no}:#{val}")
            end
            if (game.present? && @placements["round#{r_no}"].andand[t_no].blank?)
              game.update_attributes(round_no: r_no, table_no: t_no)
              @placements["round#{r_no}"] ||= {}
              @placements["round#{r_no}"]["table#{t_no}"] = game.id
              if (@current_round == r_no)
                TableMonitor.find_by_name("table#{t_no}").andand.assign_game(game)
              end
            end
          end
        end
      end
    end
    merge_data!(placements: @placements)
    Tournament.logger.info "[tmon-populate_tables] placements: #{@placements.inspect}"
    Tournament.logger.info "[tmon-populate_tables]..."
  end

  def self.distribute_to_group(players, ngroups)
    Tournament.logger.info "[tmon-distribute_to_group]..."
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
    Tournament.logger.info "...[tmon-distribute_to_group]"
    return groups
  end

  private

  def before_all_events
    Tournament.logger.info "[tournament_monitor] #{aasm.current_event.inspect}"
  end
end
