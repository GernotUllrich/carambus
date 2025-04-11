class PlayersController < ApplicationController
  include FiltersHelper
  before_action :admin_only_check, except: %i[show index]
  before_action :set_player, only: %i[show edit update destroy]

  # GET /players
  def index
    results = SearchService.call(Player.search_hash(params))
    @pagy, @players = pagy(results)
    @players = @players.includes(season_participations: { club: :region })
    respond_to do |format|
      format.html do
        render("index")
      end
    end
  end

  # GET /players/1
  def show; end

  # GET /players/new
  def new
    @player = Player.new
  end

  # GET /players/1/edit
  def edit; end

  # POST /players
  def create
    @player = Player.new(player_params)

    if @player.save
      @club = Club[params[:club_id]]
      @location = Location[params[:location_id]]
      @season = Season[params[:season_id]]
      if @club.present? && @season.present? && params[:from] == "new_guest"
        @club.season_participations.create(player: @player, season: @season, status: "guest")
        redirect_back_or_to(location_path(@location))
        return
      end
      redirect_to @player, notice: "Player was successfully created."
    else
      @location = Location[params[:location_id]]
      if params[:from] == "new_guest" && @location.present?
        redirect_back_or_to(location_path(@location))
        nil
      else
        render :new
      end
    end
  end

  # PATCH/PUT /players/1
  def update
    if @player.update(player_params)
      redirect_to @player, notice: "Player was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /players/1
  def destroy
    @player.destroy
    redirect_to players_url, notice: "Player was successfully destroyed."
  end

  def merge
    if params[:merge].present? && params[:with].present?
      merge_player = Player.find(params[:merge])
      with_players = Player.where(id: params[:with].split(",").map(&:strip).map(&:to_i)).to_a
      Player.merge_players(merge_player, with_players)
    end
    redirect_to players_path
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_player
    @player = Player.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def player_params
    params.require(:player).permit(:ba_id, :cc_id, :club_id, :guest, :lastname, :firstname, :nickname, :title)
  end
end
