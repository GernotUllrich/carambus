require "administrate/base_dashboard"

# Phase 37-01-Fix: Fehlendes Gegenstueck zu DisciplineDashboard. Wird von der
# User-Show-Seite gebraucht, die `sportwart_locations` als Field::HasMany rendert
# (Administrate sucht "#{klass}Dashboard" → LocationDashboard). Ohne diese Klasse
# 500t die Show-Seite (uninitialized constant LocationDashboard), sobald ein User
# mindestens einen Sportwart-Spielort hat. Location ist KEINE geroutete Admin-
# Resource (resources :locations, only: []) → Administrate rendert die Namen als
# Text ohne Link, genau wie bei den Disziplinen.
class LocationDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    name: Field::String,
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  COLLECTION_ATTRIBUTES = %i[id name].freeze
  SHOW_PAGE_ATTRIBUTES = %i[id name created_at updated_at].freeze
  FORM_ATTRIBUTES = %i[name].freeze
  COLLECTION_FILTERS = {}.freeze

  def display_resource(location)
    location.name
  end
end
