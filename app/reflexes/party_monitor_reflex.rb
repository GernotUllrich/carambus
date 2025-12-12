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
    Rails.logger.info "🔵 START assign_player_#{ab}"
    Rails.logger.info "🔵 Party: #{@party&.id}, Monitor: #{@party_monitor&.id}"
    Rails.logger.info "🔵 Params keys: #{params.keys.inspect}"
    
    assigned_players_ids = Player.joins(:seedings).where(seedings: { tournament: @party, role: "team_#{ab}" }).ids
    Rails.logger.info "🔵 Currently assigned IDs for team_#{ab}: #{assigned_players_ids.inspect}"
    
    add_ids = Array(params["availablePlayer#{ab.upcase}Id"]).map(&:to_i) - assigned_players_ids
    Rails.logger.info "🔵 Will add player IDs: #{add_ids.inspect}"
    
    add_ids.each do |pid|
      seeding = Seeding.create(player_id: pid, tournament: @party, role: "team_#{ab}", position: 1)
      Rails.logger.info "🔵 Created seeding ID: #{seeding.id}, valid: #{seeding.valid?}, errors: #{seeding.errors.full_messages.inspect}"
    end
    
    Rails.logger.info "🔵 Instance variables before morph: @assigned_players_#{ab}_ids exists? #{instance_variable_defined?("@assigned_players_#{ab}_ids")}"
    Rails.logger.info "🔵 About to call morph :page"
    
    # Force page re-render to show updated player lists
    morph :page
    
    Rails.logger.info "🔵 END assign_player_#{ab} - morph :page called"
  rescue StandardError => e
    Rails.logger.error "🔴 ERROR in assign_player_#{ab}: #{e.message}"
    Rails.logger.error "🔴 Backtrace: #{e.backtrace.first(10).join("\n")}"
    raise e
  end

  def remove_player(ab)
    Rails.logger.info "🔵 START remove_player_#{ab}"
    
    remove_ids = Array(params["assignedPlayer#{ab.upcase}Id"]).map(&:to_i)
    Rails.logger.info "🔵 Will remove player IDs: #{remove_ids.inspect}"
    
    deleted = Seeding.where(player_id: remove_ids, tournament: @party, role: "team_#{ab}").destroy_all
    Rails.logger.info "🔵 Destroyed #{deleted.count} seeding(s)"
    Rails.logger.info "🔵 About to call morph :page"
    
    # Force page re-render to show updated player lists
    morph :page
    
    Rails.logger.info "🔵 END remove_player_#{ab} - morph :page called"
  rescue StandardError => e
    Rails.logger.error "🔴 ERROR in remove_player_#{ab}: #{e.message}"
    Rails.logger.error "🔴 Backtrace: #{e.backtrace.first(10).join("\n")}"
    raise e
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
    # Force page re-render to show updated parameters
    morph :page
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

        # options = [
        #   :player_a_id, :player_b_id, :timeouts, :timeout,
        #   :sets_to_play, :sets_to_win, :balls_goal_a,
        #   :balls_goal_b, :innings_goal, :discipline_a,
        #   :discipline_b, :kickoff_switches_with,
        #   :fixed_display_left, :color_remains_with_set,
        #   :allow_overflow, :allow_follow_up, :free_game_form,
        #   :discipline_choice, :next_break_choice, :games_choice,
        #   :points_choice, :innings_choice, :warntime, :gametime,
        #   :first_break_choice
        # ]
        row_type = row[:type] == "14/1e" ? "14.1 endlos" : row[:type]
        # Extract numeric score from strings like "Hauptrunde 80" or just use the value if it's already a number
        score_value = row[:score]
        if score_value.is_a?(String)
          # Extract the last number from the string (e.g., "Hauptrunde 80" -> 80)
          score_value = score_value.scan(/\d+/).last.to_i
        end
        score_value = score_value.to_i if score_value.present?
        
        essential_game_options = {
          # tournament: @party,
          gname: "#{row[:seqno]}-#{row[:type]}",
          started_at: Time.now,
          round_no: r_no,
          seqno: row[:seqno]
        }
        additional_options = {
          free_game_form: "pool",
          kickoff_switches_with: (row[:next_break] unless row_type == "14.1 endlos").presence || "set",
          table_no: t_no,
          player_a_id: row[:player_a],
          player_b_id: row[:player_b],
          discipline_a: row_type,
          discipline_b: row_type,
          sets_to_win: row[:sets].to_i,
          points_choice: score_value,
          balls_goal_a: score_value,
          balls_goal_b: score_value,
          innings_goal: row[:innings].to_i,
          first_break_choice: row[:first_break]
        }
        game = @party.games.where(gname: "#{row[:seqno]}-#{row[:type]}").first
        game = @party.games.new(essential_game_options) unless game.present?
        game.assign_attributes(data: additional_options)
        game.save!
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

  def reset_party_monitor
    unless current_user&.admin?
      flash[:alert] = "Nur Administratoren können den Party Monitor zurücksetzen."
      Rails.logger.warn "Unauthorized reset_party_monitor attempt by user: #{current_user&.id}"
      return
    end

    # morph :nothing
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
    flash[:notice] = "Party Monitor komplett zurückgesetzt"
  rescue StandardError => e
    Rails.logger.info "reset_party_monitor error: #{e} #{e.backtrace}"
    flash[:alert] = "Fehler beim Zurücksetzen: #{e.message}"
  end

  def close_party
    if @party_monitor.party_result_checking_mode?
      complete = true
      games = []
      @party_monitor.data["rows"].each do |row|
        next unless ["14/1e", "10-Ball", "8-Ball", "9-Ball", "10-Ball Doppel", "9-Ball Doppel",
                     "Shootout (4er Team)"].include?(row[:type])

        row_type = row[type]
        gname = "#{row[:seqno]}-#{row_type}"
        game = @party_monitor.party.games.where(gname: gname).first
        if game.ended_at.blank?
          complete = false
        else
          games << game
        end
      end
      if complete
        game_points = @party_monitor.party.intermediate_result
        result = {}
        result["game_points"] = game_points.join(":")
        match_points = [
          (if game_points[0] > game_points[1]
             @party_monitor.data["match_points"]["win"]
           else
             game_points[0] == game_points[1] ? @party_monitor.data["match_points"]["draw"] : @party_monitor.data["match_points"]["lost"]
           end),
          (if game_points[1] > game_points[0]
             @party_monitor.data["match_points"]["win"]
           else
             game_points[1] == game_points[0] ? @party_monitor.data["match_points"]["draw"] : @party_monitor.data["match_points"]["lost"]
           end)
        ]
        result["match_points"] = match_points.join(":")
        @party_monitor.deep_merge_data!(result: result)
        @party_monitor.save
        @party_monitor.close_party!
      else
        flash[:alert] = "Die Spiele sind noch nicht vollständig erfasst!"
      end
    else
      flash[:alert] =
        "Der Party Monitor kann in diesen Zustand (#{@party_monitor.stata}) keinen Spielbericht erstellen!"
    end
  rescue StandardError => e
    Rails.logger.info "#{e} #{e.backtrace}"
    raise StandardError
  end

  private

  def load_objects
    @party_monitor = PartyMonitor.find(element.dataset["id"])
    @party = @party_monitor.party
    setup_view_variables
  end

  def setup_view_variables
    # Set up all instance variables needed by the view
    # This mirrors what the controller's show action does
    @league = @party.league
    @assigned_players_a_ids = Player.joins(:seedings).where(seedings: { role: "team_a", tournament_type: "Party",
                                                                        tournament_id: @party.id }).order("players.lastname").ids
    @assigned_players_b_ids = Player.joins(:seedings).where(seedings: { role: "team_b", tournament_type: "Party",
                                                                        tournament_id: @party.id }).order("players.lastname").ids
    @available_players_a_ids = @party.league_team_a.seedings.joins(:player).order("players.lastname").map(&:player_id).select do |pid|
      !@assigned_players_a_ids.include?(pid)
    end
    @available_players_b_ids = @party.league_team_b.seedings.joins(:player).order("players.lastname").map(&:player_id).select do |pid|
      !@assigned_players_b_ids.include?(pid)
    end
    league_team_a_name = @party.league_team_a.name
    league_team_b_name = @party.league_team_b.name
    replacement_teams_a_ids = LeagueTeam.joins(:league).where(leagues: { season_id: Season.current_season.id }).where(club_id: @party.league_team_a.club_id).where("league_teams.name > '#{league_team_a_name}'").ids - @available_players_a_ids
    replacement_teams_b_ids = LeagueTeam.joins(:league).where(leagues: { season_id: Season.current_season.id }).where(club_id: @party.league_team_b.club_id).where("league_teams.name > '#{league_team_b_name}'").ids - @available_players_b_ids
    @available_replacement_players_a_ids = Seeding.where(league_team_id: replacement_teams_a_ids).joins(:player).order("players.lastname").map(&:player_id).select do |pid|
      !@assigned_players_a_ids.include?(pid)
    end
    @available_replacement_players_b_ids = Seeding.where(league_team_id: replacement_teams_b_ids).joins(:player).order("players.lastname").map(&:player_id).select do |pid|
      !@assigned_players_b_ids.include?(pid)
    end

    @available_fitting_table_ids = @party.location.andand.tables.andand.joins(table_kind: :disciplines).andand.where(disciplines: { id: @league.discipline_id }).andand.order("name").andand.map(&:id).to_a
    @tournament_tables = @party.location.andand.tables.andand.joins(table_kind: :disciplines).andand.where(disciplines: { id: @league.discipline_id }).andand.count.to_i
    @tables_from_plan = @party_monitor.data["tables"].to_i
    @tournament_tables = [@tournament_tables, @party_monitor.data["tables"].to_i].min if @tables_from_plan > 0
  end
end
