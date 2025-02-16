class TournamentSeriesCcsController < ApplicationController
  before_action :set_tournament_series_cc, only: %i[show edit update destroy]

  # GET /tournament_series_ccs
  def index
    @pagy, @tournament_series_ccs = pagy(TournamentSeriesCc.sort_by_params(params[:sort], sort_direction))

    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @tournament_series_ccs.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @tournament_series_ccs.load
  end

  # GET /tournament_series_ccs/1
  def show; end

  # GET /tournament_series_ccs/new
  def new
    @tournament_series_cc = TournamentSeriesCc.new
  end

  # GET /tournament_series_ccs/1/edit
  def edit; end

  # POST /tournament_series_ccs
  def create
    @tournament_series_cc = TournamentSeriesCc.new(tournament_series_cc_params)

    if @tournament_series_cc.save
      redirect_to @tournament_series_cc, notice: "Tournament series cc was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /tournament_series_ccs/1
  def update
    if @tournament_series_cc.update(tournament_series_cc_params)
      redirect_to @tournament_series_cc, notice: "Tournament series cc was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /tournament_series_ccs/1
  def destroy
    @tournament_series_cc.destroy
    redirect_to tournament_series_ccs_url, notice: "Tournament series cc was successfully destroyed."
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_tournament_series_cc
    @tournament_series_cc = TournamentSeriesCc.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def tournament_series_cc_params
    params.require(:tournament_series_cc).permit(:cc_id, :name, :branch_cc_id, :season, :valuation, :series_valuation,
                                                 :no_tournaments, :point_formula, :min_points, :point_fraction, :price_money, :currency, :club_id, :show_jackpot, :jackpot, :status, :data)
  end
end
