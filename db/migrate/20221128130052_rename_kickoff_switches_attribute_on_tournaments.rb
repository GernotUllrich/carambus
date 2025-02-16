class RenameKickoffSwitchesAttributeOnTournaments < ActiveRecord::Migration[7.0]
  def change
    remove_column :tournaments, :kickoff_switches_with_set
    add_column :tournaments, :kickoff_switches_with, :string
    remove_column :tournament_locals, :kickoff_switches_with_set
    add_column :tournament_locals, :kickoff_switches_with, :string
    remove_column :tournament_monitors, :kickoff_switches_with_set
    add_column :tournament_monitors, :kickoff_switches_with, :string
  end
end
