require "administrate/base_dashboard"

class StreamConfigurationDashboard < Administrate::BaseDashboard
  # ATTRIBUTE_TYPES
  # a hash that describes the type of each of the model's fields.
  #
  # Each different type represents an Administrate::Field object,
  # which determines how the attribute is displayed
  # on pages throughout the dashboard.
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    table: Field::BelongsTo,
    location: Field::HasOne.with_options(
      class_name: "Location",
      foreign_key: :table_id
    ),
    youtube_stream_key: Field::String,
    youtube_channel_id: Field::String,
    camera_device: Field::String,
    camera_width: Field::Number,
    camera_height: Field::Number,
    camera_fps: Field::Number,
    overlay_enabled: Field::Boolean,
    overlay_position: Field::String,
    overlay_height: Field::Number,
    status: Field::Select.with_options(
      collection: %w[inactive starting active stopping error]
    ),
    last_started_at: Field::DateTime,
    last_stopped_at: Field::DateTime,
    error_message: Field::Text,
    restart_count: Field::Number,
    raspi_ip: Field::String,
    raspi_ssh_port: Field::Number,
    video_bitrate: Field::Number,
    audio_bitrate: Field::Number,
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
    table
    status
    youtube_channel_id
  ].freeze

  # SHOW_PAGE_ATTRIBUTES
  # an array of attributes that will be displayed on the model's show page.
  SHOW_PAGE_ATTRIBUTES = %i[
    id
    table
    location
    youtube_stream_key
    youtube_channel_id
    camera_device
    camera_width
    camera_height
    camera_fps
    overlay_enabled
    overlay_position
    overlay_height
    status
    last_started_at
    last_stopped_at
    error_message
    restart_count
    raspi_ip
    raspi_ssh_port
    video_bitrate
    audio_bitrate
    created_at
    updated_at
  ].freeze

  # FORM_ATTRIBUTES
  # an array of attributes that will be displayed
  # on the model's form (`new` and `edit`) pages.
  FORM_ATTRIBUTES = %i[
    table
    youtube_stream_key
    youtube_channel_id
    camera_device
    camera_width
    camera_height
    camera_fps
    overlay_enabled
    overlay_position
    overlay_height
    status
    error_message
    restart_count
    raspi_ip
    raspi_ssh_port
    video_bitrate
    audio_bitrate
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
  COLLECTION_FILTERS = {
    active: ->(resources) { resources.where(status: 'active') },
    inactive: ->(resources) { resources.where(status: 'inactive') },
    error: ->(resources) { resources.where(status: 'error') }
  }.freeze

  # Overwrite this method to customize how stream configurations are displayed
  # across all pages of the admin dashboard.
  #
  def display_resource(stream_configuration)
    "Stream Config ##{stream_configuration.id} - #{stream_configuration.table&.name || 'No Table'}"
  end
end




