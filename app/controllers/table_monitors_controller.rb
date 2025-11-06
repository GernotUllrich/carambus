# frozen_string_literal: true

class TableMonitorsController < ApplicationController
  before_action :set_table_monitor,
                only: %i[show start_game edit update destroy next_step evaluate_result set_balls toggle_dark_mode game_protocol game_protocol_tbody game_protocol_tbody_edit update_innings]

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
                :first_break_choice)
    
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
      p[:sets_to_play] = 1
      p[:allow_follow_up] = (p[:allow_follow_up] == "true" || p[:allow_follow_up] == true)
      
      Rails.logger.info "=== QUICK GAME START ==="
      Rails.logger.info "discipline_a: #{p[:discipline_a]}"
      Rails.logger.info "balls_goal_a: #{p[:balls_goal_a]}"
      Rails.logger.info "innings_goal: #{p[:innings_goal]}"
      Rails.logger.info "======================="
    end
    if p[:four_ball].present?
      p[:discipline_a] = p[:discipline_b] = "4 Ball"
      p[:balls_goal_a] = p[:balls_goal_b] = 120
      p[:innings_goal] = 0
      p[:sets_to_play] = 1
      p[:sets_to_win] = 1
    end
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
    if p[:four_ball].present?
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

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_table_monitor
    @table_monitor = TableMonitor.where(id: params[:id]).first
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
                  :allow_overflow, :allow_follow_up, :toggle_dark_mode)
  end
end
