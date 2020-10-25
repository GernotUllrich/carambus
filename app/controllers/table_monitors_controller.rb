class TableMonitorsController < ApplicationController
  before_action :set_table_monitor, only: [:show, :edit, :update, :destroy, :set_balls, :add_one, :add_ten, :redo, :undo, :next_step]

  def set_balls
    unless @table_monitor.set_n_balls_to_current_players_inning(params[:add_balls].to_i)
      flash.now[:alert] = @msg
      flash.keep[:alert]
    end
    redirect_back(fallback_location: tournament_monitor_path(@table_monitor.tournament_monitor))
  end

  def add_one
    unless @table_monitor.add_n_balls_to_current_players_inning(1)
      flash.now[:alert] = @msg
      flash.keep[:alert]
    end
    redirect_back(fallback_location: tournament_monitor_path(@table_monitor.tournament_monitor))
  end

  def add_ten
    unless @table_monitor.add_n_balls_to_current_players_inning(10)
      flash.now[:alert] = @msg
      flash.keep[:alert]
    end
    redirect_back(fallback_location: tournament_monitor_path(@table_monitor.tournament_monitor))
  end

  def redo

  end

  def undo

  end

  def next_step
    unless @table_monitor.terminate_current_inning
      flash[:alert] = @table_monitor.msg
    end
    redirect_back(fallback_location: tournament_monitor_path(@table_monitor.tournament_monitor))
  end

  # GET /table_monitors
  # GET /table_monitors.json
  def index
    @table_monitors = TableMonitor.all
  end

  # GET /table_monitors/1
  # GET /table_monitors/1.json
  def show
  end

  # GET /table_monitors/new
  def new
    @table_monitor = TableMonitor.new
  end

  # GET /table_monitors/1/edit
  def edit
  end

  # POST /table_monitors
  # POST /table_monitors.json
  def create
    @table_monitor = TableMonitor.new(table_monitor_params)

    respond_to do |format|
      if @table_monitor.save
        format.html { redirect_to @table_monitor, notice: 'Table monitor was successfully created.' }
        format.json { render :show, status: :created, location: @table_monitor }
      else
        format.html { render :new }
        format.json { render json: @table_monitor.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /table_monitors/1
  # PATCH/PUT /table_monitors/1.json
  def update
    respond_to do |format|
      if @table_monitor.update(table_monitor_params)
        format.html { redirect_to @table_monitor, notice: 'Table monitor was successfully updated.' }
        format.json { render :show, status: :ok, location: @table_monitor }
      else
        format.html { render :edit }
        format.json { render json: @table_monitor.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /table_monitors/1
  # DELETE /table_monitors/1.json
  def destroy
    @table_monitor.destroy
    respond_to do |format|
      format.html { redirect_to table_monitors_url, notice: 'Table monitor was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_table_monitor
    @table_monitor = TableMonitor.find(params[:id])
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def table_monitor_params
    params.require(:table_monitor).permit(:state, :name, :game_id, :next_game_id, :data)
  end
end
