class MigrateTargetPositionsToShots < ActiveRecord::Migration[7.2]
  def up
    # Migrate TargetPosition records to Shots
    safety_assured do
      execute <<-SQL
      INSERT INTO shots (
        training_example_id,
        shot_type,
        sequence_number,
        end_position_description_de,
        end_position_description_en,
        end_position_data,
        translations_synced_at,
        created_at,
        updated_at
      )
      SELECT
        training_example_id,
        'ideal' as shot_type,
        1 as sequence_number,
        description_text_de,
        description_text_en,
        COALESCE(ball_measurements, '{}'::jsonb) as end_position_data,
        translations_synced_at,
        created_at,
        updated_at
      FROM target_positions
    SQL
    end
  end
  
  def down
    # Remove migrated shots
    Shot.where(shot_type: 'ideal').delete_all
  end
end
