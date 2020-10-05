class PlayerTournamentParticipationsController < ApplicationController
  before_action :set_player_tournament_participation, only: [:show, :edit, :update, :destroy]

  # GET /player_tournament_participations
  # GET /player_tournament_participations.json
  def index
    @player_tournament_participations = PlayerTournamentParticipation.all
  end

  # GET /player_tournament_participations/1
  # GET /player_tournament_participations/1.json
  def show
  end

  # GET /player_tournament_participations/new
  def new
    @player_tournament_participation = PlayerTournamentParticipation.new
  end

  # GET /player_tournament_participations/1/edit
  def edit
  end

  # POST /player_tournament_participations
  # POST /player_tournament_participations.json
  def create
    @player_tournament_participation = PlayerTournamentParticipation.new(player_tournament_participation_params)

    respond_to do |format|
      if @player_tournament_participation.save
        format.html { redirect_to @player_tournament_participation, notice: 'Player tournament participation was successfully created.' }
        format.json { render :show, status: :created, location: @player_tournament_participation }
      else
        format.html { render :new }
        format.json { render json: @player_tournament_participation.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /player_tournament_participations/1
  # PATCH/PUT /player_tournament_participations/1.json
  def update
    respond_to do |format|
      if @player_tournament_participation.update(player_tournament_participation_params)
        format.html { redirect_to @player_tournament_participation, notice: 'Player tournament participation was successfully updated.' }
        format.json { render :show, status: :ok, location: @player_tournament_participation }
      else
        format.html { render :edit }
        format.json { render json: @player_tournament_participation.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /player_tournament_participations/1
  # DELETE /player_tournament_participations/1.json
  def destroy
    @player_tournament_participation.destroy
    respond_to do |format|
      format.html { redirect_to player_tournament_participations_url, notice: 'Player tournament participation was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_player_tournament_participation
      @player_tournament_participation = PlayerTournamentParticipation.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def player_tournament_participation_params
      params.require(:player_tournament_participation).permit(:player_id, :tournament_id, :data)
    end
end
