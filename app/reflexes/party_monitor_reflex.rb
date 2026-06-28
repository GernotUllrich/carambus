# frozen_string_literal: true

class PartyMonitorReflex < ApplicationReflex
  # Add Reflex methods in this file.
  #
  # All Reflex instances expose the following properties:
  #
  #   - connection - the Action  Cable connection
  #   - channel - the ActionCable channel
  #   - request - an ActionDispatch::Request proxy for the socket connection
  #   - session - the ActionDispatch::Session store for the current visitor
  #   - url - the URL of the page that triggered the reflex
  #   - element - a Hash like object  that represents the HTML element that triggered the reflex
  #   - params - parameters from the element's closest form (if any)
  #
  # Example:
  #
  #   def example(argument=true)
  #     # Your logic here...
  #     # Any declared instance variables will be made available to the Rails controller and view.
  #   end
  #
  # Learn more at: https://docs.stimulusreflex.com

  before_reflex :load_objects

  def assign_player(ab)
    assigned_players_ids = Player.joins(:seedings).where(seedings: { tournament: @party, role: "team_#{ab}" }).ids
    add_ids = Array(params["availablePlayer#{ab.upcase}Id"]).map(&:to_i) - assigned_players_ids
    add_ids.each do |pid|
      Seeding.create(player_id: pid, tournament: @party, role: "team_#{ab}", position: 1)
    end
    Rails.logger.info "======== assign_player_#{ab}"
  rescue StandardError => e
    Rails.logger.info "======== #{e} #{e.backtrace}"
  end

  def remove_player(ab)
    remove_ids = Array(params["assignedPlayer#{ab.upcase}Id"]).map(&:to_i)
    Seeding.where(player_id: remove_ids, tournament: @party, role: "team_#{ab}").destroy_all
    Rails.logger.info "======== remove_player_#{ab}"
  end

  def assign_player_a
    assign_player("a")
  end

  def assign_player_b
    assign_player("b")
  end

  def remove_player_a
    remove_player("a")
  end

  def remove_player_b
    remove_player("b")
  end

  def edit_parameter
    gather_parameters
  rescue StandardError => e
    Rails.logger.info "======== #{e} #{e.backtrace}"
  end

  def gather_parameters
    @party_monitor.data = @party_monitor.data.presence || @league.game_plan.data
    rows = @party_monitor.data["rows"]
    params.keys.each do |k|
      next unless /^#{@party.cc_id}-/.match?(k)

      v = params[k]
      v = v.to_i if v.to_i.to_s == v
      vals = k.split("-")
      row_nr = vals[1].to_i
      r_no = vals[2].to_i
      rep_no = vals[3].to_i
      type = vals[-1].to_sym
      rows[row_nr] ||= {}
      if type =~ /player/ && rep_no > 1
        rows[row_nr][type] = Array(rows[row_nr][type])
        rows[row_nr][type] << v
      else
        rows[row_nr][type] = v
      end
      rows[row_nr][:r_no] = r_no
    end
    @party_monitor.deep_merge_data!(rows: rows)
    @party_monitor.save
  end

  def prepare_next_round
    if @party_monitor.may_prepare_next_round?
      gather_parameters
      minimum_players = @party_monitor.data["minimum_players"].presence || 4
      maximum_players = @party_monitor.data["maximum_players"].presence || 8
      assigned_players_a_ids = Player.joins(:seedings).where(seedings: { tournament: @party, role: "team_a" }).ids
      assigned_players_b_ids = Player.joins(:seedings).where(seedings: { tournament: @party, role: "team_b" }).ids
      if assigned_players_a_ids.count >= minimum_players && assigned_players_b_ids.count >= minimum_players &&
         assigned_players_a_ids.count <= maximum_players && assigned_players_b_ids.count <= maximum_players
        @party_monitor.deep_merge_data!(
          assigned_players_a_ids: assigned_players_a_ids,
          assigned_players_b_ids: assigned_players_b_ids
        )
        @party_monitor.save
        @party_monitor.prepare_next_round!
      else
        flash[:alert] =
          "Ein Minimum von #{minimum_players} bzw. Maximun von #{maximum_players} Spielern ist erforderlich!"
      end
    else
      flash[:alert] =
        "Systemfehler?! Diese Funktion ist nur im Zustand 'seeding_mode' möglich!  Derzeit ist der Zustand '#{@party_monitor.state}'"
    end
  rescue StandardError => e
    Rails.logger.info "#{e} #{e.backtrace}"
    raise StandardError
  end

  def enter_next_round_seeding
    if @party_monitor.may_enter_next_round_seeding?
      @party_monitor.data = @party_monitor.data.presence || @league.game_plan.data.dup
      round = @party_monitor.current_round
      # @party_monitor.data["table_ids"] = params[:table_id].map(&:to_i).uniq
      table_id_keys = params.keys.select { |id| id =~ /table_id_#{round}_\d+/ }
      table_ids = []
      table_id_keys.each do |key|
        r_no, t_no = key.match(/table_id_(\d+)_(\d+)/)[1..2].map(&:to_i)
        table_ids[r_no - 1] ||= []
        table_ids[r_no - 1][t_no - 1] = params[key].to_i
      end
      if table_id_keys.length == table_ids[round - 1].length
        @party_monitor.deep_merge_data!(table_ids: table_ids)
        # @party_monitor.data_will_change!
        @party_monitor.save
        @party_monitor.enter_next_round_seeding!
      else
        flash[:alert] = "Mindestens #{@party_monitor.data["tables"].to_i} Tische müssen zugeordnet werden!"
      end
    else
      flash[:alert] =
        "Systemfehler?! Diese Funktion ist nur im Zustand 'table_definition_mode' möglich!  Derzeit ist der Zustand '#{@party_monitor.state}'"
    end
  rescue StandardError => e
    Rails.logger.info "#{e} #{e.backtrace}"
    raise StandardError
  end

  def finish_round_seeding_mode
    gather_parameters
    if @party_monitor.may_finish_round_seeding_mode?
      if (r_no = element.dataset["rno"]).present?
        r_no = r_no.to_i
        @party_monitor.current_round!(r_no)
      else
        @party_monitor.current_round!(@party_monitor.current_round == 0 ? 1 : @party_monitor.current_round + 1)
      end
      player_ids = []
      faults = 0
      multiple_assignments = 0
      player_a_ids = []
      player_b_ids = []
      @party_monitor.data["rows"].each do |row|
        next unless ["14/1e", "10-Ball", "8-Ball", "9-Ball", "10-Ball Doppel", "9-Ball Doppel",
                     "Shootout (4er Team)"].include?(row[:type]) && (row[:r_no] == r_no)

        row_type = row[:type] == "14/1e" ? "14.1 endlos" : row[:type]

        player_a_ids = Array(row[:player_a]).select { |id| id != 0 }.uniq
        if (player_a_ids & player_ids).present?
          multiple_assignments += (player_a_ids & player_ids).count
        else
          player_ids += player_a_ids
        end
        if /Doppel/.match?(row_type)
          faults += 1 if player_a_ids.count != 2
        elsif /4er/.match?(row_type)
          faults += 1 if player_a_ids.count != 4
        elsif player_a_ids.count != 1
          faults += 1
        end

        player_b_ids = Array(row[:player_b]).select { |id| id != 0 }.uniq
        if /Doppel/.match?(row_type)
          faults += 1 if player_b_ids.count != 2
        elsif /4er/.match?(row_type)
          faults += 1 if player_b_ids.count != 4
        elsif player_b_ids.count != 1
          faults += 1
        end
        if (player_b_ids & player_ids).present?
          multiple_assignments += (player_b_ids & player_ids).count
        else
          player_ids += player_b_ids
        end
      end
      flash[:alert] = "Nicht alle Spiele wurden besetzt!" if faults > 0
      flash[:alert] = "Spieler wurden mehrfach zugeordnet!" if multiple_assignments > 0
      @party_monitor.finish_round_seeding_mode! if faults == 0 && multiple_assignments == 0
    else
      flash[:alert] =
        "Systemfehler?! Diese Funktion ist nur im den Zuständen '#{%w[next_round_seeding_mode
                                                                      round_finished].inspect}' möglich!  Derzeit ist der Zustand '#{@party_monitor.state}'"
    end
  rescue StandardError => e
    Rails.logger.info "#{e} #{e.backtrace}"
    raise StandardError
  end

  def finish_round
    if @party_monitor.may_finish_round?
      @party_monitor.incr_current_round!
      if @party_monitor.data["rows"].index do |row|
           row[:type] == "Neue Runde" && row[:r_no] == @party_monitor.current_round
         end
        @party_monitor.finish_round!
        @party_monitor.save
        # TODO: if draw result so far play shootout!!!
        if @party_monitor.data["rows"].index do |row|
             row[:type] =~ /shootout/i && row[:r_no] == @party_monitor.current_round
           end
          points_l, points_r = @party.intermediate_result
          if points_l == points_r
            @party_monitor.prepare_next_round!
          else
            @party_monitor.save
                                                 .save!
            @party_monitor.finish_party!
          end
        else
          @party_monitor.prepare_next_round!
        end
      else
        @party_monitor.save
        @party_monitor.finish_round!
        @party_monitor.finish_party!
      end
      @party_monitor.save
    else
      flash[:alert] =
        "Systemfehler?! Diese Funktion ist nur im den Zuständen '#{["playing_round"].inspect}' möglich!  Derzeit ist der Zustand '#{@party_monitor.state}'"
    end
  rescue StandardError => e
    Rails.logger.info "#{e} #{e.backtrace}"
    raise StandardError
  end

  def start_round
    gather_parameters
    r_no = element.dataset["rno"].to_i
    @party_monitor.current_round!(r_no)
    # create games for round
    t_no = 1
    if @party_monitor.may_start_round?
      @party_monitor.data["rows"].each_with_index do |row, row_nr|
        next unless ["14/1e", "10-Ball", "8-Ball", "9-Ball", "10-Ball Doppel", "9-Ball Doppel",
                     "Shootout (4er Team)"].include?(row[:type]) && (row[:r_no] == r_no)

        # Game-Erzeugung für die Spielzeile (ohne TableMonitor) ist nach Party#build_game_for_row!
        # extrahiert (48-03/K-1) — danach unverändert do_placement + TableMonitor-Bindung.
        game = @party.build_game_for_row!(row, r_no, t_no)
        @party_monitor.do_placement(game, r_no, t_no, row, row_nr)
        t_no += 1
      end
      @party_monitor.table_monitors.each do |table_monitor|
        table_monitor.start_game(table_monitor.game.data.merge(
                                   kickoff_switches_with: @party_monitor.kickoff_switches_with.presence || "set",
                                   color_remains_with_set: @party_monitor.color_remains_with_set,
                                   fixed_display_left: @party_monitor.fixed_display_left
                                 ))
      end
      @party_monitor.start_round!
    else
      flash[:alert] = "Der Party Monitor kann in diesen Zustand (#{@party_monitor.state}) keine Runde starten!"
    end
  end

  # Zeilenweise Direkteingabe der Endergebnisse (Phase 48 / D-48-1, kein Scoreboard):
  # liest die getippten Felder der aktuellen Runde aus dem serialisierten Form und schreibt
  # je Partie game.data["ba_results"] + ended_at DIREKT (über Party#record_game_result!) —
  # ohne TableMonitor/evaluate_result. Nur im Zustand "playing_round".
  def enter_game_results
    unless @party_monitor.playing_round?
      flash[:alert] =
        "Systemfehler?! Ergebniseingabe ist nur im Zustand 'playing_round' möglich! Derzeit ist der Zustand '#{@party_monitor.state}'"
      return
    end
    r_no = element.dataset["rno"].to_i
    Array(@party_monitor.data["rows"]).each_with_index do |row, row_nr|
      next unless Party::GAME_ROW_TYPES.include?(row["type"]) && row["r_no"] == r_no

      prefix = "#{@party.cc_id}-#{row_nr}-#{r_no}-1-"
      @party.record_game_result!(
        row: row,
        sc1: params["#{prefix}sc1"],
        sc2: params["#{prefix}sc2"],
        in1: params["#{prefix}in1"],
        in2: params["#{prefix}in2"],
        br1: params["#{prefix}br1"],
        br2: params["#{prefix}br2"]
      )
    end
  rescue StandardError => e
    Rails.logger.info "#{e} #{e.backtrace}"
    raise StandardError
  end

  def reset_party_monitor
    Rails.logger.info "🔴 RESET PARTY MONITOR CALLED - User: #{current_user&.id}, Admin: #{current_user&.admin?}"
    
    unless current_user&.admin?
      flash[:alert] = "Nur Administratoren können den Party Monitor zurücksetzen."
      Rails.logger.warn "Unauthorized reset_party_monitor attempt by user: #{current_user&.id}"
      return
    end

    Rails.logger.info "🔴 Starting reset - PartyMonitor ID: #{@party_monitor.id}"
    
    # 1. Lösche Games der TableMonitors (nur wenn vorhanden)
    @party_monitor.table_monitors.each do |table_monitor|
      table_monitor.game&.destroy
    end
    # 2. Lösche alle TableMonitors
    @party_monitor.table_monitors.destroy_all
    # 3. Lösche alle Party-Games
    @party_monitor.party.games.destroy_all
    # 4. Lösche Test-Seedings (nur die mit hohen IDs)
    @party_monitor.party.seedings.where("id > 5000000").destroy_all
    # 5. Setze den PartyMonitor zurück
    @party_monitor.reset_party_monitor
    
    Rails.logger.info "🔴 Reset completed successfully"
    flash[:notice] = "Party Monitor komplett zurückgesetzt"
  rescue StandardError => e
    Rails.logger.info "reset_party_monitor error: #{e} #{e.backtrace}"
    flash[:alert] = "Fehler beim Zurücksetzen: #{e.message}"
  end

  def close_party
    if @party_monitor.party_result_checking_mode?
      outcome = @party_monitor.close_with_result! # Naht: Guard + game_points/match_points + close_party! (48-03/K-2)
      flash[:alert] = "Die Spiele sind noch nicht vollständig erfasst!" unless outcome[:ok]
    else
      flash[:alert] =
        "Der Party Monitor kann in diesen Zustand (#{@party_monitor.state}) keinen Spielbericht erstellen!"
    end
  rescue StandardError => e
    Rails.logger.info "#{e} #{e.backtrace}"
    raise StandardError
  end

  private

  def load_objects
    @party_monitor = PartyMonitor.find(element.dataset["id"])
    @party = @party_monitor.party
  end
end
