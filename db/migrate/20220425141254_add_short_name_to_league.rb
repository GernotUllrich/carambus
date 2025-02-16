class AddShortNameToLeague < ActiveRecord::Migration[6.1]
  def change
    add_column :leagues, :shortname, :string
    add_column :league_ccs, :shortname, :string
    add_column :league_ccs, :status, :string
    add_column :league_ccs, :report_form, :string
    add_column :league_ccs, :report_form_data, :string
  end
end
