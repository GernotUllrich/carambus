class AddSomeParamsToParties < ActiveRecord::Migration[7.0]
  def change
    add_column :parties, :sets_to_play, :integer, default: 1, null: false
    add_column :parties, :sets_to_win, :integer, default: 1, null: false
    add_column :parties, :team_size, :integer, default: 1, null: false
    add_column :parties, :fixed_display_left, :string
    add_column :parties, :allow_follow_up, :boolean, default: true, null: false
    add_column :parties, :color_remains_with_set, :boolean, default: true, null: false
    add_column :parties, :kickoff_switches_with, :string
    add_column :party_monitors, :sets_to_play, :integer, default: 1, null: false
    add_column :party_monitors, :sets_to_win, :integer, default: 1, null: false
    add_column :party_monitors, :team_size, :integer, default: 1, null: false
    add_column :party_monitors, :fixed_display_left, :string
    add_column :party_monitors, :allow_follow_up, :boolean, default: true, null: false
    add_column :party_monitors, :color_remains_with_set, :boolean, default: true, null: false
    add_column :party_monitors, :kickoff_switches_with, :string
  end
end
