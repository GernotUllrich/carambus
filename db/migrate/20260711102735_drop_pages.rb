class DropPages < ActiveRecord::Migration[7.2]
  # Entfernt das ausgemusterte pages-CMS (Ersatz: mkdocs). Keine FK-Constraints
  # (super_page_id war nur Index). Daten wurden vor dem Drop gesichert.
  def up
    drop_table :pages
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
