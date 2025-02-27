require "administrate/base_dashboard"

class UserDashboard < Administrate::BaseDashboard
  # ATTRIBUTE_TYPES
  # a hash that describes the type of each of the model's fields.
  #
  # Each different type represents an Administrate::Field object,
  # which determines how the attribute is displayed
  # on pages throughout the dashboard.
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    accepted_privacy_at: Field::DateTime,
    accepted_terms_at: Field::DateTime,
    admin: Field::Boolean,
    announcements_read_at: Field::DateTime,
    code: Field::String,
    confirmation_sent_at: Field::DateTime,
    confirmation_token: Field::String,
    confirmed_at: Field::DateTime,
    current_sign_in_at: Field::DateTime,
    current_sign_in_ip: Field::String.with_options(searchable: false),
    email: Field::String,
    encrypted_password: Field::String,
    first_name: Field::String,
    invitation_accepted_at: Field::DateTime,
    invitation_created_at: Field::DateTime,
    invitation_limit: Field::Number,
    invitation_sent_at: Field::DateTime,
    invitation_token: Field::String,
    invitations_count: Field::Number,
    invited_by_id: Field::Number,
    invited_by_type: Field::String,
    last_name: Field::String,
    last_otp_timestep: Field::Number,
    last_sign_in_at: Field::DateTime,
    last_sign_in_ip: Field::String.with_options(searchable: false),
    locked_at: Field::DateTime,
    name: Field::String,
    otp_backup_codes: Field::Text,
    otp_required_for_login: Field::Boolean,
    otp_secret: Field::String,
    player_id: Field::Number,
    preferences: Field::String.with_options(searchable: false),
    preferred_language: Field::String,
    remember_created_at: Field::DateTime,
    reset_password_sent_at: Field::DateTime,
    reset_password_token: Field::String,
    role: Field::Select.with_options(searchable: false, collection: ->(field) { field.resource.class.send(field.attribute.to_s.pluralize).keys }),
    sign_in_count: Field::Number,
    time_zone: Field::String,
    unconfirmed_email: Field::String,
    unlock_token: Field::String,
    username: Field::String,
    created_at: Field::DateTime,
    updated_at: Field::DateTime
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
    locked_at
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
    unlock_token
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
    locked_at
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
    unlock_token
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
