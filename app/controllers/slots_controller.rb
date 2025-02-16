class SlotsController < ApplicationController
  before_action :set_slot, only: %i[show edit update destroy]

  # Uncomment to enforce Pundit authorization
  # after_action :verify_authorized
  # rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  # GET /slots
  def index
    @pagy, @slots = pagy(Slot.sort_by_params(params[:sort], sort_direction))

    # Uncomment to authorize with Pundit
    # authorize @slots
  end

  # GET /slots/1 or /slots/1.json
  def show; end

  # GET /slots/new
  def new
    @slot = Slot.new

    # Uncomment to authorize with Pundit
    # authorize @slot
  end

  # GET /slots/1/edit
  def edit; end

  # POST /slots or /slots.json
  def create
    @slot = Slot.new(slot_params)

    # Uncomment to authorize with Pundit
    # authorize @slot

    respond_to do |format|
      if @slot.save
        format.html { redirect_to @slot, notice: "Slot was successfully created." }
        format.json { render :show, status: :created, location: @slot }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @slot.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /slots/1 or /slots/1.json
  def update
    respond_to do |format|
      if @slot.update(slot_params)
        format.html { redirect_to @slot, notice: "Slot was successfully updated." }
        format.json { render :show, status: :ok, location: @slot }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @slot.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /slots/1 or /slots/1.json
  def destroy
    @slot.destroy
    respond_to do |format|
      format.html { redirect_to slots_url, status: :see_other, notice: "Slot was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_slot
    @slot = Slot.find(params[:id])

    # Uncomment to authorize with Pundit
    # authorize @slot
  rescue ActiveRecord::RecordNotFound
    redirect_to slots_path
  end

  # Only allow a list of trusted parameters through.
  def slot_params
    params.require(:slot).permit(:dayofweek, :hourofday_start, :minuteofhour_start, :hourofday_end, :minuteofhour_end,
                                 :next_start, :next_end, :table_id, :recurring)

    # Uncomment to use Pundit permitted attributes
    # params.require(:slot).permit(policy(@slot).permitted_attributes)
  end
end
