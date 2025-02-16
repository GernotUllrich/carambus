class LeagueCcsController < ApplicationController
  before_action :admin_only_check, except: %i[show index]
  before_action :set_league_cc, only: %i[show edit update destroy]

  # GET /league_ccs
  def index
    @pagy, @league_ccs = pagy(LeagueCc.sort_by_params(params[:sort], sort_direction))

    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @league_ccs.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @league_ccs.load
  end

  # GET /league_ccs/1
  def show
    @league_team_ccs = @league_cc.league_team_ccs
    @party_ccs = @league_cc.party_ccs
  end

  # GET /league_ccs/new
  def new
    @league_cc = LeagueCc.new
  end

  # GET /league_ccs/1/edit
  def edit; end

  # POST /league_ccs
  def create
    @league_cc = LeagueCc.new(league_cc_params)

    if @league_cc.save
      redirect_to @league_cc, notice: "League cc was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /league_ccs/1
  def update
    if @league_cc.update(league_cc_params)
      redirect_to @league_cc, notice: "League cc was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /league_ccs/1
  def destroy
    @league_cc.destroy
    redirect_to league_ccs_url, notice: "League cc was successfully destroyed."
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_league_cc
    @league_cc = LeagueCc.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def league_cc_params
    params.require(:league_cc).permit(:cc_id, :name, :season_cc_id, :context)
  end
end
