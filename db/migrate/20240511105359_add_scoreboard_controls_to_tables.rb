class AddScoreboardControlsToTables < ActiveRecord::Migration[7.1]
  def change
    add_column :tables, :scoreboard, :boolean
    add_column :tables, :scoreboard_on_at, :datetime
    add_column :tables, :scoreboard_off_at, :datetime
    add_column :table_locals, :scoreboard, :boolean
    add_column :table_locals, :scoreboard_on_at, :datetime
    add_column :table_locals, :scoreboard_off_at, :datetime
  end
end
