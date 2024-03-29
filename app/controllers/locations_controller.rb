class LocationsController < ApplicationController
  include FiltersHelper
  before_action :set_location, only: [:scoreboard, :show, :edit, :update, :destroy, :new_league_tournament, :add_tables_to]

  # GET /locations
  def index
    @locations = Location.includes(:club, :region).sort_by_params(params[:sort], sort_direction)
    if @sSearch.present?
      @locations = apply_filters(@locations, Location::COLUMN_NAMES, "(locations.name ilike :search) or (locations.address ilike :search)")
    end
    @pagy, @locations = pagy(@locations) if @locations.present?
    respond_to do |format|
      format.html {
        if params[:table_only].present?
          params.reject! { |k, v| k.to_s == "table_only" }
          render(partial: "search", :layout => false)
        else
          render("index")
        end
      }
    end
  end

  # GET /locations/1
  def show
    if Current.user == User.scoreboard
      @table = @game = @table_monitor = @player_a = @player_b = nil
      session[:sb_state] ||= "welcome"
      session[:sb_state] = params[:sb_state] if params[:sb_state].present?

      @navbar = @footer = false
      @game = (Game.find(params[:terminate_game_id]) rescue nil) if session[:sb_state] == "tables" && params[:terminate_game_id].present?
      @game.destroy if @game.present? && @game.tournament.blank?
      @game.table_monitor.andand.reset_table_monitor if @game.present? && @game.tournament.present? && !@game.table_monitor.andand.playing_game?
      @table = Table.find(params[:table_id]) if params[:table_id].present?
      case session[:sb_state]
      when "welcome"
        render "scoreboard_welcome"
      when "start"
        render "scoreboard_start", locals: { table: @table }
      when "tournament"
        render "scoreboard_tournament"
      when "tables"
        render "scoreboard_tables"
      when "training"
        render "scoreboard_training"
      when "free_game"
        @table = Table.find(params[:table_id]) if params[:table_id].present?
        @player_a = Player.find(params[:player_a_id]) if params[:player_a_id].present?
        @player_b = Player.find(params[:player_b_id]) if params[:player_b_id].present?
        Table.transaction do
          if @table.present?
            @table_monitor = @table.table_monitor
            @game = @table_monitor.game
            if @game.blank?
              @game = Game.create!
              @game.game_participations.create(player: @player_a, role: "playera")
              @game.game_participations.create(player: @player_a, role: "playerb")
              @innings = 20
            end
            @table_monitor.assign_game(@game)
          end
        end
        @club = @location.club.presence
        @club_player_ids = (@club.players.select("players.id").joins(season_participations: :season).where("seasons.id = ?", Season.current_season.id).map(&:id)) if @club.present?
        @guest_player_ids = (@club.players.select("players.id").where("players.guest IS TRUE").map(&:id) - @club_player_ids) if @club.present?
        @players = Player.where(id: @guest_player_ids + (@club_player_ids.to_a - @guest_player_ids.to_a)).order("guest  desc nulls last", :firstname, :lastname)
        @player_names = @players.map { |p| "#{p.firstname} #{p.lastname}" }
        @player_ids = @players.map(&:id)
        @kickoff_switches_with_set = true
        @color_remains_with_set = true
        @allow_overflow = false
        @allow_follow_up = true
        if @table.present?
          render "scoreboard_free_game_#{TableKind::TABLE_KIND_FREE_GAME_SETUP[@table.table_kind.name]}"
          return
        end
      end
    end
  end

  def scoreboard
    session[:location_id] = @location.id
    sb_state = params[:sb_state] || "welcome"
    if current_user.present?
      sign_out(current_user)
      @user = User.scoreboard
      bypass_sign_in @user, scope: :user
      Current.user = @user
    end
    redirect_to "/locations/#{@location.md5}?sb_state=#{sb_state}"
  end

  def game_results
    @navbar = @footer = false
    @tournament = nil
    @location = Location.find(params[:id])
    if params[:tournament_id].present?
      @tournament = Tournament.find(params[:tournament_id])
    end
  end

  def placement
    @navbar = @footer = false
    @tournament = nil
    @table = Table.find(params[:table_id])
    info = "+++ 1a - locations_controller#placement @table"; DebugInfo.instance.update(info: info); Rails.logger.info info
    @location = Location.find(params[:id])
    info = "+++ 1b - locations_controller#placement @location"; DebugInfo.instance.update(info: info); Rails.logger.info info
    if params[:tournament_id].present?
      @tournament = Tournament.find(params[:tournament_id])
      info = "+++ 1c - locations_controller#placement @tournament"; DebugInfo.instance.update(info: info); Rails.logger.info info
      # @game = @table.table_monitor.andand.game
      # info = "+++ 1d - locations_controller#placement @game"; DebugInfo.instance.update(info: info); Rails.logger.info info
      # if @game.present? && @table.table_monitor.andand.data.present?
      #   tmp_results = {}
      #   if @table.table_monitor.andand.data["ba_results"].present?
      #     info = "+++ 1e - locations_controller#placement"; DebugInfo.instance.update(info: info); Rails.logger.info info
      #     tmp_results["ba_results"] = @table.table_monitor.data["ba_results"].dup
      #     tmp_results["state"] = @table.table_monitor.state
      #     info = "+++ 2x - locations_controller#placement"; DebugInfo.instance.update(info: info); Rails.logger.info info
      #     @game.deep_merge_data!("tmp_results" => tmp_results)
      #     @table.table_monitor.update(state: "ready", game_id: nil, data: {})
      #   elsif @table.table_monitor.andand.data["current_inning"].present? && @table.table_monitor.data["playera"].present? && @table.table_monitor.data["playerb"].present?
      #     info = "+++ 2e - locations_controller#placement"; DebugInfo.instance.update(info: info); Rails.logger.info info
      #     tmp_results["playera"] = @table.table_monitor.data["playera"].dup
      #     tmp_results["playerb"] = @table.table_monitor.data["playerb"].dup
      #     tmp_results["current_inning"] = @table.table_monitor.data["current_inning"].dup if
      #     tmp_results["state"] = @table.table_monitor.state
      #     info = "+++ 2y - locations_controller#placement"; DebugInfo.instance.update(info: info); Rails.logger.info info
      #     @game.deep_merge_data!("tmp_results" => tmp_results)
      #     @table.table_monitor.update(state: "ready", game_id: nil, data: {})
      #   end
      # end
      info = "+++ 3l - locations_controller#placement"; DebugInfo.instance.update(info: info); Rails.logger.info info
      @games = @tournament.games.joins(:game_participations => :player).where(game_participations: { role: "playera" }).to_a.sort_by { |game| game.game_participations.where(role: "playera").first.player.andand.lastname.to_s + game.game_participations.where(role: "playerb").first.player.andand.lastname.to_s }.select { |game| game.data.blank? || game.data["ba_results"].blank? }
      @pairs = []
      @games.map do |game|
        gpa = game.game_participations.where(role: "playera").first; playera = gpa.andand.player
        seeding_state_a = game.tournament.seedings.where(player_id: playera.id).first.andand.state
        gpb = game.game_participations.where(role: "playerb").first; playerb = gpb.andand.player
        seeding_state_b = game.tournament.seedings.where(player_id: playerb.id).first.andand.state
        unless seeding_state_a == "no_show" || seeding_state_b == "no_show"
          @pairs << [game.id, playera.fullname, playerb.fullname, "game_#{game.id}a"]
          @pairs << [game.id, playerb.fullname, playera.fullname, "game_#{game.id}b"]
        end
      end
      @pairs = @pairs.sort_by { |a| "#{a[1]} - #{a[2]}" }
    else
      redirect_to location_path(@location, table_id: @table.id, sb_state: "free_game", player_a_id: @player_a.andand.id, player_b_id: @player_b.andand.id)
    end
  end

  # GET /locations/new
  def new
    @location = Location.new
    if params[:club_id].present?
      @club = Club.find(params[:club_id])
    end
    if params[:region_id].present?
      @region = Region.find(params[:region_id])
    end
  end

  # GET /locations/1/edit
  def edit
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
    next_name = (@location.tables.order(:name).last.andand.name || "Table 0").succ
    (1..params[:number].to_i).each do |i|
      @location.tables.create(name: next_name, table_kind: table_kind)
      next_name = next_name.succ
    end
    redirect_to locations_path
  end

  def new_league_tournament
    @league = League.find_by_id(params["league_id"])
    @tournament = Tournament.new(single_or_league: "league", league: @league, region: (@league.organizer if @league.organizer.is_a?(Region)))
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

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_location
    @location = Location.find_by_md5(params[:id])
    if @location.present?
      @display_only = params[:display_only] == "false" ? false : session[:display_only].presence && JSON.parse(session[:display_only].to_s) || params[:display_only] == "true"
      session[:display_only] = JSON.parse(@display_only.to_s)
      session[:location_id] = @location.id
      unless current_user.present?
        @user = User.scoreboard
        bypass_sign_in @user, scope: :user
        Current.user = @user
      end
    else
      @location = Location.find(params[:id])
    end
  end

  # Only allow a trusted parameter "white list" through.
  def location_params
    params.require(:location).permit(:club_id, :region_id, :address, :data, :name, :season_id, :club_id, :merge, :with)
  end
end
