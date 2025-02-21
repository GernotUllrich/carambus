class ConvertSettingDataFromYamlToJson < ActiveRecord::Migration[7.2]
  # Definiere eine temporäre Klasse, die direkt auf die `settings`-Tabelle zugreift und
  # damit die in app/models/setting.rb vorhandene Serializer-Konfiguration umgeht.
  class RawSetting < ActiveRecord::Base
    self.table_name = "settings"
    self.inheritance_column = :_type_disabled # Disables STI for this model
  end

  def up
    Setting.find_each do |setting|
      # Lese den rohen, in der DB gespeicherten String (ohne Deserialisierung)
      raw_value = setting.read_attribute_before_type_cast("data")
      next if raw_value.blank?

      begin
        # Umwandlung von YAML in ein Ruby-Objekt
        yaml_data = YAML.unsafe_load(raw_value).to_h
        # Erzeugen eines JSON-Strings aus dem Objekt
        json_str = JSON.generate(yaml_data)
      rescue => e
        raise "Fehler bei der Umwandlung von Setting #{setting.id}: #{e.message}"
      end

      # Aktualisiere den Datenbankeintrag ohne Callbacks, direkt über SQL
      Setting.where(id: setting.id)
                  .update_all("data = '#{json_str.gsub("'", "''")}'")
      # setting.update_column("data", json_str)
    end
  end

  def down
    Setting.find_each do |setting|
      raw_value = setting.read_attribute_before_type_cast("data")
      next if raw_value.blank?

      begin
        # Von JSON-String zurück zu Ruby-Objekt
        json_data = JSON.parse(raw_value)
        # Zum YAML-String umwandeln
        yaml_str = YAML.dump(json_data)
      rescue => e
        raise "Fehler beim Rückumwandeln von Setting #{setting.id}: #{e.message}"
      end

      Setting.where(id: setting.id)
                  .update_all("data = '#{yaml_str}'")
      # setting.update_column("data", yaml_str)
    end
  end
end
