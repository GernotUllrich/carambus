class TournamentPlansController < ApplicationController
  before_action :set_tournament_plan, only: [:show, :edit, :update, :destroy]

  # GET /tournament_plans
  # GET /tournament_plans.json
  def index
    @tournament_plans = TournamentPlan.all
  end

  # GET /tournament_plans/1
  # GET /tournament_plans/1.json
  def show
  end

  # GET /tournament_plans/new
  def new
    @tournament_plan = TournamentPlan.new
  end

  # GET /tournament_plans/1/edit
  def edit
  end

  # POST /tournament_plans
  # POST /tournament_plans.json
  def create
    @tournament_plan = TournamentPlan.new(tournament_plan_params)

    respond_to do |format|
      if @tournament_plan.save
        format.html { redirect_to @tournament_plan, notice: 'TournamentPlan was successfully created.' }
        format.json { render :show, status: :created, location: @tournament_plan }
      else
        format.html { render :new }
        format.json { render json: @tournament_plan.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /tournament_plans/1
  # PATCH/PUT /tournament_plans/1.json
  def update
    respond_to do |format|
      if @tournament_plan.update(tournament_plan_params)
        format.html { redirect_to @tournament_plan, notice: 'TournamentPlan was successfully updated.' }
        format.json { render :show, status: :ok, location: @tournament_plan }
      else
        format.html { render :edit }
        format.json { render json: @tournament_plan.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /tournament_plans/1
  # DELETE /tournament_plans/1.json
  def destroy
    @tournament_plan.destroy
    respond_to do |format|
      format.html { redirect_to tournament_plans_url, notice: 'TournamentPlan was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_tournament_plan
    @tournament_plan = TournamentPlan.find(params[:id])
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def tournament_plan_params
    params.require(:tournament_plan).permit(
        :name, :rulesystem, :players, :ngroups, :tables, :more_description,
        :even_more_description, :data_round1, :data_round2, :data_round3, :data_round8,
        :data_round9, :data_round10, :data_round11, :executor_class, :executor_params,
        :data_round4, :data_round5, :data_round6, :data_round7, :nrepeats)
  end
end
