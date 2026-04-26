require "administrate/base_dashboard"

class StartPositionDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Administrate::Field::Number,
    training_example: Administrate::Field::BelongsTo,
    # Phase 38.4 deploy-fix 2026-04-26: Field::ActiveStorage requires
    # `administrate-field-active_storage` gem (not in Gemfile) — production
    # eager_load crashed every rails command. Filename-only fallback so the
    # dashboard boots; restore proper field type when admin-UI image upload
    # for training is needed (add gem, then revert).
    image: Administrate::Field::String,
    description_text: Administrate::Field::Text,
    description_text_de: Administrate::Field::Text,
    description_text_en: Administrate::Field::Text,
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
    description_text_de
    updated_at
  ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id
    training_example
    image
    description_text_de
    description_text_en
    ball_measurements
    position_variants
    tags
    created_at
    updated_at
  ].freeze

  FORM_ATTRIBUTES = %i[
    training_example
    image
    ball_measurements
    position_variants
    tag_list
  ].freeze

  def display_resource(start_position)
    "StartPosition ##{start_position.id}"
  end
end
