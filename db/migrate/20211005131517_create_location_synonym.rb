class CreateLocationSynonym < ActiveRecord::Migration[6.0]
  def change
    create_table :location_synonyms do |t|
      t.string :synonym
      t.integer :location_id
    end
  end
end
