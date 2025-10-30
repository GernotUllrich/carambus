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

      # Load quick_game_presets from the current environment section (not merged)
      # This ensures we show the actual editable values, not the defaults
      yaml = YAML.load_file(Rails.root.join('config', 'carambus.yml'))
      env_presets = yaml[Rails.env]&.[]('quick_game_presets')
      default_presets = yaml['default']&.[]('quick_game_presets')
      
      # Show environment-specific if it exists, otherwise show default
      presets_to_edit = env_presets || default_presets
      
      # Convert quick_game_presets to pretty JSON for editing
      @quick_game_presets_json = if presets_to_edit
        JSON.pretty_generate(presets_to_edit)
      else
        ""
      end

      # Check if config is locked
      @config_locked = File.exist?(Rails.root.join('config', 'carambus.yml.lock'))

      render 'admin/settings/index'
    end

    def create
      integer_keys = [:location_id, :club_id].map(&:to_s)
      json_keys = [:quick_game_presets].map(&:to_s)
      
      config = config_params.to_h
      
      # Parse JSON fields
      json_keys.each do |key|
        if config[key].present?
          begin
            config[key] = JSON.parse(config[key])
          rescue JSON::ParserError => e
            flash[:alert] = "Invalid JSON for #{key}: #{e.message}"
            redirect_to admin_settings_path
            return
          end
        end
      end
      
      config.each do |key, value|
        value = value.to_i if integer_keys.include?(key)
        Carambus.config.send("#{key}=", value)
      end

      Carambus.save_config(create_lock: true)
      flash[:notice] = 'Configuration updated successfully. Please restart the application for changes to take effect. Lock file created to protect your settings.'
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
        :location_id, :club_id, :no_local_protection,
        :quick_game_presets
      )
    end
  end
end
