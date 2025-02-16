class PartyCcsController < ApplicationController
  before_action :admin_only_check, except: %i[show index]
  before_action :set_party_cc, only: %i[show edit update destroy]

  # GET /party_ccs
  def index
    @pagy, @party_ccs = pagy(PartyCc.sort_by_params(params[:sort], sort_direction))

    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @party_ccs.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @party_ccs.load
  end

  # GET /party_ccs/1
  def show
    @party_game_ccs = @party_cc.party_game_ccs
  end

  # GET /party_ccs/new
  def new
    @party_cc = PartyCc.new
  end

  # GET /party_ccs/1/edit
  def edit; end

  # POST /party_ccs
  def create
    @party_cc = PartyCc.new(party_cc_params)

    if @party_cc.save
      redirect_to @party_cc, notice: "Party cc was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /party_ccs/1
  def update
    if @party_cc.update(party_cc_params)
      redirect_to @party_cc, notice: "Party cc was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /party_ccs/1
  def destroy
    @party_cc.destroy
    redirect_to party_ccs_url, notice: "Party cc was successfully destroyed."
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_party_cc
    @party_cc = PartyCc.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def party_cc_params
    params.require(:party_cc).permit(:cc_id, :group, :round, :time, :match_id, :register_at, :status, :league_cc_id,
                                     :party_id, :league_team_a_cc_id, :league_team_b_cc_id, :league_team_host_cc_id, :integer, :day_seqno, :remarks, :data)
  end
end
