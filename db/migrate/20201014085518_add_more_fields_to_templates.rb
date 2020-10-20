class AddMoreFieldsToTemplates < ActiveRecord::Migration
  def change
    add_column :templates, :groups_text_round4, :text
    add_column :templates, :groups_text_round5, :text
    add_column :templates, :groups_text_round6, :text
  end
end
