class SeasonParticipationsController < ApplicationController
  before_action :set_season_participation, only: [:show, :edit, :update, :destroy]

  # GET /season_participations
  # GET /season_participations.json
  def index
    @season_participations = SeasonParticipation.page(params[:page]).per(24)
    respond_to do |format|
      format.html
      format.json { render json: SeasonParticipationsDatatable.new(view_context, nil) }
    end
  end

  # GET /season_participations/1
  # GET /season_participations/1.json
  def show
  end

  # GET /season_participations/new
  def new
    @season_participation = SeasonParticipation.new
  end

  # GET /season_participations/1/edit
  def edit
  end

  # POST /season_participations
  # POST /season_participations.json
  def create
    @season_participation = SeasonParticipation.new(season_participation_params)

    respond_to do |format|
      if @season_participation.save
        format.html { redirect_to @season_participation, notice: 'Season participation was successfully created.' }
        format.json { render :show, status: :created, location: @season_participation }
      else
        format.html { render :new }
        format.json { render json: @season_participation.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /season_participations/1
  # PATCH/PUT /season_participations/1.json
  def update
    respond_to do |format|
      if @season_participation.update(season_participation_params)
        format.html { redirect_to @season_participation, notice: 'Season participation was successfully updated.' }
        format.json { render :show, status: :ok, location: @season_participation }
      else
        format.html { render :edit }
        format.json { render json: @season_participation.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /season_participations/1
  # DELETE /season_participations/1.json
  def destroy
    @season_participation.destroy
    respond_to do |format|
      format.html { redirect_to season_participations_url, notice: 'Season participation was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_season_participation
      @season_participation = SeasonParticipation.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def season_participation_params
      params.require(:season_participation).permit(:player_id, :season_id, :remarks)
    end
end
