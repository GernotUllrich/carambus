require "administrate/base_dashboard"

class ErrorExampleDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Administrate::Field::Number,
    training_example: Administrate::Field::BelongsTo,
    title: Administrate::Field::String,
    sequence_number: Administrate::Field::Number,
    stroke_parameters_text: Administrate::Field::Text,
    stroke_parameters_data: Administrate::Field::Jsonb,
    end_position_description: Administrate::Field::Text,
    created_at: Administrate::Field::DateTime,
    updated_at: Administrate::Field::DateTime,
  }.freeze

  COLLECTION_ATTRIBUTES = %i[
    sequence_number
    title
    training_example
    updated_at
  ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id
    training_example
    sequence_number
    title
    stroke_parameters_text
    stroke_parameters_data
    end_position_description
    created_at
    updated_at
  ].freeze

  FORM_ATTRIBUTES = %i[
    title
    sequence_number
    stroke_parameters_text
    stroke_parameters_data
    end_position_description
  ].freeze

  def display_resource(error_example)
    "#{error_example.sequence_number}. #{error_example.title || 'Fehler'}"
  end
end
