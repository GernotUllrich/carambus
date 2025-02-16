class PlayerClassesController < ApplicationController
  before_action :admin_only_check, except: %i[show index]
  before_action :set_player_class, only: %i[show edit update destroy]

  # GET /player_classes
  def index
    @pagy, @player_classes = pagy(PlayerClass.sort_by_params(params[:sort], sort_direction))

    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @player_classes.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @player_classes.load
  end

  # GET /player_classes/1
  def show; end

  # GET /player_classes/new
  def new
    @player_class = PlayerClass.new
  end

  # GET /player_classes/1/edit
  def edit; end

  # POST /player_classes
  def create
    @player_class = PlayerClass.new(player_class_params)

    if @player_class.save
      redirect_to @player_class, notice: "Player class was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /player_classes/1
  def update
    if @player_class.update(player_class_params)
      redirect_to @player_class, notice: "Player class was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /player_classes/1
  def destroy
    @player_class.destroy
    redirect_to player_classes_url, notice: "Player class was successfully destroyed."
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_player_class
    @player_class = PlayerClass.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def player_class_params
    params.require(:player_class).permit(:discipline_id, :shortname)
  end
end
