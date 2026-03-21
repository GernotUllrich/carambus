class Admin::MonitorControlsController < ApplicationController
  before_action :require_admin
  
  def index
    @locations = Location.all.order(:name)
  end
  
  def force_reload
    location_id = params[:location_id]
    
    if location_id.present?
      # Broadcast to specific location
      ActionCable.server.broadcast(
        "location_#{location_id}",
        { type: 'force_reload', timestamp: Time.now.to_i }
      )
      
      flash[:success] = "Reload signal sent to Location ##{location_id}"
      Rails.logger.info "🔄 Admin force reload triggered for location ##{location_id}"
    else
      flash[:error] = "No location specified"
    end
    
    redirect_to admin_monitor_controls_path
  end
  
  private
  
  def require_admin
    unless current_user&.admin?
      flash[:error] = "Admin access required"
      redirect_to root_path
    end
  end
end
