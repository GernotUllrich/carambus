# frozen_string_literal: true

# Befüllt und initialisiert Tische im PartyMonitor-Kontext.
# Extrahiert aus PartyMonitor als PORO (kein ApplicationService),
# da mehrere öffentliche Eintrittspunkte existieren (kein einzelnes `call`).
#
# Verantwortlichkeiten:
#   - reset_party_monitor: Setzt PartyMonitor zurück, initialisiert Attribute aus Party
#   - initialize_table_monitors: Weist TableMonitor-Records den Party-Tischen zu
#   - do_placement: Platziert ein einzelnes Spiel auf einem Tisch
#
# Instance Variables (service-lokal, kein Persistence-Risk):
#   @placements, @placement_candidates, @placements_done, @table, @table_monitor
#
# AASM-Events: Alle AASM-Events werden auf @party_monitor gefeuert, NICHT auf self.
# cattr_accessor (Pitfall): PartyMonitor.allow_change_tables (nicht TournamentMonitor.)
#
# Verwendung:
#   PartyMonitor::TablePopulator.new(party_monitor).reset_party_monitor
#   PartyMonitor::TablePopulator.new(party_monitor).initialize_table_monitors
#   PartyMonitor::TablePopulator.new(party_monitor).do_placement(game, r_no, t_no)
class PartyMonitor::TablePopulator
  def initialize(party_monitor)
    @party_monitor = party_monitor
  end

  def reset_party_monitor
    return nil if @party_monitor.party.blank?

    Rails.logger.info "[pmon-reset_party_monitor]..."
    @party_monitor.update(
      sets_to_play: @party_monitor.tournament.andand.sets_to_play.presence || 1,
      sets_to_win: @party_monitor.tournament.andand.sets_to_win.presence || 1,
      team_size: @party_monitor.tournament.andand.team_size.presence || 1,
      kickoff_switches_with: @party_monitor.tournament.andand.kickoff_switches_with || "set",
      allow_follow_up: @party_monitor.tournament.andand.allow_follow_up,
      fixed_display_left: @party_monitor.tournament.andand.fixed_display_left,
      color_remains_with_set: @party_monitor.tournament.andand.color_remains_with_set
    )
    # TODO: initialize all PartyMonitor attributes
    @party_monitor.party.games.where("games.id >= #{Game::MIN_ID}").destroy_all
    @party_monitor.party.seedings.where("id > #{Game::MIN_ID}").destroy_all
    @party_monitor.update(data: {}) unless @party_monitor.new_record?
    @league ||= @party_monitor.party.league
    @game_plan ||= @league.game_plan
    initialize_table_monitors if @game_plan.present? && !@party_monitor.party.manual_assignment
    @party_monitor.data = @party_monitor.data.presence || @game_plan&.data.dup
    @party_monitor.data_will_change!
    @party_monitor.state = "seeding_mode"
    @party_monitor.save!
  end

  def initialize_table_monitors
    Rails.logger.info "[pmon-initialize_table_monitors]..."
    @party_monitor.save!
    table_ids = Array(@party_monitor.data["table_ids"].andand.map(&:to_i))
    if table_ids.present?
      (1..[@party_monitor.party.game_plan.andand.tables.to_i, table_ids.count].min).each do |t_no|
        table = Table.find(table_ids[t_no - 1])
        table_monitor = table.table_monitor || table.table_monitor!
        table_monitor.reset_table_monitor if table_monitor.andand.game.present?
        table_monitor.update(tournament_monitor: @party_monitor) # polymorhic association as party_ or tournament_monitor
      end
      @party_monitor.reload
    else
      Rails.logger.info "state:#{@party_monitor.state}...[ptmon-initialize_table_monitors] NO TABLES"
    end
    Rails.logger.info "state:#{@party_monitor.state}...[pmon-initialize_table_monitors]"
  end

  def do_placement(new_game, r_no, t_no, row = nil, row_nr = nil)
    try do
      @placements ||= @party_monitor.data["placements"].presence
      @placement_candidates ||= @party_monitor.data["placement_candidates"].presence
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
        table_ids = @party_monitor.data["table_ids"][r_no - 1]
        if t_no.to_i > 0 &&
            ((@party_monitor.current_round == r_no &&
              new_game.present? &&
              @placements.andand["round#{r_no}"].andand["table#{t_no}"].blank?) || @party_monitor.tournament.continuous_placements)

          seqno = new_game.seqno.to_i.positive? ? new_game.seqno : next_seqno
          new_game.update(round_no: r_no.to_i, table_no: t_no, seqno: seqno)
          @placements ||= {}
          @placements["round#{r_no}"] ||= {}
          @placements["round#{r_no}"]["table#{t_no}"] ||= []
          @placements["round#{r_no}"]["table#{t_no}"].push(new_game.id)
          Tournament.logger.info "DO PLACEMENT round=#{r_no} table#{t_no} assign_game(#{new_game.gname})" if PartyMonitor::DEBUG

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
            sets_to_play: @party_monitor.sets_to_play,
            sets_to_win: new_game.data["sets_to_win"],
            team_size: @party_monitor.team_size,
            kickoff_switches_with: new_game.data["kickoff_switches_with"],
            allow_follow_up: @party_monitor.allow_follow_up,
            fixed_display_left: @party_monitor.fixed_display_left,
            color_remains_with_set: @party_monitor.color_remains_with_set
          )

          @table_monitor.assign_attributes(tournament_monitor: @party_monitor)
          @table_monitor.andand.assign_game(new_game.reload)
        elsif @party_monitor.tournament.continuous_placements?
          @placement_candidates.push(new_game.id)
        else
          info = "+++ 8a - tournament_monitor#do_placement FAILED new_game.data: #{new_game.data.inspect}, @placements: #{@placements.inspect}, new_game: #{new_game.andand.attributes.inspect}, current_round: #{@party_monitor.current_round}"
          Rails.logger.info info
        end
        @table_monitor.save
        @bg_color = "#1B0909"
      end
    rescue => e
      Rails.logger.info "StandardError #{e}, #{e.backtrace.to_a.join("\n")}"
      raise StandardError unless Rails.env == "production"

      raise ActiveRecord::Rollback
    end
  end

  private

  def next_seqno
    @party_monitor.party.games.where("games.id >= #{Game::MIN_ID}").where.not(seqno: nil).map(&:seqno).max.to_i + 1
  end
end
