require "administrate/base_dashboard"

class TagDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Administrate::Field::Number,
    name: Administrate::Field::String,
    name_de: Administrate::Field::String,
    name_en: Administrate::Field::String,
    description: Administrate::Field::Text,
    description_de: Administrate::Field::Text,
    description_en: Administrate::Field::Text,
    category: Administrate::Field::Select.with_options(
      collection: Tag::CATEGORIES
    ),
    source_language: Administrate::Field::Select.with_options(
      collection: Translatable::SUPPORTED_LANGUAGES.map { |l| [l.upcase, l] }
    ),
    translations: Administrate::Field::Jsonb,
    translations_synced_at: Administrate::Field::DateTime,
    training_concepts: Administrate::Field::HasMany,
    training_examples: Administrate::Field::HasMany,
    starting_positions: Administrate::Field::HasMany,
    target_positions: Administrate::Field::HasMany,
    created_at: Administrate::Field::DateTime,
    updated_at: Administrate::Field::DateTime,
  }.freeze

  COLLECTION_ATTRIBUTES = %i[
    name
    category
    description
    updated_at
  ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id
    name
    category
    description
    training_concepts
    training_examples
    starting_positions
    target_positions
    created_at
    updated_at
  ].freeze

  FORM_ATTRIBUTES = %i[
    source_language
    name
    name_de
    name_en
    category
    description
    description_de
    description_en
  ].freeze

  COLLECTION_FILTERS = {
    category: ->(resources, value) { resources.by_category(value) }
  }.freeze

  def display_resource(tag)
    tag.display_name
  end
end
