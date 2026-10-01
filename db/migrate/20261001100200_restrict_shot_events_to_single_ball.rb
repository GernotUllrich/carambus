# frozen_string_literal: true

class RestrictShotEventsToSingleBall < ActiveRecord::Migration[7.2]
  # v0.10: shot_events traegt nur noch Einzelball-Ereignisse; die Ball-Ball-Kontakte
  # liegen seit der Vormigration in ball_collisions. Die Reihenfolge zaehlt pro Ball
  # (Design-Doc §5.1, bestaetigt §8 Punkt 2), deshalb wird ball_involved Pflicht und
  # Teil des Unique-Index.
  #
  # Die Tabelle hat eine einstellige Zeilenzahl; Validierung und Index-Umbau im
  # selben Schritt sind unkritisch, deshalb safety_assured statt add/validate in
  # zwei Migrationen (wie 20260902232138).

  TYPE_CHECK = "shot_events_event_type_check"
  OLD_TYPES = "event_type IN ('initial_contact','cushion_contact','sperre','austausch','final_carambolage','near_miss')"
  NEW_TYPES = "event_type IN ('cushion_contact','sperre','austausch','near_miss')"
  INDEX = "idx_shot_events_on_shot_and_sequence"

  def up
    refuse_if("Event(s) mit initial_contact/final_carambolage — erst nach ball_collisions verschieben",
      "event_type IN ('initial_contact', 'final_carambolage')")
    refuse_if("Event(s) ohne ball_involved — erst den Ball nachtragen", "ball_involved IS NULL")

    safety_assured do
      remove_check_constraint :shot_events, name: TYPE_CHECK
      add_check_constraint :shot_events, NEW_TYPES, name: TYPE_CHECK
      change_column_null :shot_events, :ball_involved, false
      remove_index :shot_events, name: INDEX
      add_index :shot_events, [:shot_id, :ball_involved, :sequence_number], unique: true, name: INDEX
    end
  end

  def down
    # Rueckwaerts nur moeglich, solange keine zwei Baelle desselben Stosses dieselbe
    # Sequenznummer tragen — der alte Index zaehlt pro Stoss.
    refuse_if("Stoss/Sequenz-Paar(e) mehrfach vergeben — erst umnummerieren", <<~SQL.squish)
      (shot_id, sequence_number) IN
        (SELECT shot_id, sequence_number FROM shot_events GROUP BY 1, 2 HAVING COUNT(*) > 1)
    SQL

    safety_assured do
      remove_index :shot_events, name: INDEX
      add_index :shot_events, [:shot_id, :sequence_number], unique: true, name: INDEX
      change_column_null :shot_events, :ball_involved, true
      remove_check_constraint :shot_events, name: TYPE_CHECK
      add_check_constraint :shot_events, OLD_TYPES, name: TYPE_CHECK
    end
  end

  private

  def refuse_if(message, condition)
    count = select_value("SELECT COUNT(*) FROM shot_events WHERE #{condition}").to_i
    raise ActiveRecord::IrreversibleMigration, "#{count} #{message}" if count.positive?
  end
end
