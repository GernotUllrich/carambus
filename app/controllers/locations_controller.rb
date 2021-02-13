class LocationsController < ApplicationController
  include FiltersHelper
  before_action :set_location, only: [:show, :edit, :update, :destroy, :add_tables_to]

  # GET /locations
  def index
    @locations = Location.sort_by_params(params[:sort], sort_direction)
    if @sSearch.present?
      @locations = apply_filters(@locations, Location::COLUMN_NAMES, "(locations.name ilike :search) or (locations.address ilike :search)")
    end
    @pagy, @locations = pagy(@locations)
    respond_to do |format|
      format.html {
        if params[:table_only].present?
          params.reject! { |k, v| k.to_s == "table_only" }
          render(partial: "search", :layout => false)
        else
          render("index")
        end
      }
    end
  end

  # GET /locations/1
  def show
  end

  # GET /locations/new
  def new
    @location = Location.new
    @organizer = Club.find(params[:club_id]) || Region.find(params[:club_id])
  end

  # GET /locations/1/edit
  def edit
  end

  def add_tables_to
    table_kind = TableKind.find(params[:table_kind_id])
    next_name = (@location.tables.order(:name).last.andand.name || "Table 0").succ
    (1..params[:number].to_i).each do |i|
      @location.tables.create(name: next_name, table_kind: table_kind)
      next_name = next_name.succ
    end
    redirect_back(fallback_location: club_path(@location.club))
  end

  # POST /locations
  def create
    @location = Location.new(location_params.merge(data: JSON.parse(location_params[:data])))
    if @location.save
      redirect_to @location, notice: "Location was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /locations/1
  def update
    if @location.update(location_params.merge(data: JSON.parse(location_params[:data])))
      redirect_to @location, notice: "Location was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /locations/1
  def destroy
    @location.destroy
    redirect_to locations_url, notice: "Location was successfully destroyed."
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_location
    @location = Location.find_by_md5(params[:id])
    if @location.present?
      unless current_user.present?
        @user = User.find_by_first_name("scoreboard")
        bypass_sign_in @user, scope: :user
        Current.user = @user
        redirect_to "/"
      end
    else
      @location = Location.find(params[:id])
    end
  end

  # Only allow a trusted parameter "white list" through.
  def location_params
    params.require(:location).permit(:club_id, :address, :data, :name)
  end
end
