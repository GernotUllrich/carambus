class AddCollumnsToTemplates < ActiveRecord::Migration
  def change
    add_column :templates,:more_description, :text
    add_column :templates,:even_more_description, :text
    add_column :templates,:groups_text_round1, :text
    add_column :templates,:groups_text_round2, :text
    add_column :templates,:groups_text_round3, :text
    add_column :templates,:finals_text_round1, :text
    add_column :templates,:finals_text_round2, :text
    add_column :templates,:finals_text_round3, :text
    add_column :templates,:finals_text_round4, :text
    add_column :templates, :executor_class, :string
    add_column :templates, :executor_params, :text
  end
end
