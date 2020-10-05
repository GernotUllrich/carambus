class TournamentTemplatesController < ApplicationController
  before_action :set_tournament_template, only: [:show, :edit, :update, :destroy]

  # GET /tournament_templates
  # GET /tournament_templates.json
  def index
    @tournament_templates = TournamentTemplate.all
  end

  # GET /tournament_templates/1
  # GET /tournament_templates/1.json
  def show
  end

  # GET /tournament_templates/new
  def new
    @tournament_template = TournamentTemplate.new
  end

  # GET /tournament_templates/1/edit
  def edit
  end

  # POST /tournament_templates
  # POST /tournament_templates.json
  def create
    @tournament_template = TournamentTemplate.new(tournament_template_params)

    respond_to do |format|
      if @tournament_template.save
        format.html { redirect_to @tournament_template, notice: 'Tournament template was successfully created.' }
        format.json { render :show, status: :created, location: @tournament_template }
      else
        format.html { render :new }
        format.json { render json: @tournament_template.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /tournament_templates/1
  # PATCH/PUT /tournament_templates/1.json
  def update
    respond_to do |format|
      if @tournament_template.update(tournament_template_params)
        format.html { redirect_to @tournament_template, notice: 'Tournament template was successfully updated.' }
        format.json { render :show, status: :ok, location: @tournament_template }
      else
        format.html { render :edit }
        format.json { render json: @tournament_template.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /tournament_templates/1
  # DELETE /tournament_templates/1.json
  def destroy
    @tournament_template.destroy
    respond_to do |format|
      format.html { redirect_to tournament_templates_url, notice: 'Tournament template was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_tournament_template
      @tournament_template = TournamentTemplate.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def tournament_template_params
      params.require(:tournament_template).permit(:name, :discipline_id, :points, :innings)
    end
end
