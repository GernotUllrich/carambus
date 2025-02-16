class PartiesController < ApplicationController
  include FiltersHelper
  # TODO: callback needed?:  protect_from_forgery except: :search
  before_action :admin_only_check, except: %i[show index]
  before_action :set_party, only: %i[show edit update destroy party_monitor]

  # GET /parties
  def index
    @parties = Party.joins(:league).sort_by_params(params[:sort], sort_direction).order(day_seqno: :asc) # .joins('INNER JOIN "league_teams" AS "league_team_a" ON "league_team_a"."id" = "parties"."league_team_a_id"')#.joins('INNER JOIN "league_teams" as "league_team_b" ON "league_team_b"."id" = "parties"."league_team_b_id"').joins('INNER JOIN "league_teams" as "host_league_team" ON "host_league_team"."id" = "parties"."host_league_team_id"').sort_by_params(params[:sort], sort_direction)
    @parties = apply_filters(@parties, Party::COLUMN_NAMES, "(leagues.name ilike :search)") if @sSearch.present?
    @pagy, @parties = pagy(@parties)

    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @parties.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @parties.load
    respond_to do |format|
      format.html do
        if params[:table_only].present?
          params.reject! { |k, _v| k.to_s == "table_only" }
          render(partial: "search", layout: false)
        else
          render("index")
        end
      end
    end
  end

  # GET /parties/1
  def show; end

  # GET /parties/new
  def new
    @party = Party.new
  end

  # GET /parties/1/edit
  def edit; end

  # POST /parties
  def create
    @party = Party.new(party_params)

    if @party.save
      redirect_to @party, notice: "Party was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /parties/1
  def update
    if @party.update(party_params)
      redirect_to @party, notice: "Party was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /parties/1
  def destroy
    @party.destroy
    redirect_to parties_url, notice: "Party was successfully destroyed."
  end

  def party_monitor
    if ApplicationRecord.local_server?
      @seedings = @party.seedings
      @league = @party.league
      @party_monitor = @party.party_monitor
      msg = ""
      if @party_monitor.blank?
        @party_monitor = @party.create_party_monitor
        if @party_monitor.present?
          msg = "Party Monitor wurde gestartet."
        else
          msg = "Party Monitor konnte nicht gestartet werden."
          redirect_to @party, notice: msg
          return
        end
      end
    else
      msg = "Party Monitor kann auf dem API Server nicht gestartet werden."
      redirect_to @party, notice: msg
      return
    end
    redirect_to @party_monitor, notice: msg
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_party
    @party = Party.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def party_params
    params.require(:party).permit(:date, :league_id, :remarks, :league_team_a_id, :league_team_b_id, :ba_id,
                                  :day_seqno, :data, :host_league_team_id)
  end
end
