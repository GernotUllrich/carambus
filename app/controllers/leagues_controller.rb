class LeaguesController < ApplicationController
  before_action :set_league, only: [:show, :edit, :update, :destroy]

  # GET /leagues
  def xindex


    @pagy, @leagues = pagy(League.sort_by_params(params[:sort], sort_direction))

    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @leagues.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @leagues.load
  end
  # GET /clubs
  def index
    @leagues = League.sort_by_params(params[:sort], sort_direction)
    if @sSearch.present?
      @leagues = apply_filters(@leagues, League::COLUMN_NAMES, "(regions.shortname ilike :search) or (clubs.name ilike :search) or (clubs.address ilike :search) or (clubs.shortname ilike :search) or (clubs.email ilike :search) or (clubs.cc_id = :isearch)")
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
