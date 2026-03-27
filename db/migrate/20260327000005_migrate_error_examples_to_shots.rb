class MigrateErrorExamplesToShots < ActiveRecord::Migration[7.2]
  def up
    # Migrate ErrorExample records to Shots
    safety_assured do
      execute <<-SQL
      INSERT INTO shots (
        training_example_id,
        shot_type,
        sequence_number,
        title_de,
        title_en,
        end_position_description_de,
        end_position_description_en,
        shot_description_de,
        shot_description_en,
        shot_parameters,
        translations_synced_at,
        created_at,
        updated_at
      )
      SELECT
        training_example_id,
        'error' as shot_type,
        sequence_number + 1 as sequence_number,
        title_de,
        title_en,
        end_position_description_de,
        end_position_description_en,
        stroke_parameters_text_de,
        stroke_parameters_text_en,
        COALESCE(stroke_parameters_data, '{}'::jsonb) as shot_parameters,
        translations_synced_at,
        created_at,
        updated_at
      FROM error_examples
    SQL
    end
  end
  
  def down
    # Remove migrated shots
    Shot.where(shot_type: 'error').delete_all
  end
end
