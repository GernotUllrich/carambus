class AddIndexToHiddenToVideos < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    # add_column :videos, :hidden, :boolean, default: false, null: false
    add_index :videos, :hidden, algorithm: :concurrently
  end
end
