class TableLocalsController < ApplicationController
  before_action :set_table_local, only: %i[show edit update destroy]

  # Uncomment to enforce Pundit authorization
  # after_action :verify_authorized
  # rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  # GET /table_locals
  def index
    @pagy, @table_locals = pagy(TableLocal.sort_by_params(params[:sort], sort_direction))

    # Uncomment to authorize with Pundit
    # authorize @table_locals
  end

  # GET /table_locals/1 or /table_locals/1.json
  def show; end

  # GET /table_locals/new
  def new
    @table_local = TableLocal.new

    # Uncomment to authorize with Pundit
    # authorize @table_local
  end

  # GET /table_locals/1/edit
  def edit; end

  # POST /table_locals or /table_locals.json
  def create
    @table_local = TableLocal.new(table_local_params)

    # Uncomment to authorize with Pundit
    # authorize @table_local

    respond_to do |format|
      if @table_local.save
        format.html { redirect_to @table_local, notice: "Table local was successfully created." }
        format.json { render :show, status: :created, location: @table_local }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @table_local.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /table_locals/1 or /table_locals/1.json
  def update
    respond_to do |format|
      if @table_local.update(table_local_params)
        format.html { redirect_to @table_local, notice: "Table local was successfully updated." }
        format.json { render :show, status: :ok, location: @table_local }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @table_local.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /table_locals/1 or /table_locals/1.json
  def destroy
    @table_local.destroy
    respond_to do |format|
      format.html do
        redirect_to table_locals_url, status: :see_other, notice: "Table local was successfully destroyed."
      end
      format.json { head :no_content }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_table_local
    @table_local = TableLocal.find(params[:id])

    # Uncomment to authorize with Pundit
    # authorize @table_local
  rescue ActiveRecord::RecordNotFound
    redirect_to table_locals_path
  end

  # Only allow a list of trusted parameters through.
  def table_local_params
    params.require(:table_local).permit(:tpl_ip_address, :ip_address, :table_id)

    # Uncomment to use Pundit permitted attributes
    # params.require(:table_local).permit(policy(@table_local).permitted_attributes)
  end
end
