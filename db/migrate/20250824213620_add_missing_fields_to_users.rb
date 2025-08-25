class AddMissingFieldsToUsers < ActiveRecord::Migration[7.2]
  def change
    # Add OTP-related fields
    add_column :users, :otp_required_for_login, :boolean
    add_column :users, :otp_secret, :string
    add_column :users, :last_otp_timestep, :integer
    add_column :users, :otp_backup_codes, :text

    # Add role field
    add_column :users, :role, :integer, default: 0

    # Add last_ba_sync_date to tournaments
    add_column :tournaments, :last_ba_sync_date, :datetime

    # Add tournament_id to party_games
    add_column :party_games, :tournament_id, :integer

    # Create the generated name column using SQL
    safety_assured do
      execute <<-SQL
        ALTER TABLE users ADD COLUMN name character varying 
        GENERATED ALWAYS AS (
          (first_name::text || ' '::text) || COALESCE(last_name, ''::character varying)::text
        ) STORED
      SQL
    end
  end
end
