require "administrate/base_dashboard"

class TrainingConceptDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Administrate::Field::Number,
    title: Administrate::Field::String,
    short_description: Administrate::Field::Text,
    full_description: Administrate::Field::Text,
    source_language: Administrate::Field::Select.with_options(
      collection: TrainingConcept::SUPPORTED_LANGUAGES.map { |l| [l.upcase, l] }
    ),
    translations: Administrate::Field::Jsonb,
    disciplines: Administrate::Field::HasMany,
    training_examples: Administrate::Field::HasMany,
    created_at: Administrate::Field::DateTime,
    updated_at: Administrate::Field::DateTime,
  }.freeze

  COLLECTION_ATTRIBUTES = %i[
    title
    source_language
    disciplines
    training_examples
    updated_at
  ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id
    title
    short_description
    full_description
    source_language
    translations
    disciplines
    training_examples
    created_at
    updated_at
  ].freeze

  FORM_ATTRIBUTES = %i[
    title
    short_description
    full_description
    source_language
    disciplines
  ].freeze

  COLLECTION_FILTERS = {
    source_language: ->(resources) { 
      resources.where(source_language: params[:source_language]) if params[:source_language].present? 
    },
  }.freeze

  def display_resource(training_concept)
    training_concept.title
  end
end
