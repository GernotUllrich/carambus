class RemoveShortnameFromDisciplines < ActiveRecord::Migration
  def change
    remove_column :disciplines, :shortname
  end
end
