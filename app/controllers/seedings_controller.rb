class SeedingsController < ApplicationController
  before_action :set_seeding, only: [:show, :edit, :update, :destroy, :up, :down]

  # GET /seedings
  # GET /seedings.json
  def index
    @seedings = Seeding.page(params[:page]).per(24)
    respond_to do |format|
      format.html
      format.json { render json: SeedingsDatatable.new(view_context, nil) }
    end
  end

  def up
    @seeding.move_higher
    redirect_to :back
  end

  def down
    @seeding.move_lower
    redirect_to :back
  end

  # GET /seedings/1
  # GET /seedings/1.json
  def show
  end

  # GET /seedings/new
  def new
    @seeding = Seeding.new
  end

  # GET /seedings/1/edit
  def edit
  end

  # POST /seedings
  # POST /seedings.json
  def create
    @seeding = Seeding.new(seeding_params)

    respond_to do |format|
      if @seeding.save
        format.html { redirect_to @seeding, notice: 'Seeding was successfully created.' }
        format.json { render :show, status: :created, location: @seeding }
      else
        format.html { render :new }
        format.json { render json: @seeding.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /seedings/1
  # PATCH/PUT /seedings/1.json
  def update
    respond_to do |format|
      if @seeding.update(seeding_params)
        format.html { redirect_to @seeding, notice: 'Seeding was successfully updated.' }
        format.json { render :show, status: :ok, location: @seeding }
      else
        format.html { render :edit }
        format.json { render json: @seeding.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /seedings/1
  # DELETE /seedings/1.json
  def destroy
    @seeding.destroy
    respond_to do |format|
      format.html { redirect_to seedings_url, notice: 'Seeding was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_seeding
      @seeding = Seeding.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def seeding_params
      params.require(:seeding).permit(:player_id, :tournament_id, :status, :position, :remarks)
    end
end
