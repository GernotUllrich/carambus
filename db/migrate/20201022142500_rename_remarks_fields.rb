class RenameRemarksFields < ActiveRecord::Migration[5.2]
  def change
    rename_column :game_participations, :remarks, :data
    rename_column :games, :remarks, :data
    rename_column :innings, :remarks, :data
    rename_column :season_participations, :remarks, :data
    rename_column :seedings, :remarks, :data
    rename_column :tournament_plan_games, :remarks, :data
    rename_column :tournaments, :remarks, :data
  end
end
