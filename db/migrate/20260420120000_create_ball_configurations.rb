class CreateBallConfigurations < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    create_table :ball_configurations do |t|
      # Normalized ball coordinates in [0.0, 1.0] along length (x) and width (y).
      # All three standard carambole table sizes share a 2:1 aspect ratio
      # (match 284x142, halbmatch 230x115, klein 210x105), so normalization
      # is lossless across table_variant and positions stay comparable.
      t.float :b1_x, null: false
      t.float :b1_y, null: false
      t.float :b2_x, null: false
      t.float :b2_y, null: false
      t.float :b3_x, null: false
      t.float :b3_y, null: false

      t.string :table_variant, null: false # 'match', 'halbmatch', 'klein'
      t.string :gather_state, null: false  # 'pre_gather', 'gathering', 'post_gather'

      t.text :notes

      t.timestamps
    end

    add_check_constraint :ball_configurations,
      "table_variant IN ('match', 'halbmatch', 'klein')",
      name: "ball_configurations_table_variant_check"

    add_check_constraint :ball_configurations,
      "gather_state IN ('pre_gather', 'gathering', 'post_gather')",
      name: "ball_configurations_gather_state_check"

    add_check_constraint :ball_configurations,
      "b1_x BETWEEN 0 AND 1 AND b1_y BETWEEN 0 AND 1 AND " \
      "b2_x BETWEEN 0 AND 1 AND b2_y BETWEEN 0 AND 1 AND " \
      "b3_x BETWEEN 0 AND 1 AND b3_y BETWEEN 0 AND 1",
      name: "ball_configurations_normalized_coords_check"

    add_index :ball_configurations, [:table_variant, :gather_state],
      algorithm: :concurrently,
      name: "index_ball_configs_on_variant_and_gather_state"
    add_index :ball_configurations, :gather_state, algorithm: :concurrently
  end
end
