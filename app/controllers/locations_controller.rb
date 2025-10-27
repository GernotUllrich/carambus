# frozen_string_literal: true

# Locations associated with tables are the places where tournaments and match days are executed
class LocationsController < ApplicationController
  attr_accessor :game

  include FiltersHelper
  before_action :set_location,
                only: %i[scoreboard show edit update destroy
                         new_league_tournament add_tables_to
                         toggle_dark_mode create_event]

  # GET /locations
  def index
    results = SearchService.call(Location.search_hash(params))
    @pagy, @locations = pagy(results.includes(clubs: [], organizer: []))
    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    @locations.load

    # Preload all regions for caching
    @regions_cache = Region.all.index_by(&:id)

    # Ensure instance variables are available for both regular requests and Reflex
    @pagy ||= Pagy.new(count: results.count, page: (params[:page] || 1).to_i)

    respond_to do |format|
      format.html do
        render("index")
      end
    end
  end

  # GET /locations/1
  def show
    @table_kind_all = TableKind.all.order(:name).to_a
    Rails.logger.info "params[:table_id] = #{params[:table_id]}"
    Rails.logger.info "params[:sb_state] = #{params[:sb_state]}"
    Rails.logger.info "Current.user = #{Current.user&.email}"
    Rails.logger.info "User.scoreboard = #{User.scoreboard&.email}"
    return unless Current.user == User.scoreboard || params[:table_id].present? || params[:sb_state] == "tables"

    table = game = table_monitor = player_b = player_a = nil
    session[:sb_state] ||= "welcome"
    session[:sb_state] = params[:sb_state] if params[:sb_state].present?
    tournament = Tournament.find(params[:tournament_id]) if params[:tournament_id].present?
    @navbar = @footer = false

    # Set @table if table_id is present
    @table = Table.find(params[:table_id]) if params[:table_id].present?

    # Preload data based on state
    case session[:sb_state]
    when "tournament"
      preload_tournament_data
    when "tables"
      preload_tables_data
    end

    if session[:sb_state] == "tables" && params[:terminate_game_id].present?
      game = begin
               Game.find(params[:terminate_game_id])
             rescue StandardError => _e
               nil
             end
    end
    if game.present? && game.tournament.blank?
      game.table_monitor&.reset_table_monitor
      game.destroy
    elsif game.present? && game.tournament.present? && !game.table_monitor&.playing?
      game.table_monitor&.reset_table_monitor
    end
    if local_server?

      case session[:sb_state]
      when "welcome"
        render "scoreboard_welcome"
      when "start"
        render "scoreboard_start", locals: { table: @table }
      when "tournament"
        render "scoreboard_tournament"
      when "tables"
        @bg_color = "#1C0909"
        render "scoreboard_tables"
      when "tournament_scores"
        # @bg_color = "#1C0909"
        @bg_color = "#000000"
        render "scoreboard_tournament_scores", locals: { tournament: tournament }
      when "big_table_scores"
        # @bg_color = "#1C0909"
        @bg_color = "#000000"
        render "scoreboard_big_table_scores", locals: { tournament: tournament }
      when "table_scores"
        # @bg_color = "#1C0909"
        @bg_color = "#000000"
        render "scoreboard_table_scores", locals: { tournament: tournament }
      when "reservations"
        # @bg_color = "#1C0909"
        @bg_color = "#000000"
        render "scoreboard_reservations", locals: { tournament: tournament }
      when "training"
        render "scoreboard_training"
      when "free_game"
        # Quick Game Setup - Ultra-simple for Pi 3 Performance (DEFAULT)
        player_a = Player.find(params[:player_a_id]) if params[:player_a_id].to_i.positive?
        player_b = Player.find(params[:player_b_id]) if params[:player_b_id].to_i.positive?
        Table.transaction do
          if @table.present?
            table_monitor = @table.table_monitor || @table.table_monitor!
            if table_monitor.present?
              game = table_monitor.game
              if game.blank?
                game = Game.create!
                game.game_participations.create(player: player_a, role: "playera") if player_a
                game.game_participations.create(player: player_b, role: "playerb") if player_b
              end
              table_monitor.assign_game(game)
              table_monitor.get_options!(I18n.locale)
            end
          end
        end
        club = @location.club.presence
        if club.present?
          player_ids = club.season_participations
                           .where(season_id: Season.current_season&.id)
                           .map(&:player_id).compact.uniq
          default_guest_a = Player.default_guest(:a, @location)
          default_guest_b = Player.default_guest(:b, @location)
          guest_player_ids = club.season_participations.where(status: "guest")
                                 .where(season_id: Season.current_season&.id).map(&:player_id).compact.uniq
          club_player_ids = player_ids - guest_player_ids
          players = Player.joins(:season_participations).where(season_participations: {
            season_id: Season.current_season&.id, club_id: club.id
          }).where(id: (guest_player_ids + club_player_ids)).to_a
          
          # Prepare players list for select
          players_list = []
          players_list += [["---Gäste---", ""]]
          players_list += players.select { |p| guest_player_ids.include?(p.id) }
                                .map { |p| ["#{p.firstname} #{p.lastname}", p.id] }
          players_list += [["---Club---", ""]]
          players_list += players.select { |p| club_player_ids.include?(p.id) }
                                .map { |p| ["#{p.firstname} #{p.lastname}", p.id] }
          
          if @table.present?
            render "scoreboard_free_game_quick",
                   locals: {
                     table: @table,
                     table_monitor: table_monitor,
                     club: club,
                     players: players_list,
                     player_a: player_a,
                     player_b: player_b,
                     default_guest_a: default_guest_a,
                     default_guest_b: default_guest_b
                   }
          end
        end
      when "free_game_detail"
        # Original detailed configuration with Alpine.js
        player_a = Player.find(params[:player_a_id]) if params[:player_a_id].to_i.positive?
        player_b = Player.find(params[:player_b_id]) if params[:player_b_id].to_i.positive?
        Table.transaction do
          if @table.present?
            # noinspection RubyNilAnalysis
            table_monitor = @table.table_monitor || @table.table_monitor!
            if table_monitor.present?
              game = table_monitor.game
              if game.blank?
                game = Game.create!
                game.game_participations.create(player: player_a, role: "playera")
                game.game_participations.create(player: player_b, role: "playerb")
              end
              table_monitor.assign_game(game)
              table_monitor.get_options!(I18n.locale)
            end
          end
        end
        club = @location.club.presence
        if club.present?
          player_ids = club.season_participations
                           .where(season_id: Season.current_season&.id)
                           .map(&:player_id).compact.uniq
          default_guest_a = Player.default_guest(:a, @location)
          default_guest_b = Player.default_guest(:b, @location)
          guest_player_ids = club.season_participations.where(status: "guest")
                                 .where(season_id: Season.current_season&.id).map(&:player_id).compact.uniq
          club_player_ids = player_ids - guest_player_ids
          players = Player.joins(:season_participations).where(season_participations: {
            season_id: Season.current_season&.id, club_id: club.id
          }).where(id: (guest_player_ids + club_player_ids)).to_a
          guest_players_default = Player.where(id: [default_guest_a.player.id,
                                                    default_guest_b.player.id]).order("fl_name")
          guest_players_other = Player.joins(season_participations: %i[club
                                                                       season])
                                      .where(clubs: { id: club.id })
                                      .where.not(id: [default_guest_a.player.id,
                                                      default_guest_b.player.id])
                                      .where(season_participations: { status: "guest" })
                                      .where(seasons: { id: Season.current_season&.id })
                                      .order("fl_name")

          club_players = Player.where(id: club_player_ids).order("fl_name")

          player_names = players.map { |p| "#{p.firstname} #{p.lastname}" }
          player_ids = players.map(&:id)
        end
        kickoff_switches_with = "set"
        color_remains_with_set = true
        allow_overflow = false
        allow_follow_up = true
        if @table.present?
          @bg_color ||= "#1B0909"
          string_frozen_ = "scoreboard_free_game"
          render("#{string_frozen_}_#{TableKind::TABLE_KIND_FREE_GAME_SETUP[@table.table_kind.name]}",
                 locals: {
                   table: @table,
                   table_monitor: table_monitor,
                   kickoff_switches_with: kickoff_switches_with,
                   guest_players_default: guest_players_default,
                   guest_players_other: guest_players_other,
                   club_players: club_players,
                   player_names: player_names,
                   player_ids: player_ids,
                   color_remains_with_set: color_remains_with_set,
                   allow_overflow: allow_overflow,
                   allow_follow_up: allow_follow_up,
                   club: club,
                   player_a: player_a,
                   player_b: player_b,
                   default_guest_a: default_guest_a,
                   default_guest_b: default_guest_b
                 })
          nil
        end
      else
        redirect_back(fallback_location: root_path)
      end
    else
      redirect_back(fallback_location: root_path)
    end
  end

  def scoreboard
    session[:location_id] = @location.id
    sb_state = params[:sb_state] || "welcome"
    if current_user.present?
      sign_out(current_user)
    end
    @user = User.scoreboard
    bypass_sign_in @user, scope: :user
    Current.user = @user
    scoreboard_current = scoreboard_location_url(@location.md5, sb_state: "welcome")
    scoreboard_url = if File.exist?("#{Rails.root}/config/scoreboard_url")
                       File.read("#{Rails.root}/config/scoreboard_url").to_s.strip
                     end
    unless scoreboard_current == scoreboard_url
      File.write("#{Rails.root}/config/scoreboard_url", scoreboard_location_url(@location.md5, sb_state: "welcome"))
    end
    redirect_to location_url(@location, sb_state: sb_state, locale: params[:locale], host: request.server_name, port: request.server_port)
  end

  def game_results
    @navbar = @footer = false
    @tournament = nil
    @location = Location.find(params[:id])
    return unless params[:tournament_id].present?

    @tournament = Tournament.find(params[:tournament_id])
  end

  def placement
    @navbar = @footer = false
    @tournament = nil
    @table = Table.find(params[:table_id])
    info = "+++ 1a - locations_controller#placement @table"
    Rails.logger.info info
    @location = Location.find(params[:id])
    info = "+++ 1b - locations_controller#placement @location"
    Rails.logger.info info
    if params[:tournament_id].present?
      @tournament = Tournament.find(params[:tournament_id])
      if @tournament.present?
        info = "+++ 1c - locations_controller#placement @tournament"
        Rails.logger.info info
        info = "+++ 3l - locations_controller#placement"
        Rails.logger.info info
        @games = @tournament.games.joins(game_participations: :player).where(
          game_participations: { role: "playera" }
        ).to_a.sort_by do |game|
          game.game_participations.where(role: "playera").first&.player&.lastname.to_s +
            game.game_participations.where(role: "playerb").first&.player&.lastname.to_s
        end.select do |game|
          game.data.blank? || game.data["ba_results"].blank?
        end
        @pairs = []
        @games.map do |game|
          gpa = game.game_participations.where(role: "playera").first
          playera = gpa&.player
          seeding_state_a = game.tournament.seedings.where(player_id: playera&.id).first&.state
          gpb = game.game_participations.where(role: "playerb").first
          playerb = gpb&.player
          seeding_state_b = game.tournament.seedings.where(player_id: playerb&.id).first&.state
          unless seeding_state_a == "no_show" || seeding_state_b == "no_show"
            @pairs << [game.id, playera&.fullname, playerb&.fullname, "game_#{game.id}a"]
            @pairs << [game.id, playerb&.fullname, playera&.fullname, "game_#{game.id}b"]
          end
        end
        @pairs = @pairs.sort_by { |a| "#{a[1]} - #{a[2]}" }
      end
    else
              redirect_to location_url(@location, table_id: @table.id, sb_state: "free_game",
                                player_a_id: @player_a&.id, player_b_id: @player_b&.id, host: request.server_name, port: request.server_port)
    end
  end

  # GET /locations/new
  def new
    @location = Location.new
    @club = Club.find(params[:club_id]) if params[:club_id].present?
    @club ||= Club[Carambus.config.club_id]
    @region = Region.find(params[:region_id]) if params[:region_id].present?
    @location.organizer = @club || @region
  end

  # GET /locations/1/edit
  def edit; end

  def create_event
    Rails.logger.info "create_event"
    google_creds_json = {
      type: "service_account",
      project_id: "carambus-test",
      private_key_id: Rails.application.credentials.dig(:google_service, :public_key).gsub('\n', "\n"),
      private_key: Rails.application.credentials.dig(:google_service, :private_key).gsub('\n', "\n"),
      client_email: "service-test@carambus-test.iam.gserviceaccount.com",
      client_id: "110923757328591064447",
      auth_uri: "https://accounts.google.com/o/oauth2/auth",
      token_uri: "https://oauth2.googleapis.com/token",
      auth_provider_x509_cert_url: "https://www.googleapis.com/oauth2/v1/certs",
      client_x509_cert_url: "https://www.googleapis.com/robot/v1/metadata/x509/service-test%40carambus-test.iam.gserviceaccount.com",
      universe_domain: "googleapis.com"
    }.to_json
    scopes = %w[https://www.googleapis.com/auth/calendar https://www.googleapis.com/auth/calendar.events]
    authorizer = Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: StringIO.new(google_creds_json),
      scope: scopes
    )
    service = Google::Apis::CalendarV3::CalendarService.new
    service.authorization = authorizer
    calendar_id = Rails.application.credentials[:location_calendar_id]
    # Add timezone
    Time.zone = "UTC"

    # Parse dates
    meeting_start = Time.parse("#{params["location"]["date"]} #{params["location"]["start_time"]} UTC+2").iso8601
    meeting_end = Time.parse("#{params["location"]["date"]} #{params["location"]["end_time"]} UTC+2").iso8601

    event_object = Google::Apis::CalendarV3::Event.new(
      summary: params["location"]["summary"],
      start: {
        date_time: meeting_start,
        time_zone: "UTC"
      },
      end: {
        date_time: meeting_end,
        time_zone: "UTC"
      }
    )
    response = service.insert_event(calendar_id, event_object)
    Rails.logger.info response.inspect
  end

  def toggle_dark_mode
    if current_user.present?
      current_user.theme = current_user.theme == "dark" ? "light" : "dark"
      current_user.save
    end
    redirect_back fallback_location: @location
  end

  def merge
    if params[:merge].present? && params[:with].present?
      merge_location = Location.find(params[:merge])
      with_location_ids = Location.where(id: params[:with].split(",").map(&:strip).map(&:to_i)).map(&:id)
      merge_location.merge_locations(with_location_ids)
    end
    redirect_to locations_path
  end

  def add_tables_to
    table_kind = TableKind.find(params[:table_kind_id])
            next_name = (@location.tables.order(:name).last&.name || "Table 0").succ
    (1..params[:number].to_i).each do |_i|
      Table.create!(location: @location, name: next_name, table_kind: table_kind)
      @location.reload
      next_name = next_name.succ
    end
    redirect_to location_path(@location)
  rescue StandardError => e
    Rails.logger.info "#{e} #{e.backtrace}"
  end

  def new_league_tournament
    @league = League.find_by_id(params["league_id"])
    @tournament = Tournament.new(single_or_league: "league", league: @league,
                                 region: (@league.organizer if @league.organizer.is_a?(Region)))
  end

  # POST /locations
  def create
    @location = Location.new(location_params.merge(data: JSON.parse(location_params[:data])))
    if @location.save
      redirect_to @location, notice: "Location was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /locations/1
  def update
    if @location.update(location_params.merge(data: JSON.parse(location_params[:data])))
      redirect_to @location, notice: "Location was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /locations/1
  def destroy
    @location.destroy
    redirect_to locations_url, notice: "Location was successfully destroyed."
  end

  def scoreboard_free_game_karambol_new
    authorize! :manage, TableMonitor
    # controller logic
  end

  def scoreboard_free_game_quick
    authorize! :manage, TableMonitor
    # Reuse same player preparation logic as scoreboard_free_game_karambol_new
    # The view is ultra-simple for Pi 3 performance
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_location
    Rails.logger.info "Session Data: #{session.to_hash}"
    # Optimize query with eager loading
    @location = Location.includes(
      tables: [
        :table_kind,
        :table_monitor,
        { table_monitor: :tournament_monitor }
      ],
      clubs: []
    ).preload(:organizer).find_by_md5(params[:id]) || Location.includes(
      tables: [
        :table_kind,
        :table_monitor,
        { table_monitor: :tournament_monitor }
      ],
      clubs: []
    ).preload(:organizer).find(params[:id])

    if @location.present?
      @display_only = if params[:display_only] == "false"
                        false
                      else
                        session[:display_only].presence &&
                          JSON.parse(session[:display_only].to_s) || params[:display_only] == "true"
                      end
      session[:display_only] = JSON.parse(@display_only.to_s)
      session[:location_id] = @location.id
      unless current_user.present?
        @user = User.scoreboard
        if @user&.valid?
          bypass_sign_in @user, scope: :user
          Rails.logger.info "Session Data after auto sign_in: #{session.to_hash}"
          Current.user = @user
        else
          flash[:error] = @user.errors.full_messages
        end
      end
    else
      # Optimize fallback query with same eager loading
      @location = Location.includes(
        tables: [
          :table_kind,
          :table_monitor,
          { table_monitor: :tournament_monitor }
        ],
        clubs: []
      ).find(params[:id])
    end

    # Preload tables to avoid N+1 queries
    @tables = @location.tables.to_a

    # Preload tournament tables using loaded tables instead of new queries
    @tournament_tables = @tables.select do |t|
      if t.table_monitor.blank?
        t.table_monitor!
        t.reload
      end
      t.table_monitor&.tournament_monitor_id.present? &&
        %w[new ready ready_for_new_match].include?(t.table_monitor.state)
    end

    @free_tables = @tables - @tournament_tables
    @location.table_kinds = @table_kinds = @free_tables.map(&:table_kind).uniq
  end

  # Only allow a trusted parameter "white list" through.
  def location_params
    params.require(:location).permit(:organizer_id, :organizer_type, :region_id, :address, :data, :name, :season_id, :merge, :with)
  end

  def preload_tournament_data
    @tournaments = @location.tournaments
                            .includes(
                              :tournament_monitor,
                              :discipline,
                              tournament_monitor: {
                                table_monitors: [
                                  :table,
                                  { game: { game_participations: :player } }
                                ]
                              },
                              location: {
                                tables: [
                                  :table_kind,
                                  { table_kind: :disciplines },
                                  { table_monitor: [
                                    :game,
                                    { game: { game_participations: :player } }
                                  ] }
                                ]
                              }
                            )
                            .joins(:tournament_monitor)
                            .order("tournament_monitors.updated_at desc")

    # Preload parties and their monitors
    @parties = @location.parties.includes(:party_monitor, league: :season)

    # Preload table kinds if needed
    @table_kinds = TableKind.where(id: @location.tables.select(:table_kind_id).distinct)
  end

  def preload_tables_data
    @tables = @location.tables
                       .includes(
                         :table_kind,
                         table_kind: :disciplines,
                         table_monitor: [
                           :tournament_monitor,
                           :game,
                           { game: {
                             game_participations: {
                               player: :season_participations
                             }
                           } }
                         ]
                       )
  end
end
