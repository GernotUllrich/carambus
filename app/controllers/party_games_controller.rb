class PartyGamesController < ApplicationController
  include FiltersHelper
  # TODO: callback needed?:  protect_from_forgery except: :search
  before_action :admin_only_check, except: %i[show index]
  before_action :set_party_game, only: %i[show edit update destroy]

  # GET /party_games
  def index
    # Use SearchService for consistent filtering with SearchReflex
    search_params = { sSearch: @sSearch, sort: params[:sort], direction: sort_direction }
    results = SearchService.call(PartyGame.search_hash(search_params))
    @pagy, @party_games = pagy(results)
    
    # Include necessary associations to avoid N+1 queries
    # Note: organizer is polymorphic, so we can't eager load it directly
    @party_games = @party_games.includes(:party, :discipline, :player_a, :player_b, 
                                        party: { league: :season })

    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @party_games.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @party_games.load
  end

  # GET /party_games/1
  def show; end

  # GET /party_games/new
  def new
    @party_game = PartyGame.new
  end

  # GET /party_games/1/edit
  def edit; end

  # POST /party_games
  def create
    @party_game = PartyGame.new(party_game_params)

    if @party_game.save
      redirect_to @party_game, notice: "Party game was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /party_games/1
  def update
    if @party_game.update(party_game_params)
      redirect_to @party_game, notice: "Party game was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /party_games/1
  def destroy
    @party_game.destroy
    redirect_to party_games_url, notice: "Party game was successfully destroyed."
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_party_game
    @party_game = PartyGame.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def party_game_params
    params.require(:party_game).permit(:party_id, :seqno, :player_a_id, :player_b_id, :tournament_id)
  end
end
