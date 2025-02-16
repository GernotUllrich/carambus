class RegistrationCcsController < ApplicationController
  before_action :set_registration_cc, only: %i[show edit update destroy]

  # GET /registration_ccs
  def index
    @pagy, @registration_ccs = pagy(RegistrationCc.sort_by_params(params[:sort], sort_direction))

    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @registration_ccs.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @registration_ccs.load
  end

  # GET /registration_ccs/1
  def show; end

  # GET /registration_ccs/new
  def new
    @registration_cc = RegistrationCc.new
  end

  # GET /registration_ccs/1/edit
  def edit; end

  # POST /registration_ccs
  def create
    @registration_cc = RegistrationCc.new(registration_cc_params)

    if @registration_cc.save
      redirect_to @registration_cc, notice: "Registration cc was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /registration_ccs/1
  def update
    if @registration_cc.update(registration_cc_params)
      redirect_to @registration_cc, notice: "Registration cc was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /registration_ccs/1
  def destroy
    @registration_cc.destroy
    redirect_to registration_ccs_url, notice: "Registration cc was successfully destroyed."
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_registration_cc
    @registration_cc = RegistrationCc.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def registration_cc_params
    params.require(:registration_cc).permit(:registration_list_cc_id, :player_id, :status)
  end
end
