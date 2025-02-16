obsolete_migrations = `rails db:migrate:status`.split("\n").select { |line| line.include?("NO FILE") }

versions = obsolete_migrations.map { |migration| migration.split[1] }
new_migration_name = "remove_obsolete_migrations"
system("rails generate migration #{new_migration_name}")
latest_migration = Dir.glob("db/migrate/*#{new_migration_name}.rb").first
File.open(latest_migration, 'w') do |file|
  file.puts <<-RUBY
class #{new_migration_name.camelize} < ActiveRecord::Migration[6.1]
  def up
    safety_assured do
      execute "DELETE FROM schema_migrations WHERE version in ( '#{versions.join("', '")}' )" 
    end  
  end

  def down
    raise ActiveRecord::IrreversibleMigration 
  end
end
  RUBY
end

system("rails db:migrate")

# system("rails db:schema:dump")

