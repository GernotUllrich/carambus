class TournamentsController < ApplicationController
  include FiltersHelper
  before_action :set_tournament, only: [:show, :edit, :update, :destroy, :order_by_ranking, :edit_games, :reload_from_ba, :switch_players, :finalize_modus, :select_modus, :tournament_monitor, :reset, :start]

  # GET /tournaments
  def index
    @tournaments = Tournament.joins(:region, :season, :discipline).sort_by_params(params[:sort], sort_direction)
    if params[:sSearch].present?
      @tournaments = apply_filters(@tournaments, Tournament::COLUMN_NAMES, "(tournaments.ba_id = :isearch) or (tournaments.title ilike :search) or (tournaments.shortname ilike :search) or (regions.name ilike :search) or (seasons.name ilike :search) or (tournaments.plan_or_show ilike :search) or (tournaments.single_or_league ilike :search)")
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
      @tournament.forced_reset_tournament_monitor!
    elsif !@tournament.tournament_started
      @tournament.reset_tournament_monitor!
    else
      flash[:alert] = "Cannot reset running or finished tournament"
    end
    redirect_to tournament_path(@tournament)
  end

  def order_by_ranking
    hash = {}
    @tournament.seedings.where("seedings.id >= #{Seeding::MIN_ID}").destroy_all
    @tournament.seedings.create(
      @tournament.seedings.where("seedings.id < #{Seeding::MIN_ID}").map{|s| {player_id: s.player_id}}
    )
    @tournament.seedings.where("seedings.id >= #{Seeding::MIN_ID}").each do |seeding|
      hash[seeding] = seeding.player.player_rankings.where(discipline_id: Discipline.find_by_name("Freie Partie klein"), season_id: Season.find_by_ba_id(Season.current_season.ba_id - 1)).first.andand.rank.presence || 999
    end
    sorted = hash.to_a.sort_by do |a|
      a[1]
    end
    sorted.each_with_index do |a, ix|
      seeding, rank = a
      seeding.update_attributes(position: ix + 1)
    end

    @tournament.finish_seeding!
    @tournament.reload
    redirect_to tournament_path(@tournament)
    return
  end

  def reload_from_ba
    @tournament.scrape_single_tournament(game_details: true)
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
      where(players: @tournament.seedings.where("seedings.id >= #{Seeding::MIN_ID}").all.count).uniq
  end

  def select_modus
    begin
      @tournament.update_attributes(tournament_plan_id: TournamentPlan.find_by_id(params[:tournament_plan_id]).id)
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

  def start
    data_ = @tournament.data
    data_[:table_ids] = params[:table_id]
    @tournament.update_attributes(data: data_)
    if @tournament.valid?
      @tournament.initialize_tournament_monitor
      @tournament.reload
      @tournament.start_tournament!
      @tournament.reload
      @tournament.tournament_monitor.update_attributes(current_admin: current_user)
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
    @tournament = Tournament.new(tournament_params.merge(organizer: @organizer))

    if @tournament.save
      redirect_to @tournament, notice: "Tournament was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /tournaments/1
  def update
    begin
      if @tournament.update(tournament_params.merge(organizer: @organizer))
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

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_tournament
    @tournament = Tournament.find(params[:id])
    if params[:tournament].andand[:organizer_gid].present?
      organizer_gid = params[:tournament].delete(:organizer_gid)
      @organizer = GlobalID::Locator.locate(organizer_gid)
      params[:organizer] = @organizer if organizer_gid.present?
    end
  end

  # Only allow a trusted parameter "white list" through.
  def tournament_params
    params.require(:tournament).permit(:title, :discipline_id, :modus, :age_restriction, :date, :accredation_end, :location, :location_id, :ba_id, :season_id, :region_id, :end_date, :plan_or_show, :single_or_league, :shortname, :data, :ba_state, :state, :last_ba_sync_date, :player_class, :tournament_plan_id, :innings_goal, :balls_goal, :handicap_tournier)
  end
end
