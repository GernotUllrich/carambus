class TournamentCcsController < ApplicationController
  include FiltersHelper
  before_action :set_tournament_cc, only: %i[show edit update destroy]

  # GET /tournament_ccs
  def index
    @tournament_ccs = TournamentCc
                      .joins(:branch_cc, :discipline, :championship_type_cc, :group_cc, :category_cc, :tournament)
                      .sort_by_params(@sSearch, sort_direction)
    if @sSearch.present?
      search = <<~EOD
        (tournament_ccs.context ilike :search) or#{" "}
        (tournament_ccs.cc_id = :isearch) or#{" "}
        (tournament_ccs.location_text ilike :search) or#{" "}
        (tournament_ccs.shortname ilike :search) or#{" "}
        (tournament_ccs.name ilike :search)
      EOD
      @tournament_ccs = apply_filters(@tournament_ccs, TournamentCc::COLUMN_NAMES, search)
    end
    @pagy, @tournament_ccs = pagy(@tournament_ccs)

    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @tournament_ccs.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @tournament_ccs.load
    respond_to do |format|
      format.html do
        render("index")
      end
    end
  end

  # GET /tournament_ccs/1
  def show; end

  # GET /tournament_ccs/new
  def new
    @tournament_cc = TournamentCc.new
  end

  # GET /tournament_ccs/1/edit
  def edit; end

  # POST /tournament_ccs
  def create
    @tournament_cc = TournamentCc.new(tournament_cc_params)

    if @tournament_cc.save
      redirect_to @tournament_cc, notice: "Tournament cc was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /tournament_ccs/1
  def update
    if @tournament_cc.update(tournament_cc_params)
      redirect_to @tournament_cc, notice: "Tournament cc was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /tournament_ccs/1
  def destroy
    @tournament_cc.destroy
    redirect_to tournament_ccs_url, notice: "Tournament cc was successfully destroyed."
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_tournament_cc
    @tournament_cc = TournamentCc.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def tournament_cc_params
    params.require(:tournament_cc).permit(:cc_id, :context, :name, :shortname, :status, :branch_cc_id, :season,
                                          :registration_list_cc_id, :registration_rule, :discipline_id, :championship_type_cc_id, :category_cc_id, :group_cc_id, :tournament_start, :tournament_series_cc_id, :tournament_end, :starting_at, :league_climber_quote, :entry_fee, :max_players, :location_id, :location_text, :description, :poster, :tender, :flowchart, :ranking_list, :successor_list)
  end
end
