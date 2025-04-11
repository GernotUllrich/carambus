class ClubsController < ApplicationController
  before_action :admin_only_check, except: %i[show index]
  before_action :set_club,
                only: %i[new_club_tournament show edit update destroy get_club_details new_club_guest add_club_guest new_club_location
                         reload_from_ba reload_from_ba_with_details]

  # GET /clubs
  def index
    results = SearchService.call( Club.search_hash(params) )
    # Preload all necessary associations to avoid N+1 queries in the view
    results = results.includes(:region => :region_cc)
    @pagy, @clubs = pagy(results)
    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @clubs.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @clubs.load
    respond_to do |format|
      format.html do
        render("index")
      end
    end
  rescue StandardError => e
    Rails.logger.error "ERROR: #{e}\n#{e.backtrace.join("\n")}"
    render("index")
  end

  # GET /clubs/1
  def show; end

  def new_club_location
    @club_location = ClubLocation.new(club_id: @club.id)
    render "club_locations/new"
  end

  def new_club_guest
    @season = Season.current_season
    @season_participation = @club.season_participations.build(status: "guest")
    @player = Player.new
  end

  def add_club_guest
    @season = Season[club_guest_params[:season_id]] || Season.current_season
    @season_participation = SeasonParticipation.joins(:club, :player).where(club: @club, season: @season,
                                                                            players: { fl_name: club_guest_params[:firstname] + " " + club_guest_params[:lastname] }).first
    # @season_participation ||= SeasonParticipation.joins(:club, :player).where(club: @club, season: @season, players: {lastname: club_guest_params[:lastname]}).first
    # @season_participation ||= SeasonParticipation.joins(:club, :player).where(club: @club, season: @season, players: {firstname: club_guest_params[:firstname]}).first
    unless @season_participation.present?
      @player = Player.create(firstname: club_guest_params[:firstname], lastname: club_guest_params[:lastname])
      @season_participation = SeasonParticipation.create(club: @club, player: @player, season: @season,
                                                         status: club_guest_params[:status])
    end
    redirect_to(@club)
  end

  def new_club_tournament
    @season = Season.find(tournament_params[:season_id])
    @tournament = @club.organized_tournaments.build(season_id: @season.id)
    render "tournaments/new"
  end

  def get_club_details
    render partial: "club_details", locals: { club: @club }, layout: nil
  end

  def reload_from_ba
    if local_server?
      Version.update_from_carambus_api(update_club_from_ba: @club.id)
    else
      @club.scrape_club(Season.current_season, nil, nil, player_details: false)
    end
    redirect_back_or_to(club_path(@club))
  end

  def reload_from_ba_with_details
    if local_server?
      Version.update_from_carambus_api(update_club_from_ba: @club.id, player_details: true, force: true)
    else
      ret = @club.scrape_club(Season.current_season, nil, nil, player_details: true, force: true)
      if ret.present?
        redirect_back_or_to(club_path(@club), alert: ret)
        return
      end
    end
    redirect_back_or_to(club_path(@club))
  end

  # GET /clubs/new
  def new
    @club = Club.new
  end

  # GET /clubs/1/edit
  def edit; end

  def merge
    if params[:merge].present? && params[:with].present?
      merge_club = Club.find(params[:merge])
      with_club_ids = Club.where(id: params[:with].split(",").map(&:strip).map(&:to_i)).map(&:id)
      merge_club.merge_clubs(with_club_ids, force_merge: true)
    end
    redirect_to clubs_path
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
    args = club_params
    args[:synonyms] = args[:synonyms].split(";").map(&:strip).join("\n")
    if @club.update(args)
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
    params.require(:tournament).permit(:title, :discipline_id, :modus, :age_restriction, :date, :accredation_end,
                                       :location, :location_id, :ba_id, :season_id, :region_id, :end_date, :plan_or_show, :single_or_league, :shortname, :data, :ba_state, :state, :sync_date, :player_class, :tournament_plan_id, :innings_goal, :timeouts, :timeout, :balls_goal, :handicap_tournier)
  end

  # Only allow a trusted parameter "white list" through.
  def club_params
    params.require(:club).permit(:ba_id, :region_id, :name, :referrer, :season_id, :shortname, :synonyms, :address,
                                 :homepage, :email, :priceinfo, :logo, :status, :founded, :dbu_entry)
  end

  def club_guest_params
    params.permit(:firstname, :lastname, :nickname, :status)
  end
end
