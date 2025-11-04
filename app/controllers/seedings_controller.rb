# frozen_string_literal: true

class SeedingsController < ApplicationController
  include FiltersHelper
  before_action :admin_only_check, except: %i[show index]
  before_action :set_seeding, only: %i[show edit update destroy up down]

  # GET /seedings
  # GET /seedings
  def index
    results = SearchService.call(Seeding.search_hash(params))
    @pagy, @seedings = pagy(results)
    @seedings.load
    respond_to do |format|
      format.html do
        render("index")
      end
    end
  end

  def up
    @seeding.move_higher
    @seeding.reload
    redirect_back_or_to(define_participants_tournament_path(@seeding.tournament))
  end

  def down
    @seeding.move_lower
    redirect_back_or_to(define_participants_tournament_path(@seeding.tournament))
  end

  # GET /seedings/1
  def show; end

  # GET /seedings/new
  def new
    @seeding = Seeding.new
  end

  # GET /seedings/1/edit
  def edit; end

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
    params.require(:seeding).permit(:player_id, :tournament_id, :ba_state, :position, :data, :state, :balls_goal,
                                    :playing_discipline_id)
  end
end
