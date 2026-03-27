require "administrate/base_dashboard"

class TrainingConceptDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Administrate::Field::Number,
    title: Administrate::Field::String,
    title_de: Administrate::Field::String,
    title_en: Administrate::Field::String,
    short_description: Administrate::Field::Text,
    short_description_de: Administrate::Field::Text,
    short_description_en: Administrate::Field::Text,
    full_description: Administrate::Field::Text,
    full_description_de: Administrate::Field::Text,
    full_description_en: Administrate::Field::Text,
    source_language: Administrate::Field::Select.with_options(
      collection: Translatable::SUPPORTED_LANGUAGES.map { |l| [l.upcase, l] }
    ),
    translations: Administrate::Field::Jsonb,
    translations_synced_at: Administrate::Field::DateTime,
    source_attributions: Administrate::Field::HasMany,
    training_sources: Administrate::Field::HasMany,
    disciplines: Administrate::Field::HasMany,
    training_examples: Administrate::Field::HasMany,
    tags: Administrate::Field::HasMany,
    tag_list: Administrate::Field::String,
    created_at: Administrate::Field::DateTime,
    updated_at: Administrate::Field::DateTime,
  }.freeze

  COLLECTION_ATTRIBUTES = %i[
    title
    source_language
    disciplines
    tags
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
    tags
    training_examples
    created_at
    updated_at
  ].freeze

  FORM_ATTRIBUTES = %i[
    source_language
    title
    title_de
    title_en
    short_description
    short_description_de
    short_description_en
    full_description
    full_description_de
    full_description_en
    disciplines
    tag_list
  ].freeze

  COLLECTION_FILTERS = {
    source_language: ->(resources) { 
      resources.where(source_language: params[:source_language]) if params[:source_language].present? 
    },
  }.freeze

  def display_resource(training_concept)
    training_concept.title
  end
  
  # Override disciplines display to show "Alle" when empty
  def disciplines_display(resource)
    if resource.disciplines.any?
      resource.disciplines.pluck(:name).join(", ")
    else
      "Alle Disziplinen"
    end
  end
end
