# frozen_string_literal: true

class TableMonitorsController < ApplicationController
  before_action :set_table_monitor,
                only: %i[show start_game edit update destroy evaluate_result set_balls toggle_dark_mode]

  def set_balls
    unless @table_monitor.set_n_balls(params[:add_balls].to_i)
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
    if @table_monitor.game_id.blank?
      redirect_to location_path(@table_monitor.table.location, sb_state: 'start', table_id: @table_monitor.table.id)
      return
    end
    @navbar = false
    @footer = false
    @dark = session[:dark_scoreboard].present? ? JSON.parse(session[:dark_scoreboard].to_s) : false
    @current_element = ''
    @table_monitor.evaluate_panel_and_current
    # noinspection RubyResolve
    ClockJob.perform_later(@table_monitor, 5) if @table_monitor.andand.playing_game?
  end

  # GET /table_monitors/new
  def new
    # @table_monitor = TableMonitor.new
  end

  def toggle_dark_mode
    session[:dark_scoreboard] =
      !(session[:dark_scoreboard].present? ? JSON.parse(session[:dark_scoreboard].to_s) : false)
    redirect_to @table_monitor
  end

  def start_game
    res = @table_monitor.start_game(params.slice(:player_a_id, :player_b_id, :timeouts, :timeout,
                                                 :balls_goal_a, :balls_goal_b, :innings_goal, :discipline_a,
                                                 :discipline_b))
    @navbar = false
    @footer = false
    if res
      redirect_to @table_monitor
    else
      redirect_to "/locations/#{table.location.id}?sb_state=free_game&table_id=#{table.id}"
    end
  end

  def evaluate_result
    @table_monitor.evaluate_result
    redirect_to tournament_monitor_path(@table_monitor.tournament_monitor)
  end

  # GET /table_monitors/1/edit
  def edit; end

  # POST /table_monitors
  def create
    # @table_monitor = TableMonitor.new(table_monitor_params)
    #
    # if @table_monitor.save
    #   redirect_to @table_monitor, notice: "Table monitor was successfully created."
    # else
    #   render :new
    # end
  end

  # PATCH/PUT /table_monitors/1
  def update
    if @table_monitor.update(table_monitor_params)
      redirect_to @table_monitor, notice: 'Table monitor was successfully updated.'
    else
      render :edit
    end
  end

  # DELETE /table_monitors/1
  def destroy
    @table_monitor.destroy
    redirect_to table_monitors_url, notice: 'Table monitor was successfully destroyed.'
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_table_monitor
    @table_monitor = TableMonitor.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def table_monitor_params
    params.require(:table_monitor).permit(:tournament_monitor_id, :state, :name, :game_id, :next_game_id, :data,
                                          :ip_address, :player_a_id, :player_b_id, :balls_goal, :balls_goal_a,
                                          :balls_goal_b, :discipline, :discipline_a, :discipline_b, :innings_goal,
                                          :timeout, :timeouts)
  end
end
