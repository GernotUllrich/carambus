# frozen_string_literal: true

class CreateBallCollisions < ActiveRecord::Migration[7.2]
  # v0.10: Ball-Ball-Treffpunkte als eigene Entity (Design-Doc
  # TRAINING_SOURCES/mapping/2026-04-25_shot_trajectory_design.md, §6
  # „Finalisiertes Schema" und §8 Entscheidungen 2026-10-01).
  #
  # shots.shot_parameters bleibt die Intention, ball_collisions ist die
  # Realisierung — Redundanz bei Effet/Kraft ist gewollt.
  def change
    create_table :ball_collisions do |t|
      t.references :shot, null: false, foreign_key: true
      t.integer :sequence_number, null: false
      t.string :collision_type, null: false
      t.string :ball_attacker, null: false
      t.string :ball_target, null: false
      t.jsonb :contact_coords_normalized
      t.float :quantity_of_ball
      t.integer :force
      t.integer :speed
      t.integer :effect_vertical
      t.integer :effect_horizontal
      t.boolean :scored
      t.jsonb :properties, null: false, default: {}
      t.text :notes

      t.timestamps

      t.check_constraint "sequence_number > 0", name: "ball_collisions_sequence_number_check"
      t.check_constraint "collision_type IN ('primary_impact','secondary_impact','carambolage')",
        name: "ball_collisions_collision_type_check"
      t.check_constraint "ball_attacker IN ('b1','b2','b3') AND ball_target IN ('b1','b2','b3')",
        name: "ball_collisions_balls_check"
      t.check_constraint "ball_attacker <> ball_target", name: "ball_collisions_attacker_not_target_check"
      t.check_constraint "quantity_of_ball IS NULL OR (quantity_of_ball >= 0 AND quantity_of_ball <= 1)",
        name: "ball_collisions_quantity_of_ball_check"
      t.check_constraint "(force IS NULL OR force BETWEEN 1 AND 4) AND (speed IS NULL OR speed BETWEEN 1 AND 4)",
        name: "ball_collisions_force_speed_check"
      t.check_constraint "(effect_vertical IS NULL OR effect_vertical BETWEEN -3 AND 3) AND " \
                         "(effect_horizontal IS NULL OR effect_horizontal BETWEEN -3 AND 3)",
        name: "ball_collisions_effect_check"
      t.check_constraint "scored IS NULL OR collision_type = 'carambolage'",
        name: "ball_collisions_scored_only_carambolage_check"
    end

    add_index :ball_collisions, [:shot_id, :sequence_number],
      unique: true, name: "idx_ball_collisions_on_shot_and_sequence"
    add_index :ball_collisions, :collision_type
  end
end
