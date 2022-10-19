class AddCcIdToTournaments < ActiveRecord::Migration[6.1]
  def change
    add_column :tournaments, :cc_id, :integer
  end
end
