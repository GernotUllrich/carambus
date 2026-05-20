class TablesController < ApplicationController
  # Phase 17 / 17-01: toggle_lock ist NICHT admin-only, sondern eigen-autorisiert
  # (Admin ODER Sportwart der Location). Die uebrigen CRUD-Pfade bleiben admin-only.
  before_action :admin_only_check, except: %i[show index toggle_lock]
  before_action :set_table, only: %i[show edit update destroy toggle_lock]
  before_action :authorize_table_lock!, only: %i[toggle_lock]

  # GET /tables
  def index
    @pagy, @tables = pagy(Table.sort_by_params(params[:sort], sort_direction))

    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @tables.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @tables.load
  end

  # GET /tables/1
  def show
    @navbar = false
    @footer = false
  end

  # GET /tables/new
  def new
    @table = Table.new
  end

  # GET /tables/1/edit
  def edit; end

  # POST /tables
  def create
    @table = Table.new(table_params)

    if @table.save
      redirect_to @table, notice: "Table was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /tables/1
  def update
    if @table.update(table_params)
      redirect_to @table, notice: "Table was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /tables/1
  def destroy
    @table.destroy
    redirect_to tables_url, notice: "Table was successfully destroyed."
  end

  # PATCH /tables/1/toggle_lock
  # Phase 17 / 17-01: Tisch-Lock fuer Turnierbetrieb umschalten. Gesperrte Tische sind
  # gegen Operator-Eingriffe am Scoreboard gesperrt (siehe TableMonitor#locked_scoreboard).
  # NICHT die Google-Calendar-"Reservierung" (Heizung/Kommunikation).
  def toggle_lock
    @table.update!(locked_for_tournament: !@table.locked_for_tournament?)
    notice = if @table.locked_for_tournament?
      "Tisch #{@table.name} gesperrt – Scoreboard gegen Operator-Eingriffe gesperrt."
    else
      "Sperre von Tisch #{@table.name} aufgehoben."
    end
    redirect_back fallback_location: tables_url, notice: notice
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_table
    @table = Table.find(params[:id])
  end

  # Phase 17 / 17-01: Nur Admin ODER Sportwart der Location darf sperren/freigeben.
  def authorize_table_lock!
    return if current_user&.admin?
    return if current_user&.sportwart_location_ids&.include?(@table.location_id)

    redirect_back fallback_location: tables_url,
      alert: "Nur Admin oder Sportwart dieser Location darf Tische sperren."
  end

  # Only allow a trusted parameter "white list" through.
  def table_params
    params.require(:table).permit(:location_id, :table_kind_id, :name, :data, :ip_address)
  end
end
