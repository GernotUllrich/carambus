class TournamentPlansController < ApplicationController
  before_action :admin_only_check, except: %i[show index]
  before_action :set_tournament_plan, only: %i[show edit update destroy]

  # GET /tournament_plans
  def index
    @pagy, @tournament_plans = pagy(TournamentPlan.sort_by_params(params[:sort], sort_direction))

    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @tournament_plans.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @tournament_plans.load
  end

  # GET /tournament_plans/1
  def show; end

  # GET /tournament_plans/new
  def new
    @tournament_plan = TournamentPlan.new
  end

  # GET /tournament_plans/1/edit
  def edit; end

  # POST /tournament_plans
  def create
    @tournament_plan = TournamentPlan.new(tournament_plan_params)

    if @tournament_plan.save
      redirect_to @tournament_plan, notice: "Tournament plan was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /tournament_plans/1
  def update
    if @tournament_plan.update(tournament_plan_params)
      redirect_to @tournament_plan, notice: "Tournament plan was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /tournament_plans/1
  def destroy
    @tournament_plan.destroy
    redirect_to tournament_plans_url, notice: "Tournament plan was successfully destroyed."
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_tournament_plan
    @tournament_plan = TournamentPlan.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def tournament_plan_params
    params.require(:tournament_plan).permit(:name, :rulesystem, :players, :tables, :more_description,
                                            :even_more_description, :executor_class, :executor_params, :ngroups, :nrepeats)
  end
end
