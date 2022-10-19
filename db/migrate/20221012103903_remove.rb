class Remove < ActiveRecord::Migration[6.1]
  def change
    remove_column :tournaments, :cc_id
  end
end
