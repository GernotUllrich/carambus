class LeagueTeamsController < ApplicationController
  before_action :set_league_team, only: [:show, :edit, :update, :destroy]

  # GET /league_teams
  def index
    @pagy, @league_teams = pagy(LeagueTeam.sort_by_params(params[:sort], sort_direction))

    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @league_teams.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @league_teams.load
  end

  # GET /league_teams/1
  def show
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
