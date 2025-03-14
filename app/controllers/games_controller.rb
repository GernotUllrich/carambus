class GamesController < ApplicationController
  before_action :admin_only_check, except: %i[show index]
  before_action :set_game, only: %i[show edit update destroy]

  # GET /games
  def index
    results = SearchService.call( Game.search_hash(params) )
    @pagy, @games = pagy(results)
    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @clubs.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @games.load
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
  rescue StandardError => e
    Rails.logger.error "ERROR: #{e}\n#{e.backtrace.join("\n")}"
    render("index")
  end

  # GET /games/1
  def show; end

  # GET /games/new
  def new
    @game = Game.new
  end

  # GET /games/1/edit
  def edit; end

  # POST /games
  def create
    @game = Game.new(game_params)

    if @game.save
      redirect_to @game, notice: "Game was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /games/1
  def update
    if @game.update(game_params)
      redirect_to @game, notice: "Game was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /games/1
  def destroy
    @game.destroy
    redirect_to games_url, notice: "Game was successfully destroyed."
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_game
    @game = Game.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def game_params
    params.require(:game).permit(:tournament_id, :roles, :data, :seqno, :gname, :group_no, :table_no, :round_no,
                                 :started_at, :ended_at)
  end
end
