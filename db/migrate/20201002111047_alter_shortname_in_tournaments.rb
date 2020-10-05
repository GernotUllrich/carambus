class AlterShortnameInTournaments < ActiveRecord::Migration
  def change
    change_column :tournaments, :shortname, :string, null: false, default: ""
  end
end
