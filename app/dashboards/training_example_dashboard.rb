require "administrate/base_dashboard"

class TrainingExampleDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Administrate::Field::Number,
    training_concept: Administrate::Field::BelongsTo,
    title: Administrate::Field::String,
    title_de: Administrate::Field::String,
    title_en: Administrate::Field::String,
    sequence_number: Administrate::Field::Number,
    source_language: Administrate::Field::Select.with_options(
      collection: Translatable::SUPPORTED_LANGUAGES.map { |l| [l.upcase, l] }
    ),
    ideal_stroke_parameters_text: Administrate::Field::Text,
    ideal_stroke_parameters_text_de: Administrate::Field::Text,
    ideal_stroke_parameters_text_en: Administrate::Field::Text,
    ideal_stroke_parameters_data: Administrate::Field::Jsonb,
    translations: Administrate::Field::Jsonb,
    translations_synced_at: Administrate::Field::DateTime,
    starting_position: Administrate::Field::HasOne,
    target_position: Administrate::Field::HasOne,
    error_examples: Administrate::Field::HasMany,
    tags: Administrate::Field::HasMany,
    tag_list: Administrate::Field::String,
    created_at: Administrate::Field::DateTime,
    updated_at: Administrate::Field::DateTime,
  }.freeze

  COLLECTION_ATTRIBUTES = %i[
    sequence_number
    title
    training_concept
    updated_at
  ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id
    training_concept
    title
    sequence_number
    ideal_stroke_parameters_text
    ideal_stroke_parameters_data
    tags
    starting_position
    target_position
    error_examples
    created_at
    updated_at
  ].freeze

  FORM_ATTRIBUTES = %i[
    source_language
    training_concept
    sequence_number
    title
    title_de
    title_en
    ideal_stroke_parameters_text
    ideal_stroke_parameters_text_de
    ideal_stroke_parameters_text_en
    ideal_stroke_parameters_data
    tag_list
  ].freeze

  def display_resource(training_example)
    "#{training_example.sequence_number}. #{training_example.title || 'Beispiel'}"
  end
end
