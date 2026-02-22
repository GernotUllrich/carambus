# frozen_string_literal: true

# Locations associated with tables are the places where tournaments and match days are executed
class LocationsController < ApplicationController
  attr_accessor :game

  include FiltersHelper
  before_action :set_location,
                only: %i[scoreboard scoreboard_overlay scoreboard_text show edit update destroy
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
    # Erlaube Scoreboard-Zugriff wenn: Scoreboard-User angemeldet ODER table_id vorhanden ODER sb_state vorhanden
    return unless Current.user == User.scoreboard || params[:table_id].present? || params[:sb_state].present?

    table = game = table_monitor = player_b = player_a = nil
    session[:sb_state] ||= "welcome"
    session[:sb_state] = params[:sb_state] if params[:sb_state].present?
    
    # Clear table selection when entering "start" or "tables" state without explicit table_id
    # This ensures users can select a table fresh instead of being stuck with an old session table
    if (session[:sb_state] == "start" || session[:sb_state] == "tables") && params[:table_id].blank?
      session[:scoreboard_table_id] = nil
      Rails.logger.info "[Scoreboard] 🎯 Cleared session table_id for fresh selection (sb_state: #{session[:sb_state]})"
    end
    tournament = Tournament.find(params[:tournament_id]) if params[:tournament_id].present?
    @navbar = @footer = false

    # Set @table if table_id is present (from params or session)
    # IMPORTANT: Prefer params[:table_id] over session to allow table switching
    # But fallback to session[:scoreboard_table_id] if params is missing (e.g., page reload)
    # EXCEPTION: For "start" and "tables" states, don't restore from session to allow fresh table selection
    if params[:table_id].present?
      @table = Table.find(params[:table_id])
      # Update session with current table_id
      session[:scoreboard_table_id] = params[:table_id]
      Rails.logger.info "[Scoreboard] 🎯 Table set from params: #{@table.id} (location: #{@location.id})"
    elsif session[:scoreboard_table_id].present? && !%w[start tables].include?(session[:sb_state])
      # Only restore from session if not in "start" or "tables" state (which should show table selection)
      @table = Table.find(session[:scoreboard_table_id])
      Rails.logger.info "[Scoreboard] 🎯 Table restored from session: #{@table.id} (location: #{@location.id})"
    else
      # Clear table for "start" and "tables" states to ensure fresh table selection
      @table = nil
      Rails.logger.info "[Scoreboard] 🎯 Table cleared for fresh selection (sb_state: #{session[:sb_state]})"
    end

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
        # Blockiere wenn Turnierspiel läuft
        if @table.present?
          table_monitor = @table.table_monitor
          if table_monitor&.tournament_monitor_id.present?
            flash[:error] = I18n.t('errors.tournament_game_manipulation_blocked',
                                  default: 'Spielmanipulationen sind während eines Turniers nicht erlaubt.')
            redirect_to location_path(@location, sb_state: "welcome") and return
          end
        end
        
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
          
          guest_players_default = Player.where(id: [default_guest_a.player.id,
                                                    default_guest_b.player.id]).order("fl_name")
          guest_players_other = Player.joins(season_participations: %i[club season])
                                      .where(clubs: { id: club.id })
                                      .where.not(id: [default_guest_a.player.id,
                                                      default_guest_b.player.id])
                                      .where(season_participations: { status: "guest" })
                                      .where(seasons: { id: Season.current_season&.id })
                                      .order("fl_name")

          club_players = Player.where(id: club_player_ids).order("fl_name")
          
          if @table.present?
            @bg_color ||= "#1B0909"
            render "scoreboard_free_game_karambol_quick",
                   locals: {
                     table: @table,
                     table_monitor: table_monitor,
                     club: club,
                     guest_players_default: guest_players_default,
                     guest_players_other: guest_players_other,
                     club_players: club_players,
                     player_a: player_a,
                     player_b: player_b,
                     default_guest_a: default_guest_a,
                     default_guest_b: default_guest_b
                   }
          end
        end
      when "free_game_detail"
        # Original detailed configuration with Alpine.js
        # Blockiere wenn Turnierspiel läuft
        if @table.present?
          table_monitor = @table.table_monitor
          if table_monitor&.tournament_monitor_id.present?
            flash[:error] = I18n.t('errors.tournament_game_manipulation_blocked',
                                  default: 'Spielmanipulationen sind während eines Turniers nicht erlaubt.')
            redirect_to location_path(@location, sb_state: "welcome") and return
          end
        end
        
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
    
    # IMPORTANT: Persist table_id in session to prevent scoreboard mix-ups
    # This ensures that after page reloads, the correct table is displayed
    if params[:table_id].present?
      session[:scoreboard_table_id] = params[:table_id]
      Rails.logger.info "[Scoreboard] 🎯 Session table_id set: #{session[:scoreboard_table_id]} (location: #{@location.id})"
    end
    
    # Auto-Login zum Scoreboard-User nur wenn kein User angemeldet ist
    # Wenn ein User bereits angemeldet ist, bleibt current_user erhalten
    unless current_user.present?
      @user = User.scoreboard
      bypass_sign_in @user, scope: :user
      Current.user = @user
    end
    
    # config/scoreboard_url is never overwritten by the app. For the local server (e.g. kiosk),
    # set it once (e.g. with sb_state=table_scores); the browser reads it on start/restart.
    redirect_to location_url(@location, sb_state: sb_state, locale: params[:locale], host: request.server_name, port: request.server_port)
  end

  # Minimal scoreboard view for streaming overlay
  # This renders a lightweight version without UI chrome for use in FFmpeg video overlay
  def scoreboard_overlay
    @navbar = @footer = false
    @minimal = true
    
    # Get table from params - use table_id for uniqueness (not table number!)
    # Table numbers can be ambiguous (e.g., "Tisch 1" for both small and large tables)
    if params[:table_id].present?
      @table = @location.tables.find_by(id: params[:table_id])
    elsif params[:table].present?
      # Legacy fallback: try to find by number (deprecated, ambiguous!)
      table_number = params[:table]&.to_i
      @table = @location.tables.find_by(name: "Tisch #{table_number}")
    end
    
    @table ||= @location.tables.first # Fallback to first table
    
    # Get current game on this table
    @table_monitor = @table&.table_monitor
    @game = @table_monitor&.game
    @tournament_monitor = @table_monitor&.tournament_monitor
    @tournament = @tournament_monitor&.tournament
    
    # Render minimal overlay layout
    render layout: 'streaming_overlay'
  end

  # Text-based scoreboard data for FFmpeg drawtext filter
  def scoreboard_text
    # Get table from params
    if params[:table_id].present?
      @table = @location.tables.find_by(id: params[:table_id])
    elsif params[:table].present?
      table_number = params[:table]&.to_i
      @table = @location.tables.find_by(name: "Tisch #{table_number}")
    end
    
    @table ||= @location.tables.first
    
    # Get current game on this table
    @table_monitor = @table&.table_monitor
    @game = @table_monitor&.game
    @tournament_monitor = @table_monitor&.tournament_monitor
    @tournament = @tournament_monitor&.tournament
    
    # Build text output
    text_lines = []
    
    if @game.present? && @table_monitor.present?
      # Get fresh options from table monitor
      @table_monitor.get_options!(I18n.locale)
      options = @table_monitor.options
      
      if options.present?
        # Use the same logic as scoreboard_overlay view
        left_player = options[:current_left_player] == "playera" ? options[:player_a] : options[:player_b]
        right_player = options[:current_left_player] == "playera" ? options[:player_b] : options[:player_a]
        left_player_id = options[:current_left_player] == "playera" ? "playera" : "playerb"
        right_player_id = options[:current_left_player] == "playera" ? "playerb" : "playera"
        left_player_active = options[:current_left_player] == "playera" ? options[:player_a_active] : options[:player_b_active]
        right_player_active = options[:current_left_player] == "playera" ? options[:player_b_active] : options[:player_a_active]
        
        # Get current scores and inning balls
        left_inning_balls = @table_monitor.data[left_player_id]&.[]("innings_redo_list")&.last.to_i || 0
        right_inning_balls = @table_monitor.data[right_player_id]&.[]("innings_redo_list")&.last.to_i || 0
        left_score = left_player[:result].to_i + left_inning_balls
        right_score = right_player[:result].to_i + right_inning_balls
        
        # Format player names (remove "Dr. ")
        left_name = (left_player[:firstname].presence || left_player[:lastname]).to_s.gsub("Dr. ", "")
        right_name = (right_player[:firstname].presence || right_player[:lastname]).to_s.gsub("Dr. ", "")
        
        # Build player lines with right-aligned scores and inning balls
        # Format: "  Name:       Score (Balls)" with right alignment
        max_name_length = [left_name.length, right_name.length].max
        max_score_length = [left_score.to_s.length, right_score.to_s.length].max
        
        # Line 1: Table and LIVE indicator
        text_lines << "T#{@table&.number || '?'} • LIVE"
        
        # Line 2: Left player (with active indicator, right-aligned score)
        left_indicator = left_player_active ? '▶' : ' '
        left_inning_display = left_inning_balls > 0 ? " (#{left_inning_balls})" : ""
        left_line = "#{left_indicator} #{left_name.ljust(max_name_length)}:  #{left_score.to_s.rjust(max_score_length)}#{left_inning_display}"
        text_lines << left_line
        
        # Line 3: Right player (with active indicator, right-aligned score)
        right_indicator = right_player_active ? '▶' : ' '
        right_inning_display = right_inning_balls > 0 ? " (#{right_inning_balls})" : ""
        right_line = "#{right_indicator} #{right_name.ljust(max_name_length)}:  #{right_score.to_s.rjust(max_score_length)}#{right_inning_display}"
        text_lines << right_line
        
        # Line 4: Tournament info
        if @tournament.present?
          tournament_name = @tournament.try(:title) || @tournament.try(:name) || "Turnier"
          text_lines << tournament_name
        end
      else
        # Game exists but options not available yet
        text_lines << "T#{@table&.number || '?'} • LIVE"
        text_lines << "Spiel lädt..."
      end
    else
      # No active game
      text_lines << "#{@location&.name || 'Carambus'}"
      text_lines << "Tisch #{@table&.number || '?'} • Kein Spiel"
    end
    
    render plain: text_lines.join("\n"), content_type: 'text/plain'
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
    # Setup Google Calendar API service
    service = GoogleCalendarService.calendar_service
    calendar_id = GoogleCalendarService.calendar_id
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
    
    # Blockiere Zugriff wenn Turnierspiel läuft
    table = Table.find(params[:table_id]) if params[:table_id].present?
    if table&.table_monitor&.tournament_monitor_id.present?
      flash[:error] = I18n.t('errors.tournament_game_manipulation_blocked',
                            default: 'Spielmanipulationen sind während eines Turniers nicht erlaubt.')
      redirect_to location_path(table.location) and return
    end
    
    # controller logic
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
                       .to_a
    
    # Set @table_kinds based on actual tables present (not just free tables)
    # Filter out tables without table_kind and ensure uniqueness
    # This ensures only table kinds that actually have tables are shown
    @table_kinds = @tables
                     .select { |t| t.table_kind.present? }
                     .map(&:table_kind)
                     .uniq
                     .sort_by(&:name)
  end
end
