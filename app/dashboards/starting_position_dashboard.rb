require "administrate/base_dashboard"

class StartingPositionDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Administrate::Field::Number,
    training_example: Administrate::Field::BelongsTo,
    description_text: Administrate::Field::Text,
    ball_measurements: Administrate::Field::Jsonb,
    position_variants: Administrate::Field::Jsonb,
    tags: Administrate::Field::HasMany,
    tag_list: Administrate::Field::String,
    created_at: Administrate::Field::DateTime,
    updated_at: Administrate::Field::DateTime,
  }.freeze

  COLLECTION_ATTRIBUTES = %i[
    id
    training_example
    description_text
    updated_at
  ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id
    training_example
    description_text
    ball_measurements
    position_variants
    tags
    created_at
    updated_at
  ].freeze

  FORM_ATTRIBUTES = %i[
    description_text
    ball_measurements
    position_variants
    tag_list
  ].freeze

  def display_resource(starting_position)
    "Ausgangsposition ##{starting_position.id}"
  end
end
