class AddStateToSettings < ActiveRecord::Migration[5.2]
  def change
    add_column :settings, :state, :string, null: false, default: "startup"
  end
end
