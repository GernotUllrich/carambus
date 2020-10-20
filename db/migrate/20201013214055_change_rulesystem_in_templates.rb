class ChangeRulesystemInTemplates < ActiveRecord::Migration
  def change
    change_column :templates, :rulesystem, :text
  end
end
