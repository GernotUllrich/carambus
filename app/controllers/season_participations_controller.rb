class SeasonParticipationsController < ApplicationController

  include FiltersHelper
  before_action :set_season_participation, only: [:show, :edit, :update, :destroy]

  # GET /clubs
  def index
    @season_participations = SeasonParticipation.joins(:season, :player, :club).sort_by_params(params[:sort], sort_direction)
    if params[:sSearch].present?
      @season_participations = apply_filters(@season_participations, SeasonParticipation::COLUMN_NAMES, "(players.lastname ilike :search) or (players.firstname ilike :search) or (clubs.name ilike :search) or (clubs.shortname ilike :search) or (seasons.name ilike :search)")
    end
    @pagy, @season_participations = pagy(@season_participations)
    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @season_participations.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @season_participations.load
    respond_to do |format|
      format.html {
        if params[:table_only].present?
          params.reject!{|k,v| k.to_s == "table_only"}
          render(partial: "search", :layout => false)
        else
          render("index")
        end }
    end
  end


  # GET /season_participations/1
  def show
  end

  # GET /season_participations/new
  def new
    @season_participation = SeasonParticipation.new
  end

  # GET /season_participations/1/edit
  def edit
  end

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
