require "administrate/base_dashboard"

# Minimal dashboard to prevent Administrate from crashing
# We use custom views instead of Administrate's auto-generated interface
class ScoreboardMessageDashboard < Administrate::BaseDashboard
  # This dashboard is not actually used - we have custom views
  # But it needs to exist so Administrate doesn't crash when scanning controllers
  
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    location: Field::BelongsTo,
    table_monitor: Field::BelongsTo.with_options(class_name: "TableMonitor"),
    sender: Field::BelongsTo.with_options(class_name: "User"),
    message: Field::Text,
    acknowledged_at: Field::DateTime,
    expires_at: Field::DateTime,
    created_at: Field::DateTime,
    updated_at: Field::DateTime,
  }.freeze

  COLLECTION_ATTRIBUTES = %i[
    id
    message
    location
    acknowledged_at
  ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id
    location
    table_monitor
    sender
    message
    acknowledged_at
    expires_at
    created_at
    updated_at
  ].freeze

  FORM_ATTRIBUTES = %i[
    location
    table_monitor
    message
  ].freeze

  COLLECTION_FILTERS = {}.freeze

  def display_resource(scoreboard_message)
    "Message ##{scoreboard_message.id}"
  end
end
