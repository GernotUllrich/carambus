class BranchCcsController < ApplicationController
  before_action :set_branch_cc, only: [:show, :edit, :update, :destroy]
  before_action :set_branch_cc, only: [:fix, :check]

  def fix
    RegionCc.save_log("region_cc")
    RegionCc.sync_branches(RegionCc.session_id, armed: true)
    RegionCc.save_log("region_cc")
    redirect_to migration_cc_region_path(@region_cc.region)
  end

  Player.joins(:season_participations, {:club => :region}).joins(:party_a_games).where(season_participations: {season_id: 2}).where(regions: {id: 1}).order(:lastname).where("players.ba_id > 900000000").first.party_a_games.joins(:party => :league).where(leagues: {season_id: 2}).first.party
  f = Player.
    joins(:season_participations, {:club => :region}).
    joins(:party_a_games => {:party => :league}).
    where(season_participations: {season_id: 2}).
    where(regions: {id: 1}).
    order(:lastname).
    where("players.ba_id > 900000000").uniq.map{ |p| [p.cc_id, p.ba_id, p.lastname, p.firstname, p.id, p.party_a_games.joins(:party => :league).where(leagues: {season_id: 2}).first.andand.party.andand.ba_id].join(";") }.join("\n")

  f = Player.
    joins(:season_participations, {:club => :region}).
    joins(:party_a_games => {:party => :league}).
    where(season_participations: {season_id: 2}).
    where(regions: {id: 1}).
    order(:lastname).
    where("players.ba_id > 900000000").uniq.map{|p|[p.cc_id, p.ba_id, p.lastname, p.firstname, p.id,
     p.party_a_games.
       joins(:party => :league).
       where(leagues: {season_id: 2}).count
       # first.andand.
       # party.andand.ba_id
    ].join(";")}.join("\n")


  def check
    RegionCc.save_log("region_cc")
    RegionCc.sync_regions(RegionCc.session_id, @region_cc.region, armed: false)
    RegionCc.save_log("region_cc")
    redirect_to migration_cc_region_path(@region_cc.region)
  end
  # GET /branch_ccs
  def index
    @pagy, @branch_ccs = pagy(BranchCc.sort_by_params(params[:sort], sort_direction))

    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @branch_ccs.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @branch_ccs.load
  end

  # GET /branch_ccs/1
  def show
    @competition_ccs = @branch_cc.competition_ccs
  end

  # GET /branch_ccs/new
  def new
    @branch_cc = BranchCc.new
  end

  # GET /branch_ccs/1/edit
  def edit
  end

  # POST /branch_ccs
  def create
    @branch_cc = BranchCc.new(branch_cc_params)

    if @branch_cc.save
      redirect_to @branch_cc, notice: "Branch cc was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /branch_ccs/1
  def update
    if @branch_cc.update(branch_cc_params)
      redirect_to @branch_cc, notice: "Branch cc was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /branch_ccs/1
  def destroy
    @branch_cc.destroy
    redirect_to branch_ccs_url, notice: "Branch cc was successfully destroyed."
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_branch_cc
    @branch_cc = BranchCc.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def branch_cc_params
    params.require(:branch_cc).permit(:cc_id, :context, :region_cc_id, :discipline_id, :name)
  end
end
