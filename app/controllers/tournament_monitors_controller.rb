class TournamentMonitorsController < ApplicationController
  before_action :set_tournament_monitor, only: %i[show edit update destroy update_games switch_players start_round_games advance_round]
  before_action :ensure_tournament_director, only: %i[show edit update destroy update_games switch_players start_round_games advance_round]
  before_action :ensure_local_server, only: %i[show edit update destroy update_games switch_players start_round_games advance_round]

  # Plan 23-01 (2026-09-22): Der Rundenwechsel gehoert dem Turnierleiter.
  #
  # Bis Plan 23-01 loeste der gruene Knopf "Naechstes Spiel" am Scoreboard die Rundenkaskade
  # aus, sobald er am LETZTEN Spiel der Runde gedrueckt wurde. Der Spieler am Tisch konnte das
  # nicht sehen — und mit der Runde schloss sich das Korrekturfenster (NDM Freie Partie
  # Klasse 7, 2026-09-20: 32:32 statt 32:31, Korrektur nur per DB-Eingriff moeglich).
  #
  # `advance_round_by_operator` prueft selbst, ob die Runde abschlussbereit ist, und meldet
  # false, wenn nicht — das ist zugleich der Schutz gegen Doppelbetaetigung (zwei Requests
  # hintereinander, die der Thread-Local-Sentinel nicht abdeckt).
  def advance_round
    if @tournament_monitor.advance_round_by_operator
      flash[:notice] = t("tournament_monitors.round_status.advanced")
    else
      flash[:alert] = t("tournament_monitors.round_status.advance_rejected")
    end
    redirect_to tournament_monitor_path(@tournament_monitor)
  end

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

      # Plan 24-01 (2026-09-23): Bis hierher stand `next unless table_monitor.present?` — ein
      # abgeloestes Spiel (Tisch schon neu besetzt) wurde stillschweigend uebersprungen. Genau
      # das meldete der Betreiber als "Ich kann nichts aendern": zwei von vier Spielen kamen
      # gar nicht erst im POST an. Die Ziele kommen jetzt aus dem Tisch, wo es ihn gibt, sonst
      # aus Spiel und Turnier.
      ziele = korrektur_ziele(game, table_monitor)
      playera_balls_goal = ziele[:playera_balls_goal]
      playerb_balls_goal = ziele[:playerb_balls_goal]
      innings_goal = ziele[:innings_goal]
      
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
      unless (!playera_balls_goal.positive? || resulta <= playera_balls_goal)
        Rails.logger.warn "[TournamentMonitorsController#update_games] Game[#{game.id}] SKIPPED: resulta (#{resulta}) > playera_balls_goal (#{playera_balls_goal})"
        next
      end
      unless (!playerb_balls_goal.positive? || resultb <= playerb_balls_goal)
        Rails.logger.warn "[TournamentMonitorsController#update_games] Game[#{game.id}] SKIPPED: resultb (#{resultb}) > playerb_balls_goal (#{playerb_balls_goal})"
        next
      end
      
      # Validierung: Innings dürfen innings_goal nicht überschreiten (falls gesetzt)
      unless (!innings_goal.positive? || inningsa <= innings_goal)
        Rails.logger.warn "[TournamentMonitorsController#update_games] Game[#{game.id}] SKIPPED: inningsa (#{inningsa}) > innings_goal (#{innings_goal})"
        next
      end
      unless (!innings_goal.positive? || inningsb <= innings_goal)
        Rails.logger.warn "[TournamentMonitorsController#update_games] Game[#{game.id}] SKIPPED: inningsb (#{inningsb}) > innings_goal (#{innings_goal})"
        next
      end
      
      Rails.logger.info "[TournamentMonitorsController#update_games] Game[#{game.id}] validation PASSED, updating..."

      # Plan 24-01: Ein abgeloestes Spiel hat keinen TableMonitor, auf dessen `data` der
      # bisherige Weg schreibt. Es bekommt deshalb einen eigenen Zweig — kein Zwilling der
      # Aktion, nur ein zweiter Fall in derselben Schleife (extend-before-build).
      if table_monitor.blank?
        korrigiere_abgeloestes_spiel!(game, resulta:, resultb:, inningsa:, inningsb:,
          hsa: params["hsa"][ix].to_i, hsb: params["hsb"][ix].to_i)
        next
      end

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

    # Plan 24-01: Die Rangliste rechnet idempotent aus ALLEN GameParticipations neu (in Phase 23
    # belegt) — nach einer nachtraeglichen Korrektur muss sie angestossen werden, sonst zeigt
    # der Turnier-Monitor weiter die alten Punkte.
    @tournament_monitor.accumulate_results
    warne_bei_folgewirkung

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
  def edit
  end

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
    # Plan 40-02: :locale gehoert in die Liste, sonst schluckt `update` die Anzeigesprache
    # STILL — kein Fehler, keine Wirkung. Der Wert wird in TournamentMonitor gegen
    # I18n.available_locales validiert (40-01); leerer String kommt als nil an und bedeutet
    # "nicht konfiguriert" (die Tischsprache gilt weiter).
    params.require(:tournament_monitor).permit(:tournament_id, :date, :state, :innings_goal, :timeouts, :timeout,
                                               :balls_goal, :locale)
  end

  # Sicherstellen dass nur Spielleiter (club_admin) Zugriff haben
  # ── Plan 24-01: Korrektur abgeloester Spiele ───────────────────────────────

  # Ziele fuer die Validierung. Am Tisch stehen sie in `table_monitor.data`; ein abgeloestes
  # Spiel hat den nicht mehr, dort kommen sie aus dem Spiel bzw. dem Turnier.
  #
  # `balls_goal` je Spieler, weil Vorgabe-Turniere beiden unterschiedliche Ziele geben. Fuer
  # ein abgeloestes Spiel steht es in der GameParticipation-Historie nicht verlaesslich, wohl
  # aber im Schnappschuss — und sonst im Turnier.
  def korrektur_ziele(game, table_monitor)
    if table_monitor.present?
      return {
        playera_balls_goal: table_monitor.data["playera"]["balls_goal"].to_i,
        playerb_balls_goal: table_monitor.data["playerb"]["balls_goal"].to_i,
        innings_goal: table_monitor.data["innings_goal"].to_i
      }
    end

    schnappschuss = game.data["tmp_results"]
    turnier = @tournament_monitor.tournament
    {
      playera_balls_goal: (schnappschuss&.dig("playera", "balls_goal") || turnier.balls_goal).to_i,
      playerb_balls_goal: (schnappschuss&.dig("playerb", "balls_goal") || turnier.balls_goal).to_i,
      innings_goal: (@tournament_monitor.innings_goal || turnier.innings_goal).to_i
    }
  end

  # Schreibt eine Korrektur an einem Spiel OHNE TableMonitor.
  #
  # ⚠️ REIHENFOLGE IST WESENTLICH. `update_game_participations_for_game` bevorzugt
  # `game.data["tmp_results"]` vor den uebergebenen Werten (result_processor.rb:603). Am
  # 2026-09-23 als Ursache belegt: getippt 29, gespeichert 30, weil der Schnappschuss gewann.
  # Deshalb wird der Schnappschuss ZUERST auf den korrigierten Stand gebracht — danach sind
  # beide Quellen einig, und es ist gleichgueltig, welche die Methode waehlt.
  #
  # Der Schnappschuss wird MITGESCHRIEBEN, nicht geloescht (Betreiber-Entscheidung 24-01):
  # `game_setup.rb:312` spielt ihn beim Wieder-Platzieren auf den Tisch zurueck — geloescht
  # staende dort nichts.
  #
  # ⚠️ NUR `deep_merge_data!` — `game.data[...] = ` ist bei Game ein STILLES NO-OP, weil der
  # Getter (game.rb:95) bei jedem Zugriff neu aus dem Roh-Attribut dekodiert.
  def korrigiere_abgeloestes_spiel!(game, resulta:, resultb:, inningsa:, inningsb:, hsa:, hsb:)
    ziele = korrektur_ziele(game, nil)
    korrigiert = {
      "playera" => spielerdaten(resulta, inningsa, hsa, ziele[:playera_balls_goal]),
      "playerb" => spielerdaten(resultb, inningsb, hsb, ziele[:playerb_balls_goal])
    }

    game.deep_merge_data!(
      "tmp_results" => korrigiert,
      "ba_results" => ba_results_fuer(game, resulta, resultb, inningsa, inningsb, hsa, hsb)
    )
    game.ended_at ||= Time.now
    game.save!
    game.reload

    @tournament_monitor.update_game_participations_for_game(game, korrigiert)

    Rails.logger.info "[update_games] Plan 24-01: abgeloestes Game[#{game.id}] korrigiert " \
                      "auf #{resulta}:#{resultb} (#{inningsa}/#{inningsb} Aufnahmen)"

    lade_korrektur_in_die_cc(game)
  end

  # Betreiber-Entscheidung 24-01: die ClubCloud bekommt den korrigierten Stand sofort —
  # "sofortige CC-Sichtbarkeit ist das Ziel". `upload_game_to_cc` nimmt seit 24-01 auch ein
  # Game (setting.rb:982), weil ein abgeloestes Spiel keinen TableMonitor mehr hat.
  # Ein Fehler hier bricht die Korrektur NICHT ab — der lokale Stand fuehrt, und der
  # CSV-Upload am Turnierende traegt den Gesamtstand ohnehin hinueber.
  def lade_korrektur_in_die_cc(game)
    turnier = @tournament_monitor.tournament
    return unless turnier.tournament_cc.present? && turnier.auto_upload_to_cc?

    ergebnis = Setting.upload_game_to_cc(nil, game: game)
    if ergebnis[:success]
      Rails.logger.info "[update_games] Plan 24-01: CC-Upload fuer abgeloestes Game[#{game.id}] " \
                        "#{ergebnis[:dry_run] ? "(DRY RUN)" : ergebnis[:skipped] ? "uebersprungen" : "ok"}"
    else
      Rails.logger.warn "[update_games] Plan 24-01: CC-Upload fuer abgeloestes Game[#{game.id}] " \
                        "fehlgeschlagen: #{ergebnis[:error]}"
    end
  end

  def spielerdaten(result, innings, hs, balls_goal)
    {
      "result" => result, "innings" => innings, "hs" => hs,
      "balls_goal" => balls_goal,
      "gd" => innings.positive? ? format("%.2f", result.to_f / innings) : "0.00"
    }
  end

  # Der Satz, den die ClubCloud liest (setting.rb:1047). Aufbau wie in
  # ResultRecorder#update_ba_results_with_set_result!, hier fuer ein Ein-Satz-Spiel direkt
  # aus den korrigierten Werten gebaut — `perform_ensure_ba_results` kehrt bei bereits
  # vorhandenem `ba_results` frueh zurueck und wuerde eine Korrektur nicht nachziehen.
  def ba_results_fuer(game, resulta, resultb, inningsa, inningsb, hsa, hsb)
    {
      "Gruppe" => game.group_no,
      "Partie" => game.seqno,
      "Spieler1" => game.game_participations.where(role: "playera").first&.player&.ba_id,
      "Spieler2" => game.game_participations.where(role: "playerb").first&.player&.ba_id,
      "Sets1" => (resulta > resultb) ? 1 : 0,
      "Sets2" => (resultb > resulta) ? 1 : 0,
      "Ergebnis1" => resulta, "Ergebnis2" => resultb,
      "Aufnahmen1" => inningsa, "Aufnahmen2" => inningsb,
      "Höchstserie1" => hsa, "Höchstserie2" => hsb,
      "Tischnummer" => game.table_no
    }
  end

  # Plan 24-01 (Betreiber-Entscheidung): warnen, nicht blockieren. Aendert eine Korrektur die
  # Rangfolge, nachdem die Folgerunde daraus besetzt wurde, reicht das korrigierte Spiel nicht
  # — das muss der Turnierleiter sehen, entscheiden aber soll er selbst.
  def warne_bei_folgewirkung
    return unless @tournament_monitor.current_round.to_i > 1

    flash[:alert] = [flash[:alert], t("tournament_monitors.round_status.correction_affects_later_round",
      round: @tournament_monitor.current_round)].compact.join(" ")
  end

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
