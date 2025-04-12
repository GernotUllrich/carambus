class SeasonParticipationsController < ApplicationController
  include FiltersHelper
  before_action :admin_only_check, except: %i[show index]
  before_action :set_season_participation, only: %i[show edit update destroy]

  # GET /clubs
  def index
    results = SearchService.call( SeasonParticipation.search_hash(params) )
    results = results.includes(:player, :season, :club)
    @pagy, @season_participations = pagy(results)
    @season_participations.load
    respond_to do |format|
      format.html do
        render("index")
      end
    end
  end

  # GET /season_participations/1
  def show; end

  # GET /season_participations/new
  def new
    @season_participation = SeasonParticipation.new
  end

  # GET /season_participations/1/edit
  def edit; end

  # POST /season_participations
  def create
    @season_participation = SeasonParticipation.new(season_participation_params)

    if @season_participation.save
      redirect_to @season_participation, notice: "Season participation was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /season_participations/1
  def update
    if @season_participation.update(season_participation_params)
      redirect_to @season_participation, notice: "Season participation was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /season_participations/1
  def destroy
    @season_participation.destroy
    redirect_to season_participations_url, notice: "Season participation was successfully destroyed."
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_season_participation
    @season_participation = SeasonParticipation.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def season_participation_params
    params.require(:season_participation).permit(:player_id, :season_id, :data, :club_id)
  end
end
