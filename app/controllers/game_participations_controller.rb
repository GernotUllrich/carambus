class GameParticipationsController < ApplicationController
  before_action :admin_only_check, except: %i[show index]
  before_action :set_game_participation, only: %i[show edit update destroy]

  # GET /game_participations
  def index
    @pagy, @game_participations = pagy(GameParticipation.sort_by_params(params[:sort], sort_direction))

    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @game_participations.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @game_participations.load
  end

  # GET /game_participations/1
  def show; end

  # GET /game_participations/new
  def new
    @game_participation = GameParticipation.new
  end

  # GET /game_participations/1/edit
  def edit; end

  # POST /game_participations
  def create
    @game_participation = GameParticipation.new(game_participation_params)

    if @game_participation.save
      redirect_to @game_participation, notice: "Game participation was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /game_participations/1
  def update
    if @game_participation.update(game_participation_params)
      redirect_to @game_participation, notice: "Game participation was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /game_participations/1
  def destroy
    @game_participation.destroy
    redirect_to game_participations_url, notice: "Game participation was successfully destroyed."
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_game_participation
    @game_participation = GameParticipation.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def game_participation_params
    params.require(:game_participation).permit(:game_id, :player_id, :role, :data, :points, :result, :innings, :gd,
                                               :hs, :game)
  end
end
