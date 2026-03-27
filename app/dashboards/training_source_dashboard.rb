require "administrate/base_dashboard"

class TrainingSourceDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Administrate::Field::Number,
    title: Administrate::Field::String,
    author: Administrate::Field::String,
    publication_year: Administrate::Field::Number,
    publisher: Administrate::Field::String,
    language: Administrate::Field::Select.with_options(
      collection: [['Deutsch', 'de'], ['English', 'en'], ['Nederlands', 'nl'], ['Français', 'fr']]
    ),
    notes: Administrate::Field::Text,
    source_files_attachments: Administrate::Field::HasMany,
    source_attributions: Administrate::Field::HasMany,
    training_concepts: Administrate::Field::HasMany,
    training_examples: Administrate::Field::HasMany,
    created_at: Administrate::Field::DateTime,
    updated_at: Administrate::Field::DateTime
  }.freeze

  COLLECTION_ATTRIBUTES = %i[
    title
    author
    publication_year
    language
  ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id
    title
    author
    publication_year
    publisher
    language
    notes
    created_at
    updated_at
  ].freeze

  FORM_ATTRIBUTES = %i[
    title
    author
    publication_year
    publisher
    language
    notes
  ].freeze

  COLLECTION_FILTERS = {}.freeze

  def display_resource(training_source)
    training_source.display_name
  end
end
