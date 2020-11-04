class InningsController < ApplicationController
  before_action :set_inning, only: [:show, :edit, :update, :destroy]

  # GET /innings
  # GET /innings.json
  def index
    @innings = Inning.all
  end

  # GET /innings/1
  # GET /innings/1.json
  def show
  end

  # GET /innings/new
  def new
    @inning = Inning.new
  end

  # GET /innings/1/edit
  def edit
  end

  # POST /innings
  # POST /innings.json
  def create
    @inning = Inning.new(inning_params)

    respond_to do |format|
      if @inning.save
        format.html { redirect_to @inning, notice: 'Inning was successfully created.' }
        format.json { render :show, status: :created, location: @inning }
      else
        format.html { render :new }
        format.json { render json: @inning.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /innings/1
  # PATCH/PUT /innings/1.json
  def update
    respond_to do |format|
      if @inning.update(inning_params)
        format.html { redirect_to @inning, notice: 'Inning was successfully updated.' }
        format.json { render :show, status: :ok, location: @inning }
      else
        format.html { render :edit }
        format.json { render json: @inning.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /innings/1
  # DELETE /innings/1.json
  def destroy
    @inning.destroy
    respond_to do |format|
      format.html { redirect_to innings_url, notice: 'Inning was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_inning
      @inning = Inning.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def inning_params
      params.require(:inning).permit(:game_id, :sequence_number, :player_a_count, :player_b_count, :player_c_count, :player_d_count, :data)
    end
end
