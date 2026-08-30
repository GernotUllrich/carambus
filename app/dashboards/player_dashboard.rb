# frozen_string_literal: true

require "administrate/base_dashboard"

# Minimaler Dashboard für Player.
#
# Motivation: `PlayerLocalDashboard` führt `player` als `Field::BelongsTo`. Administrate löst
# beim Rendern eines BelongsTo-Feldes den Dashboard-Klassennamen der Zielklasse auf — ohne
# diese Klasse antwortet jede Index-, Show- und Formularseite von PlayerLocal mit
# `uninitialized constant PlayerDashboard`.
#
# Nur zur Klassenauflösung gedacht — es gibt bewusst KEINE Admin-Route für Spieler. Die
# Spielerpflege läuft über die reguläre Anwendung (`/players`), nicht über Administrate;
# derselbe Gedanke wie bei `BallConfigurationDashboard`.
class PlayerDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    fl_name: Field::String,
    lastname: Field::String,
    firstname: Field::String
  }.freeze

  COLLECTION_ATTRIBUTES = %i[id fl_name].freeze
  SHOW_PAGE_ATTRIBUTES = %i[id fl_name lastname firstname].freeze
  FORM_ATTRIBUTES = %i[].freeze
  COLLECTION_FILTERS = {}.freeze

  # Der Anzeigename im BelongsTo-Select und in der Liste: „Vorname Nachname", dieselbe Form,
  # die auch das Scoreboard nutzt (Konvention aus Plan 02-02).
  def display_resource(player)
    player.fl_name.presence || "#{player.firstname} #{player.lastname}".strip
  end
end
