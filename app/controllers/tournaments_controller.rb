# frozen_string_literal: true

class TournamentsController < ApplicationController
  include FiltersHelper

  before_action :set_tournament,
                only: %i[show edit update destroy order_by_ranking_or_handicap finish_seeding edit_games reload_from_cc new_team
                         finalize_modus select_modus tournament_monitor reset start define_participants add_team placement
                         upload_invitation parse_invitation apply_seeding_order compare_seedings add_player_by_dbu
                         use_clubcloud_as_participants update_seeding_position
                         recalculate_groups test_tournament_status_update]
  before_action :ensure_rankings_cached, only: %i[show]
  before_action :load_clubcloud_seedings, only: %i[show]
  before_action :ensure_local_server, only: %i[new create edit update destroy order_by_ranking_or_handicap
                                               finish_seeding edit_games new_team
                                               finalize_modus select_modus reset start define_participants add_team
                                               upload_invitation parse_invitation apply_seeding_order compare_seedings
                                               add_player_by_dbu use_clubcloud_as_participants update_seeding_position
                                               recalculate_groups]

  # GET /tournaments
  def index
    # Default sort by date descending if no sort specified
    search_params = params.dup
    search_params[:sort] ||= "date"
    search_params[:direction] ||= "asc"

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

  def test_tournament_status_update
    TournamentStatusUpdateJob.perform_now(@tournament)
    flash[:notice] = "Test-Update wurde gesendet - prüfen Sie die Browser-Console und Rails-Logs"
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
      # Berechne Rankings explizit (falls after_enter callback nicht funktioniert hat)
      @tournament.calculate_and_cache_rankings if @tournament.data["player_rankings"].blank?
    else
      flash[:alert] = t("not_allowed_on_api_server")
    end
    redirect_to tournament_path(@tournament)
    nil
  end

  def reload_from_cc
    # Unterscheide zwischen Setup-Phase und Ergebnis-Phase
    reload_games = params[:reload_games] == "true"

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
      @seeding_scope = if has_local_seedings
                         "seedings.id >= #{Seeding::MIN_ID}"
                       else
                         "seedings.id < #{Seeding::MIN_ID}"
                       end

      @participant_count = @tournament.seedings
                                      .where.not(state: "no_show")
                                      .where(@seeding_scope)
                                      .count

      # Versuche TournamentPlan anhand extrahierter Info zu finden (z.B. "T21", aber NICHT T0/T00)
      @proposed_discipline_tournament_plan = nil
      # Extrahiere Plan-Name (z.B. "T21" aus "T21 - 3 Gruppen à 3, 4 und 4 Spieler")
      if @tournament.data["extracted_plan_info"].present? && (match = @tournament.data["extracted_plan_info"].match(/^(T\d+)/i))
        plan_name = match[1].upcase
        # Ignoriere T0, T00, T000 etc. (Turnier findet nicht statt)
        unless plan_name.match?(/^T0+$/)
          @proposed_discipline_tournament_plan = ::TournamentPlan.where(name: plan_name).first
          Rails.logger.info "===== finalize_modus ===== Extracted plan name: #{plan_name}, found: #{@proposed_discipline_tournament_plan.present?}"
        else
          Rails.logger.info "===== finalize_modus ===== Extracted plan name #{plan_name} (T0 variant) ignored"
        end
      end

      # Fallback: Suche nach Spielerzahl + Disziplin (aber NICHT T0/T00/T000)
      unless @proposed_discipline_tournament_plan.present?
        @proposed_discipline_tournament_plan = ::TournamentPlan.joins(discipline_tournament_plans: :discipline)
                                                               .where(discipline_tournament_plans: {
                                                                        players: @participant_count,
                                                                        player_class: @tournament.player_class,
                                                                        discipline_id: @tournament.discipline_id
                                                                      })
                                                               .where.not(name: ['T0', 'T00', 'T000'])
                                                               .first
      end
      if @proposed_discipline_tournament_plan.present?
        # Berechne IMMER die NBV-Standard-Gruppenbildung (MIT Gruppengrößen aus executor_params!)
        @nbv_groups = TournamentMonitor.distribute_to_group(
          @tournament.seedings.where.not(state: "no_show").where(@seeding_scope).order(:position).map(&:player),
          @proposed_discipline_tournament_plan.ngroups,
          @proposed_discipline_tournament_plan.group_sizes # NEU: Gruppengrößen aus executor_params
        )

        # Wenn extrahierte Gruppenbildung vorhanden: vergleiche
        if @tournament.data["extracted_group_assignment"].present?
          @extracted_groups = convert_position_groups_to_player_groups(
            @tournament.data["extracted_group_assignment"],
            @tournament
          )

          # Vergleiche die beiden Gruppenbildungen
          @groups_match = groups_identical?(@extracted_groups, @nbv_groups)

          @groups = @extracted_groups
          if @groups_match
            # Identisch: Verwende extrahierte (aber eigentlich egal)
            @groups_source = :extracted_matches_nbv
            Rails.logger.info "===== finalize_modus ===== Extrahierte Gruppenbildung ist identisch mit NBV-Algorithmus ✓"
          else
            # Abweichung: Verwende extrahierte, aber zeige Warnung
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
                                                      .where.not(tournament_plans: { id: @proposed_discipline_tournament_plan&.id })
                                                      .where(discipline_tournament_plans: {
                                                               players: @participant_count,
                                                               discipline_id: @tournament.discipline_id
                                                             }).uniq
      @alternatives_other_disciplines = ::TournamentPlan
                                        .where.not(tournament_plans: { id: [@proposed_discipline_tournament_plan&.id] + @alternatives_same_discipline.map(&:id) })
                                        .where(players: @participant_count).uniq.to_a
      @default_plan = TournamentPlan.default_plan(@participant_count)
      @ko_plan = TournamentPlan.ko_plan(@participant_count)
      @alternatives_other_disciplines |= [@default_plan]
      @alternatives_other_disciplines |= [@ko_plan]
      # REMOVED: @groups wird bereits oben korrekt gesetzt (Zeile 189, 194 oder 200)
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
    # Validiere ClubCloud-Zugriff falls konfiguriert
    if @tournament.tournament_cc.present?
      begin
        Rails.logger.info "[TournamentsController#start] Validating ClubCloud access..."
        Setting.ensure_logged_in
        flash[:notice] = "ClubCloud-Zugriff validiert ✓"
      rescue StandardError => e
        flash[:alert] = "ClubCloud-Login fehlgeschlagen: #{e.message}. Bitte prüfen Sie die ClubCloud-Zugangsdaten."
        redirect_to tournament_path(@tournament)
        return
      end
    end

    data_ = @tournament.data
    data_["table_ids"] = params[:table_id]
    data_["balls_goal"] = params[:balls_goal].to_i
    data_["innings_goal"] = params[:innings_goal].to_i
    data_["timeout"] = params[:timeout].to_i
    data_["timeouts"] = params[:timeouts].to_i
    data_["sets_to_play"] = params[:sets_to_play].to_i
    data_["sets_to_win"] = params[:sets_to_win].to_i
    data_["time_out_warm_up_first_min"] = params[:time_out_warm_up_first_min].to_i
    data_["time_out_warm_up_follow_up_min"] = params[:time_out_warm_up_follow_up_min].to_i
    data_["kickoff_switches_with"] = params[:kickoff_switches_with]
    data_["fixed_display_left"] = params[:fixed_display_left].to_s
    data_["color_remains_with_set"] = params[:color_remains_with_set]
    data_["allow_overflow"] = params[:allow_overflow]
    data_["allow_follow_up"] = params[:allow_follow_up]
    data_["auto_upload_to_cc"] = params[:auto_upload_to_cc]
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
        innings_goal_value = (params[:innings_goal].presence || @tournament.innings_goal).to_i
        balls_goal_value = (params[:balls_goal].presence || @tournament.balls_goal).to_i
        
        Rails.logger.info "===== CONTROLLER START DEBUG ====="
        Rails.logger.info "params[:innings_goal]: #{params[:innings_goal].inspect}"
        Rails.logger.info "innings_goal_value: #{innings_goal_value.inspect}"
        Rails.logger.info "balls_goal_value: #{balls_goal_value.inspect}"
        Rails.logger.info "BEFORE update: tournament_monitor.innings_goal = #{@tournament.tournament_monitor.innings_goal.inspect}"
        
        update_result = @tournament.tournament_monitor.update(current_admin: current_user,
                                              timeout: (params[:timeout].presence || 0).to_i,
                                              timeouts: (params[:timeouts].presence || @tournament.timeouts).to_i,
                                              innings_goal: innings_goal_value,
                                              balls_goal: balls_goal_value,
                                              sets_to_play: (params[:sets_to_play].presence || @tournament.sets_to_play).to_i,
                                              sets_to_win: (params[:sets_to_win].presence || @tournament.sets_to_win).to_i,
                                              kickoff_switches_with: params[:kickoff_switches_with].presence || @tournament.kickoff_switches_with,
                                              color_remains_with_set: params.key?(:color_remains_with_set) ? (params[:color_remains_with_set] == "1") : @tournament.color_remains_with_set,
                                              allow_overflow: params.key?(:allow_overflow) ? (params[:allow_overflow] == "1") : @tournament.allow_overflow,
                                              allow_follow_up: params.key?(:allow_follow_up) ? (params[:allow_follow_up] == "1") : @tournament.allow_follow_up,
                                              fixed_display_left: params[:fixed_display_left].to_s.presence || @tournament.fixed_display_left)
        
        Rails.logger.info "update_result: #{update_result.inspect}"
        Rails.logger.info "AFTER update: tournament_monitor.innings_goal = #{@tournament.tournament_monitor.reload.innings_goal.inspect}"
        Rails.logger.info "===== CONTROLLER START DEBUG END ====="
        
        # CRITICAL: Aktualisiere ALLE TableMonitors mit den aktuellen TournamentMonitor-Parametern
        # Dies muss NACH dem tournament_monitor.update passieren, damit die Werte korrekt sind!
        # Beim erneuten Start werden existierende Spiele einfach wieder auf "warmup" gesetzt,
        # OHNE dass do_placement/initialize_game aufgerufen wird!
        tm = @tournament.tournament_monitor
        Rails.logger.info "===== UPDATING TableMonitors ====="
        Rails.logger.info "TournamentMonitor[#{tm.id}]: innings_goal=#{tm.innings_goal}, balls_goal=#{tm.balls_goal}, handicap_tournier=#{@tournament.handicap_tournier?}"
        tm.table_monitors.each do |table_mon|
          Rails.logger.info "Updating TableMonitor[#{table_mon.id}] with innings_goal=#{tm.innings_goal}"
          
          # Bei Handicap-Turnieren: balls_goal NICHT überschreiben (wurde in do_placement individuell gesetzt)
          # Bei normalen Turnieren: balls_goal einheitlich für beide Spieler setzen
          update_data = {
            "innings_goal" => tm.innings_goal
          }
          
          unless @tournament.handicap_tournier?
            # Nur bei NICHT-Handicap-Turnieren die balls_goal überschreiben
            update_data["playera"] = { "balls_goal" => tm.balls_goal }
            update_data["playerb"] = { "balls_goal" => tm.balls_goal }
            Rails.logger.info "  Setting balls_goal=#{tm.balls_goal} for both players (normal tournament)"
          else
            Rails.logger.info "  Keeping individual balls_goal values (handicap tournament): playera=#{table_mon.data.dig('playera', 'balls_goal')}, playerb=#{table_mon.data.dig('playerb', 'balls_goal')}"
          end
          
          table_mon.deep_merge_data!(update_data)
          table_mon.save!
          Rails.logger.info "TableMonitor[#{table_mon.id}] updated: innings_goal=#{table_mon.data['innings_goal']}, playera_balls_goal=#{table_mon.data.dig('playera', 'balls_goal')}, playerb_balls_goal=#{table_mon.data.dig('playerb', 'balls_goal')}"
        end
        Rails.logger.info "===== TableMonitors UPDATED ====="
        
        # Broadcast individual teaser updates für tournament_scores view
        # (tournament_scores view hat nur #teaser_X frames, kein #table_scores container)
        Rails.logger.info "===== Broadcasting teasers for all table monitors ====="
        tm.table_monitors.each do |table_mon|
          TableMonitorJob.perform_later(table_mon.id, "teaser") if table_mon.game.present?
        end
      end
      if @tournament.tournament_started_waiting_for_monitors?
        redirect_to tournament_monitor_path(@tournament.tournament_monitor)
      else
        redirect_back_or_to(tournament_path(@tournament))
      end
    else
      flash[:alert] = @tournament.errors.full_messages
      redirect_back_or_to(tournament_path(@tournament))
    end
    nil
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

    # Berechne mögliche Turnierpläne und Gruppenzuordnungen (wie in finalize_modus)
    @tournament.seedings.where(player_id: nil).destroy_all

    # Intelligentes Zählen: Wenn lokale Seedings existieren, nur diese zählen
    has_local_seedings = @tournament.seedings.where("seedings.id >= #{Seeding::MIN_ID}").any?
    @seeding_scope = if has_local_seedings
                       "seedings.id >= #{Seeding::MIN_ID}"
                     else
                       "seedings.id < #{Seeding::MIN_ID}"
                     end

    @participant_count = @tournament.seedings
                                    .where.not(state: "no_show")
                                    .where(@seeding_scope)
                                    .count

    # Versuche TournamentPlan anhand extrahierter Info zu finden (z.B. "T21", aber NICHT T0/T00)
    @proposed_discipline_tournament_plan = nil
    # Extrahiere Plan-Name (z.B. "T21" aus "T21 - 3 Gruppen à 3, 4 und 4 Spieler")
    if @tournament.data["extracted_plan_info"].present? && (match = @tournament.data["extracted_plan_info"].match(/^(T\d+)/i))
      plan_name = match[1].upcase
      # Ignoriere T0, T00, T000 etc. (Turnier findet nicht statt)
      @proposed_discipline_tournament_plan = ::TournamentPlan.where(name: plan_name).first unless plan_name.match?(/^T0+$/)
    end

    # Fallback: Suche nach Spielerzahl + Disziplin (aber NICHT T0/T00/T000)
    unless @proposed_discipline_tournament_plan.present?
      # Erst mit player_class versuchen
      @proposed_discipline_tournament_plan = ::TournamentPlan.joins(discipline_tournament_plans: :discipline)
                                                             .where(discipline_tournament_plans: {
                                                                      players: @participant_count,
                                                                      player_class: @tournament.player_class,
                                                                      discipline_id: @tournament.discipline_id
                                                                    })
                                                             .where.not(name: ['T0', 'T00', 'T000'])
                                                             .first

      # Fallback ohne player_class (wenn keiner gefunden wurde)
      unless @proposed_discipline_tournament_plan.present?
        @proposed_discipline_tournament_plan = ::TournamentPlan.joins(discipline_tournament_plans: :discipline)
                                                               .where(discipline_tournament_plans: {
                                                                        players: @participant_count,
                                                                        discipline_id: @tournament.discipline_id
                                                                      })
                                                               .where.not(name: ['T0', 'T00', 'T000'])
                                                               .first
      end
    end

    if @proposed_discipline_tournament_plan.present?
      # Berechne IMMER die NBV-Standard-Gruppenbildung
      @nbv_groups = TournamentMonitor.distribute_to_group(
        @tournament.seedings.where.not(state: "no_show").where(@seeding_scope).order(:position).map(&:player),
        @proposed_discipline_tournament_plan.ngroups,
        @proposed_discipline_tournament_plan.group_sizes
      )

      # Wenn extrahierte Gruppenbildung vorhanden: vergleiche
      if @tournament.data["extracted_group_assignment"].present?
        @extracted_groups = convert_position_groups_to_player_groups(
          @tournament.data["extracted_group_assignment"],
          @tournament
        )

        @groups_match = groups_identical?(@extracted_groups, @nbv_groups)
        @groups = @extracted_groups
        @groups_source = @groups_match ? :extracted_matches_nbv : :extracted_differs_from_nbv
      else
        # Keine Extraktion: Verwende NBV
        @groups = @nbv_groups
        @groups_source = :algorithm
      end
    end

    # Alternative Pläne (gleiche Disziplin, maximal 3)
    @alternatives_same_discipline = ::TournamentPlan.joins(discipline_tournament_plans: :discipline)
                                                    .where.not(tournament_plans: { id: @proposed_discipline_tournament_plan&.id })
                                                    .where(discipline_tournament_plans: {
                                                             players: @participant_count,
                                                             discipline_id: @tournament.discipline_id
                                                           }).limit(3).to_a.uniq

    # Weitere alternative Pläne (andere Disziplinen, OHNE Default- und KO-Pläne)
    @alternatives_other_disciplines = ::TournamentPlan
                                      .where.not(tournament_plans: { id: [@proposed_discipline_tournament_plan&.id] + @alternatives_same_discipline.map(&:id) })
                                      .where(players: @participant_count)
                                      .where.not("name LIKE 'Default%'")  # Keine Default-Pläne
                                      .where.not("name LIKE 'KO%'")       # Keine KO-Pläne
                                      .to_a.uniq

    # Entferne bereits vorhandene Pläne
    @alternatives_other_disciplines -= [@proposed_discipline_tournament_plan] + @alternatives_same_discipline
  end

  def new_team; end

  def add_team
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
      file_path = Rails.root.join("tmp", "invitation_#{@tournament.id}#{File.extname(uploaded_file.original_filename)}")
      File.binwrite(file_path, uploaded_file.read)

      # Speichere Pfad im Tournament (mit unprotected für global records)
      @tournament.unprotected = true
      @tournament.data = @tournament.data.merge({
                                                  "invitation_file_path" => file_path.to_s,
                                                  "invitation_filename" => uploaded_file.original_filename
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
    file_path = @tournament.data["invitation_file_path"]

    if file_path.blank? || !File.exist?(file_path)
      flash[:alert] = "Keine Einladung hochgeladen"
      redirect_to compare_seedings_tournament_path(@tournament)
      return
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
      if @extraction_result[:group_assignment].present?
        data_updates["extracted_group_assignment"] =
          @extraction_result[:group_assignment]
      end
      data_updates["extracted_plan_info"] = @extraction_result[:plan_info] if @extraction_result[:plan_info].present?

      # Speichere extrahierte Turnier-Parameter
      if @extraction_result[:extracted_params].present?
        if @extraction_result[:extracted_params][:balls_goal].present?
          data_updates["extracted_balls_goal"] =
            @extraction_result[:extracted_params][:balls_goal]
        end
        if @extraction_result[:extracted_params][:innings_goal].present?
          data_updates["extracted_innings_goal"] =
            @extraction_result[:extracted_params][:innings_goal]
        end
      end

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
    @tournament.data = @tournament.data.except("extracted_group_assignment")
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
                  alert: "Bitte DBU-Nummer eingeben"
      return
    end

    # Suche Spieler anhand DBU-Nummer
    player = Player.find_by(dbu_nr: dbu_nr)

    unless player
      redirect_to define_participants_tournament_path(@tournament),
                  alert: "❌ Kein Spieler mit DBU-Nummer #{dbu_nr} gefunden"
      return
    end

    # Prüfe ob Spieler bereits in der Teilnehmerliste ist
    seeding_scope = if @tournament.seedings.where("seedings.id >= #{Seeding::MIN_ID}").any?
                      "seedings.id >= #{Seeding::MIN_ID}"
                    else
                      "seedings.id < #{Seeding::MIN_ID}"
                    end

    existing_seeding = @tournament.seedings.where(seeding_scope).where(player_id: player.id).first

    if existing_seeding
      redirect_to define_participants_tournament_path(@tournament),
                  notice: "ℹ️ #{player.fullname} ist bereits in der Liste (Position #{existing_seeding.position})"
      return
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

      # Leite zu Schritt 3 weiter (Teilnehmerliste bearbeiten)
      redirect_to define_participants_tournament_path(@tournament), notice: notice_text
    else
      redirect_to compare_seedings_tournament_path(@tournament),
                  alert: "Keine Reihenfolge ausgewählt"
    end
  end

  # POST /tournaments/:id/use_clubcloud_as_participants
  # Konvertiert ClubCloud-Seedings zu lokalen Seedings, sortiert nach Rangliste und leitet zu Schritt 3 weiter
  def use_clubcloud_as_participants
    clubcloud_seedings = @tournament.seedings
                                    .where("seedings.id < #{Seeding::MIN_ID}")
                                    .order(:position)

    if clubcloud_seedings.any?
      # Konvertiere ClubCloud-Seedings zu lokalen Seedings
      Seeding.transaction do
        # Lösche alte lokale Seedings
        @tournament.seedings.where("seedings.id >= #{Seeding::MIN_ID}").destroy_all

        # Erstelle neue lokale Seedings (ohne Position, wird gleich sortiert)
        clubcloud_seedings.each do |cc_seeding|
          @tournament.seedings.create!(
            player_id: cc_seeding.player_id,
            balls_goal: cc_seeding.balls_goal
          )
        end
      end

      # Sortiere nach Rangliste (verwende effective_gd Logik)
      if local_server?
        # Berechne effektive Rankings (wie in calculate_and_cache_rankings)
        if @tournament.organizer.is_a?(Region) && @tournament.discipline.present?
          current_season = Season.current_season
          seasons = Season.where("id <= ?", current_season.id).order(id: :desc).limit(3).reverse

          all_rankings = PlayerRanking.where(
            discipline_id: @tournament.discipline_id,
            season_id: seasons.pluck(:id),
            region_id: @tournament.organizer_id
          ).to_a

          rankings_by_player = all_rankings.group_by(&:player_id)
          player_effective_gd = {}

          rankings_by_player.each do |player_id, rankings|
            gd_values = seasons.map do |season|
              ranking = rankings.find { |r| r.season_id == season.id }
              ranking&.gd
            end
            effective_gd = gd_values[2] || gd_values[1] || gd_values[0]
            player_effective_gd[player_id] = effective_gd if effective_gd.present?
          end

          sorted_players = player_effective_gd.sort_by { |_player_id, gd| -gd }
          player_rank = {}
          sorted_players.each_with_index do |(player_id, _gd), index|
            player_rank[player_id] = index + 1
          end
        else
          player_rank = {}
        end

        hash = {}
        @tournament.seedings.where("seedings.id >= #{Seeding::MIN_ID}").each do |seeding|
          if @tournament.handicap_tournier
            # Bei Handicap-Turnieren: Nach Vorgabe sortieren (höhere Vorgabe = schwächer = höhere Position)
            hash[seeding] = -seeding.balls_goal.to_i
          else
            # Normale Turniere: Nach effektivem Ranking sortieren
            hash[seeding] = if @tournament.team_size > 1
                              999
                            else
                              player_rank[seeding.player_id] || 999
                            end
          end
        end

        # Sortiere und setze Positionen
        sorted = hash.to_a.sort_by { |a| a[1] }
        sorted.each_with_index do |a, ix|
          seeding, = a
          seeding.update(position: ix + 1)
        end
      end

      redirect_to define_participants_tournament_path(@tournament),
                  notice: "✅ Meldeliste übernommen und nach Rangliste sortiert (#{clubcloud_seedings.count} Spieler)"
    elsif @tournament.seedings.any?
      # Falls keine ClubCloud-Seedings, aber andere Seedings existieren
      # Überspringe die Konvertierung und gehe direkt zu Schritt 3
      redirect_to define_participants_tournament_path(@tournament),
                  notice: "✅ Weiter zu Schritt 3 mit vorhandenen Seedings (#{@tournament.seedings.count} Spieler)"
    else
      redirect_to compare_seedings_tournament_path(@tournament),
                  alert: "Keine Spieler verfügbar. Bitte zuerst Meldeliste laden (Schritt 1)."
    end
  end

  # POST /tournaments/:id/update_seeding_position
  # Aktualisiert die Position eines Seedings (für Drag & Drop oder Up/Down)
  def update_seeding_position
    seeding_id = params[:seeding_id]
    new_position = params[:position].to_i

    if seeding_id.present? && new_position.positive?
      seeding = @tournament.seedings.find(seeding_id)

      # Verwende acts_as_list move_to_position wenn verfügbar
      if seeding.respond_to?(:move_to_position)
        seeding.move_to_position(new_position)
      else
        # Fallback: Manuelles Verschieben
        old_position = seeding.position
        if old_position != new_position
          Seeding.transaction do
            # Verschiebe andere Seedings
            if old_position < new_position
              # Nach unten verschoben
              @tournament.seedings
                         .where("seedings.id >= #{Seeding::MIN_ID}")
                         .where("position > ? AND position <= ?", old_position, new_position)
                         .update_all("position = position - 1")
            else
              # Nach oben verschoben
              @tournament.seedings
                         .where("seedings.id >= #{Seeding::MIN_ID}")
                         .where("position >= ? AND position < ?", new_position, old_position)
                         .update_all("position = position + 1")
            end
            # Setze neue Position
            seeding.update_column(:position, new_position)
          end
        end
      end

      head :ok
    else
      head :bad_request
    end
  end

  private

  # Stellt sicher dass Rankings gecacht sind (für alte lokale Turniere)
  def ensure_rankings_cached
    return unless @tournament
    return unless @tournament.id.present? && @tournament.id >= Tournament::MIN_ID # Nur für lokale Tournaments
    return if @tournament.data["player_rankings"].present?

    # Berechne Rankings wenn Seedings vorhanden sind (auch wenn State noch nicht korrekt)
    return unless @tournament.seedings.any?

    Rails.logger.info "[ensure_rankings_cached] Calculating rankings for tournament #{@tournament.id}"
    @tournament.calculate_and_cache_rankings
  end

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
        seedings[pos - 1]&.player_id # Position 1 = Index 0
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

  def load_clubcloud_seedings
    @clubcloud_seedings = @tournament.seedings
                                    .where("seedings.id < ?", Seeding::MIN_ID)
                                    .order(:position)
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

  # Stellt sicher, dass Turniermanagement nur auf lokalen Servern möglich ist
  # API Server dient nur zum Lesen und als Datenquelle
  # Auch auf lokalen Servern: Wenn ClubCloud-Ergebnisse vorliegen, ist das Turnier schreibgeschützt
  def ensure_local_server
    unless local_server?
      flash[:alert] =
        "⚠️ Turniermanagement ist nur auf lokalen Servern möglich. Der API Server dient ausschließlich als zentrale Datenquelle."
      redirect_to tournaments_path
      return
    end

    # Auch auf lokalen Servern: Prüfe ob ClubCloud-Ergebnisse vorliegen
    return unless @tournament&.has_clubcloud_results?

    # Sysadmin darf mit reload_games=true auch geschlossene Turniere neu laden
    if action_name == 'reload_from_cc' && params[:reload_games] == 'true' && current_user&.privileged_access?
      return
    end

    flash[:alert] =
      "⚠️ Dieses Turnier hat bereits Ergebnisse aus der ClubCloud und ist schreibgeschützt. Die ClubCloud ist die führende Datenquelle für abgeschlossene Turniere."
    redirect_to tournament_path(@tournament)
  end
end
