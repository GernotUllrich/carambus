class GamePlanCcsController < ApplicationController
  before_action :admin_only_check, except: %i[show index]
  before_action :set_game_plan_cc, only: %i[show edit update destroy]

  # GET /game_plan_ccs
  def index
    @pagy, @game_plan_ccs = pagy(GamePlanCc.sort_by_params(params[:sort], sort_direction))

    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @game_plan_ccs.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @game_plan_ccs.load
  end

  # GET /game_plan_ccs/1
  def show; end

  # GET /game_plan_ccs/new
  def new
    @game_plan_cc = GamePlanCc.new
  end

  # GET /game_plan_ccs/1/edit
  def edit; end

  # POST /game_plan_ccs
  def create
    @game_plan_cc = GamePlanCc.new(game_plan_cc_params)

    if @game_plan_cc.save
      redirect_to @game_plan_cc, notice: "Game plan cc was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /game_plan_ccs/1
  def update
    if @game_plan_cc.update(game_plan_cc_params)
      redirect_to @game_plan_cc, notice: "Game plan cc was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /game_plan_ccs/1
  def destroy
    @game_plan_cc.destroy
    redirect_to game_plan_ccs_url, notice: "Game plan cc was successfully destroyed."
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_game_plan_cc
    @game_plan_cc = GamePlanCc.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def game_plan_cc_params
    params.require(:game_plan_cc).permit(:cc_id, :name, :data, :branch_cc_id, :discipline_id, :mp_won, :mb_draw,
                                         :mp_lost, :znp, :vorgabe, :plausi, :pez_partie, :bez_brett, :rang_partie, :rang_mgd, :rang_kegel, :ersatzspieler_regel, :row_type_id)
  end
end
