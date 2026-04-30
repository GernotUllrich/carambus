class TournamentMonitorsController < ApplicationController
  before_action :set_tournament_monitor, only: %i[show edit update destroy update_games switch_players start_round_games]
  before_action :ensure_tournament_director, only: %i[show edit update destroy update_games switch_players start_round_games]
  before_action :ensure_local_server, only: %i[show edit update destroy update_games switch_players start_round_games]

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

  def start_round_games
    # Transition all table monitors with games to playing state
    @tournament_monitor.table_monitors.includes(:game).where.not(game_id: nil).each do |table_monitor|
      # Skip warmup and go directly to playing state for manual entry
      table_monitor.suppress_broadcast = true
      if %i[ready warmup warmup_a warmup_b].include?(table_monitor.state.to_sym)
        table_monitor.start_new_match! if table_monitor.may_start_new_match?
        table_monitor.finish_warmup! if table_monitor.may_finish_warmup?
        table_monitor.finish_shootout! if table_monitor.may_finish_shootout?
      end
      table_monitor.suppress_broadcast = false
      table_monitor.save!
    end
    flash[:notice] = "Alle Spiele der Runde wurden gestartet und sind bereit für die manuelle Eingabe."
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
      next unless table_monitor.present?
      
      # Validierung: Prüfe ob Ergebnisse im erlaubten Bereich liegen
      # WICHTIG: Bei Vorgabe-Turnieren können beide Spieler unterschiedliche balls_goal haben!
      # Ein Spieler kann sein Ziel erreichen, während der andere noch nicht fertig ist.
      playera_balls_goal = table_monitor.data["playera"]["balls_goal"].to_i
      playerb_balls_goal = table_monitor.data["playerb"]["balls_goal"].to_i
      innings_goal = table_monitor.data["innings_goal"].to_i
      
      resulta = params["resulta"][ix].to_i
      resultb = params["resultb"][ix].to_i
      inningsa = params["inningsa"][ix].to_i
      inningsb = params["inningsb"][ix].to_i
      
      Rails.logger.info "[TournamentMonitorsController#update_games] Game[#{game.id}] validation:"
      Rails.logger.info "  playera_balls_goal: #{playera_balls_goal}, resulta: #{resulta}"
      Rails.logger.info "  playerb_balls_goal: #{playerb_balls_goal}, resultb: #{resultb}"
      Rails.logger.info "  innings_goal: #{innings_goal}, inningsa: #{inningsa}, inningsb: #{inningsb}"
      
      # Validierung: Mindestens ein Ergebnis muss > 0 sein
      unless (resulta > 0 || resultb > 0)
        Rails.logger.warn "[TournamentMonitorsController#update_games] Game[#{game.id}] SKIPPED: No results entered"
        next
      end
      
      # Validierung: Ergebnisse dürfen die jeweiligen balls_goal nicht überschreiten (falls gesetzt)
      unless (playera_balls_goal == 0 || resulta <= playera_balls_goal)
        Rails.logger.warn "[TournamentMonitorsController#update_games] Game[#{game.id}] SKIPPED: resulta (#{resulta}) > playera_balls_goal (#{playera_balls_goal})"
        next
      end
      unless (playerb_balls_goal == 0 || resultb <= playerb_balls_goal)
        Rails.logger.warn "[TournamentMonitorsController#update_games] Game[#{game.id}] SKIPPED: resultb (#{resultb}) > playerb_balls_goal (#{playerb_balls_goal})"
        next
      end
      
      # Validierung: Innings dürfen innings_goal nicht überschreiten (falls gesetzt)
      unless (innings_goal == 0 || inningsa <= innings_goal)
        Rails.logger.warn "[TournamentMonitorsController#update_games] Game[#{game.id}] SKIPPED: inningsa (#{inningsa}) > innings_goal (#{innings_goal})"
        next
      end
      unless (innings_goal == 0 || inningsb <= innings_goal)
        Rails.logger.warn "[TournamentMonitorsController#update_games] Game[#{game.id}] SKIPPED: inningsb (#{inningsb}) > innings_goal (#{innings_goal})"
        next
      end
      
      Rails.logger.info "[TournamentMonitorsController#update_games] Game[#{game.id}] validation PASSED, updating..."

      # Ensure table_monitor is in playing state for evaluate_result to work
      table_monitor.suppress_broadcast = true
      if %i[ready warmup warmup_a warmup_b match_shootout].include?(table_monitor.state.to_sym)
        table_monitor.start_new_match! if table_monitor.may_start_new_match?
        table_monitor.finish_warmup! if table_monitor.may_finish_warmup?
        table_monitor.finish_shootout! if table_monitor.may_finish_shootout?
      end
      
      table_monitor.data["playera"]["result"] = resulta
      table_monitor.data["playerb"]["result"] = resultb
      table_monitor.data["playera"]["innings"] = inningsa
      table_monitor.data["playerb"]["innings"] = inningsb
      table_monitor.data["playera"]["hs"] = params["hsa"][ix].to_i
      table_monitor.data["playerb"]["hs"] = params["hsb"][ix].to_i
      table_monitor.data["playera"]["gd"] =
        format("%.2f", table_monitor.data["playera"]["result"].to_f / table_monitor.data["playera"]["innings"])
      table_monitor.data["playerb"]["gd"] =
        format("%.2f", table_monitor.data["playerb"]["result"].to_f / table_monitor.data["playerb"]["innings"])
      table_monitor.data_will_change!
      table_monitor.suppress_broadcast = false
      table_monitor.save
      game.update(ended_at: Time.now)
      @tournament_monitor.update_game_participations(table_monitor)
      table_monitor.evaluate_result
      
      # WICHTIG: Triggere ClubCloud-Upload (falls aktiviert)
      # Dies entspricht der Logik in lib/tournament_monitor_state.rb:finalize_game_result
      tournament = @tournament_monitor.tournament
      if tournament.tournament_cc.present? && tournament.auto_upload_to_cc?
        Rails.logger.info "[TournamentMonitorsController#update_games] Attempting ClubCloud upload for game[#{game.id}] (manual entry)..."
        result = Setting.upload_game_to_cc(table_monitor)
        if result[:success]
          if result[:dry_run]
            Rails.logger.info "[TournamentMonitorsController#update_games] 🧪 ClubCloud upload DRY RUN completed for game[#{game.id}] (development mode)"
          elsif result[:skipped]
            Rails.logger.info "[TournamentMonitorsController#update_games] ⊘ ClubCloud upload skipped for game[#{game.id}] (already uploaded)"
          else
            Rails.logger.info "[TournamentMonitorsController#update_games] ✓ ClubCloud upload successful for game[#{game.id}]"
          end
        else
          Rails.logger.warn "[TournamentMonitorsController#update_games] ✗ ClubCloud upload failed for game[#{game.id}]: #{result[:error]}"
          # Fehler ist bereits in tournament.data["cc_upload_errors"] geloggt
        end
      end
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
    @tiebreak_on_draw_default = derive_tiebreak_default(@tournament_monitor)
  end

  # GET /tournament_monitors/1/edit
  def edit
    @tiebreak_on_draw_default = derive_tiebreak_default(@tournament_monitor)
  end

  # POST /tournament_monitors
  def create
    @tournament_monitor = TournamentMonitor.new(tournament_monitor_params)

    if @tournament_monitor.save
      # Phase 38.7 Plan 12 (Gap-04): :create deliberately does NOT persist
      # tournament_tiebreak_on_draw. The before_action stack
      # (ensure_tournament_director, line 3) only protects
      # %i[show edit update destroy ...] — :create is NOT in that list,
      # so persisting Tournament.data here would let any signed-in user
      # mutate director-controlled data. Operator workflow: create the
      # monitor first, then edit it to set the tiebreak flag (which IS
      # gated by ensure_tournament_director on :update).
      redirect_to @tournament_monitor, notice: "Tournament monitor was successfully created."
    else
      @tiebreak_on_draw_default = derive_tiebreak_default(@tournament_monitor)
      render :new
    end
  end

  # PATCH/PUT /tournament_monitors/1
  def update
    if @tournament_monitor.update(tournament_monitor_params)
      # Phase 38.7 Plan 12 (Gap-04): persist Tournament.data['tiebreak_on_draw'].
      # Gated by the existing before_action stack (ensure_tournament_director +
      # ensure_local_server) which IS active on :update.
      persist_tournament_tiebreak_override(@tournament_monitor)
      redirect_to @tournament_monitor, notice: "Tournament monitor was successfully updated."
    else
      @tiebreak_on_draw_default = derive_tiebreak_default(@tournament_monitor)
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

  # Phase 38.7 Plan 12 (Gap-04): default value for the startup-form tiebreak
  # checkbox. Reads Tournament.data first (Level 1 — already set), then falls
  # back to the bound TournamentPlan's executor_params['g1']['tiebreak_on_draw']
  # (Level 2 — plan default), else false. The form pre-checks the box
  # accordingly.
  def derive_tiebreak_default(tournament_monitor)
    t = tournament_monitor&.tournament
    return false if t.nil?

    t_data = t.data.is_a?(Hash) ? t.data : (begin; JSON.parse(t.data.to_s); rescue; {}; end)
    return !!t_data["tiebreak_on_draw"] if t_data.is_a?(Hash) && t_data.key?("tiebreak_on_draw")

    plan = t.tournament_plan
    if plan&.respond_to?(:executor_params)
      plan_params = plan.executor_params.is_a?(Hash) ? plan.executor_params : (begin; JSON.parse(plan.executor_params.to_s); rescue; {}; end)
      g1 = plan_params.is_a?(Hash) ? plan_params["g1"] : nil
      return !!g1["tiebreak_on_draw"] if g1.is_a?(Hash) && g1.key?("tiebreak_on_draw")
    end

    false
  end

  # Phase 38.7 Plan 12 (Gap-04): persist the operator's pick onto
  # Tournament.data['tiebreak_on_draw'] when the form param is present.
  #
  # AUTH GATE: This helper is called ONLY from `update` (NOT from `create`).
  # The controller's existing before_action stack
  # (ensure_tournament_director + ensure_local_server, registered with
  # `only: %i[show edit update destroy ...]`) protects `:update` but NOT
  # `:create`. Calling this from `:create` would let any signed-in user
  # mutate Tournament.data. Workflow: operator creates the TournamentMonitor
  # first (unauthenticated-friendly path stays unchanged), then edits it
  # once to tick the box.
  #
  # Sparse semantics: missing param → no-op (leave Tournament.data
  # untouched). Present param ('1' true, anything else false) →
  # explicit write that overrides plan default.
  def persist_tournament_tiebreak_override(tournament_monitor)
    return unless params.key?(:tournament_tiebreak_on_draw)
    t = tournament_monitor&.tournament
    return if t.nil?

    raw = params[:tournament_tiebreak_on_draw]
    bool = raw == "1" || raw == "true" || raw == true

    current = t.data.is_a?(Hash) ? t.data.dup : (begin; JSON.parse(t.data.to_s); rescue; {}; end)
    current = {} unless current.is_a?(Hash)
    current["tiebreak_on_draw"] = bool

    # Tournament's data column is a JSON-encoded text column (serialize :data,
    # coder: JSON, type: Hash). We write via update_columns to bypass:
    #   1) Tournament's before_save which mutates organizer + extracts certain
    #      keys out of data (lines 313-330) — irrelevant to tiebreak_on_draw and
    #      would cause confusing diff noise.
    #   2) Tournament's belongs_to :organizer presence validation, which
    #      unrelated callbacks elsewhere (TournamentMonitor reset) can leave
    #      transiently nil during the request lifecycle. We don't want a stale
    #      organizer state to block this targeted single-key write.
    # update_columns also skips PaperTrail; that's an acceptable tradeoff for
    # this operator-set flag (audit trail comes from Rails.logger.info below
    # and from the TournamentMonitor's own PaperTrail entry on the same request).
    # We pass the Hash itself (NOT JSON-stringified): Tournament uses
    # `serialize :data, coder: JSON, type: Hash` so AR will JSON-encode the
    # Hash on write and reject a pre-stringified value with
    # ActiveRecord::SerializationTypeMismatch.
    t.update_columns(data: current, updated_at: Time.current)
    Rails.logger.info "[TournamentMonitorsController] Plan 12 (Gap-04) " \
      "Tournament.data['tiebreak_on_draw']=#{bool} tournament=#{t.id}"
  end

  # Sicherstellen dass nur Spielleiter (club_admin) Zugriff haben
  def ensure_tournament_director
    unless current_user&.club_admin? || current_user&.system_admin?
      flash[:alert] = "Zugriff verweigert: Nur Spielleiter können auf den Tournament Monitor zugreifen."
      redirect_to root_path
    end
  end

  # Stellt sicher, dass Tournament Monitor nur auf lokalen Servern möglich ist
  def ensure_local_server
    unless local_server?
      flash[:alert] = "⚠️ Tournament Monitor ist nur auf lokalen Servern verfügbar. Der API Server dient ausschließlich als zentrale Datenquelle."
      redirect_to tournaments_path
    end
  end
end
