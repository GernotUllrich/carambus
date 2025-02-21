class ConvertPartyDataFromYamlToJson < ActiveRecord::Migration[7.2]
  # Definiere eine temporäre Klasse, die direkt auf die `parties`-Tabelle zugreift und
  # damit die in app/models/party.rb vorhandene Serializer-Konfiguration umgeht.
  class RawParty < ActiveRecord::Base
    self.table_name = 'parties'
    self.inheritance_column = :_type_disabled # Disables STI for this model
  end

  def up
    Party.find_each do |party|
      # Lese den rohen, in der DB gespeicherten String (ohne Deserialisierung)
      %w{data remarks}.each do |key|
        raw_value = party.read_attribute_before_type_cast(key)
        next if raw_value.blank?

        begin
          # Umwandlung von YAML in ein Ruby-Objekt
          yaml_data = YAML.unsafe_load(raw_value).to_h
          # Erzeugen eines JSON-Strings aus dem Objekt
          json_str = JSON.generate(yaml_data)
        rescue StandardError => e
          raise "Fehler bei der Umwandlung von Party #{party.id}, #{key}: #{e.message}"
        end

        # Aktualisiere den Datenbankeintrag ohne Callbacks, direkt über SQL
        Party.where(id: party.id)
             .update_all("#{key} = '#{json_str.gsub("'", "''")}'")
      end
    end
  end

  def down
    Party.find_each do |party|
      raw_value = party.read_attribute_before_type_cast(key)
      next if raw_value.blank?

      begin
        # Von JSON-String zurück zu Ruby-Objekt
        json_data = JSON.parse(raw_value)
        # Zum YAML-String umwandeln
        yaml_str = YAML.dump(json_data)
      rescue StandardError => e
        raise "Fehler beim Rückumwandeln von Party #{party.id}, #{key}: #{e.message}"
      end

      Party.where(id: party.id)
           .update_all("#{key} = '#{yaml_str}'")
    end
  end
end
