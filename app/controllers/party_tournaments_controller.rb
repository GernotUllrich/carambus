class PartyTournamentsController < ApplicationController
  before_action :admin_only_check, except: [:show, :index]
  before_action :set_party_tournament, only: [:show, :edit, :update, :destroy]

  # GET /party_tournaments
  def index
    @pagy, @party_tournaments = pagy(PartyTournament.sort_by_params(params[:sort], sort_direction))

    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @party_tournaments.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @party_tournaments.load
  end

  # GET /party_tournaments/1
  def show
  end

  # GET /party_tournaments/new
  def new
    @party_tournament = PartyTournament.new
  end

  # GET /party_tournaments/1/edit
  def edit
  end

  # POST /party_tournaments
  def create
    @party_tournament = PartyTournament.new(party_tournament_params)

    if @party_tournament.save
      redirect_to @party_tournament, notice: "Party tournament was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /party_tournaments/1
  def update
    if @party_tournament.update(party_tournament_params)
      redirect_to @party_tournament, notice: "Party tournament was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /party_tournaments/1
  def destroy
    @party_tournament.destroy
    redirect_to party_tournaments_url, notice: "Party tournament was successfully destroyed."
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_party_tournament
    @party_tournament = PartyTournament.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def party_tournament_params
    params.require(:party_tournament).permit(:party_id, :tournament_id, :position)
  end
end
