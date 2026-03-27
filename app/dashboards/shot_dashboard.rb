require "administrate/base_dashboard"

class ShotDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    training_example: Field::BelongsTo,
    shot_image: Field::ActiveStorage,
    shot_type: Field::Select.with_options(
      collection: ['ideal', 'alternative', 'error']
    ),
    sequence_number: Field::Number,
    
    # Translatable fields
    title_de: Field::Text,
    title_en: Field::Text,
    title_fr: Field::Text,
    title_nl: Field::Text,
    
    notes_de: Field::Text,
    notes_en: Field::Text,
    notes_fr: Field::Text,
    notes_nl: Field::Text,
    
    end_position_description_de: Field::Text,
    end_position_description_en: Field::Text,
    end_position_description_fr: Field::Text,
    end_position_description_nl: Field::Text,
    
    shot_description_de: Field::Text,
    shot_description_en: Field::Text,
    shot_description_fr: Field::Text,
    shot_description_nl: Field::Text,
    
    # Structured data
    end_position_type: Field::String,
    end_position_data: Field::Text.with_options(searchable: false),
    shot_parameters: Field::Text.with_options(searchable: false),
    
    translations_synced_at: Field::DateTime,
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  COLLECTION_ATTRIBUTES = %i[
    id
    training_example
    shot_type
    sequence_number
    title_de
    updated_at
  ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id
    training_example
    shot_type
    sequence_number
    shot_image
    title_de
    title_en
    notes_de
    notes_en
    end_position_description_de
    end_position_description_en
    shot_description_de
    shot_description_en
    end_position_type
    end_position_data
    shot_parameters
    translations_synced_at
    created_at
    updated_at
  ].freeze

  FORM_ATTRIBUTES = %i[
    training_example
    shot_type
    sequence_number
    shot_image
  ].freeze

  COLLECTION_FILTERS = {
    shot_type: ->(resources, value) { resources.where(shot_type: value) }
  }.freeze

  def display_resource(shot)
    "Shot ##{shot.id} (#{shot.shot_type})"
  end
end
