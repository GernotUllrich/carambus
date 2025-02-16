class SeasonCcsController < ApplicationController
  before_action :admin_only_check, except: %i[show index]
  before_action :set_season_cc, only: %i[show edit update destroy]

  # GET /season_ccs
  def index
    @pagy, @season_ccs = pagy(SeasonCc.sort_by_params(params[:sort], sort_direction))

    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @season_ccs.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @season_ccs.load
  end

  # GET /season_ccs/1
  def show
    @league_ccs = @season_cc.league_ccs
  end

  # GET /season_ccs/new
  def new
    @season_cc = SeasonCc.new
  end

  # GET /season_ccs/1/edit
  def edit; end

  # POST /season_ccs
  def create
    @season_cc = SeasonCc.new(season_cc_params)

    if @season_cc.save
      redirect_to @season_cc, notice: "Season cc was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /season_ccs/1
  def update
    if @season_cc.update(season_cc_params)
      redirect_to @season_cc, notice: "Season cc was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /season_ccs/1
  def destroy
    @season_cc.destroy
    redirect_to season_ccs_url, notice: "Season cc was successfully destroyed."
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_season_cc
    @season_cc = SeasonCc.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def season_cc_params
    params.require(:season_cc).permit(:cc_id, :name, :season_id, :competition_cc_id, :context)
  end
end
