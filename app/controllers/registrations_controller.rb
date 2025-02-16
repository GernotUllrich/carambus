# frozen_string_literal: true

class RegistrationsController < Devise::RegistrationsController
  before_action :configure_permitted_parameters
  # PUT /resource
  # We need to use a copy of the resource because we don't want to change
  # the current user in place.
  def update
    self.resource = resource_class.to_adapter.get!(send(:"current_#{resource_name}").to_key)
    prev_unconfirmed_email = resource.unconfirmed_email if resource.respond_to?(:unconfirmed_email)

    resource_updated = update_resource(resource, account_update_params)
    yield resource if block_given?
    if resource_updated
      set_flash_message_for_update(resource, prev_unconfirmed_email)
      bypass_sign_in resource, scope: resource_name if sign_in_after_change_password?

      #respond_with resource, location: after_update_path_for(resource)
      redirect_to root_path
    else
      clean_up_passwords resource
      set_minimum_password_length
      respond_with resource
    end
  end


  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:account_update,
                                      keys: %i[
                                        first_name
                                        last_name
                                        email
                                        current_password
                                        password
                                        timezone
                                        theme
                                        locale
                                      ])
  end

  def update_resource(resource, params)
    # Handle preferences update
    resource.preferences ||= {}
    %i[theme timezone locale].each do |key|
      resource.preferences[key.to_s] = params.delete(key) if params[key]
    end

    # Handle password update
    if params[:password].present?
      super
    else
      resource.update_without_password(params.except(:current_password))
    end
  end

  def after_update_path_for(resource)
    edit_user_registration_path
  end
end
