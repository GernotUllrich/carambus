class PartyMonitorsController < ApplicationController
  before_action :set_party_monitor, only: %i[show edit update destroy upload_form]

  # Uncomment to enforce Pundit authorization
  # after_action :verify_authorized
  # rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  # GET /party_monitors
  def index
    @pagy, @party_monitors = pagy(PartyMonitor.sort_by_params(params[:sort], sort_direction))

    # Uncomment to authorize with Pundit
    # authorize @party_monitors
  end

  # GET /party_monitors/1 or /party_monitors/1.json
  def show
    @party = @party_monitor.party
    @league = @party.league
    @assigned_players_a_ids = Player.joins(:seedings).where(seedings: { role: "team_a", tournament_type: "Party",
                                                                        tournament_id: @party.id }).order("players.lastname").ids
    @assigned_players_b_ids = Player.joins(:seedings).where(seedings: { role: "team_b", tournament_type: "Party",
                                                                        tournament_id: @party.id }).order("players.lastname").ids
    @available_players_a_ids = @party.league_team_a.seedings.joins(:player).order("players.lastname").map(&:player_id).select do |pid|
      !@assigned_players_a_ids.include?(pid)
    end
    @available_players_b_ids = @party.league_team_b.seedings.joins(:player).order("players.lastname").map(&:player_id).select do |pid|
      !@assigned_players_b_ids.include?(pid)
    end
    league_team_a_name = @party.league_team_a.name
    league_team_b_name = @party.league_team_b.name
    replacement_teams_a_ids = LeagueTeam.joins(:league).where(leagues: { season_id: Season.current_season.id }).where(club_id: @party.league_team_a.club_id).where("league_teams.name > '#{league_team_a_name}'").ids - @available_players_a_ids
    replacement_teams_b_ids = LeagueTeam.joins(:league).where(leagues: { season_id: Season.current_season.id }).where(club_id: @party.league_team_b.club_id).where("league_teams.name > '#{league_team_b_name}'").ids - @available_players_b_ids
    @available_replacement_players_a_ids = Seeding.where(league_team_id: replacement_teams_a_ids).joins(:player).order("players.lastname").map(&:player_id).select do |pid|
      !@assigned_players_a_ids.include?(pid)
    end
    @available_replacement_players_b_ids = Seeding.where(league_team_id: replacement_teams_b_ids).joins(:player).order("players.lastname").map(&:player_id).select do |pid|
      !@assigned_players_b_ids.include?(pid)
    end

    @available_fitting_table_ids = @party.location.andand.tables.andand.joins(table_kind: :disciplines).andand.where(disciplines: { id: @league.discipline_id }).andand.order("name").andand.map(&:id).to_a
    @tournament_tables = @party.location.andand.tables.andand.joins(table_kind: :disciplines).andand.where(disciplines: { id: @league.discipline_id }).andand.count.to_i
    @tables_from_plan = @party_monitor.data["tables"].to_i
    @tournament_tables = [@tournament_tables, @party_monitor.data["tables"].to_i].min if @tables_from_plan > 0
  end

  def upload_form
    @party_monitor
  end

  # GET /party_monitors/new
  def new
    @party_monitor = PartyMonitor.new

    # Uncomment to authorize with Pundit
    # authorize @party_monitor
  end

  # GET /party_monitors/1/edit
  def edit; end

  # POST /party_monitors or /party_monitors.json
  def create
    @party_monitor = PartyMonitor.new(party_monitor_params)

    # Uncomment to authorize with Pundit
    # authorize @party_monitor

    respond_to do |format|
      if @party_monitor.save
        format.html { redirect_to @party_monitor, notice: "Party monitor was successfully created." }
        format.json { render :show, status: :created, location: @party_monitor }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @party_monitor.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /party_monitors/1 or /party_monitors/1.json
  def update
    respond_to do |format|
      if @party_monitor.update(party_monitor_params)
        format.html { redirect_to @party_monitor, notice: "Party monitor was successfully updated." }
        format.json { render :show, status: :ok, location: @party_monitor }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @party_monitor.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /party_monitors/1 or /party_monitors/1.json
  def destroy
    @party_monitor.destroy
    respond_to do |format|
      format.html do
        redirect_to party_monitors_url, status: :see_other, notice: "Party monitor was successfully destroyed."
      end
      format.json { head :no_content }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_party_monitor
    raise "StandardError", "Funktion not allowed on API Server" unless ApplicationRecord.local_server?

    @party_monitor = PartyMonitor.find(params[:id])

    # Uncomment to authorize with Pundit
    # authorize @party_monitor
  rescue ActiveRecord::RecordNotFound
    redirect_to party_monitors_path
  end

  # Only allow a list of trusted parameters through.
  def party_monitor_params
    params.require(:party_monitor).permit(:party_id, :state, :data, :started_at, :ended_at)

    # Uncomment to use Pundit permitted attributes
    # params.require(:party_monitor).permit(policy(@party_monitor).permitted_attributes)
  end
end
