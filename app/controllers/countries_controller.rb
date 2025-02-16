class CountriesController < ApplicationController
  before_action :admin_only_check, except: %i[show index]
  before_action :set_country, only: %i[show edit update destroy]

  # GET /countries
  def index
    results = SearchService.call( Country.search_hash(params) )
    @pagy, @countries = pagy(results)
    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @countries.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @countries.load
  end

  # GET /countries/1
  def show; end

  # GET /countries/new
  def new
    @country = Country.new
  end

  # GET /countries/1/edit
  def edit; end

  # POST /countries
  def create
    @country = Country.new(country_params)

    if @country.save
      redirect_to @country, notice: "Country was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /countries/1
  def update
    if @country.update(country_params)
      redirect_to @country, notice: "Country was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /countries/1
  def destroy
    @country.destroy
    redirect_to countries_url, notice: "Country was successfully destroyed."
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_country
    @country = Country.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def country_params
    params.require(:country).permit(:name, :code)
  end
end
