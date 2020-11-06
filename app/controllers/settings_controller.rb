class SettingsController < ApplicationController

  # GET /settings
  # GET /settings.json
  def index
    @setting = Setting.instance
    @edit_mode = false
    render :show
  end

  # GET /settings/1
  # GET /settings/1.json
  def show
    @setting = Setting.instance
    @edit_mode = false
  end

  # GET /settings/1/edit
  def edit
    @setting = Setting.instance
    @edit_mode = true
    render :show
  end

  def club_settings
    @setting = Setting.instance
  end

  def update_club_settings
    @setting = Setting.instance
    Setting.key_set_value(:small_table_no, params[:small_table_no].to_i)
    Setting.key_set_value(:large_table_no, params[:large_table_no].to_i)
    Setting.key_set_value(:pool_table_no, params[:pool_table_no].to_i)
    Setting.key_set_value(:snooker_table_no, params[:snooker_table_no].to_i)
    inst = Setting.instance
    inst.region_id = params[:region_id].to_i
    inst.club_id = params[:club_id].to_i
    inst.save!
    render 'home/index'
  end

  def tournament_settings
    @setting = Setting.instance
  end

  def update_tournament_settings
    @setting = Setting.instance
  end

  def manage_tournament
    @setting = Setting.instance
    @setting.update_attributes(tournament_id: params[:tournament_id].to_i)
    redirect_to tournament_path(@setting.tournament)
  end

  # PATCH/PUT /settings/1
  # PATCH/PUT /settings/1.json
  def update
    @setting = Setting.instance
    hash = @setting.read_attribute(:data)
    if setting_params["key"].present?
      setting_params["key"].each_with_index do |k, ix|
        hash[k] = params["val"][ix]
      end
    end
    @setting.data_will_change!

    respond_to do |format|
      if @setting.write_attribute(:data, hash)
        format.html { redirect_to @setting, notice: 'Home page setting was successfully updated.' }
        format.json { render :show, status: :ok, location: @setting }
      else
        format.html { render :edit }
        format.json { render json: @setting.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    raise ActionController::RoutingError.new('Not Found')
  end

  private

  # Only allow a list of trusted parameters through.
  def setting_params
    request.params
  end
end
