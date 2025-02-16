class SeasonsController < ApplicationController
  before_action :admin_only_check, except: %i[show index]
  before_action :set_season, only: %i[show edit update destroy]

  # GET /seasons
  def index
    @pagy, @seasons = pagy(Season.sort_by_params(params[:sort], sort_direction))

    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @seasons.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @seasons.load
  end

  # GET /seasons/1
  def show; end

  # GET /seasons/new
  def new
    @season = Season.new
  end

  # GET /seasons/1/edit
  def edit; end

  # POST /seasons
  def create
    @season = Season.new(season_params)

    if @season.save
      redirect_to @season, notice: "Season was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /seasons/1
  def update
    if @season.update(season_params)
      redirect_to @season, notice: "Season was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /seasons/1
  def destroy
    @season.destroy
    redirect_to seasons_url, notice: "Season was successfully destroyed."
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_season
    @season = Season.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def season_params
    params.require(:season).permit(:ba_id, :name, :data)
  end
end
