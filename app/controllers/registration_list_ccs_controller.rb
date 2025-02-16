class RegistrationListCcsController < ApplicationController
  before_action :set_registration_list_cc, only: %i[show edit update destroy]

  # GET /registration_list_ccs
  def index
    @pagy, @registration_list_ccs = pagy(RegistrationListCc.sort_by_params(params[:sort], sort_direction))

    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @registration_list_ccs.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @registration_list_ccs.load
  end

  # GET /registration_list_ccs/1
  def show; end

  # GET /registration_list_ccs/new
  def new
    @registration_list_cc = RegistrationListCc.new
  end

  # GET /registration_list_ccs/1/edit
  def edit; end

  # POST /registration_list_ccs
  def create
    @registration_list_cc = RegistrationListCc.new(registration_list_cc_params)

    if @registration_list_cc.save
      redirect_to @registration_list_cc, notice: "Registration list cc was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /registration_list_ccs/1
  def update
    if @registration_list_cc.update(registration_list_cc_params)
      redirect_to @registration_list_cc, notice: "Registration list cc was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /registration_list_ccs/1
  def destroy
    @registration_list_cc.destroy
    redirect_to registration_list_ccs_url, notice: "Registration list cc was successfully destroyed."
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_registration_list_cc
    @registration_list_cc = RegistrationListCc.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def registration_list_cc_params
    params.require(:registration_list_cc).permit(:cc_id, :context, :name, :branch_cc_id, :season_id, :discipline_id,
                                                 :category_cc_id, :deadline, :qualifying_date, :data, :status)
  end
end
