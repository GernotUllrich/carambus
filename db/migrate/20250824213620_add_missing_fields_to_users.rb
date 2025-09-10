class AddMissingFieldsToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :otp_required_for_login, :boolean unless column_exists?(:users, :otp_required_for_login)
    add_column :users, :otp_secret, :string unless column_exists?(:users, :otp_secret)
    add_column :users, :last_otp_timestep, :integer unless column_exists?(:users, :last_otp_timestep)
    add_column :users, :otp_backup_codes, :text unless column_exists?(:users, :otp_backup_codes)
    add_column :users, :code, :string unless column_exists?(:users, :code)
    add_column :users, :preferences, :jsonb unless column_exists?(:users, :preferences)
    add_column :users, :name, :string, as: "(((first_name)::text || ' '::text) || (COALESCE(last_name, ''::character varying))::text)", stored: true unless column_exists?(:users, :name)
    add_column :users, :role, :jsonb, default: 0 unless column_exists?(:users, :role)
  end
end
