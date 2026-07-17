class AddGrantedByUserIdToUserTournaments < ActiveRecord::Migration[7.2]
  def change
    add_column :user_tournaments, :granted_by_user_id, :bigint
  end
end
