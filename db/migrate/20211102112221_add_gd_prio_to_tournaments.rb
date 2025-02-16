class AddGdPrioToTournaments < ActiveRecord::Migration[6.0]
  def change
    add_column :tournaments, :gd_has_prio, :boolean, default: false, null: false
  end
end
