# frozen_string_literal: true

require "administrate/base_dashboard"

# Minimaler Dashboard für BallConfiguration.
#
# Motivation: StartPositionDashboard.SHOW_PAGE_ATTRIBUTES enthält
# `ball_configuration` (BelongsTo), und ShotDashboard.SHOW_PAGE_ATTRIBUTES
# enthält `end_ball_configuration` (BelongsTo). Administrate lädt beim
# Rendern von BelongsTo-Feldern den assoziierten Dashboard-Klassennamen
# — ohne diese Klasse werfen alle Show-Pages von TrainingExample (über
# die HasOne-Kette) sowie Shot eine NameError.
#
# Nur zur Klassenauflösung gedacht — KEIN Admin-Route dafür eingerichtet
# (keine Mount-Entscheidung in config/routes.rb). Das ist absichtlich:
# BallConfiguration-Pflege passiert über Seeds oder direkt am Model,
# nicht interaktiv im Admin. Sichtbar wird eine BallConfiguration für
# den User ausschließlich via das SVG-Partial
# `admin/shared/_ball_configuration_diagram.html.erb`.
#
# Wenn später ein CRUD-Admin für BallConfigurations gewünscht wird,
# hier die Attribut-Listen erweitern und `resources :ball_configurations`
# zur admin-Namespace-Block in config/routes.rb hinzufügen.
class BallConfigurationDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Administrate::Field::Number,
    table_variant: Administrate::Field::String,
    position_type: Administrate::Field::String,
    gather_state: Administrate::Field::String,
    orientation: Administrate::Field::String,
    flow_direction: Administrate::Field::String,
    biais_degrees: Administrate::Field::Number,
    biais_class: Administrate::Field::String,
    target_cushion: Administrate::Field::String,
    b1_x: Administrate::Field::Number,
    b1_y: Administrate::Field::Number,
    b2_x: Administrate::Field::Number,
    b2_y: Administrate::Field::Number,
    b3_x: Administrate::Field::Number,
    b3_y: Administrate::Field::Number,
    notes: Administrate::Field::Text,
    created_at: Administrate::Field::DateTime,
    updated_at: Administrate::Field::DateTime
  }.freeze

  COLLECTION_ATTRIBUTES = %i[
    id
    table_variant
    position_type
    gather_state
    updated_at
  ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id
    table_variant
    position_type
    gather_state
    orientation
    flow_direction
    biais_degrees
    biais_class
    b1_x b1_y
    b2_x b2_y
    b3_x b3_y
    notes
    created_at
    updated_at
  ].freeze

  FORM_ATTRIBUTES = %i[
    table_variant
    position_type
    gather_state
    orientation
    flow_direction
    biais_degrees
    biais_class
    target_cushion
    b1_x b1_y
    b2_x b2_y
    b3_x b3_y
    notes
  ].freeze

  def display_resource(bc)
    label = [bc.table_variant, bc.position_type, bc.gather_state].compact.join(" / ")
    "BallConfig ##{bc.id} (#{label})"
  end
end
