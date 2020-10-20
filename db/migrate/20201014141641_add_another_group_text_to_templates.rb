class AddAnotherGroupTextToTemplates < ActiveRecord::Migration
  def change
    add_column :templates, :groups_text_round7, :text
  end
end
