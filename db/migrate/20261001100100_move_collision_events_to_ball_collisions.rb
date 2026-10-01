# frozen_string_literal: true

class MoveCollisionEventsToBallCollisions < ActiveRecord::Migration[7.2]
  # v0.10: initial_contact und final_carambolage sind Ball-Ball-Kontakte und
  # wandern aus shot_events nach ball_collisions:
  #
  #   initial_contact   → primary_impact  (Angreifer = ball_involved, Ziel = b2)
  #   final_carambolage → carambolage     (Angreifer = ball_involved, Ziel = b3, scored = true)
  #
  # Die neue Zeile uebernimmt ID und Zeitstempel der alten. Damit ist das Ergebnis
  # auf jeder Datenbank mit demselben Bestand identisch (Training Authority,
  # Staging) — ein spaeteres Trainingspaket findet die Kollisionen unveraendert
  # vor, statt sie unter anderen IDs doppelt anzulegen. Die IDs kollidieren nicht:
  # ball_collisions ist bis hierher leer.
  #
  # Die Sequenznummer bleibt die bisherige Event-Nummer (Luecken sind erlaubt). So
  # bleibt die Zeitfolge relativ zu den verbleibenden Events erhalten, auf die der
  # Diagramm-Rueckfall ohne `phase`-Feld angewiesen ist.
  #
  # Ein Event ohne ball_involved bricht die Migration ab (NOT NULL) — bewusst laut,
  # statt einen Angreifer zu raten.
  #
  # safety_assured: reines DML auf einstelligen Zeilenzahlen, keine Sperre von Belang.

  def up
    safety_assured { move_rows }
  end

  def down
    # Die urspruengliche Event-Sequenz ist nicht mehr rekonstruierbar.
    count = select_value("SELECT COUNT(*) FROM ball_collisions").to_i
    if count.positive?
      raise ActiveRecord::IrreversibleMigration,
        "#{count} Kollision(en) vorhanden — Rueckweg nur ueber das Backup vor v0.10."
    end
  end

  private

  def move_rows
    execute <<~SQL
      INSERT INTO ball_collisions
        (id, shot_id, sequence_number, collision_type, ball_attacker, ball_target,
         contact_coords_normalized, scored, notes, properties, created_at, updated_at)
      SELECT id, shot_id, sequence_number,
             CASE event_type WHEN 'initial_contact' THEN 'primary_impact' ELSE 'carambolage' END,
             ball_involved,
             CASE event_type WHEN 'initial_contact' THEN 'b2' ELSE 'b3' END,
             contact_coords_normalized,
             CASE event_type WHEN 'final_carambolage' THEN TRUE END,
             notes, '{}'::jsonb, created_at, updated_at
      FROM shot_events
      WHERE event_type IN ('initial_contact', 'final_carambolage')
    SQL

    moved = execute("DELETE FROM shot_events WHERE event_type IN ('initial_contact', 'final_carambolage')").cmd_tuples
    say "#{moved} Event-Zeile(n) nach ball_collisions verschoben"

    # Sequenz hinter die uebernommenen IDs ziehen, niemals zurueck.
    execute <<~SQL
      SELECT setval(pg_get_serial_sequence('ball_collisions', 'id'),
                    GREATEST((SELECT MAX(id) FROM ball_collisions),
                             (SELECT last_value FROM ball_collisions_id_seq)))
      WHERE EXISTS (SELECT 1 FROM ball_collisions)
    SQL
  end
end
