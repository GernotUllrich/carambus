class TournamentTablesController < ApplicationController
  before_action :set_tournament_table, only: [:show, :edit, :update, :destroy]

  # GET /tournament_tables
  # GET /tournament_tables.json
  def index
    @tournament_tables = TournamentTable.all
  end

  # GET /tournament_tables/1
  # GET /tournament_tables/1.json
  def show
  end

  # GET /tournament_tables/new
  def new
    @tournament_table = TournamentTable.new
  end

  # GET /tournament_tables/1/edit
  def edit
  end

  # POST /tournament_tables
  # POST /tournament_tables.json
  def create
    @tournament_table = TournamentTable.new(tournament_table_params)

    respond_to do |format|
      if @tournament_table.save
        format.html { redirect_to @tournament_table, notice: 'Tournament table was successfully created.' }
        format.json { render :show, status: :created, location: @tournament_table }
      else
        format.html { render :new }
        format.json { render json: @tournament_table.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /tournament_tables/1
  # PATCH/PUT /tournament_tables/1.json
  def update
    respond_to do |format|
      if @tournament_table.update(tournament_table_params)
        format.html { redirect_to @tournament_table, notice: 'Tournament table was successfully updated.' }
        format.json { render :show, status: :ok, location: @tournament_table }
      else
        format.html { render :edit }
        format.json { render json: @tournament_table.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /tournament_tables/1
  # DELETE /tournament_tables/1.json
  def destroy
    @tournament_table.destroy
    respond_to do |format|
      format.html { redirect_to tournament_tables_url, notice: 'Tournament table was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_tournament_table
      @tournament_table = TournamentTable.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def tournament_table_params
      params.require(:tournament_table).permit(:tournament_id, :table_id, :table_no)
    end
end
