require "administrate/base_dashboard"

class TrainingExampleDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Administrate::Field::Number,
    training_concepts: Administrate::Field::HasMany,
    parent: Administrate::Field::BelongsTo.with_options(class_name: 'TrainingExample'),
    children: Administrate::Field::HasMany.with_options(class_name: 'TrainingExample'),
    title: Administrate::Field::String,
    title_de: Administrate::Field::String,
    title_en: Administrate::Field::String,
    source_language: Administrate::Field::Select.with_options(
      collection: Translatable::SUPPORTED_LANGUAGES.map { |l| [l.upcase, l] }
    ),
    source_notes: Administrate::Field::Text,
    source_attributions: Administrate::Field::HasMany,
    training_sources: Administrate::Field::HasMany,
    ideal_stroke_parameters_text: Administrate::Field::Text,
    ideal_stroke_parameters_text_de: Administrate::Field::Text,
    ideal_stroke_parameters_text_en: Administrate::Field::Text,
    ideal_stroke_parameters_data: Administrate::Field::Jsonb,
    translations: Administrate::Field::Jsonb,
    translations_synced_at: Administrate::Field::DateTime,
    start_position: Administrate::Field::HasOne,
    shots: Administrate::Field::HasMany,
    tags: Administrate::Field::HasMany,
    created_at: Administrate::Field::DateTime,
    updated_at: Administrate::Field::DateTime,
  }.freeze

  COLLECTION_ATTRIBUTES = %i[
    id
    title
    training_concepts
    updated_at
  ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id
    training_concepts
    parent
    children
    title
    source_notes
    training_sources
    ideal_stroke_parameters_text
    ideal_stroke_parameters_data
    tags
    start_position
    shots
    created_at
    updated_at
  ].freeze

  FORM_ATTRIBUTES = %i[
    source_language
    title
    title_de
    title_en
    source_notes
    source_attributions
    ideal_stroke_parameters_text
    ideal_stroke_parameters_text_de
    ideal_stroke_parameters_text_en
    ideal_stroke_parameters_data
  ].freeze

  def display_resource(training_example)
    "##{training_example.id} #{training_example.title || 'Beispiel'}"
  end
end
