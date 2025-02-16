class AddSynonymsToDisciplines < ActiveRecord::Migration[7.0]
  def change
    add_column :disciplines, :synonyms, :text
    execute <<-SQL
        UPDATE disciplines SET synonyms = name
    SQL
  end
end
