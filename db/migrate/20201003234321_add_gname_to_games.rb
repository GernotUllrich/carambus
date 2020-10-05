class AddGnameToGames < ActiveRecord::Migration
  def change
    add_column :games, :gname, :string
  end
end
