class AddInitialTcToTournaments < ActiveRecord::Migration[6.0]
  def change
    add_column :tournaments, :initial_tc, :integer, default: 0, null: false
  end
end
