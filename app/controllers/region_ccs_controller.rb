class RegionCcsController < ApplicationController
  before_action :set_region_cc, only: [:show, :edit, :update, :destroy]



  # GET /region_ccs
  def index
    @pagy, @region_ccs = pagy(RegionCc.sort_by_params(params[:sort], sort_direction))

    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @region_ccs.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @region_ccs.load
  end

  # GET /region_ccs/1
  def show
  end

  # GET /region_ccs/new
  def new
    @region_cc = RegionCc.new
  end

  # GET /region_ccs/1/edit
  def edit
  end

  # POST /region_ccs
  def create
    @region_cc = RegionCc.new(region_cc_params)

    if @region_cc.save
      redirect_to @region_cc, notice: "Region cc was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /region_ccs/1
  def update
    if @region_cc.update(region_cc_params)
      redirect_to @region_cc, notice: "Region cc was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /region_ccs/1
  def destroy
    @region_cc.destroy
    redirect_to region_ccs_url, notice: "Region cc was successfully destroyed."
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_region_cc
    @region_cc = RegionCc.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def region_cc_params
    params.require(:region_cc).permit(:cc_id, :context, :region_id, :shortname, :name)
  end
end
