class PlayersController < ApplicationController
  include FiltersHelper
  before_action :set_player, only: [:show, :edit, :update, :destroy]

  # GET /players
  def index
    @players = Player.joins(:club => :region).sort_by_params(params[:sort], sort_direction)
    if params[:sSearch].present?
      @players = apply_filters(@players, Player::COLUMN_NAMES, "(players.firstname ilike :search) or (players.lastname ilike :search) or (regions.shortname ilike :search) or (clubs.shortname ilike :search)")
    end
    @pagy, @players = pagy(@players)
    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @players.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @players.load
    respond_to do |format|
      format.html {
        if params[:table_only].present?
          params.reject!{|k,v| k.to_s == "table_only"}
          render(partial: "search", :layout => false)
        else
          render("index")
        end }
    end
  end

  # GET /players/1
  def show
  end

  # GET /players/new
  def new
    @player = Player.new
  end

  # GET /players/1/edit
  def edit
  end

  # POST /players
  def create
    @player = Player.new(player_params)

    if @player.save
      redirect_to @player, notice: "Player was successfully created."
    else
      render :new
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

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_player
    @player = Player.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def player_params
    params.require(:player).permit(:ba_id, :club_id, :lastname, :firstname, :title)
  end
end
