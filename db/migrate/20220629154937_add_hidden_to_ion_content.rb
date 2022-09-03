class AddHiddenToIonContent < ActiveRecord::Migration[6.1]
  def change
    add_column :ion_contents, :hidden, :boolean, null: false, default: false
  end
end
