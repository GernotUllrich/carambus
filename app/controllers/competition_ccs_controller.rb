class CompetitionCcsController < ApplicationController
  before_action :admin_only_check, except: %i[show index]
  before_action :set_competition_cc, only: %i[show edit update destroy]

  # GET /competition_ccs
  def index
    @pagy, @competition_ccs = pagy(CompetitionCc.sort_by_params(params[:sort], sort_direction))

    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @competition_ccs.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @competition_ccs.load
  end

  # GET /competition_ccs/1
  def show
    @season_ccs = @competition_cc.season_ccs
  end

  # GET /competition_ccs/new
  def new
    @competition_cc = CompetitionCc.new
  end

  # GET /competition_ccs/1/edit
  def edit; end

  # POST /competition_ccs
  def create
    @competition_cc = CompetitionCc.new(competition_cc_params)

    if @competition_cc.save
      redirect_to @competition_cc, notice: "Competition cc was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /competition_ccs/1
  def update
    if @competition_cc.update(competition_cc_params)
      redirect_to @competition_cc, notice: "Competition cc was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /competition_ccs/1
  def destroy
    @competition_cc.destroy
    redirect_to competition_ccs_url, notice: "Competition cc was successfully destroyed."
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_competition_cc
    @competition_cc = CompetitionCc.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def competition_cc_params
    params.require(:competition_cc).permit(:cc_id, :name, :context, :branch_cc_id, :discipline_id)
  end
end
