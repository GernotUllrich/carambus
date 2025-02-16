class IonContentsController < ApplicationController
  before_action :set_ion_content, only: %i[show edit update destroy]

  # GET /ion_contents
  def index
    @pagy, @ion_contents = pagy(IonContent.sort_by_params(params[:sort], sort_direction))

    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @ion_contents.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @ion_contents.load
  end

  # GET /ion_contents/1
  def show; end

  # GET /ion_contents/new
  def new
    @ion_content = IonContent.new
  end

  # GET /ion_contents/1/edit
  def edit; end

  # POST /ion_contents
  def create
    @ion_content = IonContent.new(ion_content_params)

    if @ion_content.save
      redirect_to @ion_content, notice: "Ion content was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /ion_contents/1
  def update
    if @ion_content.update(ion_content_params.merge(data: JSON.parse(ion_content_params[:data])))
      redirect_to @ion_content, notice: "Ion content was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /ion_contents/1
  def destroy
    @ion_content.destroy
    redirect_to ion_contents_url, notice: "Ion content was successfully destroyed."
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_ion_content
    @ion_content = IonContent.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def ion_content_params
    params.require(:ion_content).permit(:page_id, :title, :html, :level, :scraped_at, :deep_scraped_at,
                                        :ion_content_id, :data, :hidden, :position)
  end
end
