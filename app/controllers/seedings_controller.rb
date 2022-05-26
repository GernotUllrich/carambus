class SeedingsController < ApplicationController
  include FiltersHelper
  before_action :set_seeding, only: [:show, :edit, :update, :destroy, :up, :down]

  # GET /seedings
  # GET /seedings
  def index
    @seedings = Seeding.joins(:player, :tournament => :season).sort_by_params(params[:sort], sort_direction)
    if @sSearch.present?
      @seedings = apply_filters(@seedings, Seeding::COLUMN_NAMES, "(tournaments.title ilike :search) or (players.lastname||', '||players.firstname ilike :search) or (players.nickname ilike :search) or (seasons.name ilike :search) or (seedings.state ilike :search)")
    end
    @pagy, @seedings = pagy(@seedings)
    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @seedings.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @seedings.load
    respond_to do |format|
      format.html {
        if params[:table_only].present?
          params.reject!{|k,v| k.to_s == "table_only"}
          render(partial: "search", :layout => false)
        else
          render("index")
        end }
    end
  end

  def up
    @seeding.move_higher
    @seeding.reload
    redirect_back(fallback_location: tournament_path(@seeding.tournament))
  end

  def down
    @seeding.move_lower
    redirect_back(fallback_location: tournament_path(@seeding.tournament))
  end

  # GET /seedings/1
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
  def create
    @seeding = Seeding.new(seeding_params)

    if @seeding.save
      redirect_to @seeding, notice: "Seeding was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /seedings/1
  def update
    if @seeding.update(seeding_params)
      redirect_to @seeding, notice: "Seeding was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /seedings/1
  def destroy
    @seeding.destroy
    redirect_to seedings_url, notice: "Seeding was successfully destroyed."
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_seeding
    @seeding = Seeding.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def seeding_params
    params.require(:seeding).permit(:player_id, :tournament_id, :ba_state, :position, :data, :state, :balls_goal, :playing_discipline_id)
  end
end
