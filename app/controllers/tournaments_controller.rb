class TournamentsController < ApplicationController
  include FiltersHelper
  before_action :set_tournament,
                only: %i[show edit update destroy order_by_ranking_or_handicap finish_seeding edit_games reload_from_cc new_team
                         finalize_modus select_modus tournament_monitor reset start define_participants add_team placement
                         upload_invitation parse_invitation apply_seeding_order compare_seedings add_player_by_dbu
                         recalculate_groups]

  # GET /tournaments
  def index
    # Default sort by date descending if no sort specified
    search_params = params.dup
    search_params[:sort] ||= 'Date'
    search_params[:direction] ||= 'desc'
    
    results = SearchService.call(Tournament.search_hash(search_params))
    @pagy, @tournaments = pagy(results.includes(:discipline, :season, :location, :tournament_cc).preload(:organizer))
    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @tournaments.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @tournaments.load
    respond_to do |format|
      format.html do
        render("index")
      end
    end
  end

  # GET /tournaments/1
  def show; end

  def edit_games
    @edit_games_modus = true
  end

  def reset
    if params[:force_reset].present?
      @tournament.forced_reset_tournament_monitor!
    elsif !@tournament.tournament_started
      @tournament.reset_tmt_monitor!
    else
      flash[:alert] = "Cannot reset running or finished tournament"
    end
    redirect_to tournament_path(@tournament)
  end

  def order_by_ranking_or_handicap
    if local_server?
      hash = {}
      unless @tournament.organizer.is_a?(Club) || (@tournament.id >= Seeding::MIN_ID)
        # restore seedings from ba
        @tournament.seedings.where("seedings.id >= #{Seeding::MIN_ID}").destroy_all
        @tournament.seedings.create(
          @tournament.seedings.where("seedings.id < #{Seeding::MIN_ID}").map do |s|
            { player_id: s.player_id, balls_goal: s.balls_goal }
          end
        )
      end
      @tournament.seedings.where("seedings.id >= #{@tournament.organizer.is_a?(Club) ? Seeding::MIN_ID : Seeding::MIN_ID}").each do |seeding|
        if @tournament.handicap_tournier
          hash[seeding] = -seeding.balls_goal.to_i
        else
          diff = Season.current_season&.name == "2021/2022" ? 2 : 1
          hash[seeding] = if @tournament.team_size > 1
                            999
                          else
                            seeding.player.player_rankings.where(discipline_id: Discipline.find_by_name("Freie Partie klein"),
                                                                 season_id: Season.find_by_ba_id(Season.current_season&.ba_id.to_i - diff))
                                   .first&.rank.presence || 999
                          end
        end
      end
      sorted = hash.to_a.sort_by do |a|
        a[1]
      end
      sorted.each_with_index do |a, ix|
        seeding, = a
        seeding.update(position: ix + 1)
      end

      # @tournament.finish_seeding!
      # @tournament.reload
    else
      flash[:alert] = t("not_allowed_on_api_server")
    end
    redirect_to tournament_path(@tournament)
    nil
  end

  def finish_seeding
    if local_server?
      @tournament.finish_seeding!
      @tournament.reload
    else
      flash[:alert] = t("not_allowed_on_api_server")
    end
    redirect_to tournament_path(@tournament)
    nil
  end

  def reload_from_cc
    # Unterscheide zwischen Setup-Phase und Ergebnis-Phase
    reload_games = params[:reload_games] == 'true'
    
    if local_server?
      if reload_games
        # Nach dem Turnier: Komplett-Reset und Spiele von ClubCloud laden
        @tournament.reset_tournament
        Version.update_from_carambus_api(update_tournament_from_cc: @tournament.id)
      else
        # Vor/während Turnier: Nur lokale Seedings zurücksetzen
        @tournament.seedings.where("seedings.id >= #{Seeding::MIN_ID}").destroy_all
        @tournament.reset_tmt_monitor! if @tournament.tournament_monitor.present?
        
        # Hole Updates vom API Server (inkl. ClubCloud-Seedings)
        # WICHTIG: reload_games: false damit API Server die Seedings nicht löscht!
        Version.update_from_carambus_api(update_tournament_from_cc: @tournament.id, reload_games: false)
      end
    else
      # API Server: Scrape von ClubCloud
      @tournament.scrape_single_tournament_public(reload_game_results: reload_games)
    end
    
    redirect_back_or_to(tournament_path(@tournament))
  end

  def finalize_modus
    if @tournament.league.present?
      @tournament.unprotected = true
      @tournament.assign_attributes(tournament_plan_id: @tournament.league.league_plan.id)
      @tournament.save
      @tournament.unprotected = false
      @tournament.finish_mode_selection!
      @tournament.reload
    else
      @tournament.seedings.where(player_id: nil).destroy_all
      
      # Intelligentes Zählen: Wenn lokale Seedings existieren, nur diese zählen
      # Ansonsten ClubCloud-Seedings zählen (verhindert Duplikat-Zählung)
      has_local_seedings = @tournament.seedings.where("seedings.id >= #{Seeding::MIN_ID}").any?
      @seeding_scope = has_local_seedings ? 
                        "seedings.id >= #{Seeding::MIN_ID}" : 
                        "seedings.id < #{Seeding::MIN_ID}"
      
      @participant_count = @tournament.seedings
                                      .where.not(state: "no_show")
                                      .where(@seeding_scope)
                                      .count
      
      # Versuche TournamentPlan anhand extrahierter Info zu finden (z.B. "T21")
      @proposed_discipline_tournament_plan = nil
      if @tournament.data['extracted_plan_info'].present?
        # Extrahiere Plan-Name (z.B. "T21" aus "T21 - 3 Gruppen à 3, 4 und 4 Spieler")
        if (match = @tournament.data['extracted_plan_info'].match(/^(T\d+)/i))
          plan_name = match[1].upcase
          @proposed_discipline_tournament_plan = ::TournamentPlan.where(name: plan_name).first
          Rails.logger.info "===== finalize_modus ===== Extracted plan name: #{plan_name}, found: #{@proposed_discipline_tournament_plan.present?}"
        end
      end
      
      # Fallback: Suche nach Spielerzahl + Disziplin
      unless @proposed_discipline_tournament_plan.present?
        @proposed_discipline_tournament_plan = ::TournamentPlan.joins(discipline_tournament_plans: :discipline)
                                                               .where(discipline_tournament_plans: {
                                                                        players: @participant_count,
                                                                        player_class: @tournament.player_class,
                                                                        discipline_id: @tournament.discipline_id
                                                                      }).first
      end
      if @proposed_discipline_tournament_plan.present?
        # Berechne IMMER die NBV-Standard-Gruppenbildung
        @nbv_groups = TournamentMonitor.distribute_to_group(
          @tournament.seedings.where.not(state: "no_show").where(@seeding_scope).order(:position).map(&:player), 
          @proposed_discipline_tournament_plan.ngroups
        )
        
        # Wenn extrahierte Gruppenbildung vorhanden: vergleiche
        if @tournament.data['extracted_group_assignment'].present?
          @extracted_groups = convert_position_groups_to_player_groups(
            @tournament.data['extracted_group_assignment'],
            @tournament
          )
          
          # Vergleiche die beiden Gruppenbildungen
          @groups_match = groups_identical?(@extracted_groups, @nbv_groups)
          
          if @groups_match
            # Identisch: Verwende extrahierte (aber eigentlich egal)
            @groups = @extracted_groups
            @groups_source = :extracted_matches_nbv
            Rails.logger.info "===== finalize_modus ===== Extrahierte Gruppenbildung ist identisch mit NBV-Algorithmus ✓"
          else
            # Abweichung: Verwende extrahierte, aber zeige Warnung
            @groups = @extracted_groups
            @groups_source = :extracted_differs_from_nbv
            Rails.logger.warn "===== finalize_modus ===== ⚠️  Extrahierte Gruppenbildung weicht von NBV-Algorithmus ab!"
          end
        else
          # Keine Extraktion: Verwende NBV
          @groups = @nbv_groups
          @groups_source = :algorithm
        end
      end
      @alternatives_same_discipline = ::TournamentPlan.joins(discipline_tournament_plans: :discipline)
                                                      .where.not(tournament_plans: { id: @proposed_discipline_tournament_plan.andand.id })
                                                      .where(discipline_tournament_plans: {
                                                               players: @participant_count,
                                                               discipline_id: @tournament.discipline_id
                                                             }).uniq
      @alternatives_other_disciplines = ::TournamentPlan
                                        .where.not(tournament_plans: { id: [@proposed_discipline_tournament_plan.andand.id] + @alternatives_same_discipline.map(&:id) })
                                        .where(players: @participant_count).uniq.to_a
      @default_plan = TournamentPlan.default_plan(@participant_count)
      @ko_plan = TournamentPlan.ko_plan(@participant_count)
      @alternatives_other_disciplines |= [@default_plan]
      @alternatives_other_disciplines |= [@ko_plan]
      @groups = TournamentMonitor.distribute_to_group(
        @tournament.seedings.where.not(state: "no_show").where(@seeding_scope).order(:position).map(&:player), 
        @default_plan.ngroups
      )
    end
  end

  def select_modus
    begin
      @tournament.unprotected = true
      @tournament.assign_attributes(tournament_plan_id: TournamentPlan.find_by_id(params[:tournament_plan_id]).id)
      @tournament.save
      @tournament.unprotected = false
      @tournament.finish_mode_selection!
      @tournament.save
      @tournament.reload
    rescue StandardError => e
      flash[:alert] = e.message
      redirect_back_or_to(tournament_path(@tournament))
      return
    end
    redirect_to tournament_monitor_tournament_path(@tournament)
  end

  def tournament_monitor
    return unless @tournament.tournament_monitor.present?

    redirect_to tournament_monitor_path(@tournament.tournament_monitor)
  end

  def placement
    info = "+++ 4 - tournaments_controller#placement"
    Rails.logger.info info
    @navbar = @footer = false
    @game = Game.find(params[:game_id])
    @table = Table.find(params[:table_id])
    TournamentMonitor.transaction do
      @tournament_monitor = @tournament.tournament_monitor
      @table_monitor = @table.table_monitor || @table.table_monitor!
      @table_monitor.update(tournament_monitor_id: @tournament_monitor.id,
                            tournament_monitor_type: @tournament_monitor.type)
    end
    Rails.logger.info "+++ 6 - tournaments_controller#placement"
    @tournament_monitor.do_placement(@game, @tournament_monitor.current_round, @tournament.t_no_from(@table), nil, nil)
    redirect_to table_monitor_path(@table_monitor)
  end

  def start
    data_ = @tournament.data
    data_["table_ids"] =params[:table_id]
    data_["balls_goal"] =params[:balls_goal].to_i
    data_["innings_goal"] =params[:innings_goal].to_i
    data_["timeout"] =params[:timeout].to_i
    data_["timeouts"] =params[:timeouts].to_i
    data_["sets_to_play"] =params[:sets_to_play].to_i
    data_["sets_to_win"] =params[:sets_to_win].to_i
    data_["time_out_warm_up_first_min"] =params[:time_out_warm_up_first_min].to_i
    data_["time_out_warm_up_follow_up_min"] =params[:time_out_warm_up_follow_up_min].to_i
    data_["kickoff_switches_with"] =params[:kickoff_switches_with]
    data_["fixed_display_left"] =params[:fixed_display_left].to_s
    data_["color_remains_with_set"] =params[:color_remains_with_set]
    data_["allow_overflow"] =params[:allow_overflow]
    data_["allow_follow_up"] = params[:allow_follow_up]
    @tournament.unprotected = true
    @tournament.data_will_change!
    @tournament.assign_attributes(data: data_)
    @tournament.save
    if @tournament.valid?
      Tournament.transaction do
        @tournament.initialize_tournament_monitor
        @tournament.reload
        @tournament.start_tournament!
        @tournament.save
        @tournament.reload
        @tournament.tournament_monitor.update(current_admin: current_user,
                                              timeout: (params[:timeout].presence || @tournament.timeout).to_i,
                                              timeouts: (params[:timeouts].presence || @tournament.timeouts).to_i,
                                              sets_to_play: (params[:sets_to_play].presence || @tournament.sets_to_play).to_i,
                                              sets_to_win: (params[:sets_to_win].presence || @tournament.sets_to_win).to_i,
                                              kickoff_switches_with: params[:kickoff_switches_with],
                                              color_remains_with_set: params[:color_remains_with_set] == "1",
                                              allow_overflow: params[:allow_overflow].present?,
                                              allow_follow_up: params[:allow_follow_up].present?,
                                              fixed_display_left: params[:fixed_display_left].to_s)
      end
      if @tournament.tournament_started_waiting_for_monitors?
        redirect_to tournament_monitor_path(@tournament.tournament_monitor)
        return
      else
        redirect_back_or_to(tournament_path(@tournament))
        return
      end
    else
      flash[:alert] = @tournament.errors.full_messages
      redirect_back_or_to(tournament_path(@tournament))
      return
    end
  end

  # GET /tournaments/new
  def new
    @tournament = Tournament.new
  end

  # GET /tournaments/1/edit
  def edit; end

  # POST /tournaments
  def create
    @tournament = Tournament.new(tournament_params)
    @league = League.find_by_id(params["league_id"])
    if @league.present?
      @tournament.organizer = @league.organizer
      @tournament.single_or_league = "league"
      @tournament.season = @league.season
      @tournament.league = @league
    else
      @tournament.single_or_league = "single"
    end
    if @tournament.save
      redirect_to @tournament, notice: "Tournament was successfully created."
    else
      redirect_back(fallback_location: tournaments_path)
    end
  end

  # PATCH/PUT /tournaments/1
  def update
    @tournament.unprotected = true
    if @tournament.update(tournament_params)
      redirect_to @tournament, notice: "Tournament was successfully updated."
    else
      render :edit
    end
  rescue StandardError => e
    Rails.logger.info "#{e} #{e.backtrace.join("\n")}"
  end

  # DELETE /tournaments/1
  def destroy
    @tournament.destroy
    redirect_to tournaments_url, notice: "Tournament was successfully destroyed."
  end

  def define_participants
    @seedings = @tournament.seedings
    @league = @tournament.league
  end

  def new_team; end

  def add_team
    try do
      team_players = []
      (1..@tournament.team_size).each_with_index do |n, ix|
        next unless params["player_#{n}_ba_id"].present?

        player = Player.find_by_ba_id(params["player_#{n}_ba_id"])
        if player.present?
          team_players[ix] = player
        else
          redirect_to define_participants_tournament_path(@tournament),
                      alert: t("No Player with ba_id #{params["player_#{n}_ba_id"]}")
          return
        end
      end
      team_players.sort_by!(&:ba_id)
      team = Team.find_or_create_by!(tournament_id: @tournament.id, firstname: team_players[0].firstname,
                                     lastname: team_players[0].lastname)
      ary = team_players.map do |pl|
        {
          "firstname" => pl.firstname,
          "lastname" => pl.lastname,
          "player_id" => pl.id,
          "ba_id" => pl.ba_id
        }
      end
      team.deep_merge_data!("players" => ary)
      team.save!
      @tournament.reload
      redirect_to define_participants_tournament_path(@tournament)
    rescue StandardError => e
      Rails.logger.info "#{e} #{e.backtrace.join("\n")}"
    end
  end

  # GET /tournaments/:id/compare_seedings
  def compare_seedings
    @local_seedings = @tournament.seedings
                                 .where("seedings.id >= #{Seeding::MIN_ID}")
                                 .order(:position)
    @clubcloud_seedings = @tournament.seedings
                                     .where("seedings.id < #{Seeding::MIN_ID}")
                                     .order(:position)
  end

  # POST /tournaments/:id/upload_invitation
  def upload_invitation
    if params[:invitation_file].present?
      uploaded_file = params[:invitation_file]
      
      # Speichere temporär
      file_path = Rails.root.join('tmp', "invitation_#{@tournament.id}#{File.extname(uploaded_file.original_filename)}")
      File.open(file_path, 'wb') do |file|
        file.write(uploaded_file.read)
      end
      
      # Speichere Pfad im Tournament (mit unprotected für global records)
      @tournament.unprotected = true
      @tournament.data = @tournament.data.merge({
        'invitation_file_path' => file_path.to_s,
        'invitation_filename' => uploaded_file.original_filename
      })
      @tournament.save!
      @tournament.unprotected = false
      
      # Automatisch parsen
      redirect_to parse_invitation_tournament_path(@tournament)
    else
      flash[:alert] = "Bitte wählen Sie eine Datei aus"
      redirect_to compare_seedings_tournament_path(@tournament)
    end
  end

  # GET /tournaments/:id/parse_invitation
  def parse_invitation
    file_path = @tournament.data['invitation_file_path']
    
    if file_path.blank? || !File.exist?(file_path)
      flash[:alert] = "Keine Einladung hochgeladen"
      redirect_to compare_seedings_tournament_path(@tournament) and return
    end
    
    # Extrahiere Setzliste
    @extraction_result = SeedingListExtractor.extract_from_file(file_path)
    
    if @extraction_result[:success]
      # Matched mit Datenbank
      @match_result = SeedingListExtractor.match_with_database(
        @extraction_result[:players],
        @tournament
      )
      
      # Speichere extrahierte Daten
      data_updates = {}
      data_updates['extracted_group_assignment'] = @extraction_result[:group_assignment] if @extraction_result[:group_assignment].present?
      data_updates['extracted_plan_info'] = @extraction_result[:plan_info] if @extraction_result[:plan_info].present?
      
      if data_updates.any?
        @tournament.unprotected = true
        @tournament.data = @tournament.data.merge(data_updates)
        @tournament.save!
        @tournament.unprotected = false
      end
    end
    
    # Zeige Ergebnis
    render :parse_invitation
  end

  # POST /tournaments/:id/recalculate_groups
  # Option C: Verwirft extrahierte Gruppenbildung und berechnet neu
  def recalculate_groups
    @tournament.unprotected = true
    @tournament.data = @tournament.data.except('extracted_group_assignment')
    @tournament.save!
    @tournament.unprotected = false
    
    redirect_to finalize_modus_tournament_path(@tournament),
                notice: "✅ Gruppenbildung neu berechnet (NBV-Algorithmus)"
  end

  # POST /tournaments/:id/add_player_by_dbu
  def add_player_by_dbu
    dbu_nr = params[:dbu_nr]
    
    if dbu_nr.blank?
      redirect_to define_participants_tournament_path(@tournament),
                  alert: "Bitte DBU-Nummer eingeben" and return
    end
    
    # Suche Spieler anhand DBU-Nummer
    player = Player.find_by(dbu_nr: dbu_nr)
    
    unless player
      redirect_to define_participants_tournament_path(@tournament),
                  alert: "❌ Kein Spieler mit DBU-Nummer #{dbu_nr} gefunden" and return
    end
    
    # Prüfe ob Spieler bereits in der Teilnehmerliste ist
    seeding_scope = @tournament.seedings.where("seedings.id >= #{Seeding::MIN_ID}").count > 0 ? 
                      "seedings.id >= #{Seeding::MIN_ID}" : 
                      "seedings.id < #{Seeding::MIN_ID}"
    
    existing_seeding = @tournament.seedings.where(seeding_scope).where(player_id: player.id).first
    
    if existing_seeding
      redirect_to define_participants_tournament_path(@tournament),
                  notice: "ℹ️ #{player.fullname} ist bereits in der Liste (Position #{existing_seeding.position})" and return
    end
    
    # Füge Spieler ans Ende der Setzliste hinzu
    max_position = @tournament.seedings.where(seeding_scope).maximum(:position) || 0
    
    @tournament.seedings.create!(
      player_id: player.id,
      position: max_position + 1
    )
    
    redirect_to define_participants_tournament_path(@tournament),
                notice: "✅ #{player.fullname} (DBU #{dbu_nr}) als Nachmelder hinzugefügt (Position #{max_position + 1})"
  end

  # POST /tournaments/:id/apply_seeding_order
  def apply_seeding_order
    seeding_order = params[:seeding_order] # Array von Player IDs in Reihenfolge
    balls_goal_hash = params[:balls_goal] || {} # Hash mit player_id => balls_goal
    
    if seeding_order.present?
      # Erstelle oder aktualisiere lokale Seedings in der neuen Reihenfolge
      Seeding.transaction do
        # Lösche alte lokale Seedings
        @tournament.seedings.where("seedings.id >= #{Seeding::MIN_ID}").destroy_all
        
        # Erstelle neue in der richtigen Reihenfolge (inkl. Vorgaben)
        seeding_order.each_with_index do |player_id, index|
          @tournament.seedings.create!(
            player_id: player_id,
            position: index + 1,
            balls_goal: balls_goal_hash[player_id.to_s]&.to_i
          )
        end
      end
      
      # Info-Message: Mit/ohne Vorgaben
      has_handicaps = balls_goal_hash.values.any?(&:present?)
      notice_text = if has_handicaps
                      "✅ Setzliste mit Vorgaben übernommen (#{seeding_order.count} Spieler)"
                    else
                      "✅ Setzliste übernommen (#{seeding_order.count} Spieler)"
                    end
      
      redirect_to tournament_path(@tournament), notice: notice_text
    else
      redirect_to compare_seedings_tournament_path(@tournament),
                  alert: "Keine Reihenfolge ausgewählt"
    end
  end

  private

  # Konvertiert Positions-basierte Gruppenbildung zu Player-IDs
  # Input: { 1 => [1, 5, 9], 2 => [2, 6, 10], ... } (Positionen)
  # Output: { "group1" => [player_id1, player_id5, ...], ... }
  def convert_position_groups_to_player_groups(position_groups, tournament)
    # Verwende @seeding_scope wenn verfügbar, sonst intelligente Erkennung
    scope = @seeding_scope || begin
      has_local = tournament.seedings.where("seedings.id >= #{Seeding::MIN_ID}").any?
      has_local ? "seedings.id >= #{Seeding::MIN_ID}" : "seedings.id < #{Seeding::MIN_ID}"
    end
    
    seedings = tournament.seedings
                         .where.not(state: "no_show")
                         .where(scope)
                         .order(:position)
                         .to_a
    
    player_groups = {}
    position_groups.each do |group_no, positions|
      player_groups["group#{group_no}"] = positions.map do |pos|
        seedings[pos - 1]&.player_id  # Position 1 = Index 0
      end.compact
    end
    
    player_groups
  end
  
  # Vergleicht zwei Gruppenbildungen (als Hash mit Player-IDs)
  # Returns true wenn identisch, false wenn unterschiedlich
  def groups_identical?(groups_a, groups_b)
    return false if groups_a.nil? || groups_b.nil?
    return false if groups_a.keys.sort != groups_b.keys.sort
    
    groups_a.keys.all? do |group_key|
      # Vergleiche als Sets (Reihenfolge egal innerhalb der Gruppe)
      groups_a[group_key].sort == groups_b[group_key].sort
    end
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_tournament
    @tournament = Tournament.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def tournament_params
    params.require(:tournament).permit(:title, :discipline_id, :modus, :age_restriction, :date, :accredation_end,
                                       :location_text, :location_id, :ba_id, :season_id, :region_id, :end_date, :plan_or_show,
                                       :single_or_league, :shortname, :data, :ba_state, :state, :last_ba_sync_date,
                                       :player_class, :tournament_plan_id, :innings_goal, :timeouts, :timeout, :balls_goal,
                                       :handicap_tournier, :league_id, :organizer_id, :organizer_type, :manual_assignment, :continuous_placements,
                                       :sets_to_win, :sets_to_play, :team_size, :kickoff_switches_with, :fixed_display_left,
                                       :color_remains_with_set, :allow_overflow, :allow_follow_up)
  end
end
