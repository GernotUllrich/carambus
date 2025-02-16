class TournamentMonitorsController < ApplicationController
  before_action :set_tournament_monitor, only: %i[show edit update destroy update_games switch_players]

  def switch_players
    @game = Game[params[:game_id]]
    if @game.present?
      roles = @game.game_participations.map(&:role).reverse
      @game.game_participations.each_with_index do |gp, ix|
        gp.update(role: roles[ix])
      end
    end
    redirect_to tournament_monitor_path(@tournament_monitor)
  end

  def update_games
    seqno_keys = params.keys.select { |k| k =~ /seqno_(\d+)/ && params[k].present? }
    seqno_keys.each do |k|
      game_id = k.match(/seqno_(\d+)/)[1]
      Game[game_id].update(seqno: params[k].to_i)
    end
    params["game_id"].andand.each_with_index do |game_id, ix|
      game = @tournament_monitor.tournament.games.where("id >= #{Game::MIN_ID}").includes(:table_monitor).find(game_id)
      next unless game.present?

      table_monitor = game.table_monitor
      next unless (table_monitor.data["playera"]["balls_goal"].to_i == 0 || params["resulta"][ix].to_i <= table_monitor.data["playera"]["balls_goal"].to_i) &&
                  (table_monitor.data["playerb"]["balls_goal"].to_i == 0 || params["resultb"][ix].to_i <= table_monitor.data["playerb"]["balls_goal"].to_i) &&
                  (table_monitor.data["innings_goal"].to_i == 0 || params["inningsa"][ix].to_i <= table_monitor.data["innings_goal"].to_i) &&
                  (table_monitor.data["innings_goal"].to_i == 0 || params["inningsb"][ix].to_i <= table_monitor.data["innings_goal"].to_i) &&
                  (params["resulta"][ix].to_i > 0 || params["resultb"][ix].to_i > 0)

      table_monitor.data["playera"]["result"] = params["resulta"][ix].to_i
      table_monitor.data["playerb"]["result"] = params["resultb"][ix].to_i
      table_monitor.data["playera"]["innings"] = params["inningsa"][ix].to_i
      table_monitor.data["playerb"]["innings"] = params["inningsb"][ix].to_i
      table_monitor.data["playera"]["hs"] = params["hsa"][ix].to_i
      table_monitor.data["playerb"]["hs"] = params["hsb"][ix].to_i
      table_monitor.data["playera"]["gd"] =
        format("%.2f", table_monitor.data["playera"]["result"].to_f / table_monitor.data["playera"]["innings"])
      table_monitor.data["playerb"]["gd"] =
        format("%.2f", table_monitor.data["playerb"]["result"].to_f / table_monitor.data["playerb"]["innings"])
      table_monitor.data_will_change!
      table_monitor.save
      game.update(ended_at: Time.now)
      @tournament_monitor.update_game_participations(table_monitor)
      table_monitor.evaluate_result
    end
    redirect_back_or_to(tournament_monitor_path(@tournament_monitor))
  end

  # GET /tournament_monitors
  def index
    @pagy, @tournament_monitors = pagy(TournamentMonitor.sort_by_params(params[:sort], sort_direction))

    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @tournament_monitors.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @tournament_monitors.load
  end

  # GET /tournament_monitors/1
  def show; end

  # GET /tournament_monitors/new
  def new
    @tournament_monitor = TournamentMonitor.new
  end

  # GET /tournament_monitors/1/edit
  def edit; end

  # POST /tournament_monitors
  def create
    @tournament_monitor = TournamentMonitor.new(tournament_monitor_params)

    if @tournament_monitor.save
      redirect_to @tournament_monitor, notice: "Tournament monitor was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /tournament_monitors/1
  def update
    if @tournament_monitor.update(tournament_monitor_params)
      redirect_to @tournament_monitor, notice: "Tournament monitor was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /tournament_monitors/1
  def destroy
    @tournament_monitor.destroy
    redirect_to tournament_monitors_url, notice: "Tournament monitor was successfully destroyed."
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_tournament_monitor
    @tournament_monitor = TournamentMonitor.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def tournament_monitor_params
    params.require(:tournament_monitor).permit(:tournament_id, :date, :state, :innings_goal, :timeouts, :timeout,
                                               :balls_goal)
  end
end
