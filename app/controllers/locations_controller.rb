class LocationsController < ApplicationController
  before_action :set_location, only: [:show, :edit, :update, :destroy, :add_tables_to]

  # GET /locations
  # GET /locations.json
  def index
    @locations = Location.all
  end

  # GET /locations/1
  # GET /locations/1.json
  def show
  end

  # GET /locations/new
  def new
    @location = Location.new(club_id: params[:club_id])
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
  # POST /locations.json
  def create
    @location = Location.new(location_params)

    respond_to do |format|
      if @location.save
        format.html { redirect_to @location, notice: 'Location was successfully created.' }
        format.json { render :show, status: :created, location: @location }
      else
        format.html { render :new }
        format.json { render json: @location.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /locations/1
  # PATCH/PUT /locations/1.json
  def update
    respond_to do |format|
      if @location.update(location_params)
        format.html { redirect_to @location, notice: 'Location was successfully updated.' }
        format.json { render :show, status: :ok, location: @location }
      else
        format.html { render :edit }
        format.json { render json: @location.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /locations/1
  # DELETE /locations/1.json
  def destroy
    @location.destroy
    respond_to do |format|
      format.html { redirect_to locations_url, notice: 'Location was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_location
      @location = Location.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def location_params
      params.require(:location).permit(:club_id, :name, :address, :data).merge(data: (JSON.parse(params[:location][:data]) rescue {}))
    end
end
