class TournamentsController < ApplicationController
  include FiltersHelper
  before_action :set_tournament, only: [:show, :edit, :update, :destroy, :order_by_ranking_or_handicap, :finish_seeding, :edit_games, :reload_from_ba, :switch_players, :finalize_modus, :select_modus, :tournament_monitor, :reset, :start, :define_participants, :placement]

  # GET /tournaments
  def index
    @tournaments = Tournament.joins(:season, :discipline).sort_by_params(@sSearch, sort_direction)
    if @sSearch.present?
      @tournaments = apply_filters(@tournaments, Tournament::COLUMN_NAMES, "(tournaments.ba_id = :isearch) or (tournaments.title ilike :search) or (tournaments.shortname ilike :search) or (seasons.name ilike :search) or (tournaments.plan_or_show ilike :search) or (tournaments.single_or_league ilike :search)")
    end
    @pagy, @tournaments = pagy(@tournaments)
    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @tournaments.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @tournaments.load
    respond_to do |format|
      format.html {
        if params[:table_only].present?
          params.reject! { |k, v| k.to_s == "table_only" }
          render(partial: "search", :layout => false)
        else
          render("index")
        end }
    end
  end

  # GET /tournaments/1
  def show
  end

  def edit_games
    @edit_games_modus = true
  end

  def reset
    if params[:force_reset].present?
      @tournament.tournament_monitor.destroy
      @tournament.forced_reset_tournament_monitor!
    elsif !@tournament.tournament_started
      @tournament.tournament_monitor.destroy
      @tournament.reset_tournament_monitor!
    else
      flash[:alert] = "Cannot reset running or finished tournament"
    end
    redirect_to tournament_path(@tournament)
  end

  def order_by_ranking_or_handicap
    hash = {}
    unless @tournament.organizer.is_a? Club
      #restore seedings from ba
      @tournament.seedings.where("seedings.id >= #{Seeding::MIN_ID}").destroy_all
      @tournament.seedings.create(
        @tournament.seedings.where("seedings.id < #{Seeding::MIN_ID}").map { |s| { player_id: s.player_id } }
      )
    end
    @tournament.seedings.where("seedings.id >= #{Seeding::MIN_ID}").each do |seeding|
      if @tournament.handicap_tournier
        hash[seeding] = -seeding.balls_goal.to_i
      else
        hash[seeding] = seeding.player.player_rankings.where(discipline_id: Discipline.find_by_name("Freie Partie klein"), season_id: Season.find_by_ba_id(Season.current_season.ba_id - 1)).first.andand.rank.presence || 999
      end
    end
    sorted = hash.to_a.sort_by do |a|
      a[1]
    end
    sorted.each_with_index do |a, ix|
      seeding, rank = a
      seeding.update(position: ix + 1)
    end

    #@tournament.finish_seeding!
    #@tournament.reload
    redirect_to tournament_path(@tournament)
    return
  end

  def finish_seeding
    @tournament.finish_seeding!
    @tournament.reload
    redirect_to tournament_path(@tournament)
  end

  def reload_from_ba
    Version.update_from_carambus_api(update_tournament_from_ba: @tournament.id)
    redirect_back(fallback_location: tournament_path(@tournament))
  end

  def finalize_modus
    @proposed_discipline_tournament_plan = ::TournamentPlan.joins(:discipline_tournament_plans => :discipline).
      where(discipline_tournament_plans: {
        players: @tournament.seedings.where("seedings.id >= #{Seeding::MIN_ID}").all.count,
        player_class: @tournament.player_class,
        discipline_id: @tournament.discipline_id
      }).first
    @groups = TournamentMonitor.distribute_to_group(@tournament.seedings.where("seedings.id >= #{Seeding::MIN_ID}").order(:position).map(&:player), @proposed_discipline_tournament_plan.ngroups) if @proposed_discipline_tournament_plan.present?
    @alternatives_same_discipline = ::TournamentPlan.joins(:discipline_tournament_plans => :discipline).
      where.not(tournament_plans: { id: @proposed_discipline_tournament_plan.andand.id }).
      where(discipline_tournament_plans: {
        players: @tournament.seedings.where("seedings.id >= #{Seeding::MIN_ID}").all.count,
        discipline_id: @tournament.discipline_id
      }).uniq
    @alternatives_other_disciplines = ::TournamentPlan.
      where.not(tournament_plans: { id: [@proposed_discipline_tournament_plan.andand.id] + @alternatives_same_discipline.map(&:id) }).
      where(players: @tournament.seedings.where("seedings.id >= #{Seeding::MIN_ID}").all.count).uniq.to_a
    @default_plan = TournamentPlan.default_plan(@tournament.seedings.where("seedings.id >= #{Seeding::MIN_ID}").count)
    @alternatives_other_disciplines |= [@default_plan]
    @groups = TournamentMonitor.distribute_to_group(@tournament.seedings.where("seedings.id >= #{Seeding::MIN_ID}").order(:position).map(&:player), @default_plan.ngroups)
  end

  def select_modus
    begin
      @tournament.update(tournament_plan_id: TournamentPlan.find_by_id(params[:tournament_plan_id]).id)
      @tournament.finish_mode_selection!
      @tournament.reload
    rescue Exception => e
      flash[:alert] = e.message
      redirect_back(fallback_location: tournament_path(@tournament))
      return
    end
    redirect_to tournament_monitor_tournament_path(@tournament)
  end

  def tournament_monitor
    if @tournament.tournament_monitor.present?
      redirect_to tournament_monitor_path(@tournament.tournament_monitor)
    end
  end

  def placement
    info = "+++ 4 - tournaments_controller#placement"; DebugInfo.instance.update(info: info); Rails.logger.info info
    @navbar = @footer = false
    @game = Game.find(params[:game_id])
    @table = Table.find(params[:table_id])
    @tournament_monitor = @tournament.tournament_monitor
    @table_monitor = TableMonitor.find_by_table_id(@table.id) || TableMonitor.create(table_id: @table.id)
    @table_monitor.update(tournament_monitor_id: @tournament_monitor.id)
    # if @table_monitor.game.present? && @game != @table_monitor.game
    #   info = "+++ 4b - tournaments_controller#placement"; DebugInfo.instance.update(info: info); Rails.logger.info info
    #   tmp_results = {}
    #   if @table_monitor.andand.data["ba_results"].present?
    #     info = "+++ 1 - tournaments_controller#placement"; DebugInfo.instance.update(info: info); Rails.logger.info info
    #     tmp_results["ba_results"] = @table_monitor.data["ba_results"].dup
    #     tmp_results["state"] = @table_monitor.state
    #     info = "+++ 2a - tournaments_controller#placement"; DebugInfo.instance.update(info: info); Rails.logger.info info
    #     @game.deep_merge_data!("tmp_results" => tmp_results)
    #     @table_monitor.update(state: "ready", game_id: nil, data: {})
    #   elsif @table_monitor.andand.data["current_inning"].present? && @table_monitor.data["playera"].present? && @table_monitor.data["playerb"].present?
    #
    #     info = "+++ 2 - tournaments_controller#placement"; DebugInfo.instance.update(info: info); Rails.logger.info info
    #     tmp_results["playera"] = @table_monitor.data["playera"].dup
    #     tmp_results["playerb"] = @table_monitor.data["playerb"].dup
    #     tmp_results["current_inning"] = @table_monitor.data["current_inning"].dup
    #     tmp_results["state"] = @table_monitor.state
    #     info = "+++ 2b - tournaments_controller#placement"; DebugInfo.instance.update(info: info); Rails.logger.info info
    #     @game.deep_merge_data!("tmp_results" => tmp_results)
    #     @table_monitor.update(state: "ready", game_id: nil, data: {})
    #   end
    # end
    # @table_monitor.update(name: "table#{@table.number}")
    # if @game.andand.data.andand["tmp_results"].present?
    #   info = "+++ 5 - tournaments_controller#placement"; DebugInfo.instance.update(info: info); Rails.logger.info info
    #   #Rails.logger.info "+++ 5 - tournaments_controller#placement"
    #   tmp_results = @game.data.delete("tmp_results")
    #   state = tmp_results.delete("state")
    #   @table_monitor.deep_merge_data!(tmp_results)
    #   @table_monitor.update(state: state, game_id: @game.id)
    # end
    # info = "+++ 3t2 - locations_controller#placement"; DebugInfo.instance.update(info: info); Rails.logger.info info
    Rails.logger.info "+++ 6 - tournaments_controller#placement"
      @tournament_monitor.do_placement(@game, @tournament_monitor.current_round, @tournament.t_no_from(@table))
    redirect_to table_monitor_path(@table_monitor)
  end

  def start
    data_ = @tournament.data
    data_[:table_ids] = params[:table_id]
    @tournament.update(data: data_)
    if @tournament.valid?
      @tournament.initialize_tournament_monitor
      @tournament.reload
      @tournament.start_tournament!
      @tournament.reload
      @tournament.tournament_monitor.update(current_admin: current_user)
      redirect_to tournament_monitor_path(@tournament.tournament_monitor)
    else
      flash[:alert] = @tournament.errors.full_messages
      redirect_back(fallback_location: tournament_path(@tournament))
    end
  end

  # GET /tournaments/new
  def new
    @tournament = Tournament.new
  end

  # GET /tournaments/1/edit
  def edit

  end

  # POST /tournaments
  def create
    @tournament = Tournament.new(tournament_params)

    if @tournament.save
      redirect_to @tournament, notice: "Tournament was successfully created."
    else
      redirect_to :back
    end
  end

  # PATCH/PUT /tournaments/1
  def update
    begin
      if @tournament.update(tournament_params)
        redirect_to @tournament, notice: "Tournament was successfully updated."
      else
        render :edit
      end
    rescue Exception => e
      Rails.logger.info "#{e} #{e.backtrace.join("\n")}"
    end
  end

  # DELETE /tournaments/1
  def destroy
    @tournament.destroy
    redirect_to tournaments_url, notice: "Tournament was successfully destroyed."
  end

  def define_participants
    @seedings = @tournament.seedings
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_tournament
    @tournament = Tournament.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def tournament_params
    params.require(:tournament).permit(:title, :discipline_id, :modus, :age_restriction, :date, :accredation_end, :location, :location_id, :ba_id, :season_id, :region_id, :end_date, :plan_or_show, :single_or_league, :shortname, :data, :ba_state, :state, :last_ba_sync_date, :player_class, :tournament_plan_id, :innings_goal, :balls_goal, :handicap_tournier, :organizer_id, :organizer_type, :manual_assignment)
  end
end
