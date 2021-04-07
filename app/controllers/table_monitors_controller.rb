class TableMonitorsController < ApplicationController
  before_action :set_table_monitor, only: [:show, :start_game, :edit, :update, :destroy, :set_balls, :toggle_dark_mode]

  def set_balls
    unless @table_monitor.set_n_balls_to_current_players_inning(params[:add_balls].to_i)
      flash.now[:alert] = @msg
      flash.keep[:alert]
    end
    redirect_back(fallback_location: tournament_monitor_path(@table_monitor.tournament_monitor))
  end

  # GET /table_monitors
  def index
    @pagy, @table_monitors = pagy(TableMonitor.sort_by_params(params[:sort], sort_direction))

    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @table_monitors.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @table_monitors.load
  end

  # GET /table_monitors/1
  def show
    @navbar = false
    @footer = false
    @dark = session[:dark_scoreboard].present? ? JSON.parse(session[:dark_scoreboard]) : false
    @current_element = ""
  end

  # GET /table_monitors/new
  def new
    @table_monitor = TableMonitor.new
  end

  def toggle_dark_mode
    session[:dark_scoreboard] = !(session[:dark_scoreboard].present? ? JSON.parse(session[:dark_scoreboard]) : false)
    redirect_to @table_monitor
  end

  def start_game
    @game = @table_monitor.game
    if @game.blank?
      @game = Game.create!(table_monitor: @table_monitor)
    else
      @game.game_participations.destroy_all
    end
    @game.update(data: {})
    @game.game_participations.create!(player: (params[:player_a_id].to_i > 0 ? Player.find(params[:player_a_id]) : nil), role: "playera")
    @game.game_participations.create!(player: (params[:player_b_id].to_i > 0 ? Player.find(params[:player_b_id]) : nil), role: "playerb")

    result = { "result" => {
      "playera" => {
        "balls_goal" => params[:balls_goal_a],
        "inings" => params[:innings],
        "discipline" => params[:discipline_a],
      },
      "playerb" => {
        "balls_goal" => params[:balls_goal_b],
        "inings" => params[:innings],
        "discipline" => params[:discipline_b],
      },
    }
    }
    @table_monitor.initialize_game
    @table_monitor.deep_merge_data!(result)
    @navbar = false
    @footer = false

    redirect_to (@table_monitor)
  end

  # GET /table_monitors/1/edit
  def edit
  end

  # POST /table_monitors
  def create
    @table_monitor = TableMonitor.new(table_monitor_params)

    if @table_monitor.save
      redirect_to @table_monitor, notice: "Table monitor was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /table_monitors/1
  def update
    if @table_monitor.update(table_monitor_params)
      redirect_to @table_monitor, notice: "Table monitor was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /table_monitors/1
  def destroy
    @table_monitor.destroy
    redirect_to table_monitors_url, notice: "Table monitor was successfully destroyed."
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_table_monitor
    @table_monitor = TableMonitor.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def table_monitor_params
    params.require(:table_monitor).permit(:tournament_monitor_id, :state, :name, :game_id, :next_game_id, :data, :ip_address)
  end
end
