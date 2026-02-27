require "administrate/base_dashboard"

class VideoDashboard < Administrate::BaseDashboard
  # ATTRIBUTE_TYPES
  # a hash that describes the type of each of the model's fields.
  #
  # Each different type represents an Administrate::Field object,
  # which determines how the attribute is displayed
  # on pages throughout the dashboard.
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    data: Field::String.with_options(searchable: false),
    description: Field::Text,
    discipline: Field::BelongsTo,
    duration: Field::Number,
    external_id: Field::String,
    hidden: Field::Boolean,
    international_source: Field::BelongsTo,
    language: Field::String,
    like_count: Field::Number,
    metadata_extracted: Field::Boolean,
    metadata_extracted_at: Field::DateTime,
    published_at: Field::DateTime,
    thumbnail_url: Field::String,
    title: Field::String,
    videoable: Field::Polymorphic,
    view_count: Field::Number,
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
    data
    description
    discipline
  ].freeze

  # SHOW_PAGE_ATTRIBUTES
  # an array of attributes that will be displayed on the model's show page.
  SHOW_PAGE_ATTRIBUTES = %i[
    id
    data
    description
    discipline
    duration
    external_id
    hidden
    international_source
    language
    like_count
    metadata_extracted
    metadata_extracted_at
    published_at
    thumbnail_url
    title
    videoable
    view_count
    created_at
    updated_at
  ].freeze

  # FORM_ATTRIBUTES
  # an array of attributes that will be displayed
  # on the model's form (`new` and `edit`) pages.
  FORM_ATTRIBUTES = %i[
    data
    description
    discipline
    duration
    external_id
    hidden
    international_source
    language
    like_count
    metadata_extracted
    metadata_extracted_at
    published_at
    thumbnail_url
    title
    videoable
    view_count
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

  # Overwrite this method to customize how videos are displayed
  # across all pages of the admin dashboard.
  #
  # def display_resource(video)
  #   "Video ##{video.id}"
  # end
end
