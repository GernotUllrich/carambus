require "administrate/base_dashboard"

class IncompleteRecordDashboard < Administrate::BaseDashboard
  # This dashboard represents InternationalTournaments with placeholder references
  ATTRIBUTE_TYPES = {
    id: Administrate::Field::Number,
    title: Administrate::Field::String,
    date: Administrate::Field::DateTime,
    end_date: Administrate::Field::DateTime,
    location_text: Administrate::Field::String,
    discipline: Administrate::Field::BelongsTo,
    season: Administrate::Field::BelongsTo,
    location: Administrate::Field::BelongsTo.with_options(class_name: "Location"),
    organizer: Administrate::Field::Polymorphic,
    international_source: Administrate::Field::BelongsTo,
    external_id: Administrate::Field::String,
    source_url: Administrate::Field::String,
    state: Administrate::Field::String,
    created_at: Administrate::Field::DateTime,
    updated_at: Administrate::Field::DateTime
  }.freeze

  COLLECTION_ATTRIBUTES = %i[
    id
    title
    date
    discipline
    season
  ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id
    title
    date
    end_date
    location_text
    discipline
    season
    location
    organizer
    international_source
    external_id
    source_url
    state
    created_at
    updated_at
  ].freeze

  FORM_ATTRIBUTES = %i[
    title
    date
    end_date
    location_text
    discipline
    season
    location
    organizer
  ].freeze

  COLLECTION_FILTERS = {}.freeze

  def display_resource(tournament)
    "#{tournament.title} (#{tournament.date&.strftime('%Y-%m-%d')})"
  end
  
  # Return the model class this dashboard represents
  def self.model
    InternationalTournament
  end
end
