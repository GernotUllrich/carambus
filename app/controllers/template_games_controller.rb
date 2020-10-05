class TemplateGamesController < ApplicationController
  before_action :set_template_game, only: [:show, :edit, :update, :destroy]

  # GET /template_games
  # GET /template_games.json
  def index
    @template_games = TemplateGame.all
  end

  # GET /template_games/1
  # GET /template_games/1.json
  def show
  end

  # GET /template_games/new
  def new
    @template_game = TemplateGame.new
  end

  # GET /template_games/1/edit
  def edit
  end

  # POST /template_games
  # POST /template_games.json
  def create
    @template_game = TemplateGame.new(template_game_params)

    respond_to do |format|
      if @template_game.save
        format.html { redirect_to @template_game, notice: 'Template game was successfully created.' }
        format.json { render :show, status: :created, location: @template_game }
      else
        format.html { render :new }
        format.json { render json: @template_game.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /template_games/1
  # PATCH/PUT /template_games/1.json
  def update
    respond_to do |format|
      if @template_game.update(template_game_params)
        format.html { redirect_to @template_game, notice: 'Template game was successfully updated.' }
        format.json { render :show, status: :ok, location: @template_game }
      else
        format.html { render :edit }
        format.json { render json: @template_game.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /template_games/1
  # DELETE /template_games/1.json
  def destroy
    @template_game.destroy
    respond_to do |format|
      format.html { redirect_to template_games_url, notice: 'Template game was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_template_game
      @template_game = TemplateGame.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def template_game_params
      params.require(:template_game).permit(:name, :template_id, :remarks)
    end
end
