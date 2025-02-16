class RegionCcsController < ApplicationController
  before_action :admin_only_check, except: %i[show index]
  before_action :set_region_cc, only: %i[show edit update destroy fix check
                                         fix_branch_cc check_branch_cc
                                         fix_competition_cc check_competition_cc
                                         fix_season_cc check_season_cc
                                         fix_party_cc check_party_cc
                                         fix_league_cc check_league_cc
                                         fix_league_team_cc check_league_team_cc
                                         fix_game_plan_cc check_game_plan_cc]

  def fix
    RegionCc.save_log("region_cc")
    RegionCcAction.synchronize_region_structure(@opts.merge(armed: true))
    RegionCc.save_log("region_cc")
    redirect_to migration_cc_region_path(@region_cc.region)
  end

  def check
    RegionCc.save_log("region_cc")
    RegionCcAction.synchronize_region_structure(@opts.merge(armed: false))
    RegionCc.save_log("region_cc")
    redirect_to migration_cc_region_path(@region_cc.region)
  end

  def fix_branch_cc
    RegionCc.save_log("branch_cc")
    RegionCcAction.synchronize_branch_structure(@opts.merge(armed: true))
    RegionCc.save_log("branch_cc")
    redirect_to migration_cc_region_path(@region_cc.region)
  end

  def check_branch_cc
    RegionCc.save_log("branch_cc")
    RegionCcAction.synchronize_branch_structure(@opts.merge(armed: false))
    RegionCc.save_log("branch_cc")
    redirect_to migration_cc_region_path(@region_cc.region)
  end

  def fix_competition_cc
    RegionCc.save_log("competition_cc")
    RegionCcAction.synchronize_competition_structure(@opts.merge(armed: true))
    RegionCc.save_log("competition_cc")
    redirect_to migration_cc_region_path(@region_cc.region)
  end

  def check_competition_cc
    RegionCc.save_log("competition_cc")
    RegionCcAction.synchronize_competition_structure(@opts.merge(armed: false))
    RegionCc.save_log("competition_cc")
    redirect_to migration_cc_region_path(@region_cc.region)
  end

  def fix_season_cc
    RegionCc.save_log("season_cc")
    RegionCcAction.synchronize_season_structure(@opts.merge(armed: true))
    RegionCc.save_log("season_cc")
    redirect_to migration_cc_region_path(@region_cc.region)
  end

  def check_season_cc
    RegionCc.save_log("season_cc")
    RegionCcAction.synchronize_season_structure(@opts.merge(armed: false))
    RegionCc.save_log("season_cc")
    redirect_to migration_cc_region_path(@region_cc.region)
  end

  def fix_party_cc
    RegionCc.save_log("party_cc")
    RegionCcActionAction.synchronize_party_structure(@opts.merge(armed: true))
    RegionCc.save_log("party_cc")
    redirect_to migration_cc_region_path(@region_cc.region)
  end

  def check_party_cc
    RegionCc.save_log("party_cc")
    RegionCcActionAction.synchronize_party_structure(@opts.merge(armed: false))
    RegionCc.save_log("party_cc")
    redirect_to migration_cc_region_path(@region_cc.region)
  end

  def fix_party_game_cc
    RegionCc.save_log("party_game_cc")
    RegionCcActionAction.synchronize_party_game_structure(@opts.merge(armed: true))
    RegionCc.save_log("party_game_cc")
    redirect_to migration_cc_region_path(@region_cc.region)
  end

  def check_party_game_cc
    RegionCc.save_log("party_game_cc")
    RegionCcActionAction.synchronize_party_game_structure(@opts.merge(armed: false))
    RegionCc.save_log("party_game_cc")
    redirect_to migration_cc_region_path(@region_cc.region)
  end

  def fix_league_cc
    RegionCc.save_log("league_cc")
    RegionCcAction.synchronize_league_structure(@opts.merge(armed: true))
    RegionCc.save_log("league_cc")
    redirect_to migration_cc_region_path(@region_cc.region)
  end

  def check_league_cc
    RegionCc.save_log("league_cc")
    RegionCcAction.synchronize_league_structure(@opts.merge(armed: false))
    RegionCc.save_log("league_cc")
    redirect_to migration_cc_region_path(@region_cc.region)
  end

  def fix_league_team_cc
    RegionCc.save_log("league_team_cc")
    RegionCcAction.synchronize_league_team_structure(@opts.merge(armed: true))
    RegionCc.save_log("league_team_cc")
    redirect_to migration_cc_region_path(@region_cc.region)
  end

  def check_league_team_cc
    RegionCc.save_log("league_team_cc")
    RegionCcAction.synchronize_league_team_structure(@opts.merge(armed: false))
    RegionCc.save_log("league_team_cc")
    redirect_to migration_cc_region_path(@region_cc.region)
  end

  def fix_game_plan_cc
    RegionCc.save_log("game_plan_cc")
    RegionCcAction.synchronize_game_plan_structure(@opts.merge(armed: true))
    RegionCc.save_log("game_plan_cc")
    redirect_to migration_cc_region_path(@region_cc.region)
  end

  def check_game_plan_cc
    RegionCc.save_log("game_plan_cc")
    RegionCcAction.synchronize_game_plan_structure(@opts.merge(armed: false))
    RegionCc.save_log("game_plan_cc")
    redirect_to migration_cc_region_path(@region_cc.region)
  end

  # GET /region_ccs
  def index
    @pagy, @region_ccs = pagy(RegionCc.sort_by_params(params[:sort], sort_direction))

    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @region_ccs.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @region_ccs.load
  end

  # GET /region_ccs/1
  def show
    @branch_ccs = @region_cc.branch_ccs
  end

  # GET /region_ccs/new
  def new
    @region_cc = RegionCc.new(context: params[:context], region_id: params[:region_id], shortname: params[:shortname],
                              name: params[:name])
  end

  # GET /region_ccs/1/edit
  def edit; end

  # POST /region_ccs
  def create
    @region_cc = RegionCc.new(region_cc_params)
    # get main page with given public
    _, doc = RegionCc.new.get_cc_with_url("Home", @region_cc.public_url)
    @region_cc.base_url = doc.css("a.cclogin")[0]["href"]
    @region_cc.cc_id = doc.css("a").find { |a| a["href"].match(/f=\d+$/) }["href"].match(/f=(\d+)$/)[1].to_i
    if @region_cc.save
      redirect_to @region_cc, notice: "Region cc was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /region_ccs/1
  def update
    if @region_cc.update(region_cc_params)
      redirect_to @region_cc, notice: "Region cc was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /region_ccs/1
  def destroy
    @region_cc.destroy
    redirect_to region_ccs_url, notice: "Region cc was successfully destroyed."
  end

  def synchronize_region_structure
    redirect_to
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_region_cc
    get_base_options
    @region_cc = RegionCc.find(params[:id])
  end

  def get_base_options
    @session_id = cookies[:session_id]
    @context = cookies[:context]
    cookies[:context] = @context = "nbv" unless @context.present?
    @season_name = cookies[:season_name]
    cookies[:season_name] = @season_name = Season.last.name unless @season_name.present?
    @force_update = cookies[:force_update]
    @opts = {
      season_name: @season_name,
      armed: @force_update,
      context: @context,
      session_id: @session_id
    }
  end

  # Only allow a trusted parameter "white list" through.
  def region_cc_params
    params.require(:region_cc).permit(:cc_id, :context, :region_id, :public_url, :season_name, :base_url, :shortname,
                                      :name)
  end
end
