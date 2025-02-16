class IonModulesController < ApplicationController
  before_action :set_ion_module, only: %i[show edit update destroy]

  # GET /ion_modules
  def index
    @pagy, @ion_modules = pagy(IonModule.sort_by_params(params[:sort], sort_direction))

    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @ion_modules.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @ion_modules.load
  end

  # GET /ion_modules/1
  def show; end

  # GET /ion_modules/new
  def new
    @ion_module = IonModule.new
  end

  # GET /ion_modules/1/edit
  def edit; end

  # POST /ion_modules
  def create
    @ion_module = IonModule.new(ion_module_params)

    if @ion_module.save
      redirect_to @ion_module, notice: "Ion module was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /ion_modules/1
  def update
    if @ion_module.update(ion_module_params)
      redirect_to @ion_module, notice: "Ion module was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /ion_modules/1
  def destroy
    @ion_module.destroy
    redirect_to ion_modules_url, notice: "Ion module was successfully destroyed."
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_ion_module
    @ion_module = IonModule.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def ion_module_params
    params.require(:ion_module).permit(:module_id, :ion_content_id, :module_type, :position, :html, :data)
  end
end
