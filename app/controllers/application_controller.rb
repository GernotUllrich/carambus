class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  include SetCurrentRequestDetails
  include SetLocale
  include Jumpstart::Controller
  include Accounts::SubscriptionStatus
  include Users::NavbarNotifications
  include Users::TimeZone
  include Pagy::Backend
  include CurrentHelper
  include Sortable

  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :masquerade_user!

  before_action do
    if params.has_key?(:sSearch)
      session[:"s_#{params[:controller]}"] = params[:sSearch]
    end
    @sSearch = session[:"s_#{params[:controller]}"] if params[:action] == "index"
    @navbar = true
    @footer = true
    @dark = false
  end

  before_action :set_paper_trail_whodunnit
  around_action :switch_locale

  def default_url_options
    { locale: I18n.locale }
  end

  def set_current_admin
    #  set @current_user from session data here
    TournamentMonitor.current_admin = @current_user
  end
  protected


  def admin_only_check
    unless current_user.andand.admin?
      redirect_to root_path, alert: "Admin Only - ask gernot.ullrich@gmx.de for permission"
      return false
    end
  end

  def switch_locale(&action)
    locale = params[:locale] || I18n.default_locale
    I18n.with_locale(locale, &action)
  end
  # To add extra fields to Devise registration, add the attribute names to `extra_keys`
  def configure_permitted_parameters
    extra_keys = [:avatar, :name, :time_zone, :preferred_language]
    signup_keys = extra_keys + [:terms_of_service, :invite, owned_accounts_attributes: [:name]]
    devise_parameter_sanitizer.permit(:sign_up, keys: signup_keys)
    devise_parameter_sanitizer.permit(:account_update, keys: extra_keys)
    devise_parameter_sanitizer.permit(:accept_invitation, keys: extra_keys)
  end

  def after_sign_in_path_for(resource_or_scope)
    stored_location_for(resource_or_scope) || super
  end

  # Helper method for verifying authentication in a before_action, but redirecting to sign up instead of login
  def authenticate_user_with_sign_up!
    unless user_signed_in?
      store_location_for(:user, request.fullpath)
      redirect_to new_user_registration_path, alert: t("create_an_account_first")
    end
  end

  def require_current_account_admin
    unless current_account_admin?
      redirect_to root_path, alert: t("must_be_an_admin")
    end
  end
end
