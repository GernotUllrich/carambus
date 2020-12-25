class TableMonitorsController < ApplicationController
  before_action :set_table_monitor, only: [:show, :edit, :update, :destroy, :set_balls, :up, :down, :add_one, :add_ten, :undo, :next_step]

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
  end

  # GET /table_monitors/new
  def new
    @table_monitor = TableMonitor.new
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
