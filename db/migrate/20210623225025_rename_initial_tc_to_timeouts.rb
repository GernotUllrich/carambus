class RenameInitialTcToTimeouts < ActiveRecord::Migration[6.0]
  def change
    rename_column :tournaments, :initial_tc, :timeouts
  end
end
