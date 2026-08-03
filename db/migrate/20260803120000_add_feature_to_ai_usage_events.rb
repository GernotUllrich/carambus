# frozen_string_literal: true

# Ergänzt AiUsageEvent um die Stream-Dimension `feature`, damit sich der Token-Verbrauch
# der verschiedenen AI-Aufrufe unterscheiden lässt (chat/translation/search/docs). Bestehende
# Events stammen ausschließlich aus dem SpielleiterChat → Default "chat" backfillt sie korrekt.
# add_column mit Default ist auf PostgreSQL 11+ instant (kein Table-Rewrite) → strong_migrations-safe.
class AddFeatureToAiUsageEvents < ActiveRecord::Migration[7.2]
  def change
    add_column :ai_usage_events, :feature, :string, default: "chat", null: false
  end
end
