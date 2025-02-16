class ClubLocationsController < ApplicationController
  before_action :set_club_location, only: %i[show edit update destroy]

  # Uncomment to enforce Pundit authorization
  # after_action :verify_authorized
  # rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  # GET /club_locations
  def index
    @pagy, @club_locations = pagy(ClubLocation.sort_by_params(params[:sort], sort_direction))

    # Uncomment to authorize with Pundit
    # authorize @club_locations
  end

  # GET /club_locations/1 or /club_locations/1.json
  def show; end

  # GET /club_locations/new
  def new
    @club_location = ClubLocation.new

    # Uncomment to authorize with Pundit
    # authorize @club_location
  end

  # GET /club_locations/1/edit
  def edit; end

  # POST /club_locations or /club_locations.json
  def create
    @club_location = ClubLocation.new(club_location_params)

    # Uncomment to authorize with Pundit
    # authorize @club_location

    respond_to do |format|
      if @club_location.save
        format.html { redirect_to @club_location, notice: "Club location was successfully created." }
        format.json { render :show, status: :created, location: @club_location }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @club_location.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /club_locations/1 or /club_locations/1.json
  def update
    respond_to do |format|
      if @club_location.update(club_location_params)
        format.html { redirect_to @club_location, notice: "Club location was successfully updated." }
        format.json { render :show, status: :ok, location: @club_location }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @club_location.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /club_locations/1 or /club_locations/1.json
  def destroy
    @club_location.destroy
    respond_to do |format|
      format.html do
        redirect_to club_locations_url, status: :see_other, notice: "Club location was successfully destroyed."
      end
      format.json { head :no_content }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_club_location
    @club_location = ClubLocation.find(params[:id])

    # Uncomment to authorize with Pundit
    # authorize @club_location
  rescue ActiveRecord::RecordNotFound
    redirect_to club_locations_path
  end

  # Only allow a list of trusted parameters through.
  def club_location_params
    params.require(:club_location).permit(:club_id, :location_id, :status)

    # Uncomment to use Pundit permitted attributes
    # params.require(:club_location).permit(policy(@club_location).permitted_attributes)
  end
end
