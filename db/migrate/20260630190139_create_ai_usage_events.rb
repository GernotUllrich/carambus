# frozen_string_literal: true

# Phase 49-01: lokale Telemetrie-Tabelle für den AI-Token-Verbrauch des SpielleiterChat.
# Pro Chat-Turn ein Eintrag je verwendetem Modell (Haiku→Sonnet-Hybrid kann beide treffen).
# Rein lokal (kein LocalProtector/RegionTaggable); neue Records bekommen id >= MIN_ID.
class CreateAiUsageEvents < ActiveRecord::Migration[7.2]
  def change
    create_table :ai_usage_events do |t|
      t.string :scenario_context # = Carambus.config.context (z.B. "nbv")
      t.bigint :user_id          # kein FK-Constraint (lokale Telemetrie)
      t.string :persona          # Persona-/Rollen-Label (Snapshot zum Zeitpunkt des Turns)
      t.string :model            # z.B. "claude-haiku-4-5-20251001" / "claude-sonnet-4-6"
      t.integer :input_tokens, default: 0, null: false
      t.integer :output_tokens, default: 0, null: false
      t.integer :cache_creation_tokens, default: 0, null: false
      t.integer :cache_read_tokens, default: 0, null: false
      t.decimal :est_cost_eur, precision: 10, scale: 6, default: 0, null: false

      t.timestamps
    end

    add_index :ai_usage_events, [:scenario_context, :created_at]
  end
end
