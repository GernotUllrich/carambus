class AddRawTranslationColumnsToShots < ActiveRecord::Migration[7.2]
  # v0.8 Tier 2C: Shot bindet Translatable ein, dessen before_save-Hook
  # `sync_source_language_fields` die Raw-Felder title / notes /
  # end_position_description / shot_description liest. Die Spalten
  # existierten aber nicht — jeder Shot.create brach mit NoMethodError
  # ab (siehe db/seeds/training_concepts.rb Kommentar). Wir fügen die
  # vier Raw-Spalten als nullable :text hinzu und backfillen aus den
  # _de-Varianten, falls Daten da sind (aktuell 0 Rows, aber robust
  # gegen spätere Deploys).
  def change
    add_column :shots, :title, :text
    add_column :shots, :notes, :text
    add_column :shots, :end_position_description, :text
    add_column :shots, :shot_description, :text

    reversible do |dir|
      dir.up do
        # Idempotent backfill, No-Op bei leerer Tabelle. Raw-Spalte wird
        # nur aus _de gefüllt, wenn sie null ist — manuell gesetzte Werte
        # bleiben erhalten.
        safety_assured do
          execute <<~SQL
            UPDATE shots SET title                    = title_de
             WHERE title IS NULL AND title_de IS NOT NULL;
          SQL
          execute <<~SQL
            UPDATE shots SET notes                    = notes_de
             WHERE notes IS NULL AND notes_de IS NOT NULL;
          SQL
          execute <<~SQL
            UPDATE shots SET end_position_description = end_position_description_de
             WHERE end_position_description IS NULL
               AND end_position_description_de IS NOT NULL;
          SQL
          execute <<~SQL
            UPDATE shots SET shot_description         = shot_description_de
             WHERE shot_description IS NULL
               AND shot_description_de IS NOT NULL;
          SQL
        end
      end
    end
  end
end
