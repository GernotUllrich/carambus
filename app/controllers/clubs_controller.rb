class ClubsController < ApplicationController
  include FiltersHelper
  before_action :set_club, only: [:new_club_tournament, :show, :edit, :update, :destroy, :get_club_details, :new_club_guest, :new_club_location, :reload_from_ba, :reload_from_ba_with_player_details]

  # GET /clubs
  def index
    @clubs = Club.joins(:region).sort_by_params(params[:sort], sort_direction)
    if @sSearch.present?
      @clubs = apply_filters(@clubs, Club::COLUMN_NAMES, "(regions.name ilike :search) or (clubs.name ilike :search) or (clubs.address ilike :search) or (clubs.shortname ilike :search) or (clubs.email ilike :search)")
    end
    @pagy, @clubs = pagy(@clubs)
    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @clubs.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @clubs.load
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

  # GET /clubs/1
  def show
  end

  def new_club_location
    @location = @club.tournament_locations.build
    render "locations/new"
  end

  def new_club_guest
    @player = @club.players.build(guest:true)
    render "players/new"
  end

  def new_club_tournament
    @season = Season.find(tournament_params[:season_id])

    @tournament = @club.organized_tournaments.build(season_id: @season.id)
    render "tournaments/new"
  end

  def get_club_details
    render partial: 'club_details', locals: {club: @club}, layout: nil
  end

  def reload_from_ba
    Version.update_from_carambus_api(update_club_from_ba: @club.id)
    redirect_back(fallback_location: club_path(@club))
  end

  def reload_from_ba_with_player_details
    Version.update_from_carambus_api(update_club_from_ba: @club.id, player_details: true)
    redirect_back(fallback_location: club_path(@club))
  end

  # GET /clubs/new
  def new
    @club = Club.new
  end

  # GET /clubs/1/edit
  def edit
  end

  # POST /clubs
  def create
    @club = Club.new(club_params)

    if @club.save
      redirect_to @club, notice: "Club was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /clubs/1
  def update
    if @club.update(club_params)
      redirect_to @club, notice: "Club was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /clubs/1
  def destroy
    @club.destroy
    redirect_to clubs_url, notice: "Club was successfully destroyed."
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_club
    @club = Club.find(params[:id])
  end

  def tournament_params
    params.require(:tournament).permit(:title, :discipline_id, :modus, :age_restriction, :date, :accredation_end, :location, :location_id, :ba_id, :season_id, :region_id, :end_date, :plan_or_show, :single_or_league, :shortname, :data, :ba_state, :state, :last_ba_sync_date, :player_class, :tournament_plan_id, :innings_goal, :timeouts, :timeout, :balls_goal, :handicap_tournier)
  end
  # Only allow a trusted parameter "white list" through.
  def club_params
    params.require(:club).permit(:ba_id, :region_id, :name, :season_id, :shortname, :address, :homepage, :email, :priceinfo, :logo, :status, :founded, :dbu_entry)
  end
end
