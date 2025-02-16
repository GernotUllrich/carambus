class DisciplinePhasesController < ApplicationController
  before_action :set_discipline_phase, only: %i[show edit update destroy]

  # Uncomment to enforce Pundit authorization
  # after_action :verify_authorized
  # rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  # GET /discipline_phases
  def index
    @pagy, @discipline_phases = pagy(DisciplinePhase.sort_by_params(params[:sort], sort_direction))

    # Uncomment to authorize with Pundit
    # authorize @discipline_phases
  end

  # GET /discipline_phases/1 or /discipline_phases/1.json
  def show; end

  # GET /discipline_phases/new
  def new
    @discipline_phase = DisciplinePhase.new

    # Uncomment to authorize with Pundit
    # authorize @discipline_phase
  end

  # GET /discipline_phases/1/edit
  def edit; end

  # POST /discipline_phases or /discipline_phases.json
  def create
    @discipline_phase = DisciplinePhase.new(discipline_phase_params)

    # Uncomment to authorize with Pundit
    # authorize @discipline_phase

    respond_to do |format|
      if @discipline_phase.save
        format.html { redirect_to @discipline_phase, notice: "Discipline phase was successfully created." }
        format.json { render :show, status: :created, location: @discipline_phase }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @discipline_phase.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /discipline_phases/1 or /discipline_phases/1.json
  def update
    respond_to do |format|
      if @discipline_phase.update(discipline_phase_params)
        format.html { redirect_to @discipline_phase, notice: "Discipline phase was successfully updated." }
        format.json { render :show, status: :ok, location: @discipline_phase }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @discipline_phase.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /discipline_phases/1 or /discipline_phases/1.json
  def destroy
    @discipline_phase.destroy
    respond_to do |format|
      format.html do
        redirect_to discipline_phases_url, status: :see_other, notice: "Discipline phase was successfully destroyed."
      end
      format.json { head :no_content }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_discipline_phase
    @discipline_phase = DisciplinePhase.find(params[:id])

    # Uncomment to authorize with Pundit
    # authorize @discipline_phase
  rescue ActiveRecord::RecordNotFound
    redirect_to discipline_phases_path
  end

  # Only allow a list of trusted parameters through.
  def discipline_phase_params
    params.require(:discipline_phase).permit(:name, :discipline_id, :parent_discipline_id, :position, :data)

    # Uncomment to use Pundit permitted attributes
    # params.require(:discipline_phase).permit(policy(@discipline_phase).permitted_attributes)
  end
end
