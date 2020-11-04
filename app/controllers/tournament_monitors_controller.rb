class TournamentMonitorsController < ApplicationController
  before_action :set_tournament_monitor, only: [:show, :edit, :update_games, :switch_players, :update, :destroy]

def switch_players
    @game = Game[params[:game_id]]
    if @game.present?
      roles = @game.game_participations.map(&:role).reverse
      @game.game_participations.each_with_index do |gp, ix|
        gp.update_attributes(role: roles[ix])
      end
    end
    redirect_to tournament_monitor_path(@tournament_monitor)
  end

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

  def update_games
    params["game_id"].each_with_index do |game_id,ix|
      game = @tournament_monitor.tournament.games.includes(:table_monitor).find(game_id)
      if game.present?
        table_monitor = game.table_monitor
        table_monitor.data["playera"]["result"] = params["resulta"][ix].to_i
        table_monitor.data["playerb"]["result"] = params["resultb"][ix].to_i
        table_monitor.data["playera"]["innings"] = params["inningsa"][ix].to_i
        table_monitor.data["playerb"]["innings"] = params["inningsb"][ix].to_i
        table_monitor.data["playera"]["hs"] = params["hsa"][ix].to_i
        table_monitor.data["playerb"]["hs"] = params["hsb"][ix].to_i
        table_monitor.data["playera"]["gd"] = sprintf("%.2f", table_monitor.data["playera"]["result"].to_f / table_monitor.data["playera"]["innings"])
        table_monitor.data["playerb"]["gd"] = sprintf("%.2f", table_monitor.data["playerb"]["result"].to_f / table_monitor.data["playerb"]["innings"])
        table_monitor.data_will_change!
        table_monitor.save
        game.update_attributes(ended_at: Time.now)
        @tournament_monitor.update_game_participations(table_monitor)
        table_monitor.evaluate_result
      end
    end
    redirect_back(fallback_location: tournament_monitor_path(@tournament_monitor))
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
