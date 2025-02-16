class MetaMapsController < ApplicationController
  before_action :admin_only_check, except: %i[show index]
  before_action :set_meta_map, only: %i[show edit update destroy]

  # GET /meta_maps
  def index
    @pagy, @meta_maps = pagy(MetaMap.sort_by_params(params[:sort], sort_direction))

    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @meta_maps.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @meta_maps.load
  end

  # GET /meta_maps/1
  def show; end

  # GET /meta_maps/new
  def new
    @meta_map = MetaMap.new
  end

  # GET /meta_maps/1/edit
  def edit; end

  # POST /meta_maps
  def create
    @meta_map = MetaMap.new(meta_map_params.merge(data: JSON.parse(meta_map_params[:data])))

    if @meta_map.save
      redirect_to @meta_map, notice: "Meta map was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /meta_maps/1
  def update
    if @meta_map.update(meta_map_params.merge(data: JSON.parse(meta_map_params[:data])))
      redirect_to @meta_map, notice: "Meta map was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /meta_maps/1
  def destroy
    @meta_map.destroy
    redirect_to meta_maps_url, notice: "Meta map was successfully destroyed."
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_meta_map
    @meta_map = MetaMap.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def meta_map_params
    params.require(:meta_map).permit(:class_ba, :class_cc, :ba_base_url, :cc_base_url, :data)
  end
end
