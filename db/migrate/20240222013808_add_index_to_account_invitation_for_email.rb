class AddIndexToAccountInvitationForEmail < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!
  def change
    # Only execute if JumpStart Pro account_invitations table exists (legacy migration)
    return unless table_exists?(:account_invitations)

    add_index :account_invitations, [:account_id, :email], unique: true, algorithm: :concurrently

    # Remove redundant index
    remove_index :account_invitations, :account_id
  end
end
