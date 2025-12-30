# frozen_string_literal: true

module Admin
  class StreamConfigurationsController < Admin::ApplicationController
    before_action :set_stream_configuration, only: [:show, :edit, :update, :destroy, :start, :stop, :restart, :health_check]
    before_action :set_locations_and_tables, only: [:new, :edit, :create, :update]
    
    # GET /admin/stream_configurations
    def index
      @stream_configurations = StreamConfiguration
        .includes(:table, :location)
        .order('locations.name, tables.name')
        .references(:locations, :tables)
      
      # Group by location for better organization
      @configurations_by_location = @stream_configurations.group_by(&:location)
    end
    
    # GET /admin/stream_configurations/1
    def show
      @recent_logs = fetch_recent_logs(@stream_configuration)
    end
    
    # GET /admin/stream_configurations/new
    def new
      @stream_configuration = StreamConfiguration.new
      
      # Pre-populate from params if available
      if params[:table_id]
        @stream_configuration.table_id = params[:table_id]
      end
    end
    
    # GET /admin/stream_configurations/1/edit
    def edit
    end
    
    # POST /admin/stream_configurations
    def create
      @stream_configuration = StreamConfiguration.new(stream_configuration_params.except(:location_id))
      
      if @stream_configuration.save
        redirect_to admin_stream_configurations_path, notice: 'Stream-Konfiguration wurde erfolgreich erstellt.'
      else
        render :new
      end
    end
    
    # PATCH/PUT /admin/stream_configurations/1
    def update
      if @stream_configuration.update(stream_configuration_params)
        # If stream is active, restart it to apply new settings
        if @stream_configuration.active?
          @stream_configuration.restart_streaming
          flash[:notice] = 'Konfiguration aktualisiert. Stream wird neu gestartet...'
        else
          flash[:notice] = 'Stream-Konfiguration wurde erfolgreich aktualisiert.'
        end
        redirect_to admin_stream_configurations_path
      else
        render :edit
      end
    end
    
    # DELETE /admin/stream_configurations/1
    def destroy
      # Stop stream if running
      @stream_configuration.stop_streaming if @stream_configuration.operational?
      
      @stream_configuration.destroy
      redirect_to admin_stream_configurations_path, notice: 'Stream-Konfiguration wurde gelöscht.'
    end
    
    # POST /admin/stream_configurations/1/start
    def start
      if @stream_configuration.start_streaming
        redirect_to admin_stream_configurations_path, notice: 'Stream wird gestartet...'
      else
        redirect_to admin_stream_configurations_path, alert: "Stream kann nicht gestartet werden (Status: #{@stream_configuration.status})"
      end
    end
    
    # POST /admin/stream_configurations/1/stop
    def stop
      if @stream_configuration.stop_streaming
        redirect_to admin_stream_configurations_path, notice: 'Stream wird gestoppt...'
      else
        redirect_to admin_stream_configurations_path, alert: "Stream kann nicht gestoppt werden (Status: #{@stream_configuration.status})"
      end
    end
    
    # POST /admin/stream_configurations/1/restart
    def restart
      @stream_configuration.restart_streaming
      redirect_to admin_stream_configurations_path, notice: 'Stream wird neu gestartet...'
    end
    
    # POST /admin/stream_configurations/1/health_check
    def health_check
      @stream_configuration.check_health
      
      respond_to do |format|
        format.html { redirect_to admin_stream_configurations_path, notice: 'Health-Check wurde gestartet...' }
        format.json { 
          render json: {
            stream_id: @stream_configuration.id,
            status: @stream_configuration.status,
            last_started_at: @stream_configuration.last_started_at&.iso8601,
            error_message: @stream_configuration.error_message
          }
        }
      end
    end
    
    # POST /admin/stream_configurations/deploy_all
    def deploy_all
      location_id = params[:location_id]
      
      if location_id.present?
        location = Location.find(location_id)
        configs = location.stream_configurations
      else
        configs = StreamConfiguration.all
      end
      
      configs.each do |config|
        StreamDeployJob.perform_later(config.id)
      end
      
      redirect_to admin_stream_configurations_path, 
        notice: "Deployment für #{configs.count} Stream(s) wurde gestartet..."
    end
    
    private
    
    def set_stream_configuration
      @stream_configuration = StreamConfiguration.find(params[:id])
    end
    
    def set_locations_and_tables
      @locations = Location.includes(:tables).order(:name)
    end
    
    def stream_configuration_params
      params.require(:stream_configuration).permit(
        :table_id,
        :youtube_stream_key,
        :youtube_channel_id,
        :camera_device,
        :camera_width,
        :camera_height,
        :camera_fps,
        :overlay_enabled,
        :overlay_position,
        :overlay_height,
        :raspi_ip,
        :raspi_ssh_user,
        :raspi_ssh_port,
        :video_bitrate,
        :audio_bitrate
      )
    end
    
    def fetch_recent_logs(config)
      # This would SSH to the Raspi and fetch recent logs
      # For now, return placeholder
      []
    rescue
      []
    end
  end
end

