require "administrate/base_dashboard"

class TrainingExampleDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Administrate::Field::Number,
    training_concept: Administrate::Field::BelongsTo,
    title: Administrate::Field::String,
    sequence_number: Administrate::Field::Number,
    ideal_stroke_parameters_text: Administrate::Field::Text,
    ideal_stroke_parameters_data: Administrate::Field::Jsonb,
    starting_position: Administrate::Field::HasOne,
    target_position: Administrate::Field::HasOne,
    error_examples: Administrate::Field::HasMany,
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
    starting_position
    target_position
    error_examples
    created_at
    updated_at
  ].freeze

  FORM_ATTRIBUTES = %i[
    training_concept
    title
    sequence_number
    ideal_stroke_parameters_text
    ideal_stroke_parameters_data
  ].freeze

  def display_resource(training_example)
    "#{training_example.sequence_number}. #{training_example.title || 'Beispiel'}"
  end
end
