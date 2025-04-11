class LeagueTeamCcsController < ApplicationController
  include FiltersHelper
  # TODO: callback needed?:  protect_from_forgery except: :search
  before_action :admin_only_check, except: %i[show index]
  before_action :set_league_team_cc, only: %i[show edit update destroy]

  # GET /league_team_ccs
  def index
    results = SearchService.call( LeagueTeamCc.search_hash(params) )
    @pagy, @league_team_ccs = pagy(results)
    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @league_team_ccs.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @league_team_ccs.load
    respond_to do |format|
      format.html do
        render("index")
      end
    end
  end

  # GET /league_team_ccs/1
  def show
    @party_ccs = PartyCc.where(id: @league_team_cc.party_a_ccs.ids + @league_team_cc.party_b_ccs.ids)
  end

  # GET /league_team_ccs/new
  def new
    @league_team_cc = LeagueTeamCc.new
  end

  # GET /league_team_ccs/1/edit
  def edit; end

  # POST /league_team_ccs
  def create
    @league_team_cc = LeagueTeamCc.new(league_team_cc_params)

    if @league_team_cc.save
      redirect_to @league_team_cc, notice: "League team cc was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /league_team_ccs/1
  def update
    if @league_team_cc.update(league_team_cc_params)
      redirect_to @league_team_cc, notice: "League team cc was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /league_team_ccs/1
  def destroy
    @league_team_cc.destroy
    redirect_to league_team_ccs_url, notice: "League team cc was successfully destroyed."
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_league_team_cc
    @league_team_cc = LeagueTeamCc.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def league_team_cc_params
    params.require(:league_team_cc).permit(:cc_id, :name, :shortname, :league_cc_id, :league_team_id, :data)
  end
end
