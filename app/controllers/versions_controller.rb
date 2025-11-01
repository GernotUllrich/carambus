class VersionsController < ApplicationController
  before_action :set_version, only: %i[show edit update destroy]

  # GET /versions
  def index
    @pagy, @versions = pagy(Version.sort_by_params(params[:sort], sort_direction))

    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @versions.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @versions.load
  end

  # GET /versions/1
  def show; end

  # GET /versions/new
  def new
    @version = Version.new
  end

  # GET /versions/1/edit
  def edit; end

  # POST /versions
  def create
    @version = Version.new(version_params)

    if @version.save
      redirect_to @version, notice: "Version was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /versions/1
  def update
    if @version.update(version_params)
      redirect_to @version, notice: "Version was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /versions/1
  def destroy
    @version.destroy
    redirect_to versions_url, notice: "Version was successfully destroyed."
  end

  def last_version
    render json: { last_version: Version.last.id }.to_json
  end

  def current_revision
    render json: { current_revision: `cat #{Rails.root}/REVISION`.strip }.to_json
  end

  def update_carambus
    Version.update_carambus
  end

  def get_updates
    last_version_id = params[:last_version_id]
    force = params[:force].presence
    player_details = params[:player_details].presence
    league_details = params[:league_details].presence
    if (tournament_id = params[:update_tournament_from_cc]).present?
      @tournament = Tournament.find(tournament_id)
      @tournament.scrape_single_tournament_public(reload_game_results: true)
    elsif (club_id = params[:update_club_from_cc]).present?
      @club = Club.find(club_id)
      @region = @club&.region
      @club.scrape_club(Season.current_season, nil, nil, player_details: player_details, force: force)
    elsif (region_id = params[:update_region_from_cc]).present?
      @region = Region.find(region_id)
      @region.scrape_clubs(player_details: player_details)
    elsif (region_id = params[:scrape_upcoming_tournaments]).present?
      @region = Region.find(region_id)
      days_ahead = params[:days_ahead]&.to_i || 30
      @region.scrape_upcoming_tournaments(days_ahead: days_ahead)
    elsif (region_id = params[:reload_tournaments]).present?
      @region = Region.find(region_id)
      @region.scrape_single_tournament_public(Season[params[:season_id]])
    elsif (region_id = params[:reload_leagues]).present?
      @region = Region.find(region_id)
      @region.scrape_single_league_public(Season[params[:season_id]], league_details: false)
    elsif (region_id = params[:reload_leagues_with_details]).present?
      @region = Region.find(region_id)
      @region.scrape_single_league_public(Season[params[:season_id]], league_details: true)
    elsif (league_id = params[:update_league_from_cc]).present?
      @league = League[league_id]
      @region = @league&.organizer
      League[league_id]&.scrape_single_league_from_cc(league_details: league_details)
    end
    if last_version_id.present?
      attrs = []
      version_query = Version.where("id > ?", last_version_id.to_i)

      # Filter versions by region using the new region_id system
      if params[:region_id].present?
        version_query = version_query.for_region(params[:region_id])
      end

      version_query.order(id: :asc).limit(20_000).all.each do |version|
        attr = version.attributes
        attr["object_changes"] = YAML.load(attr["object_changes"]).to_json if attr["object_changes"].present?
        attr["object"] = YAML.load(attr["object"]).to_json if attr["object"].present?

        # Ensure region_id and global_context are included in the response
        attr["region_id"] = version.region_id
        attr["global_context"] = version.global_context

        attrs.push(attr)
      end

      str = attrs.to_json
      render json: str
    else
      render json: []
    end
  rescue Exception
    raise ActionController::RoutingError, "Not Found"
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_version
    @version = Version.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def version_params
    params.require(:version).permit(:item_type, :item_id, :event, :whodunnit, :object, :object_changes)
  end
end
