class AddMissingFieldsToUsers < ActiveRecord::Migration[7.2]
  add_column :users, :otp_required_for_login, :boolean
  add_column :users, :otp_secret, :string
  add_column :users, :last_otp_timestep, :integer
  add_column :users, :otp_backup_codes, :text
  add_column :users, :code, :string
  add_column :users, :preferences, :jsonb
  add_column :users, :name, :string, as: "(((first_name)::text || ' '::text) || (COALESCE(last_name, ''::character varying))::text)", stored: true
  add_column :users, :role, :jsonb, default: 0
end
