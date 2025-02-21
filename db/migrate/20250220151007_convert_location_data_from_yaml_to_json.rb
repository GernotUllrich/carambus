class ConvertLocationDataFromYamlToJson < ActiveRecord::Migration[7.2]
  # Definiere eine temporäre Klasse, die direkt auf die `locations`-Tabelle zugreift und
  # damit die in app/models/location.rb vorhandene Serializer-Konfiguration umgeht.
  class RawLocation < ActiveRecord::Base
    self.table_name = 'locations'
    self.inheritance_column = :_type_disabled # Disables STI for this model
  end

  def up
    Location.find_each do |location|
      # Lese den rohen, in der DB gespeicherten String (ohne Deserialisierung)
      raw_value = location.read_attribute_before_type_cast("data")
      next if raw_value.blank?

      begin
        # Umwandlung von YAML in ein Ruby-Objekt
        yaml_data = YAML.unsafe_load(raw_value).to_h
        # Erzeugen eines JSON-Strings aus dem Objekt
        json_str = JSON.generate(yaml_data)
      rescue StandardError => e
        raise "Fehler bei der Umwandlung von Location #{location.id}: #{e.message}"
      end

      # Aktualisiere den Datenbankeintrag ohne Callbacks, direkt über SQL
      Location.where(id: location.id)
                .update_all("data = '#{json_str.gsub("'", "''")}'")
      #location.update_column("data", json_str)
    end
  end

  def down
    Location.find_each do |location|
      raw_value = location.read_attribute_before_type_cast("data")
      next if raw_value.blank?

      begin
        # Von JSON-String zurück zu Ruby-Objekt
        json_data = JSON.parse(raw_value)
        # Zum YAML-String umwandeln
        yaml_str = YAML.dump(json_data)
      rescue StandardError => e
        raise "Fehler beim Rückumwandeln von Location #{location.id}: #{e.message}"
      end

      Location.where(id: location.id)
                .update_all("data = '#{yaml_str}'")
      # location.update_column("data", yaml_str)
    end
  end
end
