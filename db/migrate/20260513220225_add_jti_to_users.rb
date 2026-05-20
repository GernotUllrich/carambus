class AddJtiToUsers < ActiveRecord::Migration[7.2]
  # Plan 13-06.2 / D-13-06.1-C: JWT-Token-Auth via devise-jwt mit JTIMatcher-Revocation.
  # `jti` (JWT ID) wird beim Sign-In automatisch gesetzt; alle Tokens mit anderem JTI
  # werden als revoked behandelt (Force-Logout, Logout-All-Devices).
  # NULLable: bestehende User ohne JWT-Login funktionieren weiter via Cookie-Pfad (Backwards-Compat).
  #
  # strong_migrations-Compliance:
  # - disable_ddl_transaction! erforderlich für add_index :concurrently (Plan 13-06.2 Production-Befund)
  # - column_exists?/index_exists?-Guards machen die Migration idempotent (resilient gegen Re-Run nach Teil-Erfolg)
  disable_ddl_transaction!

  def up
    unless column_exists?(:users, :jti)
      add_column :users, :jti, :string
    end
    unless index_exists?(:users, :jti)
      add_index :users, :jti, algorithm: :concurrently
    end
  end

  def down
    if index_exists?(:users, :jti)
      remove_index :users, :jti, algorithm: :concurrently
    end
    if column_exists?(:users, :jti)
      remove_column :users, :jti
    end
  end
end
