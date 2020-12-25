class InningsController < ApplicationController
  before_action :set_inning, only: [:show, :edit, :update, :destroy]

  # GET /innings
  def index
    @pagy, @innings = pagy(Inning.sort_by_params(params[:sort], sort_direction))

    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @innings.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @innings.load
  end

  # GET /innings/1
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
  def create
    @inning = Inning.new(inning_params)

    if @inning.save
      redirect_to @inning, notice: "Inning was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /innings/1
  def update
    if @inning.update(inning_params)
      redirect_to @inning, notice: "Inning was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /innings/1
  def destroy
    @inning.destroy
    redirect_to innings_url, notice: "Inning was successfully destroyed."
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_inning
    @inning = Inning.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def inning_params
    params.require(:inning).permit(:game_id, :sequence_number, :player_a_count, :player_b_count, :player_c_count, :player_d_count, :date)
  end
end
