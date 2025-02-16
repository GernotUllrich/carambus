class AddAdminControlledToTournament < ActiveRecord::Migration[6.0]
  def change
    add_column :tournaments, :admin_controlled, :boolean, null: false, default: false
  end
end
