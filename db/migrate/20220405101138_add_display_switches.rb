class AddDisplaySwitches < ActiveRecord::Migration[6.0]
  def change
    add_column :tournaments, :kickoff_switches_with_set, :boolean, default: true, null: false
    add_column :tournament_locals, :kickoff_switches_with_set, :boolean, default: true, null: false
    add_column :tournament_monitors, :kickoff_switches_with_set, :boolean, default: true, null: false
    add_column :tournaments, :fixed_display_left, :string
    add_column :tournament_locals, :fixed_display_left, :string
    add_column :tournament_monitors, :fixed_display_left, :string
    add_column :tournaments, :color_remains_with_set, :boolean, default: true, null: false
    add_column :tournament_locals, :color_remains_with_set, :boolean, default: true, null: false
    add_column :tournament_monitors, :color_remains_with_set, :boolean, default: true, null: false
  end
end
