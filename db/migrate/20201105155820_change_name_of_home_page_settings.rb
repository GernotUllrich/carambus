class ChangeNameOfSettings < ActiveRecord::Migration[5.2]
  def change
    rename_table :home_page_settings, :settings
  end
end
