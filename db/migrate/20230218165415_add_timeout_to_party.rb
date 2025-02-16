class AddTimeoutToParty < ActiveRecord::Migration[7.0]
  def change
    add_column :parties, :timeout, :integer, default: 0, null: false
    add_column :parties, :timeouts, :integer
    add_column :party_monitors, :timeout, :integer, default: 0, null: false
    add_column :party_monitors, :timeouts, :integer
  end
end
