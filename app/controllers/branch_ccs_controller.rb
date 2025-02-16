class BranchCcsController < ApplicationController
  before_action :admin_only_check, except: %i[show index]
  before_action :set_branch_cc, only: %i[show edit update destroy]

  # GET /branch_ccs
  def index
    @pagy, @branch_ccs = pagy(BranchCc.sort_by_params(params[:sort], sort_direction))

    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @branch_ccs.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @branch_ccs.load
  end

  # GET /branch_ccs/1
  def show
    @competition_ccs = @branch_cc.competition_ccs
  end

  # GET /branch_ccs/new
  def new
    @branch_cc = BranchCc.new
  end

  # GET /branch_ccs/1/edit
  def edit; end

  # POST /branch_ccs
  def create
    @branch_cc = BranchCc.new(branch_cc_params)

    if @branch_cc.save
      redirect_to @branch_cc, notice: "Branch cc was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /branch_ccs/1
  def update
    if @branch_cc.update(branch_cc_params)
      redirect_to @branch_cc, notice: "Branch cc was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /branch_ccs/1
  def destroy
    @branch_cc.destroy
    redirect_to branch_ccs_url, notice: "Branch cc was successfully destroyed."
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_branch_cc
    @branch_cc = BranchCc.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def branch_cc_params
    params.require(:branch_cc).permit(:cc_id, :context, :region_cc_id, :discipline_id, :name)
  end
end
