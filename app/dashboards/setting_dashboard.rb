require "administrate/base_dashboard"

class SettingDashboard < Administrate::BaseDashboard
  # ATTRIBUTE_TYPES
  # a hash that describes the type of each of the model's fields.
  #
  # Each different type represents an Administrate::Field object,
  # which determines how the attribute is displayed
  # on pages throughout the dashboard.
  ATTRIBUTE_TYPES = {
    application_name: Field::String,
    location_name: Field::String,
    location_address: Field::String,
    domain: Field::String,
    default_from_email: Field::String,
    support_email: Field::String,
    carambus_api_url: Field::String,
    region_id: Field::Number,
    club_id: Field::Number,
    location_id: Field::Number,
    small_table_no: Field::Number,
    large_table_no: Field::Number,
    pool_table_no: Field::Number,
    snooker_table_no: Field::Number,
  }.freeze

  # SHOW_PAGE_ATTRIBUTES
  # an array of attributes that will be displayed on the model's show page.
  SHOW_PAGE_ATTRIBUTES = %i[
    application_name: Field::String,
    location_name: Field::String,
    location_address: Field::String,
    domain: Field::String,
    default_from_email: Field::String,
    support_email: Field::String,
    carambus_api_url: Field::String,
    region_id: Field::Number,
    club_id: Field::Number,
    location_id: Field::Number,
    small_table_no: Field::Number,
    large_table_no: Field::Number,
    pool_table_no: Field::Number,
    snooker_table_no: Field::Number,
  ].freeze

  # FORM_ATTRIBUTES
  # an array of attributes that will be displayed
  # on the model's form (`new` and `edit`) pages.
  FORM_ATTRIBUTES = %i[
    application_name: Field::String,
    location_name: Field::String,
    location_address: Field::String,
    domain: Field::String,
    default_from_email: Field::String,
    support_email: Field::String,
    carambus_api_url: Field::String,
    region_id: Field::Number,
    club_id: Field::Number,
    location_id: Field::Number,
    small_table_no: Field::Number,
    large_table_no: Field::Number,
    pool_table_no: Field::Number,
    snooker_table_no: Field::Number,
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
