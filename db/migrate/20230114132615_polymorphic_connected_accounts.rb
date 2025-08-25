class PolymorphicConnectedAccounts < ActiveRecord::Migration[7.0]
  StrongMigrations.disable_check(:rename_table)
  StrongMigrations.disable_check(:rename_column)
  disable_ddl_transaction!
  def change
safety_assured {
    # Only proceed if the source table exists and target table doesn't
    if table_exists?(:user_connected_accounts) && !table_exists?(:connected_accounts)
      # Only remove foreign key if it exists
      if foreign_key_exists?(:user_connected_accounts, column: :user_id)
    remove_foreign_key :user_connected_accounts, column: :user_id
      end

      # Only remove index if it exists
      if index_exists?(:user_connected_accounts, :user_id)
    remove_index :user_connected_accounts, column: :user_id
      end

    rename_table :user_connected_accounts, :connected_accounts
    rename_column :connected_accounts, :user_id, :owner_id
    add_column :connected_accounts, :owner_type, :string
    add_index :connected_accounts, [:owner_id, :owner_type], algorithm: :concurrently

      # Backfill existing connected accounts using SQL
      execute "UPDATE connected_accounts SET owner_type = 'User'"
    elsif table_exists?(:connected_accounts)
      # If the target table already exists, just ensure it has the right structure
      unless column_exists?(:connected_accounts, :owner_type)
        add_column :connected_accounts, :owner_type, :string
      end

      unless index_exists?(:connected_accounts, [:owner_id, :owner_type])
        add_index :connected_accounts, [:owner_id, :owner_type], algorithm: :concurrently
      end
    else
      # If neither table exists, create the target table
      create_table :connected_accounts do |t|
        t.integer :owner_id
        t.string :owner_type
        t.timestamps
      end

      add_index :connected_accounts, [:owner_id, :owner_type], algorithm: :concurrently
    end
}
  end
end
