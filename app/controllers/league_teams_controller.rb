class LeagueTeamsController < ApplicationController
  include FiltersHelper
  protect_from_forgery except: :search
  before_action :set_league_team, only: [:show, :edit, :update, :destroy]

  # GET /league_teams
  def index
    @league_teams = LeagueTeam.joins(:league).sort_by_params(params[:sort], sort_direction)
    if @sSearch.present?
      @league_teams = apply_filters(@league_teams, LeagueTeam::COLUMN_NAMES, "(league_teams.name ilike :search) or (league_teams.shortname ilike :search) or (leagues.name ilike :search)")
    end
    @pagy, @league_teams = pagy(@league_teams)
    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @league_teams.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @league_teams.load
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

  # GET /league_teams/1
  def show
    @parties = Party.where(id: @league_team.parties_a.ids + @league_team.parties_b.ids)
  end

  # GET /league_teams/new
  def new
    @league_team = LeagueTeam.new
  end

  # GET /league_teams/1/edit
  def edit
  end

  # POST /league_teams
  def create
    @league_team = LeagueTeam.new(league_team_params)

    if @league_team.save
      redirect_to @league_team, notice: "League team was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /league_teams/1
  def update
    if @league_team.update(league_team_params)
      redirect_to @league_team, notice: "League team was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /league_teams/1
  def destroy
    @league_team.destroy
    redirect_to league_teams_url, notice: "League team was successfully destroyed."
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_league_team
    @league_team = LeagueTeam.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def league_team_params
    params.require(:league_team).permit(:name, :shortname, :league_id, :ba_id, :club_id)
  end
end
