class TableKindsController < ApplicationController
  before_action :set_table_kind, only: [:show, :edit, :update, :destroy]

  # GET /table_kinds
  # GET /table_kinds.json
  def index
    @table_kinds = TableKind.page(params[:page]).per(24)
    respond_to do |format|
      format.html
      format.json { render json: TableKindsDatatable.new(view_context, nil) }
    end
  end

  # GET /table_kinds/1
  # GET /table_kinds/1.json
  def show
  end

  # GET /table_kinds/new
  def new
    @table_kind = TableKind.new
  end

  # GET /table_kinds/1/edit
  def edit
  end

  # POST /table_kinds
  # POST /table_kinds.json
  def create
    @table_kind = TableKind.new(table_kind_params)

    respond_to do |format|
      if @table_kind.save
        format.html { redirect_to @table_kind, notice: 'Table kind was successfully created.' }
        format.json { render :show, status: :created, location: @table_kind }
      else
        format.html { render :new }
        format.json { render json: @table_kind.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /table_kinds/1
  # PATCH/PUT /table_kinds/1.json
  def update
    respond_to do |format|
      if @table_kind.update(table_kind_params)
        format.html { redirect_to @table_kind, notice: 'Table kind was successfully updated.' }
        format.json { render :show, status: :ok, location: @table_kind }
      else
        format.html { render :edit }
        format.json { render json: @table_kind.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /table_kinds/1
  # DELETE /table_kinds/1.json
  def destroy
    @table_kind.destroy
    respond_to do |format|
      format.html { redirect_to table_kinds_url, notice: 'Table kind was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_table_kind
      @table_kind = TableKind.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def table_kind_params
      params.require(:table_kind).permit(:name, :short, :measures)
    end
end
