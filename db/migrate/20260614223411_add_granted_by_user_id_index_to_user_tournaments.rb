class AddGrantedByUserIdIndexToUserTournaments < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_index :user_tournaments, :granted_by_user_id, algorithm: :concurrently
  end
end
