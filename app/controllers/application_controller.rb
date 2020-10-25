class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  before_action :authenticate_user!
  protect_from_forgery with: :exception
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :set_paper_trail_whodunnit

  before_action :set_current_admin

  def set_current_admin
    #  set @current_user from session data here
    TournamentMonitor.current_admin = @current_user
  end

  protected

  # TODO what's following?
  def configure_permitted_parameters
    added_attrs = [:username, :email, :password, :password_confirmation, :remember_me]
    devise_parameter_sanitizer.permit :sign_up, keys: added_attrs
    devise_parameter_sanitizer.permit :account_update, keys: added_attrs
  end

  private

  def after_sign_in_path_for(resource)
    stored_location_for(resource) || tournament_monitors_path
  end
end
