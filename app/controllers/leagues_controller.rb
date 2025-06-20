class LeaguesController < ApplicationController
  include FiltersHelper
  before_action :admin_only_check, except: %i[show index]
  before_action :set_league, only: %i[show edit update destroy reload_from_cc reload_from_cc_with_details]

  # GET /leagues
  def index
    results = SearchService.call(League.search_hash(params))
    @pagy, @leagues = pagy(
      results.includes(:season, :discipline, :game_plan)
             .preload(:organizer)
    )
    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @leagues.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @leagues.load
    respond_to do |format|
      format.html do
        render("index")
      end
    end
  end

  # GET /leagues/1
  def show; end

  # GET /leagues/new
  def new
    @league = League.new
  end

  # GET /leagues/1/edit
  def edit; end

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

  def reload_from_cc
    if local_server?
      Version.update_from_carambus_api(update_league_from_cc: @league.id)
    else
      @league.scrape_single_league_from_cc(league_details: false)
    end
    redirect_back_or_to(league_path(@league))
  end

  def reload_from_cc_with_details
    if local_server?
      Version.update_from_carambus_api(update_league_from_cc: @league.id, league_details: true)
    else
      @league.scrape_single_league_from_cc(league_details: true)
    end
    redirect_back_or_to(league_path(@league))
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_league
    @league = League.find(params[:id].to_i)
  end

  # Only allow a trusted parameter "white list" through.
  def league_params
    params.require(:league).permit(:name, :registration_until, :organizer_type, :organizer_id, :season_id, :ba_id,
                                   :ba_id2, :discipline_id)
  end
end
