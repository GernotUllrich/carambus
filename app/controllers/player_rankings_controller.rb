class PlayerRankingsController < ApplicationController
  include FiltersHelper
  before_action :admin_only_check, except: %i[show index]
  before_action :set_player_ranking, only: %i[show edit update destroy]

  # GET /player_rankings
  def index
    results = SearchService.call( PlayerRanking.search_hash(params) )
    @pagy, @player_rankings = pagy(results)
    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @player_rankings.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @player_rankings.load
    respond_to do |format|
      format.html do
        if params[:table_only].present?
          params.reject! { |k, _v| k.to_s == "table_only" }
          render(partial: "search", layout: false)
        else
          render("index")
        end
      end
    end
  end

  # GET /player_rankings/1
  def show; end

  # GET /player_rankings/new
  def new
    @player_ranking = PlayerRanking.new
  end

  # GET /player_rankings/1/edit
  def edit; end

  # POST /player_rankings
  def create
    @player_ranking = PlayerRanking.new(player_ranking_params)

    if @player_ranking.save
      redirect_to @player_ranking, notice: "Player ranking was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /player_rankings/1
  def update
    if @player_ranking.update(player_ranking_params)
      redirect_to @player_ranking, notice: "Player ranking was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /player_rankings/1
  def destroy
    @player_ranking.destroy
    redirect_to player_rankings_url, notice: "Player ranking was successfully destroyed."
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_player_ranking
    @player_ranking = PlayerRanking.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def player_ranking_params
    params.require(:player_ranking).permit(:player_id, :region_id, :season_id, :org_level, :discipline_id, :status,
                                           :points, :gd, :hs, :bed, :btg, :player_class_id, :p_player_class_id, :pp_player_class_id, :p_gd, :pp_gd, :tournament_player_class_id, :rank, :remarks, :g, :v, :quote, :sp_g, :sp_v, :sp_quote, :balls, :sets, :t_ids)
  end
end
