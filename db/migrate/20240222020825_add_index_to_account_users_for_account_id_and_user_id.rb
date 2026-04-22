class AddIndexToAccountUsersForAccountIdAndUserId < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!
  def change
    # Only execute if JumpStart Pro account_users table exists (legacy migration)
    return unless table_exists?(:account_users)

    add_index :account_users, [:account_id, :user_id], unique: true, algorithm: :concurrently

    # Remove redundant indexes
    remove_index :account_users, :account_id
    remove_index :account_users, :user_id
  end
end
