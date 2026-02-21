require "administrate/base_dashboard"

class InternationalSourceDashboard < Administrate::BaseDashboard
  # ATTRIBUTE_TYPES
  # a hash that describes the type of each of the model's fields.
  #
  # Each different type represents an Administrate::Field object,
  # which determines how the attribute is displayed
  # on pages throughout the dashboard.
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    name: Field::String,
    source_type: Field::Select.with_options(
      collection: ['youtube', 'umb', 'ceb', 'acc', 'other']
    ),
    base_url: Field::String,
    api_credentials: Field::Text,
    active: Field::Boolean,
    metadata: Field::Text,
    last_scraped_at: Field::DateTime,
    created_at: Field::DateTime,
    updated_at: Field::DateTime,
    videos: Field::HasMany
  }.freeze

  # COLLECTION_ATTRIBUTES
  # an array of attributes that will be displayed on the model's index page.
  #
  # By default, it's limited to four items to reduce clutter on index pages.
  # Feel free to add, remove, or rearrange items.
  COLLECTION_ATTRIBUTES = %i[
    id
    name
    source_type
    active
    last_scraped_at
  ].freeze

  # SHOW_PAGE_ATTRIBUTES
  # an array of attributes that will be displayed on the model's show page.
  SHOW_PAGE_ATTRIBUTES = %i[
    id
    name
    source_type
    base_url
    api_credentials
    active
    metadata
    last_scraped_at
    created_at
    updated_at
    videos
  ].freeze

  # FORM_ATTRIBUTES
  # an array of attributes that will be displayed
  # on the model's form (`new` and `edit`) pages.
  FORM_ATTRIBUTES = %i[
    name
    source_type
    base_url
    api_credentials
    active
    metadata
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

  # Overwrite this method to customize how international sources are displayed
  # across all pages of the admin dashboard.
  #
  def display_resource(international_source)
    "#{international_source.name} (#{international_source.source_type})"
  end
end
