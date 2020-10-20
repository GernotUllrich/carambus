class DisciplineTournamentPlansController < ApplicationController
  before_action :set_discipline_tournament_plan, only: [:show, :edit, :update, :destroy]

  # GET /discipline_tournament_plans
  # GET /discipline_tournament_plans.json
  def index
    @discipline_tournament_plans = DisciplineTournamentPlan.page(params[:page]).per(24)
    respond_to do |format|
      format.html
      format.json { render json: DisciplineTournamentPlansDatatable.new(view_context, nil) }
    end
  end

  # GET /discipline_tournament_plans/1
  # GET /discipline_tournament_plans/1.json
  def show
  end

  # GET /discipline_tournament_plans/new
  def new
    @discipline_tournament_plan = DisciplineTournamentPlan.new
  end

  # GET /discipline_tournament_plans/1/edit
  def edit
  end

  # POST /discipline_tournament_plans
  # POST /discipline_tournament_plans.json
  def create
    @discipline_tournament_plan = DisciplineTournamentPlan.new(discipline_tournament_plan_params)

    respond_to do |format|
      if @discipline_tournament_plan.save
        format.html { redirect_to @discipline_tournament_plan, notice: 'Discipline tournament_plan was successfully created.' }
        format.json { render :show, status: :created, location: @discipline_tournament_plan }
      else
        format.html { render :new }
        format.json { render json: @discipline_tournament_plan.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /discipline_tournament_plans/1
  # PATCH/PUT /discipline_tournament_plans/1.json
  def update
    respond_to do |format|
      if @discipline_tournament_plan.update(discipline_tournament_plan_params)
        format.html { redirect_to @discipline_tournament_plan, notice: 'Discipline tournament_plan was successfully updated.' }
        format.json { render :show, status: :ok, location: @discipline_tournament_plan }
      else
        format.html { render :edit }
        format.json { render json: @discipline_tournament_plan.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /discipline_tournament_plans/1
  # DELETE /discipline_tournament_plans/1.json
  def destroy
    @discipline_tournament_plan.destroy
    respond_to do |format|
      format.html { redirect_to discipline_tournament_plans_url, notice: 'Discipline tournament_plan was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_discipline_tournament_plan
      @discipline_tournament_plan = DisciplineTournamentPlan.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def discipline_tournament_plan_params
      params.require(:discipline_tournament_plan).permit(:discipline_id, :tournament_plan_id, :points, :innings, :players)
    end
end
