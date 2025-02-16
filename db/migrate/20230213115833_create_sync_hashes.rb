class CreateSyncHashes < ActiveRecord::Migration[7.0]
  def change
    create_table :sync_hashes do |t|
      t.string :url
      t.string :md5

      t.timestamps
    end
  end
end
