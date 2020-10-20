class AddTournamentIdToGroupExecutors < ActiveRecord::Migration
  def change
    add_column :group_executors, :tournament_id, :integer, null: false
  end
end
