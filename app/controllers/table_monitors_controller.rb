# frozen_string_literal: true

class TableMonitorsController < ApplicationController
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
      current_user.theme = current_user.theme == "dark" ? "light" : "dark"
      current_user.save
    end
    redirect_back fallback_location: @table_monitor
  end

  def demo_scoreboard
    @navbar = false
    @footer = false
    render 'demo_scoreboard', layout: 'application'
  end

  def start_game
    p = params.permit(params.keys)
    p = p.slice(:player_a_id, :player_b_id, :timeouts, :timeout,
                :sets_to_play, :sets_choice, :sets_2_choice, :sets_to_win, :balls_goal, :balls_goal_choice, :balls_goal_2_choice, :balls_goal_a, :balls_goal_a_choice, :balls_goal_a_2_choice,
                :balls_goal_b, :balls_goal_b_choice, :balls_goal_b_2_choice, :innings_goal, :discipline_a, :discipline_a_choice,
                :discipline_b, :discipline_b_choice, :kickoff_switches_with,
                :fixed_display_left, :color_remains_with_set,
                :allow_overflow, :allow_follow_up, :free_game_form, :quick_game_form, :preset,
                :discipline_choice, :next_break_choice, :games_choice, :games_2_choice, :four_ball,
                :points_choice, :points_2_choice, :innings_choice, :innings_2_choice, :warntime, :gametime, :commit,
                :first_break_choice, :initial_red_balls, :frames_to_win, :frames_to_win_choice, :frames_to_win_2_choice,
                # 38.1-06: BK2-Kombi params — set_target_points (50/60/70) is
                # the raw user input; the BK2 branch below packs it into
                # p[:bk2_options] which then flows to GameSetup whitelist.
                :set_target_points)

    # Process standard form parameters (unless quick_game_form)
    unless p[:quick_game_form].present?
      p[:innings_choice] = p[:innings_2_choice].presence || p[:innings_choice]
      p[:points_choice] = p[:points_2_choice].presence || p[:points_choice]
      p[:balls_goal_a] =
        p[:balls_goal_b] = p[:balls_goal_choice] = p[:balls_goal_2_choice].presence || p[:balls_goal_choice]
      p[:balls_goal_a_choice] = p[:balls_goal_a_2_choice].presence || p[:balls_goal_a_choice].presence
      p[:balls_goal_b_choice] = p[:balls_goal_b_2_choice].presence || p[:balls_goal_b_choice].presence
      p[:kickoff_switches_with] = (p[:kickoff_switches_with].presence || "set")
      p[:discipline_a] = p[:discipline_a_choice]
      p[:discipline_b] = p[:discipline_b_choice]
      p[:balls_goal_a] = p[:balls_goal_a_choice]
      p[:balls_goal_b] = p[:balls_goal_b_choice]
      p[:innings_goal] = p[:innings_choice]
      p[:sets_to_play] = p[:sets_2_choice].presence || p[:sets_choice]
      p[:sets_to_win] = p[:games_2_choice].presence || p[:games_choice]
    else
      # Handle Quick Game (for Pi 3 performance)
      # Quick buttons send parameters directly via hidden fields - DON'T override them!
      p[:balls_goal_a] = p[:balls_goal_a].to_i if p[:balls_goal_a].present?
      p[:balls_goal_b] = p[:balls_goal_b].to_i if p[:balls_goal_b].present?
      p[:innings_goal] = p[:innings_goal].to_i if p[:innings_goal].present?
      p[:sets_to_win] = p[:sets_to_win].to_i if p[:sets_to_win].present?
      p[:sets_to_play] = p[:sets_to_play].to_i if p[:sets_to_play].present?
      # For Pool set games (8-Ball, 9-Ball, 10-Ball), sets_to_play should be calculated from sets_to_win
      if p[:quick_game_form] == 'pool' && p[:discipline_a] != '14.1 endlos' && p[:sets_to_win].to_i > 0
        p[:sets_to_play] = p[:sets_to_win].to_i * 2 - 1 if p[:sets_to_play].to_i <= 1
      else
        p[:sets_to_play] = 1 if p[:sets_to_play].to_i <= 0
      end
      p[:allow_follow_up] = (p[:allow_follow_up] == "true" || p[:allow_follow_up] == true)
      # 38.1-06: BK2-Kombi quick-start also packs bk2_options + CLAMPS discipline.
      # The _quick_game_buttons partial emits quick_game_form=bk2_kombi +
      # set_target_points; we mirror the detail-form branch's logic here.
      # CLAMP (T-38.1-06-01) applies here too — discipline_a/b MUST be
      # "BK2-Kombi" even if an attacker submits a different value.
      if p[:quick_game_form] == "bk2_kombi"
        p[:discipline_a] = "BK2-Kombi"
        p[:discipline_b] = "BK2-Kombi"
        set_target = p.delete(:set_target_points).to_i
        set_target = 50 unless [50, 60, 70].include?(set_target)
        p[:bk2_options] = { "set_target_points" => set_target }
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
    end
    # 38.1 WR-01: guard the `four_ball` branch against silently bulldozing
    # BK2-Kombi state. BK2 quick/detail forms never emit `four_ball`, but a
    # tampered POST carrying both `quick_game_form=bk2_kombi` (or
    # `free_game_form=bk2_kombi`) AND `four_ball=1` must NOT drop BK2
    # settings. Consistent with the CLAMP posture (T-38.1-06-01).
    if p[:four_ball].present? && p[:quick_game_form] != "bk2_kombi" && p[:free_game_form] != "bk2_kombi"
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
            (p.delete(:next_break_choice) == "1" ? "winner" : "set")
        end
        p[:warntime] = p.delete(:warntime).to_i
        p[:gametime] = p.delete(:gametime).to_i
        if p[:discipline_a] == "14.1 endlos"
          p[:balls_goal_a] = p[:balls_goal_b] = p.delete(:points_choice).to_i
        else
          p[:balls_goal_a] = p[:balls_goal_b] = 1
          p[:sets_to_win] = p.delete(:games_choice).to_i
        end
        p[:innings_goal] = p[:discipline_a] == "14.1 endlos" ? p.delete(:innings_choice).to_i : 1
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
      elsif p[:free_game_form] == "bk2_kombi"
        # 38.1-06: Submitted by scoreboard_free_game_karambol_new.html.erb
        # (detail form, via Alpine computed getters) OR by
        # _quick_game_buttons.html.erb (BK2 branch). The view packs
        # discipline_a / discipline_b = "BK2-Kombi" as string literals (NOT
        # as indices into KARAMBOL_DISCIPLINE_MAP — BK2-Kombi is not in that
        # map; see Discipline::BK2_DISCIPLINE_MAP for the canonical list).
        #
        # CLAMP (T-38.1-06-01): hard-assign BK2-Kombi rather than `||=` — an
        # attacker POSTing free_game_form=bk2_kombi with a tampered
        # discipline_a must have that overwritten. BK2-Kombi is the ONLY
        # legitimate discipline for this form value per D-08.
        p[:discipline_a] = "BK2-Kombi"
        p[:discipline_b] = "BK2-Kombi"
        set_target = p.delete(:set_target_points).to_i
        set_target = 50 unless [50, 60, 70].include?(set_target)
        p[:bk2_options] = { "set_target_points" => set_target }
        # BK2-Kombi scoring is shot-by-shot against a set target, not balls_goal.
        p[:balls_goal_a] = 0
        p[:balls_goal_b] = 0
        p[:innings_goal] = 0
        p[:sets_to_win]  = (p[:sets_to_win].presence  || 2).to_i
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
    # 38.1 WR-03: `set_target_points` is whitelisted in the `.slice(...)` list
    # at the top of this action as a raw BK2 input. The BK2 branches (quick
    # and detail) both `p.delete(:set_target_points)` and pack it into
    # `p[:bk2_options]`. For every other form path (pool/snooker/karambol/
    # 4-Ball), if a client submits `set_target_points` (the shared detail
    # form always emits it, usually as ""), it would leak into
    # `GameSetup#build_result_hash` / `@options` and clutter logs. Drop it
    # unconditionally unless this is a BK2 submission.
    unless p[:free_game_form] == "bk2_kombi" || p[:quick_game_form] == "bk2_kombi"
      p.delete(:set_target_points)
    end
    if p[:commit] == "Start Shootout"
      p[:discipline_b] = p[:discipline_a] = p[:discipline] = "shootout"
      p[:timeouts] = 0
      p[:timeout] = p[:gametime]
    end
    # 38.1 WR-01: same BK2 guard as the earlier `four_ball` branch. See
    # comment above at the first occurrence.
    if p[:four_ball].present? && p[:quick_game_form] != "bk2_kombi" && p[:free_game_form] != "bk2_kombi"
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
  def edit; end

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
              filename: "spielprotokoll_#{@table_monitor.id}_#{Time.current.strftime('%Y%m%d_%H%M%S')}.pdf",
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
                     sb_state: 'welcome',
                     host: request.server_name,
                     port: request.server_port)
      else
        locations_path
      end
    end

    unless @table_monitor
      Rails.logger.warn("TableMonitor #{params[:id]} not found; redirecting to welcome screen")
      redirect_to next_path.call,
                  alert: I18n.t('table_monitors.not_found_reassign',
                                default: 'Der ausgewählte TableMonitor ist nicht verfügbar. Bitte wählen Sie einen Tisch neu aus.') and return
    end

    if @table_monitor.table.blank?
      Rails.logger.info("TableMonitor #{@table_monitor.id} is currently not assigned to a table; sending user to welcome screen")
      redirect_to next_path.call,
                  alert: I18n.t('table_monitors.rebind_required',
                                default: 'Dieser TableMonitor ist keinem Tisch zugeordnet. Bitte wählen Sie einen Tisch im Location-Menü aus.') and return
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
      flash[:error] = I18n.t('errors.tournament_game_manipulation_blocked',
                            default: 'Spielmanipulationen sind während eines Turniers nicht erlaubt.')
      redirect_back(fallback_location: locations_path) and return
    end
  end
end
