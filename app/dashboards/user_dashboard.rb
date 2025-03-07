require "administrate/base_dashboard"

class UserDashboard < Administrate::BaseDashboard
  # ATTRIBUTE_TYPES
  # a hash that describes the type of each of the model's fields.
  #
  # Each different type represents an Administrate::Field object,
  # which determines how the attribute is displayed
  # on pages throughout the dashboard.
  ATTRIBUTE_TYPES = {
    id: Administrate::Field::Number,
    accepted_privacy_at: Administrate::Field::DateTime,
    accepted_terms_at: Administrate::Field::DateTime,
    admin: Administrate::Field::Boolean,
    announcements_read_at: Administrate::Field::DateTime,
    code: Administrate::Field::String,
    confirmation_sent_at: Administrate::Field::DateTime,
    confirmation_token: Administrate::Field::String,
    confirmed_at: Administrate::Field::DateTime,
    current_sign_in_at: Administrate::Field::DateTime,
    current_sign_in_ip: Administrate::Field::String.with_options(searchable: false),
    email: Administrate::Field::String,
    encrypted_password: Administrate::Field::String,
    first_name: Administrate::Field::String,
    invitation_accepted_at: Administrate::Field::DateTime,
    invitation_created_at: Administrate::Field::DateTime,
    invitation_limit: Administrate::Field::Number,
    invitation_sent_at: Administrate::Field::DateTime,
    invitation_token: Administrate::Field::String,
    invitations_count: Administrate::Field::Number,
    invited_by_id: Administrate::Field::Number,
    invited_by_type: Administrate::Field::String,
    last_name: Administrate::Field::String,
    last_otp_timestep: Administrate::Field::Number,
    last_sign_in_at: Administrate::Field::DateTime,
    last_sign_in_ip: Administrate::Field::String.with_options(searchable: false),
    name: Administrate::Field::String,
    otp_backup_codes: Administrate::Field::Text,
    otp_required_for_login: Administrate::Field::Boolean,
    otp_secret: Administrate::Field::String,
    player_id: Administrate::Field::Number,
    preferences: Administrate::Field::String.with_options(searchable: false),
    preferred_language: Administrate::Field::String,
    remember_created_at: Administrate::Field::DateTime,
    reset_password_sent_at: Administrate::Field::DateTime,
    reset_password_token: Administrate::Field::String,
    role: Administrate::Field::Select.with_options(searchable: false, collection: ->(field) { field.resource.class.send(field.attribute.to_s.pluralize).keys }),
    sign_in_count: Administrate::Field::Number,
    time_zone: Administrate::Field::String,
    unconfirmed_email: Administrate::Field::String,
    username: Administrate::Field::String,
    created_at: Administrate::Field::DateTime,
    updated_at: Administrate::Field::DateTime
  }.freeze

  # COLLECTION_ATTRIBUTES
  # an array of attributes that will be displayed on the model's index page.
  #
  # By default, it's limited to four items to reduce clutter on index pages.
  # Feel free to add, remove, or rearrange items.
  COLLECTION_ATTRIBUTES = %i[
    id
    name
    email
    role
  ].freeze

  # SHOW_PAGE_ATTRIBUTES
  # an array of attributes that will be displayed on the model's show page.
  SHOW_PAGE_ATTRIBUTES = %i[
    id
    accepted_privacy_at
    accepted_terms_at
    admin
    announcements_read_at
    code
    confirmation_sent_at
    confirmation_token
    confirmed_at
    current_sign_in_at
    current_sign_in_ip
    email
    encrypted_password
    first_name
    invitation_accepted_at
    invitation_created_at
    invitation_limit
    invitation_sent_at
    invitation_token
    invitations_count
    invited_by_id
    invited_by_type
    last_name
    last_otp_timestep
    last_sign_in_at
    last_sign_in_ip
    name
    otp_backup_codes
    otp_required_for_login
    otp_secret
    player_id
    preferences
    preferred_language
    remember_created_at
    reset_password_sent_at
    reset_password_token
    role
    sign_in_count
    time_zone
    unconfirmed_email
    username
    created_at
    updated_at
  ].freeze

  # FORM_ATTRIBUTES
  # an array of attributes that will be displayed
  # on the model's form (`new` and `edit`) pages.
  FORM_ATTRIBUTES = %i[
    accepted_privacy_at
    accepted_terms_at
    admin
    announcements_read_at
    code
    confirmation_sent_at
    confirmation_token
    confirmed_at
    current_sign_in_at
    current_sign_in_ip
    email
    encrypted_password
    first_name
    invitation_accepted_at
    invitation_created_at
    invitation_limit
    invitation_sent_at
    invitation_token
    invitations_count
    invited_by_id
    invited_by_type
    last_name
    last_otp_timestep
    last_sign_in_at
    last_sign_in_ip
    name
    otp_backup_codes
    otp_required_for_login
    otp_secret
    player_id
    preferences
    preferred_language
    remember_created_at
    reset_password_sent_at
    reset_password_token
    role
    sign_in_count
    time_zone
    unconfirmed_email
    username
  ].freeze

  # COLLECTION_FILTERS
  # a hash that defines filters that can be used while searching via the search
  # field of the dashboard.
  #
  # For example to add an option to search for open resources by typing "open:"
  # in the search field:
  #
  #   COLLECTION_FILTERS = {
  #     open: ->(resources) { resources.where(open: true) }
  #   }.freeze
  COLLECTION_FILTERS = {}.freeze

  # Overwrite this method to customize how users are displayed
  # across all pages of the admin dashboard.
  #
  # def display_resource(user)
  #   "User ##{user.id}"
  # end
end
