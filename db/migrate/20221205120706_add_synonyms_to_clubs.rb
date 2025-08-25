class AddSynonymsToClubs < ActiveRecord::Migration[7.0]
  def change
    add_column :clubs, :synonyms, :text
  end
end
