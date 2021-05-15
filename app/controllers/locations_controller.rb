class LocationsController < ApplicationController
  include FiltersHelper
  before_action :set_location, only: [:scoreboard, :show, :edit, :update, :destroy, :add_tables_to]

  # GET /locations
  def index
    @locations = Location.sort_by_params(params[:sort], sort_direction)
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
      @table = @table_monitor = @player_a = @player_b = nil
      session[:sb_state] ||= "welcome"
      session[:sb_state] = params[:sb_state] if params[:sb_state].present?

      @navbar = @footer = false
      @table = Table.find(params[:table_id]) if params[:table_id].present?
      case session[:sb_state]
      when "welcome"
        render "scoreboard_welcome"
      when "start"
        render "scoreboard_start", locals: {table: @table}
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
        if @table.present?
          @table_monitor = @table.table_monitor || TableMonitor.create!(table_id: @table.id)
          @game = @table_monitor.game
          if @game.blank?
            @game = Game.create!
            @game.game_participations.create(player: @player_a, role: "playera")
            @game.game_participations.create(player: @player_a, role: "playerb")
          end
          @table_monitor.assign_game(@game)
        end
        @players = @location.club.players.joins(season_participations: :season).where("seasons.id = ?", Season.current_season.id).order(:lastname, :firstname)
        @player_names = @players.map { |p| "#{p.lastname}, #{p.firstname}" }
        @player_ids = @players.map(&:id)
        if @table.present?
          render "scoreboard_free_game"
          return
        end
      end
    end
  end

  def scoreboard
    session[:location_id] = @location.id
    if current_user.present?
      sign_out(current_user)
      @user = User.find_by_first_name("scoreboard")
      bypass_sign_in @user, scope: :user
      Current.user = @user
    end
    redirect_to "/locations/#{@location.md5}"
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
      @games = @tournament.games.joins(:game_participations => :player).where(game_participations: { role: "playera" }).to_a.sort_by { |game| game.game_participations.where(role: "playera").first.player.lastname + game.game_participations.where(role: "playerb").first.player.lastname }.select { |game| game.data.blank? || game.data["ba_results"].blank? }
      @pairs = []
      @games.map do |game|
        gpa = game.game_participations.where(role: "playera").first; playera = gpa.andand.player
        gpb = game.game_participations.where(role: "playerb").first; playerb = gpb.andand.player
        @pairs << [game.id, playera.fullname, playerb.fullname, "game_#{game.id}a"]
        @pairs << [game.id, playerb.fullname, playera.fullname, "game_#{game.id}b"]
      end
      @pairs = @pairs.sort_by { |a| "#{a[1]} - #{a[2]}" }
    else
      redirect_to location_path(@location, table_id: @table.id, sb_state: "free_game", player_a_id: @player_a.andand.id, player_b_id: @player_b.andand.id)
    end
  end

  # GET /locations/new
  def new
    @location = Location.new
    @organizer = Club.find(params[:club_id]) || Region.find(params[:club_id])
  end

  # GET /locations/1/edit
  def edit
  end

  def merge
    if params[:merge].present? && params[:with].present?
      @merge_location = Location.find(params[:merge])
      @with_location_ids = Location.where(id: params[:with].split(",").map(&:strip).map(&:to_i)).map(&:id)
      if @merge_location.present? && @with_location_ids.present?
        Tournament.where(location_id: @with_location_ids).update_all(location_id: @merge_location.id)
        Location.where(id: @with_location_ids).destroy_all
      end
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
      session[:location_id] = @location.id
      unless current_user.present?
        @user = User.find_by_first_name("scoreboard")
        bypass_sign_in @user, scope: :user
        Current.user = @user
      end
    else
      @location = Location.find(params[:id])
    end
  end

  # Only allow a trusted parameter "white list" through.
  def location_params
    params.require(:location).permit(:club_id, :address, :data, :name, :merge, :with)
  end
end
