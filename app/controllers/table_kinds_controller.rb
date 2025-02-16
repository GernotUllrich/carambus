class TableKindsController < ApplicationController
  before_action :admin_only_check, except: %i[show index]
  before_action :set_table_kind, only: %i[show edit update destroy]

  # GET /table_kinds
  def index
    @pagy, @table_kinds = pagy(TableKind.sort_by_params(params[:sort], sort_direction))

    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @table_kinds.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @table_kinds.load
  end

  # GET /table_kinds/1
  def show; end

  # GET /table_kinds/new
  def new
    @table_kind = TableKind.new
  end

  # GET /table_kinds/1/edit
  def edit; end

  # POST /table_kinds
  def create
    @table_kind = TableKind.new(table_kind_params)

    if @table_kind.save
      redirect_to @table_kind, notice: "Table kind was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /table_kinds/1
  def update
    if @table_kind.update(table_kind_params)
      redirect_to @table_kind, notice: "Table kind was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /table_kinds/1
  def destroy
    @table_kind.destroy
    redirect_to table_kinds_url, notice: "Table kind was successfully destroyed."
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_table_kind
    @table_kind = TableKind.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def table_kind_params
    params.require(:table_kind).permit(:name, :short, :measures)
  end
end
