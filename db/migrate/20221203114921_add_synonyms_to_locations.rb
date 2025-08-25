class AddSynonymsToLocations < ActiveRecord::Migration[7.0]
  def change
    add_column :locations, :synonyms, :text
  end
end
