class AddJtiToUsers < ActiveRecord::Migration[7.2]
  # Plan 13-06.2 / D-13-06.1-C: JWT-Token-Auth via devise-jwt mit JTIMatcher-Revocation.
  # `jti` (JWT ID) wird beim Sign-In automatisch gesetzt; alle Tokens mit anderem JTI
  # werden als revoked behandelt (Force-Logout, Logout-All-Devices).
  # NULLable: bestehende User ohne JWT-Login funktionieren weiter via Cookie-Pfad (Backwards-Compat).
  def change
    add_column :users, :jti, :string
    add_index :users, :jti
  end
end
