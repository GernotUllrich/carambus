class AddDocToSyncHashes < ActiveRecord::Migration[7.0]
  def change
    add_column :sync_hashes, :doc, :text
  end
end
