class PartyGameCcsController < ApplicationController
  before_action :admin_only_check, except: %i[show index]
  before_action :set_party_game_cc, only: %i[show edit update destroy]

  # GET /party_game_ccs
  def index
    @pagy, @party_game_ccs = pagy(PartyGameCc.sort_by_params(params[:sort], sort_direction))

    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @party_game_ccs.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @party_game_ccs.load
  end

  # GET /party_game_ccs/1
  def show; end

  # GET /party_game_ccs/new
  def new
    @party_game_cc = PartyGameCc.new
  end

  # GET /party_game_ccs/1/edit
  def edit; end

  # POST /party_game_ccs
  def create
    @party_game_cc = PartyGameCc.new(party_game_cc_params)

    if @party_game_cc.save
      redirect_to @party_game_cc, notice: "Party game cc was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /party_game_ccs/1
  def update
    if @party_game_cc.update(party_game_cc_params)
      redirect_to @party_game_cc, notice: "Party game cc was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /party_game_ccs/1
  def destroy
    @party_game_cc.destroy
    redirect_to party_game_ccs_url, notice: "Party game cc was successfully destroyed."
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_party_game_cc
    @party_game_cc = PartyGameCc.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def party_game_cc_params
    params.require(:party_game_cc).permit(:cc_id, :seqno, :player_a_id, :player_b_id, :data, :name, :discipline_id)
  end
end
