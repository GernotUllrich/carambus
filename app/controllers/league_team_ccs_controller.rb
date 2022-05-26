class LeagueTeamCcsController < ApplicationController
  before_action :admin_only_check, except: [:show, :index]
  include FiltersHelper
  protect_from_forgery except: :search
  before_action :set_league_team_cc, only: [:show, :edit, :update, :destroy]

  # GET /league_team_ccs
  def index
    @league_team_ccs = LeagueTeamCc.joins(:league_team).joins(:league_cc => {:season_cc => { :competition_cc => :branch_cc }}).sort_by_params(params[:sort], sort_direction)
    if @sSearch.present?
      @league_team_ccs_no_query = @league_team_ccs
      @league_team_ccs = apply_filters(@league_team_ccs, Club::COLUMN_NAMES, "(season_ccs.name ilike :search) or (league_ccs.cc_id = :isearch) or (league_team_ccs.cc_id = :isearch) or (league_team_ccs.shortname ilike :search) or (league_team_ccs.name ilike :search) or (league_teams.shortname ilike :search) or (league_teams.name ilike :search) or (league_ccs.name ilike :search) or (branch_ccs.name ilike :search)")
      @league_team_ccs = @league_team_ccs_no_query if @league_team_ccs.count == 0
    end
    @pagy, @league_team_ccs = pagy(@league_team_ccs)
    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @league_team_ccs.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @league_team_ccs.load
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

  # GET /league_team_ccs/1
  def show
    @party_ccs = PartyCc.where(id: @league_team_cc.party_a_ccs.ids + @league_team_cc.party_b_ccs.ids)
  end

  # GET /league_team_ccs/new
  def new
    @league_team_cc = LeagueTeamCc.new
  end

  # GET /league_team_ccs/1/edit
  def edit
  end

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
