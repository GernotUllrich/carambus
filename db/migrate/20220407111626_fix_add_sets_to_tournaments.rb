class FixAddSetsToTournaments < ActiveRecord::Migration[6.0]
  def change
    add_column :tournament_monitors, :team_size, :integer, default: 1, null: false
  end
end
