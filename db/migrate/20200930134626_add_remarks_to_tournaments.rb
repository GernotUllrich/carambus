class AddRemarksToTournaments < ActiveRecord::Migration
  def change
    add_column :tournaments, :remarks, :text
  end
end
