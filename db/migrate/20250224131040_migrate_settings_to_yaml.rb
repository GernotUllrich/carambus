class MigrateSettingsToYaml < ActiveRecord::Migration[7.0]
  def up
    return unless setting = Setting.first

    yaml_path = Rails.root.join('config', 'carambus.yml')
    yaml = YAML.load_file(yaml_path)

    # Migrate data hash
    setting.data.each do |key, value_hash|
      next if ['session_id', 'last_version_id'].include?(key)

      type, val = value_hash.to_a.flatten
      parsed_value = case type
                     when "Integer" then val.to_i
                     when "TrueClass", "FalseClass" then val == "true"
                     else val.to_s
                     end

      yaml['default'][key] = parsed_value
    end

    # Migrate model attributes
    %w[region_id club_id tournament_id].each do |attr|
      value = setting.send(attr)
      yaml['default'][attr] = value if value.present?
    end

    File.write(yaml_path, yaml.to_yaml)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
