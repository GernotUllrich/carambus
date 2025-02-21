class ConvertMetaMapDataFromYamlToJson < ActiveRecord::Migration[7.2]
  # Definiere eine temporäre Klasse, die direkt auf die `meta_maps`-Tabelle zugreift und
  # damit die in app/models/meta_map.rb vorhandene Serializer-Konfiguration umgeht.
  class RawMetaMap < ActiveRecord::Base
    self.table_name = 'meta_maps'
    self.inheritance_column = :_type_disabled # Disables STI for this model
  end

  def up
    MetaMap.find_each do |meta_map|
      # Lese den rohen, in der DB gespeicherten String (ohne Deserialisierung)
      raw_value = meta_map.read_attribute_before_type_cast("data")
      next if raw_value.blank?

      begin
        # Umwandlung von YAML in ein Ruby-Objekt
        yaml_data = YAML.unsafe_load(raw_value).to_h
        # Erzeugen eines JSON-Strings aus dem Objekt
        json_str = JSON.generate(yaml_data)
      rescue StandardError => e
        raise "Fehler bei der Umwandlung von MetaMap #{meta_map.id}: #{e.message}"
      end

      # Aktualisiere den Datenbankeintrag ohne Callbacks, direkt über SQL
      MetaMap.where(id: meta_map.id)
              .update_all("data = '#{json_str.gsub("'", "''")}'")
      #meta_map.update_column("data", json_str)
    end
  end

  def down
    MetaMap.find_each do |meta_map|
      raw_value = meta_map.read_attribute_before_type_cast("data")
      next if raw_value.blank?

      begin
        # Von JSON-String zurück zu Ruby-Objekt
        json_data = JSON.parse(raw_value)
        # Zum YAML-String umwandeln
        yaml_str = YAML.dump(json_data)
      rescue StandardError => e
        raise "Fehler beim Rückumwandeln von MetaMap #{meta_map.id}: #{e.message}"
      end

      MetaMap.where(id: meta_map.id)
              .update_all("data = '#{yaml_str}'")
      # meta_map.update_column("data", yaml_str)
    end
  end
end
