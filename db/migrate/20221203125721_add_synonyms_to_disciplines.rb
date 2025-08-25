class AddSynonymsToDisciplines < ActiveRecord::Migration[7.0]
  def change
    add_column :disciplines, :synonyms, :text
  end
end
