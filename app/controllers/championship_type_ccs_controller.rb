class ChampionshipTypeCcsController < ApplicationController
  before_action :set_championship_type_cc, only: %i[show edit update destroy]

  # GET /championship_type_ccs
  def index
    @pagy, @championship_type_ccs = pagy(ChampionshipTypeCc.sort_by_params(params[:sort], sort_direction))

    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @championship_type_ccs.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @championship_type_ccs.load
  end

  # GET /championship_type_ccs/1
  def show; end

  # GET /championship_type_ccs/new
  def new
    @championship_type_cc = ChampionshipTypeCc.new
  end

  # GET /championship_type_ccs/1/edit
  def edit; end

  # POST /championship_type_ccs
  def create
    @championship_type_cc = ChampionshipTypeCc.new(championship_type_cc_params)

    if @championship_type_cc.save
      redirect_to @championship_type_cc, notice: "Championship type cc was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /championship_type_ccs/1
  def update
    if @championship_type_cc.update(championship_type_cc_params)
      redirect_to @championship_type_cc, notice: "Championship type cc was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /championship_type_ccs/1
  def destroy
    @championship_type_cc.destroy
    redirect_to championship_type_ccs_url, notice: "Championship type cc was successfully destroyed."
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_championship_type_cc
    @championship_type_cc = ChampionshipTypeCc.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def championship_type_cc_params
    params.require(:championship_type_cc).permit(:cc_id, :name, :shortname, :context, :branch_cc_id, :status)
  end
end
