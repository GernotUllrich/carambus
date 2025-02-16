class AddSetsToTournaments < ActiveRecord::Migration[6.0]
  def change
    add_column :tournament_locals, :sets_to_win, :integer, default: 1, null: false
    add_column :tournament_locals, :sets_to_play, :integer, default: 1, null: false
    add_column :tournament_locals, :team_size, :integer, default: 1, null: false
    add_column :tournaments, :sets_to_win, :integer, default: 1, null: false
    add_column :tournaments, :sets_to_play, :integer, default: 1, null: false
    add_column :tournaments, :team_size, :integer, default: 1, null: false
    add_column :tournament_monitors, :sets_to_win, :integer, default: 1, null: false
    add_column :tournament_monitors, :sets_to_play, :integer, default: 1, null: false
  end
end
