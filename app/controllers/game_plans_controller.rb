class GamePlansController < ApplicationController
  # Plan 19-01: Schreiben nur fuer Admins. Vorher liefen alle Schreibaktionen anonym durch —
  # zusammen mit dem frueheren eval auf `data` eine Codeausfuehrung fuer jeden Besucher.
  # Eigenes Gate statt admin_only_check: dessen Ausnahme guest_player_creation? liesse das
  # Scoreboard-Konto durch (Muster require_tournament_admin, 17-05). Laeuft vor set_game_plan.
  before_action :require_game_plan_admin, only: %i[new create edit update destroy]
  before_action :set_game_plan, only: %i[show edit update destroy]

  # Uncomment to enforce Pundit authorization
  # after_action :verify_authorized
  # rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  # GET /game_plans
  def index
    @pagy, @game_plans = pagy(GamePlan.sort_by_params(params[:sort], sort_direction))

    # Uncomment to authorize with Pundit
    # authorize @game_plans
  end

  # GET /game_plans/1 or /game_plans/1.json
  def show; end

  # GET /game_plans/new
  def new
    @game_plan = GamePlan.new

    # Uncomment to authorize with Pundit
    # authorize @game_plan
  end

  # GET /game_plans/1/edit
  def edit; end

  # POST /game_plans or /game_plans.json
  def create
    @game_plan = GamePlan.new(game_plan_params.except(:data))

    # Uncomment to authorize with Pundit
    # authorize @game_plan

    respond_to do |format|
      if assign_parsed_data(@game_plan) && @game_plan.save
        format.html { redirect_to @game_plan, notice: "Game plan was successfully created." }
        format.json { render :show, status: :created, location: @game_plan }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @game_plan.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /game_plans/1 or /game_plans/1.json
  def update
    respond_to do |format|
      @game_plan.name = game_plan_params[:name]
      if assign_parsed_data(@game_plan) && @game_plan.save
        format.html { redirect_to @game_plan, notice: "Game plan was successfully updated." }
        format.json { render :show, status: :ok, location: @game_plan }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @game_plan.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /game_plans/1 or /game_plans/1.json
  def destroy
    @game_plan.destroy
    respond_to do |format|
      format.html { redirect_to game_plans_url, status: :see_other, notice: "Game plan was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private

  def require_game_plan_admin
    return if current_user&.admin?

    flash[:alert] = I18n.t("game_plans.errors.admin_required")
    redirect_to game_plans_path
  end

  # Plan 19-01: `data` kommt aus dem Formular als JSON-Text (das Formular zeigt den JSON-Rohtext
  # der Spalte) und wird geparst, nie als Ruby-Code ausgewertet. Leeres Feld = leerer Plan.
  # Liefert false und setzt einen Fehler, wenn der Text kein JSON-Objekt ist.
  def assign_parsed_data(game_plan)
    raw = game_plan_params[:data].to_s
    parsed = raw.strip.empty? ? {} : JSON.parse(raw)
    raise JSON::ParserError, "kein JSON-Objekt" unless parsed.is_a?(Hash)

    game_plan.data = parsed
    true
  rescue JSON::ParserError
    game_plan.errors.add(:data, I18n.t("game_plans.errors.invalid_data"))
    false
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_game_plan
    @game_plan = GamePlan.find(params[:id])

    # Uncomment to authorize with Pundit
    # authorize @game_plan
  rescue ActiveRecord::RecordNotFound
    redirect_to game_plans_path
  end

  # Only allow a list of trusted parameters through.
  def game_plan_params
    params.require(:game_plan).permit(:footprint, :data, :name)

    # Uncomment to use Pundit permitted attributes
    # params.require(:game_plan).permit(policy(@game_plan).permitted_attributes)
  end
end
