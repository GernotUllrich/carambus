module Admin
  class SettingsController < Admin::ApplicationController
    include CableReady::Broadcaster

    def index
      @config = Carambus.config
      @contexts = Region.order(:shortname).map { |region| [region.name, region.shortname] }
      @region = Region.find_by_shortname(@config.context)

      if @region
        @locations = Location.where(organizer_type: "Region", organizer_id: @region.id)
                           .order(:name)
        #.map { |location| [location.name, location.id] }

        @clubs = Club.where.not(name: "").where(region_id: @region.id)
                    .order(:name)
      else
        @locations = []
        @clubs = []
      end

      render 'admin/settings/index'
    end

    def create
      integer_keys = [:small_table_no, :large_table_no, :pool_table_no, :snooker_table_no,
                      :location_id, :club_id].map(&:to_s)
      config = config_params.to_h
      config.each do |key, value|
        value = value.to_i if integer_keys.include?(key)
        Carambus.config.send("#{key}=", value)
      end

      Carambus.save_config
      flash[:notice] = 'Configuration updated successfully. Please restart the application for changes to take effect.'
      redirect_to admin_settings_path
    end

    def update
      create  # Gleiche Logik wie create
    end

    def update_selectors
      region = Region.find_by_shortname(params[:context])

      if region
        locations = Location.where(organizer_type: "Region", organizer_id: region.id)
                           .order(:name)
                           .map { |location| [location.name, location.id.to_s] }

        clubs = Club.where(region_id: region.id)
                    .order(:name)
                    .map { |club| [club.name, club.id.to_s] }
      else
        locations = []
        clubs = []
      end

      render json: { locations: locations, clubs: clubs }
    end

    private

    def config_params
      params.require(:config).permit(
        :application_name, :carambus_api_url, :carambus_domain, :queue_adapter,
        :season_name, :force_update, :context,
        :support_email, :business_name, :business_address,
        :small_table_no, :large_table_no, :pool_table_no, :snooker_table_no,
        :location_id, :club_id, :no_local_protection
      )
    end
  end
end
