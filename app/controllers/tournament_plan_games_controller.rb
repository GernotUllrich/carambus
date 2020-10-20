class TournamentPlanGamesController < ApplicationController
  before_action :set_tournament_plan_game, only: [:show, :edit, :update, :destroy]

  # GET /tournament_plan_games
  # GET /tournament_plan_games.json
  def index
    @tournament_plan_games = TournamentPlanGame.all
  end

  # GET /tournament_plan_games/1
  # GET /tournament_plan_games/1.json
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
  # POST /tournament_plan_games.json
  def create
    @tournament_plan_game = TournamentPlanGame.new(tournament_plan_game_params)

    respond_to do |format|
      if @tournament_plan_game.save
        format.html { redirect_to @tournament_plan_game, notice: 'TournamentPlan game was successfully created.' }
        format.json { render :show, status: :created, location: @tournament_plan_game }
      else
        format.html { render :new }
        format.json { render json: @tournament_plan_game.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /tournament_plan_games/1
  # PATCH/PUT /tournament_plan_games/1.json
  def update
    respond_to do |format|
      if @tournament_plan_game.update(tournament_plan_game_params)
        format.html { redirect_to @tournament_plan_game, notice: 'TournamentPlan game was successfully updated.' }
        format.json { render :show, status: :ok, location: @tournament_plan_game }
      else
        format.html { render :edit }
        format.json { render json: @tournament_plan_game.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /tournament_plan_games/1
  # DELETE /tournament_plan_games/1.json
  def destroy
    @tournament_plan_game.destroy
    respond_to do |format|
      format.html { redirect_to tournament_plan_games_url, notice: 'TournamentPlan game was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_tournament_plan_game
      @tournament_plan_game = TournamentPlanGame.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def tournament_plan_game_params
      params.require(:tournament_plan_game).permit(:name, :tournament_plan_id, :remarks)
    end
end
