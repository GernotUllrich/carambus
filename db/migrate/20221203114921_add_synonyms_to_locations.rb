class AddSynonymsToLocations < ActiveRecord::Migration[7.0]
  def change
    add_column :locations, :synonyms, :text
    execute <<-SQL
        UPDATE locations SET synonyms = name
    SQL
  end
end
