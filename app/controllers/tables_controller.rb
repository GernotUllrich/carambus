class TablesController < ApplicationController
  before_action :admin_only_check, except: %i[show index]
  before_action :set_table, only: %i[show edit update destroy]

  # GET /tables
  def index
    @pagy, @tables = pagy(Table.sort_by_params(params[:sort], sort_direction))

    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @tables.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @tables.load
  end

  # GET /tables/1
  def show
    @navbar = false
    @footer = false
  end

  # GET /tables/new
  def new
    @table = Table.new
  end

  # GET /tables/1/edit
  def edit; end

  # POST /tables
  def create
    @table = Table.new(table_params)

    if @table.save
      redirect_to @table, notice: "Table was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /tables/1
  def update
    if @table.update(table_params)
      redirect_to @table, notice: "Table was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /tables/1
  def destroy
    @table.destroy
    redirect_to tables_url, notice: "Table was successfully destroyed."
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_table
    @table = Table.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def table_params
    params.require(:table).permit(:location_id, :table_kind_id, :name, :data, :ip_address)
  end
end
