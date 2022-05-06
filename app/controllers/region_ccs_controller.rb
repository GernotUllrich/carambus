class RegionCcsController < ApplicationController
  before_action :set_region_cc, only: [:show, :edit, :update, :destroy, :fix, :check,
                                       :fix_branch_cc, :check_branch_cc]

  def fix
    RegionCc.save_log("region_cc")
    RegionCc.sync_regions(RegionCc.session_id, @region_cc.region, armed: true)
    RegionCc.save_log("region_cc")
    redirect_to migration_cc_region_path(@region_cc.region)
  end

  def check
    RegionCc.save_log("region_cc")
    unless @region_cc.region.blank?
      regions_todo = [@region_cc.region]
      regions_done = RegionCc.sync_regions(RegionCc.session_id, @region_cc.region, armed: false)
    else
      RegionCc.logger.info "REPORT unbekannter Regional-Context #{@region_c.name}"
    end
    regions_still_todo = regions_todo - regions_done
    unless regions_still_todo.blank?
      RegionCc.logger.info "REPORT regions with context #{@region_cc.name} not yet in CC: #{Region.where(id: regions_todo).map(&:name)}"
    end
    regions_overdone = regions_done - regions_todo
    unless regions_overdone.blank?
      RegionCc.logger.info "REPORT more regions with context #{@region_cc.name} than expected in CC: #{Region.where(id: regions_overdone).map(&:name)}"
    end

    RegionCc.save_log("region_cc")
    redirect_to migration_cc_region_path(@region_cc.region)
  end

  def fix_branch_cc
    RegionCc.save_log("branch_cc")
    @region_cc.sync_branches(RegionCc.session_id, armed: true)
    RegionCc.save_log("branch_cc")
    redirect_to migration_cc_region_path(@region_cc.region)
  end

  def check_branch_cc
    RegionCc.save_log("branch_cc")
    @region_cc.sync_branches(RegionCc.session_id, armed: false)
    RegionCc.save_log("branch_cc")
    redirect_to migration_cc_region_path(@region_cc.region)
  end

  # GET /region_ccs
  def index
    @pagy, @region_ccs = pagy(RegionCc.sort_by_params(params[:sort], sort_direction))

    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @region_ccs.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @region_ccs.load
  end

  # GET /region_ccs/1
  def show
    @branch_ccs = @region_cc.branch_ccs
  end

  # GET /region_ccs/new
  def new
    @region_cc = RegionCc.new(context:params[:context], region_id: params[:region_id], shortname: params[:shortname], name: params[:name])
  end

  # GET /region_ccs/1/edit
  def edit
  end

  # POST /region_ccs
  def create
    @region_cc = RegionCc.new(region_cc_params)
    #get main page with given public
    _, doc = RegionCc.new.get_cc_with_url("Home", nil, @region_cc.public_url )
    @region_cc.base_url = doc.css("a.cclogin")[0]["href"]
    @region_cc.cc_id = doc.css("a").select{|a| a["href"].match(/f=\d+$/)}.first["href"].match(/f=(\d+)$/)[1].to_i
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

  def synchronize_region_structure
    redirect_to
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_region_cc
    @region_cc = RegionCc.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def region_cc_params
    params.require(:region_cc).permit(:cc_id, :context, :region_id, :public_url, :base_url, :shortname, :name)
  end
end
