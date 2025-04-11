class RegionsController < ApplicationController
  include FiltersHelper
  # TODO: callback needed?:  protect_from_forgery except: :search
  before_action :admin_only_check, except: %i[show index]
  before_action :set_region,
                only: %i[show edit update destroy reload_from_ba migration_cc set_base_parameters reload_from_ba
                         reload_from_ba_with_details reload_tournaments reload_leagues reload_leagues_with_details]

  def set_base_parameters
    cookies[:session_id] = params["PHPSESSID"]
    cookies[:context] = @region.shortname.downcase
    cookies[:season_name] = Season.find(params["season_id"]).name
    cookies[:force_update] = params[:force_update]
    flash[:notice] = "Session Id gesetzt."
    redirect_to migration_cc_region_path(@region)
  end

  # GET /regions
  def index
    results = SearchService.call( Region.search_hash(params) )
    # Eager load the country association to avoid N+1 queries in the view
    results = results.includes(:country) if results.respond_to?(:includes)
    @pagy, @regions = pagy(results)
    if @regions.count == 0
      session[:s_regions] = nil
      flash[:alert] = "NO MATCHES on '#{@sSearch}'"
    end
    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @regions.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @regions.load
    respond_to do |format|
      format.html do
        render("index")
      end
    end
  end

  # GET /regions/1
  def show
    @t_pagy, @tournaments = pagy(Tournament.where(season: Season.current_season,
                                                  organizer: @region).order("tournaments.date asc"))
    @tournaments.load
  end

  # GET /regions/new
  def new
    @region = Region.new
  end

  # GET /regions/1/edit
  def edit; end

  # POST /regions
  def create
    @region = Region.new(region_params)

    if @region.save
      redirect_to @region, notice: "Region was successfully created."
    else
      render :new
    end
  end

  def reload_from_ba
    if local_server?
      Version.update_from_carambus_api(update_region_from_ba: @region.id)
    else
      @region.scrape_clubs(player_details: false)
    end
    redirect_back_or_to(region_path(@region))
  end

  def reload_from_ba_with_details
    if local_server?
      Version.update_from_carambus_api(update_region_from_ba: @region.id, player_details: true)
    else
      # @region.scrape_clubs(player_details: true, start_with_club_shortname: "Snooker Club 147 Essen e.V.")
      @region.scrape_clubs(player_details: true)
    end
    redirect_back_or_to(region_path(@region))
  end

  def reload_tournaments
    if local_server?
      Version.update_from_carambus_api(reload_tournaments: @region.id, season_id: Season.current_season.id)
    else
      @region.scrape_single_tournament_public(Season.current_season)
    end
    redirect_back_or_to(region_path(@region))
  end

  def reload_leagues
    if local_server?
      Version.update_from_carambus_api(reload_leagues: @region.id, season_id: Season.current_season.id)
    else
      @region.scrape_single_league_public(Season.current_season, league_details: false)
    end
    redirect_back_or_to(region_path(@region))
  end

  def reload_leagues_with_details
    if local_server?
      Version.update_from_carambus_api(reload_leagues_with_details: @region.id, season_id: Season.current_season.id)
    else
      @region.scrape_single_league_public(Season.current_season, league_details: true)
    end
    redirect_back_or_to(region_path(@region))
  end

  # PATCH/PUT /regions/1
  def update
    if @region.update(region_params)
      redirect_to @region, notice: "Region was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /regions/1
  def destroy
    @region.destroy
    redirect_to regions_url, notice: "Region was successfully destroyed."
  end

  def migration_cc; end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_region
    @region = Region.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def region_params
    params.require(:region).permit(:name, :shortname, :public_cc_url_base, :logo, :email, :address, :country_id,
                                   :season_name, :session_id, :context)
  end
end
