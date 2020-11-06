class AddSomeRelationshipsToSettings < ActiveRecord::Migration[5.2]
  def change
    add_column :settings, :region_id, :integer
    add_column :settings, :club_id, :integer
    add_column :settings, :tournament_id, :integer
  end
end
