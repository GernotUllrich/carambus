class DisciplineCcsController < ApplicationController
  before_action :set_discipline_cc, only: %i[show edit update destroy]

  # GET /discipline_ccs
  def index
    @pagy, @discipline_ccs = pagy(DisciplineCc.sort_by_params(params[:sort], sort_direction))

    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @discipline_ccs.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @discipline_ccs.load
  end

  # GET /discipline_ccs/1
  def show; end

  # GET /discipline_ccs/new
  def new
    @discipline_cc = DisciplineCc.new
  end

  # GET /discipline_ccs/1/edit
  def edit; end

  # POST /discipline_ccs
  def create
    @discipline_cc = DisciplineCc.new(discipline_cc_params)

    if @discipline_cc.save
      redirect_to @discipline_cc, notice: "Discipline cc was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /discipline_ccs/1
  def update
    if @discipline_cc.update(discipline_cc_params)
      redirect_to @discipline_cc, notice: "Discipline cc was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /discipline_ccs/1
  def destroy
    @discipline_cc.destroy
    redirect_to discipline_ccs_url, notice: "Discipline cc was successfully destroyed."
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_discipline_cc
    @discipline_cc = DisciplineCc.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def discipline_cc_params
    params.require(:discipline_cc).permit(:cc_id, :name, :discipline_id, :branch_cc_id, :context)
  end
end
