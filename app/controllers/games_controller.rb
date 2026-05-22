class GamesController < ApplicationController
  before_action :admin_only_check, except: %i[show index]
  before_action :set_game, only: %i[show edit update destroy]

  # GET /games
  def index
    results = SearchService.call( Game.search_hash(params) )
    @pagy, @games = pagy(results.includes(:tournament))
    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @clubs.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @games.load
    respond_to do |format|
      format.html do
        render("index")
      end
    end
  rescue StandardError => e
    Rails.logger.error "ERROR: #{e}\n#{e.backtrace.join("\n")}"
    render("index")
  end

  # GET /games/1
  def show; end

  # GET /games/new
  def new
    @game = Game.new
  end

  # GET /games/1/edit
  def edit; end

  # POST /games
  def create
    @game = Game.new(game_params)

    if @game.save
      redirect_to @game, notice: "Game was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /games/1
  def update
    if @game.update(game_params)
      redirect_to @game, notice: "Game was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /games/1
  def destroy
    # Phase 18 / Hold-Guard-Followup zu 18-03: Ein App-getriebenes Spiel mit unbestaetigtem
    # Ergebnis (TableMonitor#external_result_pending? — game.data["external_id"] gesetzt +
    # result_acknowledged_at nil) darf NICHT geloescht werden, bevor die App es via
    # POST acknowledge_result abgeholt hat — auch nicht durch Admins/SysAdmins. Sonst wird die
    # Tisch-Bindung (has_one :table_monitor, dependent: :nullify) geloest, der Tisch neu belegbar,
    # und das nachfolgende App-start_game der naechsten Teilrunde schlaegt fehl. Expliziter
    # Override via ?force=1 (analog reset_table_monitor(force:) / TableReleaser, 17-05).
    if @game.table_monitor&.external_result_pending? && params[:force].blank?
      redirect_to games_url,
        alert: "Dieses Spiel gehört zu einem laufenden App-Turnier und wurde noch nicht abgeholt (acknowledge_result). Löschen blockiert — mit ?force=1 erzwingbar."
      return
    end
    @game.destroy
    redirect_to games_url, notice: "Game was successfully destroyed."
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_game
    @game = Game.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def game_params
    params.require(:game).permit(:tournament_id, :roles, :data, :seqno, :gname, :group_no, :table_no, :round_no,
                                 :started_at, :ended_at)
  end
end
