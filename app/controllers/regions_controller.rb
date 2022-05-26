class RegionsController < ApplicationController
  include FiltersHelper
  protect_from_forgery except: :search
  before_action :set_region, only: [:show, :edit, :update, :destroy, :reload_from_ba, :reload_from_ba_with_player_details, :migration_cc, :set_base_parameters]

  def set_base_parameters
    cookies[:session_id] = params["PHPSESSID"]
    cookies[:context] = @region.shortname.downcase
    cookies[:season_name] = Season.find(params["season_id"]).name
    cookies[:force_update] = params[:force_update]
    flash[:notice] = "Session Id gesetzt."
    redirect_to migration_cc_region_path(@region)
  end

  # GET /regions
  def index
    @regions = Region.includes(:country).sort_by_params(params[:sort], sort_direction)
    if @sSearch.present?
      @regions = apply_filters(@regions, Region::COLUMN_NAMES, "(regions.name ilike :search) or (regions.shortname ilike :search) or (regions.email ilike :search)")
    end
    @pagy, @regions = pagy(@regions)
    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @regions.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @regions.load
    respond_to do |format|
      format.html {
        if params[:table_only].present?
          params.reject! { |k, v| k.to_s == "table_only" }
          render(partial: "search", :layout => false)
        else
          render("index")
        end }
    end
  end

  # GET /regions/1
  def show
    @t_pagy, @tournaments = pagy(Tournament.where(season_id: Season.last.id, region_id: @region.id).order("tournaments.date asc"))
    @tournaments.load
  end

  # GET /regions/new
  def new
    @region = Region.new
  end

  # GET /regions/1/edit
  def edit
  end

  # POST /regions
  def create
    @region = Region.new(region_params)

    if @region.save
      redirect_to @region, notice: "Region was successfully created."
    else
      render :new
    end
  end

  def reload_from_ba
    Version.update_from_carambus_api(update_region_from_ba: @region.id)
    redirect_back(fallback_location: region_path(@region))
  end

  def reload_from_ba_with_player_details
    Version.update_from_carambus_api(update_region_from_ba: @region.id, player_details: true)
    redirect_back(fallback_location: region_path(@region))
  end

  # PATCH/PUT /regions/1
  def update
    if @region.update(region_params)
      redirect_to @region, notice: "Region was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /regions/1
  def destroy
    @region.destroy
    redirect_to regions_url, notice: "Region was successfully destroyed."
  end

  def migration_cc
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_region
    @region = Region.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def region_params
    params.require(:region).permit(:name, :shortname, :logo, :email, :address, :country_id, :season_name, :session_id, :context )
  end
end
