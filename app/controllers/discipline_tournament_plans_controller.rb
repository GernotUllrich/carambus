class DisciplineTournamentPlansController < ApplicationController
  before_action :admin_only_check, except: %i[show index]
  before_action :set_discipline_tournament_plan, only: %i[show edit update destroy]

  # GET /discipline_tournament_plans
  def index
    @pagy, @discipline_tournament_plans = pagy(DisciplineTournamentPlan.sort_by_params(params[:sort], sort_direction(params[:direction])))

    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @discipline_tournament_plans.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @discipline_tournament_plans.load
  end

  # GET /discipline_tournament_plans/1
  def show; end

  # GET /discipline_tournament_plans/new
  def new
    @discipline_tournament_plan = DisciplineTournamentPlan.new
    @disciplines = Discipline.all.order(:name)
    @tournament_plans = TournamentPlan.all.order(:name)
  end

  # GET /discipline_tournament_plans/1/edit
  def edit
    @disciplines = Discipline.all.order(:name)
    @tournament_plans = TournamentPlan.all.order(:name)
  end

  # POST /discipline_tournament_plans
  def create
    @discipline_tournament_plan = DisciplineTournamentPlan.new(discipline_tournament_plan_params)

    if @discipline_tournament_plan.save
      redirect_to @discipline_tournament_plan, notice: "Discipline tournament plan was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /discipline_tournament_plans/1
  def update
    if @discipline_tournament_plan.update(discipline_tournament_plan_params)
      redirect_to @discipline_tournament_plan, notice: "Discipline tournament plan was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /discipline_tournament_plans/1
  def destroy
    @discipline_tournament_plan.destroy
    redirect_to discipline_tournament_plans_url, notice: "Discipline tournament plan was successfully destroyed."
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_discipline_tournament_plan
    @discipline_tournament_plan = DisciplineTournamentPlan.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def discipline_tournament_plan_params
    params.require(:discipline_tournament_plan).permit(:discipline_id, :tournament_plan_id, :points, :innings,
                                                       :players, :player_class)
  end
end
