class TournamentPlanGamesController < ApplicationController
  before_action :set_tournament_plan_game, only: [:show, :edit, :update, :destroy]

  # GET /tournament_plan_games
  def index
    @pagy, @tournament_plan_games = pagy(TournamentPlanGame.sort_by_params(params[:sort], sort_direction))

    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @tournament_plan_games.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @tournament_plan_games.load
  end

  # GET /tournament_plan_games/1
  def show
  end

  # GET /tournament_plan_games/new
  def new
    @tournament_plan_game = TournamentPlanGame.new
  end

  # GET /tournament_plan_games/1/edit
  def edit
  end

  # POST /tournament_plan_games
  def create
    @tournament_plan_game = TournamentPlanGame.new(tournament_plan_game_params)

    if @tournament_plan_game.save
      redirect_to @tournament_plan_game, notice: "Tournament plan game was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /tournament_plan_games/1
  def update
    if @tournament_plan_game.update(tournament_plan_game_params)
      redirect_to @tournament_plan_game, notice: "Tournament plan game was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /tournament_plan_games/1
  def destroy
    @tournament_plan_game.destroy
    redirect_to tournament_plan_games_url, notice: "Tournament plan game was successfully destroyed."
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_tournament_plan_game
    @tournament_plan_game = TournamentPlanGame.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def tournament_plan_game_params
    params.require(:tournament_plan_game).permit(:name, :tournament_plan_id, :data)
  end
end
