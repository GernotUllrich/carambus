class CategoryCcsController < ApplicationController
  before_action :set_category_cc, only: %i[show edit update destroy]

  # GET /category_ccs
  def index
    results = SearchService.call( CategoryCc.search_hash(params) )
    @pagy, @category_ccs = pagy(results)
    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @category_ccs.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @category_ccs.load
  end

  # GET /category_ccs/1
  def show; end

  # GET /category_ccs/new
  def new
    @category_cc = CategoryCc.new
  end

  # GET /category_ccs/1/edit
  def edit; end

  # POST /category_ccs
  def create
    @category_cc = CategoryCc.new(category_cc_params)

    if @category_cc.save
      redirect_to @category_cc, notice: "Category cc was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /category_ccs/1
  def update
    if @category_cc.update(category_cc_params)
      redirect_to @category_cc, notice: "Category cc was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /category_ccs/1
  def destroy
    @category_cc.destroy
    redirect_to category_ccs_url, notice: "Category cc was successfully destroyed."
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_category_cc
    @category_cc = CategoryCc.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def category_cc_params
    params.require(:category_cc).permit(:context, :max_age, :min_age, :name, :sex, :status, :cc_id, :branch_cc_id)
  end
end
