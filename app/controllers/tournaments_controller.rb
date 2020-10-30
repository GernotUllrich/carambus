class TournamentsController < ApplicationController
  before_action :set_tournament, only: [:show, :edit, :update, :destroy, :order_by_ranking, :edit_games, :reload_from_ba, :switch_players, :finalize_modus, :select_modus, :tournament_monitor, :reset, :start]

  # GET /tournaments
  # GET /tournaments.json
  def index
    @tournaments = Tournament.page(params[:page]).per(24)
    respond_to do |format|
      format.html
      format.json { render json: TournamentsDatatable.new(view_context, nil) }
    end
  end

  # GET /tournaments/1
  # GET /tournaments/1.json
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
    @tournament.seedings.each do |seeding|
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
            players: @tournament.seedings.all.count,
            player_class: @tournament.player_class,
            discipline_id: @tournament.discipline_id
        }).first
    @groups = TournamentMonitor.distribute_to_group(@tournament.seedings.order(:position).map(&:player), @proposed_discipline_tournament_plan.ngroups) if @proposed_discipline_tournament_plan.present?
    @alternatives_same_discipline = ::TournamentPlan.joins(:discipline_tournament_plans => :discipline).
        where.not(tournament_plans: {id: @proposed_discipline_tournament_plan.andand.id}).
        where(discipline_tournament_plans: {
            players: @tournament.seedings.all.count,
            discipline_id: @tournament.discipline_id
        }).uniq
    @alternatives_other_disciplines = ::TournamentPlan.
        where.not(tournament_plans: {id: [@proposed_discipline_tournament_plan.andand.id] + @alternatives_same_discipline.map(&:id)}).
        where(players: @tournament.seedings.all.count).uniq
  end

  def select_modus
    @tournament.update_attributes(tournament_plan_id: TournamentPlan.find_by_id(params[:tournament_plan_id]).id)
    @tournament.finish_mode_selection!
    @tournament.reload

    redirect_to tournament_monitor_tournament_path(@tournament)
  end

  def tournament_monitor
    if @tournament.tournament_monitor.present?
      redirect_to tournament_monitor_path(@tournament.tournament_monitor)
    end
  end

  def start
    @tournament.initialize_tournament_monitor
    @tournament.reload
    @tournament.start_tournament!
    @tournament.reload
    redirect_to tournament_monitor_path(@tournament.tournament_monitor)
  end

  # GET /tournaments/new
  def new
    @tournament = Tournament.new
  end

  # GET /tournaments/1/edit
  def edit
  end

  # POST /tournaments
  # POST /tournaments.json
  def create
    @tournament = Tournament.new(tournament_params)

    respond_to do |format|
      if @tournament.save
        format.html { redirect_to @tournament, notice: 'Tournament was successfully created.' }
        format.json { render :show, status: :created, location: @tournament }
      else
        format.html { render :new }
        format.json { render json: @tournament.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /tournaments/1
  # PATCH/PUT /tournaments/1.json
  def update
    respond_to do |format|
      if @tournament.update(tournament_params)
        format.html { redirect_to @tournament, notice: 'Tournament was successfully updated.' }
        format.json { render :show, status: :ok, location: @tournament }
      else
        format.html { render :edit }
        format.json { render json: @tournament.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /tournaments/1
  # DELETE /tournaments/1.json
  def destroy
    @tournament.destroy
    respond_to do |format|
      format.html { redirect_to tournaments_url, notice: 'Tournament was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_tournament
    @tournament = Tournament.find(params[:id])
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def tournament_params
    params.require(:tournament).permit(:title, :reagion_id, :discipline_id, :season_id, :shortname, :discipline_id, :modus, :age_restriction, :date, :player_class, :tournament_plan_id, :accredation_end, :location, :hosting_tournament_id)
  end
end
