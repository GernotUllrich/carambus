class CreateBaselineFromProductionBase20221012 < ActiveRecord::Migration[7.2]
  def up
    # Load the baseline schema from the extracted SQL file using psql
    schema_file = Rails.root.join('db', 'schema_baseline_20221012')

    if File.exist?(schema_file)
      # Use psql to load the schema directly
      safety_assured do
        # Get database configuration
        config = ActiveRecord::Base.connection_db_config.configuration_hash

        # Build psql command - use current user if username is not set
        host = config[:host] || 'localhost'
        port = config[:port] || 5432
        database = config[:database]
        username = config[:username] || ENV['USER'] || 'gullrich'

        # Execute psql command
        psql_cmd = "psql -h #{host} -p #{port} -U #{username} -d #{database} -f #{schema_file}"

        # Debug: Log the command
        Rails.logger.info "Executing psql command: #{psql_cmd}"

        # Set PGPASSWORD environment variable if password is provided
        if config[:password]
          ENV['PGPASSWORD'] = config[:password]
        end

        # Execute the command
        result = system(psql_cmd)

        if result
          Rails.logger.info "Baseline schema loaded successfully from #{schema_file}"
        else
          raise "Failed to load baseline schema from #{schema_file}"
        end
      end
    else
      raise "Baseline schema file not found: #{schema_file}"
    end
  end

  def down
    # This migration cannot be rolled back as it creates the baseline
    # Rolling back would destroy the entire database structure
    raise ActiveRecord::IrreversibleMigration, "Cannot rollback baseline migration"
  end
end
