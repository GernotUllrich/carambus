class ClubsController < ApplicationController
  before_action :set_club, only: [:show, :edit, :update, :destroy, :get_club_details, :reload_from_ba, :reload_from_ba_with_player_details]

  # GET /clubs
  # GET /clubs.json
  def index
    @clubs = Club.page(params[:page]).per(24)
    respond_to do |format|
      format.html
      format.json { render json: ClubsDatatable.new(view_context, nil) }
    end
  end

  # GET /clubs/1
  # GET /clubs/1.json
  def show
  end

  def get_club_details
    render partial: 'club_details', locals: {club: @club}, layout: nil
  end

  def reload_from_ba
    @club.scrape_single_club(player_details: false)
    redirect_to club_path(@club)
  end

  def reload_from_ba_with_player_details
    @club.scrape_single_club(player_details: true)
    redirect_to club_path(@club)
  end

  # GET /clubs/new
  def new
    @club = Club.new
  end

  # GET /clubs/1/edit
  def edit
  end

  # POST /clubs
  # POST /clubs.json
  def create
    @club = Club.new(club_params)

    respond_to do |format|
      if @club.save
        format.html { redirect_to @club, notice: 'Club was successfully created.' }
        format.json { render :show, status: :created, location: @club }
      else
        format.html { render :new }
        format.json { render json: @club.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /clubs/1
  # PATCH/PUT /clubs/1.json
  def update
    respond_to do |format|
      if @club.update(club_params)
        format.html { redirect_to @club, notice: 'Club was successfully updated.' }
        format.json { render :show, status: :ok, location: @club }
      else
        format.html { render :edit }
        format.json { render json: @club.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /clubs/1
  # DELETE /clubs/1.json
  def destroy
    @club.destroy
    respond_to do |format|
      format.html { redirect_to clubs_url, notice: 'Club was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_club
      @club = Club.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def club_params
      params.require(:club).permit(:ba_id, :region_id, :name, :shortname, :address, :homepage, :email, :priceinfo, :logo, :status, :founded, :dbu_entry)
    end
end
