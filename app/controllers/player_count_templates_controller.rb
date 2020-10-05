class PlayerCountTemplatesController < ApplicationController
  before_action :set_player_count_template, only: [:show, :edit, :update, :destroy]

  # GET /player_count_templates
  # GET /player_count_templates.json
  def index
    @player_count_templates = PlayerCountTemplate.all
  end

  # GET /player_count_templates/1
  # GET /player_count_templates/1.json
  def show
  end

  # GET /player_count_templates/new
  def new
    @player_count_template = PlayerCountTemplate.new
  end

  # GET /player_count_templates/1/edit
  def edit
  end

  # POST /player_count_templates
  # POST /player_count_templates.json
  def create
    @player_count_template = PlayerCountTemplate.new(player_count_template_params)

    respond_to do |format|
      if @player_count_template.save
        format.html { redirect_to @player_count_template, notice: 'Player count template was successfully created.' }
        format.json { render :show, status: :created, location: @player_count_template }
      else
        format.html { render :new }
        format.json { render json: @player_count_template.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /player_count_templates/1
  # PATCH/PUT /player_count_templates/1.json
  def update
    respond_to do |format|
      if @player_count_template.update(player_count_template_params)
        format.html { redirect_to @player_count_template, notice: 'Player count template was successfully updated.' }
        format.json { render :show, status: :ok, location: @player_count_template }
      else
        format.html { render :edit }
        format.json { render json: @player_count_template.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /player_count_templates/1
  # DELETE /player_count_templates/1.json
  def destroy
    @player_count_template.destroy
    respond_to do |format|
      format.html { redirect_to player_count_templates_url, notice: 'Player count template was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_player_count_template
      @player_count_template = PlayerCountTemplate.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def player_count_template_params
      params.require(:player_count_template).permit(:name, :tournament_template_id, :players, :template_id)
    end
end
