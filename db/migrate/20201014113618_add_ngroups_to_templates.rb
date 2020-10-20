class AddNgroupsToTemplates < ActiveRecord::Migration
  def change
    add_column :templates, :ngroups, :integer, default: 2, null: false
  end
end
