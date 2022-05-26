class LeaguesController < ApplicationController
  include FiltersHelper
  before_action :admin_only_check, except: [:show, :index]
  before_action :set_league, only: [:show, :edit, :update, :destroy]

  # GET /leagues
  def index
    @leagues = League.joins('INNER JOIN "regions" ON ("regions"."id" = "leagues"."organizer_id" AND "leagues"."organizer_type" = \'Region\')').sort_by_params(params[:sort], sort_direction)
    if @sSearch.present?
      @leagues = apply_filters(@leagues, League::COLUMN_NAMES, "(leagues.name ilike :search) or (regions.shortname ilike :search)")
    end
    @pagy, @leagues = pagy(@leagues)
    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @leagues.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @leagues.load
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
  # GET /leagues/1
  def show
  end

  # GET /leagues/new
  def new
    @league = League.new
  end

  # GET /leagues/1/edit
  def edit
  end

  # POST /leagues
  def create
    @league = League.new(league_params)

    if @league.save
      redirect_to @league, notice: "League was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /leagues/1
  def update
    if @league.update(league_params)
      redirect_to @league, notice: "League was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /leagues/1
  def destroy
    @league.destroy
    redirect_to leagues_url, notice: "League was successfully destroyed."
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_league
    @league = League.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def league_params
    params.require(:league).permit(:name, :registration_until, :organizer_type, :organizer_id, :season_id, :ba_id, :ba_id2, :discipline_id)
  end
end
