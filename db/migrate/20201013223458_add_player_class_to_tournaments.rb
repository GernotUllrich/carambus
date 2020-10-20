class AddPlayerClassToTournaments < ActiveRecord::Migration
  def change
    add_column :tournaments, :player_class, :string
  end
end
