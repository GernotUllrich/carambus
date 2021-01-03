class TTournamentsController < ApplicationController
  before_action :set_t_tournament, only: [:show, :edit, :update, :destroy]

  # GET /t_tournaments
  def index
    @pagy, @t_tournaments = pagy(TTournament.sort_by_params(params[:sort], sort_direction))

    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @t_tournaments.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @t_tournaments.load
  end

  # GET /t_tournaments/1
  def show
  end

  # GET /t_tournaments/new
  def new
    @t_tournament = TTournament.new
  end

  # GET /t_tournaments/1/edit
  def edit
  end

  # POST /t_tournaments
  def create
    @t_tournament = TTournament.new(t_tournament_params)

    if @t_tournament.save
      redirect_to @t_tournament, notice: "T tournament was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /t_tournaments/1
  def update
    if @t_tournament.update(t_tournament_params)
      redirect_to @t_tournament, notice: "T tournament was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /t_tournaments/1
  def destroy
    @t_tournament.destroy
    redirect_to t_tournaments_url, notice: "T tournament was successfully destroyed."
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_t_tournament
    @t_tournament = TTournament.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def t_tournament_params
    params.fetch(:t_tournament, {})
  end
end
