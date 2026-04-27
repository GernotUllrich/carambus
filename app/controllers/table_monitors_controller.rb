# frozen_string_literal: true

class TableMonitorsController < ApplicationController
  # Phase 38.4-13 P1/P3: discipline-specific ballziel fallback used by clamp_bk_family_params!
  # when the local Discipline record is missing OR has an empty ballziel_choices array.
  # MIRRORS script/seed_bk2_disciplines.rb — keep these two in sync.
  # Defense-in-depth against carambus_api → local-server Version sync gaps (see STATE.md
  # "sync-version-yaml-load-json-collision" todo). The seed remains canonical; this
  # constant ensures user-facing forms still work when the seed has not yet propagated.
  BK_FAMILY_BALLZIEL_FALLBACK = {
    "BK50" => [50],
    "BK100" => [100],
    "BK-2" => [50, 60, 70, 80, 90, 100],
    "BK-2plus" => [50, 60, 70, 80, 90, 100],
    "BK2-Kombi" => [50, 60, 70]
  }.freeze

  before_action :set_table_monitor,
    only: %i[show start_game edit update destroy next_step evaluate_result set_balls toggle_dark_mode]
  before_action :block_tournament_manipulation,
    only: %i[start_game update destroy]

  def set_balls
    unless @table_monitor.set_n_balls(params[:add_balls].to_i)
      flash.now[:alert] = @msg
      flash.keep[:alert]
    end
    redirect_back_or_to(tournament_monitor_path(@table_monitor.tournament_monitor))
  end

  # GET /@table_monitors
  def index
    @pagy, @table_monitors = pagy(TableMonitor.sort_by_params(params[:sort], sort_direction))

    # We explicitly load the records to avoid triggering multiple DB calls in the views when
    # checking if records exist and iterating over them.
    # Calling @table_monitors.any? in the view will use the loaded records to check existence
    # instead of making an extra DB call.
    @table_monitors.load
  end

  # GET /@table_monitors/1
  def show
    if @table_monitor.blank?
      redirect_to locations_path
      return
    elsif @table_monitor.game_id.blank? && @table_monitor.prev_game_id.blank?
      redirect_to location_url(@table_monitor.table.location, sb_state: "tables",
        table_id: @table_monitor.andand.table.andand.id, host: request.server_name, port: request.server_port)
      return
    end
    @navbar = false
    @footer = false
    @current_element = ""
    @table_monitor.evaluate_panel_and_current
    @table_monitor.save if @table_monitor.changed?
  end

  # GET /@table_monitors/new
  def new
    # @table_monitor = TableMonitor.new
  end

  def toggle_dark_mode
    # session[:dark_scoreboard] =
    #   !(session[:dark_scoreboard].present? ? JSON.parse(session[:dark_scoreboard].to_s) : false)
    if current_user.present?
      current_user.theme = (current_user.theme == "dark") ? "light" : "dark"
      current_user.save
    end
    redirect_back fallback_location: @table_monitor
  end

  def demo_scoreboard
    @navbar = false
    @footer = false
    render "demo_scoreboard", layout: "application"
  end

  def start_game
    # 38.4-08: .to_h forces a plain Hash so subsequent clamp_bk_family_params!
    # writes (e.g. p[:bk2_options] = { ... }) target a Hash, and the value
    # forwarded to GameSetup.call(options: p) is convertible without raising
    # ActionController::UnfilteredParameters on unpermitted nested keys
    # (see I9 / I9b regression tests in table_monitors_controller_test.rb).
    p = params.permit(params.keys).to_h
    p = p.slice(:player_a_id, :player_b_id, :timeouts, :timeout,
      :sets_to_play, :sets_choice, :sets_2_choice, :sets_to_win, :balls_goal, :balls_goal_choice, :balls_goal_2_choice, :balls_goal_a, :balls_goal_a_choice, :balls_goal_a_2_choice,
      :balls_goal_b, :balls_goal_b_choice, :balls_goal_b_2_choice, :innings_goal, :discipline_a, :discipline_a_choice,
      :discipline_b, :discipline_b_choice, :kickoff_switches_with,
      :fixed_display_left, :color_remains_with_set,
      :allow_overflow, :allow_follow_up, :free_game_form, :quick_game_form, :preset,
      :discipline_choice, :next_break_choice, :games_choice, :games_2_choice, :four_ball,
      :points_choice, :points_2_choice, :innings_choice, :innings_2_choice, :warntime, :gametime, :commit,
      :first_break_choice, :initial_red_balls, :frames_to_win, :frames_to_win_choice, :frames_to_win_2_choice,
      # 38.4-04 D-06: top-level balls_goal param from BK-family quick-game buttons.
      # Whitelisted here; clamped to discipline.ballziel_choices in clamp_bk_family_params!.
      :balls_goal,
      # 38.2-01 D-14/D-20: first-set-mode selector. Flat top-level
      # key (Alpine.js hidden input compatibility). Whitelisted to
      # %w[direkter_zweikampf serienspiel] in the BK2 branches below.
      :bk2_first_set_mode)

    # Process standard form parameters (unless quick_game_form)
    if p[:quick_game_form].present?
      # Handle Quick Game (for Pi 3 performance)
      # Quick buttons send parameters directly via hidden fields - DON'T override them!
      p[:balls_goal_a] = p[:balls_goal_a].to_i if p[:balls_goal_a].present?
      p[:balls_goal_b] = p[:balls_goal_b].to_i if p[:balls_goal_b].present?
      p[:innings_goal] = p[:innings_goal].to_i if p[:innings_goal].present?
      p[:sets_to_win] = p[:sets_to_win].to_i if p[:sets_to_win].present?
      p[:sets_to_play] = p[:sets_to_play].to_i if p[:sets_to_play].present?
      # For Pool set games (8-Ball, 9-Ball, 10-Ball), sets_to_play should be calculated from sets_to_win
      if p[:quick_game_form] == "pool" && p[:discipline_a] != "14.1 endlos" && p[:sets_to_win].to_i > 0
        p[:sets_to_play] = p[:sets_to_win].to_i * 2 - 1 if p[:sets_to_play].to_i <= 1
      elsif p[:sets_to_play].to_i <= 0
        p[:sets_to_play] = 1
      end
      p[:allow_follow_up] = (p[:allow_follow_up] == "true" || p[:allow_follow_up] == true)
      # 38.4-04 D-04/D-06: BK-family quick-start (all 5 BK-* disciplines).
      # The _quick_game_buttons partial emits quick_game_form=bk2_kombi for
      # BK2-Kombi and quick_game_form=bk_family for the 4 new disciplines.
      # CLAMP (T-38.4-04-02/03): discipline_a/b must be in BK2_DISCIPLINE_MAP;
      # balls_goal must intersect discipline.ballziel_choices.
      if p[:quick_game_form] == "bk2_kombi" || p[:quick_game_form] == "bk_family"
        # Discipline CLAMP — accept any of the 5 BK-* names, default to first.
        unless Discipline::BK2_DISCIPLINE_MAP.include?(p[:discipline_a].to_s)
          p[:discipline_a] = Discipline::BK2_DISCIPLINE_MAP.first
        end
        p[:discipline_b] = p[:discipline_a]
        clamp_bk_family_params!(p)
        # 38.2-01 D-14: accept first_set_mode (flat top-level key). CLAMP to
        # whitelist, fall back to "direkter_zweikampf" on absence or tampering.
        raw_mode = p.delete(:bk2_first_set_mode).to_s
        first_set_mode = %w[direkter_zweikampf serienspiel].include?(raw_mode) ? raw_mode : "direkter_zweikampf"
        p[:bk2_options]["first_set_mode"] = first_set_mode
      end

      # 38.1 IN-02: downgraded from .info to .debug (block form avoids string
      # interpolation cost when debug level is off).
      Rails.logger.debug { "=== QUICK GAME START ===" }
      Rails.logger.debug { "quick_game_form: #{p[:quick_game_form]}" }
      Rails.logger.debug { "discipline_a: #{p[:discipline_a]}" }
      Rails.logger.debug { "balls_goal_a: #{p[:balls_goal_a]}" }
      Rails.logger.debug { "innings_goal: #{p[:innings_goal]}" }
      Rails.logger.debug { "sets_to_win: #{p[:sets_to_win]}" }
      Rails.logger.debug { "sets_to_play: #{p[:sets_to_play]}" }
      Rails.logger.debug { "kickoff_switches_with: #{p[:kickoff_switches_with]}" }
      Rails.logger.debug { "=======================" }
    else
      p[:innings_choice] = p[:innings_2_choice].presence || p[:innings_choice]
      p[:points_choice] = p[:points_2_choice].presence || p[:points_choice]
      p[:balls_goal_a] =
        p[:balls_goal_b] = p[:balls_goal_choice] = p[:balls_goal_2_choice].presence || p[:balls_goal_choice]
      p[:balls_goal_a_choice] = p[:balls_goal_a_2_choice].presence || p[:balls_goal_a_choice].presence
      p[:balls_goal_b_choice] = p[:balls_goal_b_2_choice].presence || p[:balls_goal_b_choice].presence
      p[:kickoff_switches_with] = (p[:kickoff_switches_with].presence || "set")
      # 38.4-P6: skip karambol-shaped reassignments for BK-family detail forms.
      # The BK-* detail view shares the karambol form skeleton — its hidden
      # `_radio_select` partials still emit `discipline_{a,b}_choice` /
      # `balls_goal_{a,b}_choice` when x-show'd false. Without this guard those
      # values clobber the BK-* hidden inputs (`discipline_a="BK100"` etc.) and
      # the downstream BK CLAMP at line 242 falls back to BK2-Kombi's
      # ballziel_choices, silently coercing balls_goal=100 to 50.
      unless Discipline::BK2_FREE_GAME_FORMS.include?(p[:free_game_form].to_s)
        p[:discipline_a] = p[:discipline_a_choice]
        p[:discipline_b] = p[:discipline_b_choice]
        p[:balls_goal_a] = p[:balls_goal_a_choice]
        p[:balls_goal_b] = p[:balls_goal_b_choice]
      end
      p[:innings_goal] = p[:innings_choice]
      # 2026-04-27 (F1 fix): for BK-family detail forms the view's hidden inputs
      # already emit the correct sets_to_win / sets_to_play (e.g. 2/3 for BK-2kombi,
      # 1/1 for BK-2/BK-2plus/BK50/BK100). The karambol-shaped *_choice radio-selects
      # default to "0" when x-show'd false and would unconditionally clobber the
      # BK-correct values. Skip the overwrite for BK-family — same posture as the
      # discipline_*/balls_goal_* guard above. Without this, BK-2kombi from the
      # Detail Page started as a single set (sets_to_win=0) instead of best-of-3.
      unless Discipline::BK2_FREE_GAME_FORMS.include?(p[:free_game_form].to_s)
        p[:sets_to_play] = p[:sets_2_choice].presence || p[:sets_choice]
        p[:sets_to_win] = p[:games_2_choice].presence || p[:games_choice]
      end
    end
    # 38.4-04: guard the `four_ball` branch against silently bulldozing
    # any BK-family state. BK-* quick/detail forms never emit `four_ball`, but a
    # tampered POST carrying both a BK-family form key AND `four_ball=1` must NOT
    # drop BK-family settings. Consistent with the CLAMP posture (T-38.4-04-03).
    bk_family_form = Discipline::BK2_FREE_GAME_FORMS.include?(p[:free_game_form].to_s) ||
      %w[bk2_kombi bk_family].include?(p[:quick_game_form].to_s)
    if p[:four_ball].present? && !bk_family_form
      p[:discipline_a] = p[:discipline_b] = "4 Ball"
      p[:balls_goal_a] = p[:balls_goal_b] = 120
      p[:innings_goal] = 0
      p[:sets_to_play] = 1
      p[:sets_to_win] = 1
    end
    # Process free_game_form only for detail forms (not quick_game_form)
    # Quick games already have discipline_a/b set directly
    unless p[:quick_game_form].present?
      if p[:free_game_form] == "pool"
        p[:discipline_a] = p[:discipline_b] = Discipline::POOL_DISCIPLINE_MAP[p.delete(:discipline_choice).to_i]
        unless p[:discipline_a] == "14.1 endlos"
          p[:kickoff_switches_with] =
            ((p.delete(:next_break_choice) == "1") ? "winner" : "set")
        end
        p[:warntime] = p.delete(:warntime).to_i
        p[:gametime] = p.delete(:gametime).to_i
        if p[:discipline_a] == "14.1 endlos"
          p[:balls_goal_a] = p[:balls_goal_b] = p.delete(:points_choice).to_i
        else
          p[:balls_goal_a] = p[:balls_goal_b] = 1
          p[:sets_to_win] = p.delete(:games_choice).to_i
        end
        p[:innings_goal] = (p[:discipline_a] == "14.1 endlos") ? p.delete(:innings_choice).to_i : 1
        p[:first_break_choice] = p[:first_break_choice].to_i # 0: AusStoßen, 1: Heim/Spieler A, 2: Gast/Spieler B
      elsif p[:free_game_form] == "karambol"
        p[:discipline_a] = p[:discipline_b] = Discipline::KARAMBOL_DISCIPLINE_MAP[p.delete(:discipline_choice).to_i]
      elsif p[:free_game_form] == "snooker"
        # Snooker parameters
        # 38.1 IN-02: downgraded from .info to .debug.
        Rails.logger.debug { "=== SNOOKER PARAMS DEBUG ===" }
        Rails.logger.debug { "sets_to_win: #{p[:sets_to_win].inspect}" }
        Rails.logger.debug { "sets_to_play: #{p[:sets_to_play].inspect}" }
        Rails.logger.debug { "frames_to_win: #{p[:frames_to_win].inspect}" }
        Rails.logger.debug { "frames_to_win_choice: #{p[:frames_to_win_choice].inspect}" }
        Rails.logger.debug { "frames_to_win_2_choice: #{p[:frames_to_win_2_choice].inspect}" }
        Rails.logger.debug { "initial_red_balls: #{p[:initial_red_balls].inspect}" }
        Rails.logger.debug { "============================" }

        p[:initial_red_balls] = p.delete(:initial_red_balls).to_i
        p[:warntime] = p.delete(:warntime).to_i
        p[:gametime] = p.delete(:gametime).to_i
        p[:first_break_choice] = p[:first_break_choice].to_i
        # sets_to_win and sets_to_play: try from hidden fields first, fallback to _choice params
        # Use .presence to convert empty strings to nil
        frames_to_win = p.delete(:sets_to_win).presence ||
          p.delete(:frames_to_win_choice).presence ||
          p.delete(:frames_to_win_2_choice).presence ||
          p.delete(:frames_to_win).presence ||
          2
        p[:sets_to_win] = frames_to_win.to_i
        p[:sets_to_play] = (frames_to_win.to_i * 2 - 1)

        # 38.1 IN-02: downgraded from .info to .debug.
        Rails.logger.debug { "=== SNOOKER RESULT ===" }
        Rails.logger.debug { "Calculated frames_to_win: #{frames_to_win}" }
        Rails.logger.debug { "Final sets_to_win: #{p[:sets_to_win]}" }
        Rails.logger.debug { "Final sets_to_play: #{p[:sets_to_play]}" }
        Rails.logger.debug { "======================" }
      elsif Discipline::BK2_FREE_GAME_FORMS.include?(p[:free_game_form].to_s)
        # 38.4-04 D-04/D-06: Submitted by scoreboard_free_game_karambol_new.html.erb
        # (detail form) for any of the 5 BK-* disciplines. The view packs
        # discipline_a / discipline_b as the selected discipline name (NOT as an
        # index into KARAMBOL_DISCIPLINE_MAP — BK-* disciplines are not in that
        # map; see Discipline::BK2_DISCIPLINE_MAP for the canonical list).
        #
        # CLAMP (T-38.4-04-03): discipline_a/b must be in BK2_DISCIPLINE_MAP;
        # default to BK2-Kombi for bk2_kombi free_game_form, or derive from
        # free_game_form for the other 4 BK-* disciplines.
        unless Discipline::BK2_DISCIPLINE_MAP.include?(p[:discipline_a].to_s)
          p[:discipline_a] = Discipline::BK2_DISCIPLINE_MAP.first
        end
        p[:discipline_b] = p[:discipline_a]
        clamp_bk_family_params!(p)
        # 38.2-01 D-14: accept first_set_mode from the detail form's Alpine-
        # driven hidden input. CLAMP to whitelist (same posture as T-38.1-06-01
        # for discipline_a/b); fall back to "direkter_zweikampf" on absence or
        # tampering.
        raw_mode = p.delete(:bk2_first_set_mode).to_s
        first_set_mode = %w[direkter_zweikampf serienspiel].include?(raw_mode) ? raw_mode : "direkter_zweikampf"
        p[:bk2_options]["first_set_mode"] = first_set_mode
        # Phase 38.4 R5-7: Aufnahmen-Limit aus dem Formular durchreichen, statt
        # blanket innings_goal=0. Ohne dies schließt karambol's end_of_set? nie
        # über die Aufnahmen-Bedingung — Set lief ewig wenn weder Punkt-Ziel noch
        # andere Abbruchbedingung griff (User-Report 2026-04-26: "Kein Abbruch,
        # wenn beide 5 Aufnahmen erreicht haben").
        # - BK50 / BK100: jeder Spieler genau 1 Aufnahme (Regelwerk).
        # - BK-2 / BK-2plus / BK-2kombi: Form-Wert (Default 5 per Plan P12).
        p[:innings_goal] = case p[:discipline_a]
                           when "BK50", "BK100"
                             1
                           else
                             (p[:innings_choice].presence || p[:innings_2_choice].presence || 5).to_i
                           end
        p[:sets_to_win] = (p[:sets_to_win].presence || 2).to_i
        p[:sets_to_play] = (p[:sets_to_play].presence || 3).to_i
        p[:kickoff_switches_with] = (p[:kickoff_switches_with].presence || "set")
        p[:first_break_choice] = p[:first_break_choice].to_i
        # Drop stray karambol/pool params that the shared form may have submitted
        p.delete(:discipline_choice)
      end
    end

    p[:color_remains_with_set] = (p[:color_remains_with_set] == "1")
    p[:allow_overflow] = (p[:allow_overflow] == "1")
    # Normalize allow_follow_up depending on form source
    p[:allow_follow_up] = if p[:quick_game_form].present?
      (p[:allow_follow_up].to_s == "true") && p[:discipline_a] != "14.1 endlos"
    else
      (p[:allow_follow_up] == "1") && p[:discipline_a] != "14.1 endlos"
    end
    if p[:commit] == "Start Shootout"
      p[:discipline_b] = p[:discipline_a] = p[:discipline] = "shootout"
      p[:timeouts] = 0
      p[:timeout] = p[:gametime]
    end
    # 38.4-04: same BK-family guard as the earlier `four_ball` branch above.
    if p[:four_ball].present? && !bk_family_form
      p[:discipline_a] = p[:discipline_b] = "4 Ball"
      p[:balls_goal_a] = p[:balls_goal_b] = 120
      p[:innings_goal] = 0
      p[:sets_to_play] = 1
      p[:sets_to_win] = 1
      p[:color_remains_with_set] = true
      p[:allow_overflow] = false
      p[:timeouts] = 0
      p[:timeout] = 0
    end
    res = @table_monitor.start_game(p)
    @navbar = false
    @footer = false
    if res
      redirect_to @table_monitor
    else
      redirect_to location_url(@table_monitor.table.location, sb_state: "free_game",
        table_id: @table_monitor.table.id, host: request.server_name, port: request.server_port)
    end
  end

  def next_step
    @tournament_monitor = @table_monitor.tournament_monitor
    @location = @table_monitor.table.location
    @table_monitor.force_next_state
    redirect_back_or_to(location_path(@location))
  end

  def evaluate_result
    @tournament_monitor = @table_monitor.tournament_monitor
    @table_monitor.evaluate_result
    redirect_back_or_to tournament_monitor_path(@tournament_monitor)
  end

  # GET /@table_monitors/1/edit
  def edit
  end

  # POST /@table_monitors
  def create
    # @table_monitor = TableMonitor.new(@table_monitor_params)
    #
    # if @table_monitor.save
    #   redirect_to @table_monitor, notice: "Table monitor was successfully created."
    # else
    #   render :new
    # end
  end

  # PATCH/PUT /@table_monitors/1
  def update
    if @table_monitor.update(table_monitor_params)
      redirect_to @table_monitor, notice: "Table monitor was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /@table_monitors/1
  def destroy
    @table_monitor.destroy
    redirect_to table_monitors_url, notice: "Table monitor was successfully destroyed."
  end

  # GET /@table_monitors/1/game_protocol
  # All game protocol functionality now handled by GameProtocolReflex
  # Old JSON/HTML endpoints removed - modal is server-side rendered via panel_state

  # Print protocol - generates PDF with 3 protocols per landscape A4 page
  def print_protocol
    @table_monitor = TableMonitor.find(params[:id])
    @history = @table_monitor.innings_history
    @location = @table_monitor.table.location

    pdf = ProtocolPdf.new(@table_monitor, @history, @location)

    send_data pdf.render,
      filename: "spielprotokoll_#{@table_monitor.id}_#{Time.current.strftime("%Y%m%d_%H%M%S")}.pdf",
      type: "application/pdf",
      disposition: :inline
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_table_monitor
    @table_monitor = TableMonitor.find_by(id: params[:id])

    next_path = -> do
      fallback_location = Location.order(:id).first
      if fallback_location
        location_url(fallback_location,
          sb_state: "welcome",
          host: request.server_name,
          port: request.server_port)
      else
        locations_path
      end
    end

    unless @table_monitor
      Rails.logger.warn("TableMonitor #{params[:id]} not found; redirecting to welcome screen")
      redirect_to next_path.call,
        alert: I18n.t("table_monitors.not_found_reassign",
          default: "Der ausgewählte TableMonitor ist nicht verfügbar. Bitte wählen Sie einen Tisch neu aus.") and return
    end

    if @table_monitor.table.blank?
      Rails.logger.info("TableMonitor #{@table_monitor.id} is currently not assigned to a table; sending user to welcome screen")
      redirect_to next_path.call,
        alert: I18n.t("table_monitors.rebind_required",
          default: "Dieser TableMonitor ist keinem Tisch zugeordnet. Bitte wählen Sie einen Tisch im Location-Menü aus.") and return
    end

    @table_monitor.get_options!(I18n.locale)

    @display_only = if params[:display_only] == "false"
      false
    else
      session[:display_only].presence &&
        JSON.parse(session[:display_only].to_s) ||
        params[:display_only] == "true"
    end
    session[:display_only] = JSON.parse(@display_only.to_s)
  end

  # Only allow a trusted parameter "white list" through.
  def table_monitor_params
    params.permit(:@tournament_monitor_id, :state, :name, :game_id, :next_game_id, :data,
      :ip_address, :player_a_id, :player_b_id, :balls_goal, :balls_goal_a,
      :balls_goal_b, :discipline, :discipline_a, :discipline_b, :innings_goal,
      :timeout, :timeouts, :kickoff_switches_with,
      :fixed_display_left, :color_remains_with_set, :balls_on_table,
      :allow_overflow, :allow_follow_up, :toggle_dark_mode, :initial_red_balls)
  end

  # Verhindert Manipulationen an TableMonitor während eines Turniers
  def block_tournament_manipulation
    if @table_monitor&.tournament_monitor_id.present?
      flash[:error] = I18n.t("errors.tournament_game_manipulation_blocked",
        default: "Spielmanipulationen sind während eines Turniers nicht erlaubt.")
      redirect_back(fallback_location: locations_path) and return
    end
  end

  # 38.4-04 D-06 / T-38.4-04-02: CLAMPs balls_goal to the allowed
  # ballziel_choices for the selected BK-family discipline, and packs
  # bk2_options with the clamped value + the two integer config fields.
  # Mutates p in place; always returns p.
  def clamp_bk_family_params!(p)
    discipline_name = p[:discipline_a].to_s
    discipline = Discipline.find_by(name: discipline_name)

    # Phase 38.4-13 P1/P3: defense-in-depth ballziel fallback when the local
    # Discipline record is missing OR has empty ballziel_choices (carambus_api
    # → local-server sync gap, see STATE.md
    # "sync-version-yaml-load-json-collision" todo). The seed in
    # script/seed_bk2_disciplines.rb is canonical; BK_FAMILY_BALLZIEL_FALLBACK
    # is the safety net — keep them in sync.
    allowed = discipline&.ballziel_choices.presence ||
      BK_FAMILY_BALLZIEL_FALLBACK[discipline_name] ||
      [50]

    # balls_goal CLAMP (T-38.4-04-02): intersect user input with allowed list.
    # Phase 38.4-13 P1: read :balls_goal first; fall back to :balls_goal_a /
    # :balls_goal_b when caller omitted the top-level field (some legacy paths
    # emit only the per-player variants). The quick-start partial at
    # _quick_game_buttons.html.erb:141-145 emits all three; tolerating any
    # shape keeps clamp robust.
    # Slice-list precondition (I-13-01): :balls_goal_a and :balls_goal_b are
    # in the permit/slice list at line 74 — verified 2026-04-25.
    requested = (p.delete(:balls_goal).presence ||
                 p[:balls_goal_a].presence ||
                 p[:balls_goal_b].presence).to_i
    clamped_goal = allowed.include?(requested) ? requested : allowed.first

    p[:balls_goal] = clamped_goal
    p[:balls_goal_a] = clamped_goal
    p[:balls_goal_b] = clamped_goal

    # bk2_options CLAMPs for dz_max / sp_max (1..99). Read from params[:bk2_options]
    # (nested hash not in the slice list; CLAMP provides security).
    submitted_bk2_opts = params[:bk2_options] || {}
    dz_max = submitted_bk2_opts[:direkter_zweikampf_max_shots_per_turn].to_i
    sp_max = submitted_bk2_opts[:serienspiel_max_innings_per_set].to_i
    dz_max = 2 unless (1..99).cover?(dz_max)
    sp_max = 5 unless (1..99).cover?(sp_max)

    # 38.4-10 O8: BK-2plus + BK-2kombi have no other valid DZ-max variant — hardcode 2
    # regardless of submitted form value. The detail-view standalone DZ-max row was
    # removed; the hidden input on line 252 of scoreboard_free_game_karambol_new.html.erb
    # still emits bk2_dz_max_shots (initialized to 2 in the x-data wrapper) for shape
    # consistency, but the server is authoritative.
    dz_max = 2 if %w[BK-2plus BK2-Kombi].include?(p[:discipline_a].to_s)

    p[:bk2_options] = {
      "balls_goal" => clamped_goal,
      "direkter_zweikampf_max_shots_per_turn" => dz_max,
      "serienspiel_max_innings_per_set" => sp_max
    }

    p
  end
end
