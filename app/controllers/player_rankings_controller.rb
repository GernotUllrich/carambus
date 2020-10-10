class PlayerRankingsController < ApplicationController
  before_action :set_player_ranking, only: [:show, :edit, :update, :destroy]

  # GET /player_rankings
  # GET /player_rankings.json
  def index
    @player_rankings = PlayerRanking.page(params[:page]).per(24)
    respond_to do |format|
      format.html
      format.json { render json: PlayerRankingsDatatable.new(view_context, nil) }
    end
  end

  # GET /player_rankings/1
  # GET /player_rankings/1.json
  def show
  end

  # GET /player_rankings/new
  def new
    @player_ranking = PlayerRanking.new
  end

  # GET /player_rankings/1/edit
  def edit
  end

  # POST /player_rankings
  # POST /player_rankings.json
  def create
    @player_ranking = PlayerRanking.new(player_ranking_params)

    respond_to do |format|
      if @player_ranking.save
        format.html { redirect_to @player_ranking, notice: 'Player ranking was successfully created.' }
        format.json { render :show, status: :created, location: @player_ranking }
      else
        format.html { render :new }
        format.json { render json: @player_ranking.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /player_rankings/1
  # PATCH/PUT /player_rankings/1.json
  def update
    respond_to do |format|
      if @player_ranking.update(player_ranking_params)
        format.html { redirect_to @player_ranking, notice: 'Player ranking was successfully updated.' }
        format.json { render :show, status: :ok, location: @player_ranking }
      else
        format.html { render :edit }
        format.json { render json: @player_ranking.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /player_rankings/1
  # DELETE /player_rankings/1.json
  def destroy
    @player_ranking.destroy
    respond_to do |format|
      format.html { redirect_to player_rankings_url, notice: 'Player ranking was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_player_ranking
      @player_ranking = PlayerRanking.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def player_ranking_params
      params.require(:player_ranking).permit(:player_id, :region_id, :player_ranking_id, :season_id, :org_level, :discipline_id, :status, :points, :innings, :gd, :hs, :bed, :btg, :player_class_id, :p_player_class_id, :pp_player_class_id, :p_gd, :pp_gd, :tournament_player_class_id, :rank)
    end
end
