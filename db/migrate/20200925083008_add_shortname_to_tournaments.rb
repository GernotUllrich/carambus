class AddShortnameToTournaments < ActiveRecord::Migration
  def change
    add_column :tournaments, :shortname, :string
  end
end
