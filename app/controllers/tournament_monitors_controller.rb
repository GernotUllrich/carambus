class TournamentMonitorsController < ApplicationController
  before_action :set_tournament_monitor, only: [:show, :edit, :update, :destroy]

  # GET /tournament_monitors
  # GET /tournament_monitors.json
  def index
    @tournament_monitors = TournamentMonitor.all
  end

  # GET /tournament_monitors/1
  # GET /tournament_monitors/1.json
  def show
  end

  # GET /tournament_monitors/new
  def new
    @tournament_monitor = TournamentMonitor.new
  end

  # GET /tournament_monitors/1/edit
  def edit
  end

  # POST /tournament_monitors
  # POST /tournament_monitors.json
  def create
    @tournament_monitor = TournamentMonitor.new(tournament_monitor_params)

    respond_to do |format|
      if @tournament_monitor.save
        format.html { redirect_to @tournament_monitor, notice: 'Tournament execution was successfully created.' }
        format.json { render :show, status: :created, location: @tournament_monitor }
      else
        format.html { render :new }
        format.json { render json: @tournament_monitor.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /tournament_monitors/1
  # PATCH/PUT /tournament_monitors/1.json
  def update
    respond_to do |format|
      if @tournament_monitor.update(tournament_monitor_params)
        format.html { redirect_to @tournament_monitor, notice: 'Tournament execution was successfully updated.' }
        format.json { render :show, status: :ok, location: @tournament_monitor }
      else
        format.html { render :edit }
        format.json { render json: @tournament_monitor.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /tournament_monitors/1
  # DELETE /tournament_monitors/1.json
  def destroy
    @tournament_monitor.destroy
    respond_to do |format|
      format.html { redirect_to tournament_monitors_url, notice: 'Tournament execution was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_tournament_monitor
      @tournament_monitor = TournamentMonitor.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def tournament_monitor_params
      params.require(:tournament_monitor).permit(:tournament_id, :data, :state)
    end
end
