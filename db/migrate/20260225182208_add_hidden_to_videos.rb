class AddHiddenToVideos < ActiveRecord::Migration[7.2]
  def change
    add_column :videos, :hidden, :boolean, default: false, null: false
    add_index :videos, :hidden
  end
end
