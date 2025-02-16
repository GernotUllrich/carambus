class AddPolyOrgToLocations < ActiveRecord::Migration[6.0]
  def change
    add_column :locations, :organizer_type, :string
    add_column :locations, :organizer_id, :integer
  end
end
