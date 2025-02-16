class GroupCcsController < ApplicationController
  before_action :set_group_cc, only: %i[show edit update destroy]

  # GET /group_ccs
  def index
    @pagy, @group_ccs = pagy(GroupCc.sort_by_params(params[:sort], sort_direction))

    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @group_ccs.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @group_ccs.load
  end

  # GET /group_ccs/1
  def show; end

  # GET /group_ccs/new
  def new
    @group_cc = GroupCc.new
  end

  # GET /group_ccs/1/edit
  def edit; end

  # POST /group_ccs
  def create
    @group_cc = GroupCc.new(group_cc_params)

    if @group_cc.save
      redirect_to @group_cc, notice: "Group cc was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /group_ccs/1
  def update
    if @group_cc.update(group_cc_params)
      redirect_to @group_cc, notice: "Group cc was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /group_ccs/1
  def destroy
    @group_cc.destroy
    redirect_to group_ccs_url, notice: "Group cc was successfully destroyed."
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_group_cc
    @group_cc = GroupCc.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def group_cc_params
    params.require(:group_cc).permit(:cc_id, :name, :context, :display, :status, :branch_cc_id, :data)
  end
end
