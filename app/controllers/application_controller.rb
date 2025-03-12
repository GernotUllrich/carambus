class ApplicationController < ActionController::Base
  #include SetCurrentRequestDetails
  include CableReady::Broadcaster
  include CanCan::ControllerAdditions
  include DarkModeHelper
  protect_from_forgery with: :exception

  include Authentication
  include Authorization
  include CurrentHelper
  include DeviceFormat
  include Pagy::Backend
  include Sortable
  include Users::TimeZone
  include SetCurrentRequestDetails

  before_action :check_mini_profiler if Rails.env != "production" && Rails.env != "test"
  before_action :set_paper_trail_whodunnit
  before_action do
    if params.has_key?(:sSearch)
      session[:"s_#{params[:controller]}"] = params[:sSearch]
    else
      params[:sSearch] = session[:"s_#{params[:controller]}"]
    end
    @sSearch = session[:"s_#{params[:controller]}"] if params[:action] == "index"
    @navbar = true
    @footer = true
  end
  before_action :set_user_preferences
  before_action :set_model_class
  around_action :switch_locale
  around_action :set_current_user
  # impersonates :user

  # before_action :set_locale

  def check_mini_profiler
    # if current_user&.is_admin? # Assuming you have a method to verify if a user is an admin
    Rack::MiniProfiler.authorize_request
    # end
  end

  def local_server?
    Carambus.config.carambus_api_url.present?
  end

  def default_url_options
    { locale: I18n.locale }
  end

  def set_current_admin
    #  set @current_user from session data here
    TournamentMonitor.current_admin = @current_user
  end

  def current_ability
    @current_ability ||= Ability.new(current_user)
  end

  def dark_mode?
    return false unless user_signed_in?
    current_user.prefers_dark_mode?
  end
  helper_method :dark_mode?

  protected

  def logged_in_check
    return if current_user.present?

    redirect_back fallback_location: root_path,
                  alert: "Anmeldung erforderlich - ask gernot.ullrich@gmx.de for permission"
    false
  end

  def admin_only_check
    return if current_user.andand.admin? || guest_player_creation?

    redirect_back fallback_location: root_path, alert: "Admin Only - ask gernot.ullrich@gmx.de for permission"
    false
  end

  def guest_player_creation?
    Current.user.andand.email == "scoreboard@carambus.de" && params[:club_id].present? && params[:season_id].present?
  end

  def switch_locale(&action)
    Rails.logger.debug "8 Locale param: #{params[:locale]}"
    locale = params[:locale] || current_user&.preferred_language || extract_locale_from_accept_language_header || I18n.default_locale
    Rails.logger.debug "9 Setting locale to: #{locale}"
    I18n.with_locale(locale, &action)
  end

  def after_sign_in_path_for(resource)
    if resource.admin?
      admin_root_path
    else
      super
    end
  end

  private

  def require_account
    redirect_to new_user_registration_path unless current_account
  end

  def set_current_user
    User.current = current_user
    yield
  ensure
    User.current = nil
  end

  def set_user_preferences
    if user_signed_in?
      # Set theme
      case current_user.preferences['theme']
      when 'dark' then helpers.set_dark_mode(true)
      when 'light' then helpers.set_dark_mode(false)
      else helpers.set_system_theme
      end

      # Set locale
      I18n.locale = current_user.preferences['locale'] || I18n.default_locale

      # Set timezone
      Time.zone = current_user.preferences['timezone'] || 'Berlin'
    end
  end

  def extract_locale_from_accept_language_header
    request.env['HTTP_ACCEPT_LANGUAGE']&.scan(/^[a-z]{2}/)&.first
  end

  def set_model_class
    controller_name = self.class.name.sub(/Controller$/, '')
    @model_class = controller_name.singularize.safe_constantize
  end
end
