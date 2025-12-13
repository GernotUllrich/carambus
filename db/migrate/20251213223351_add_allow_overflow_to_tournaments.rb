class AddAllowOverflowToTournaments < ActiveRecord::Migration[7.2]
  def change
    add_column :tournaments, :allow_overflow, :boolean, default: false, null: false
  end
end
