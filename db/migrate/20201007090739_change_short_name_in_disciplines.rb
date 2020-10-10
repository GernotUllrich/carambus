class ChangeShortNameInDisciplines < ActiveRecord::Migration
  def change
    rename_column :disciplines, :short_name, :shortname
  end
end
