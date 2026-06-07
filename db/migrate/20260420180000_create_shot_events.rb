class CreateShotEvents < ActiveRecord::Migration[7.2]
  # v0.8 Tier 2D: kinetische Sub-Events innerhalb eines Shots.
  # Granularität, die Contis „Sperre" und „Austausch" als typisierte
  # Ereignisse abbildet statt als Freitext in shots.notes. `notes` ist
  # DE-only plain text (kein Translatable — konsistent mit
  # concept_principles, YAGNI bis Lokalisierungs-Druck entsteht).
  def change
    create_table :shot_events do |t|
      t.references :shot,             null: false, foreign_key: true
      t.integer    :sequence_number,  null: false
      t.string     :event_type,       null: false
      t.string     :ball_involved
      t.string     :cushion_involved
      t.jsonb      :contact_coords_normalized
      t.text       :notes

      t.timestamps
    end

    add_index :shot_events, [:shot_id, :sequence_number],
              unique: true, name: "idx_shot_events_on_shot_and_sequence"

    add_check_constraint :shot_events,
      "event_type IN ('initial_contact','cushion_contact','sperre','austausch','final_carambolage','near_miss')",
      name: "shot_events_event_type_check"

    add_check_constraint :shot_events,
      "ball_involved IS NULL OR ball_involved IN ('b1','b2','b3')",
      name: "shot_events_ball_involved_check"

    add_check_constraint :shot_events,
      "cushion_involved IS NULL OR cushion_involved IN ('short_left','short_right','long_near','long_far')",
      name: "shot_events_cushion_involved_check"
  end
end
