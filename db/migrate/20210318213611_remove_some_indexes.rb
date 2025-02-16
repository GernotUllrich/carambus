class RemoveSomeIndexes < ActiveRecord::Migration[6.0]
  def change
    remove_foreign_key "table_monitors", "games"
    remove_foreign_key "table_monitors", "tournament_monitors"
  end
end
