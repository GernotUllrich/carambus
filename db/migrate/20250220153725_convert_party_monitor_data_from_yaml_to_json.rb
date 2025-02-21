class ConvertPartyMonitorDataFromYamlToJson < ActiveRecord::Migration[7.2]
  # Definiere eine temporäre Klasse, die direkt auf die `party_monitors`-Tabelle zugreift und
  # damit die in app/models/party_monitor.rb vorhandene Serializer-Konfiguration umgeht.
  class RawPartyMonitor < ActiveRecord::Base
    self.table_name = "party_monitors"
    self.inheritance_column = :_type_disabled # Disables STI for this model
  end

  def up
    PartyMonitor.find_each do |party_monitor|
      # Lese den rohen, in der DB gespeicherten String (ohne Deserialisierung)
      raw_value = party_monitor.read_attribute_before_type_cast("data")
      next if raw_value.blank?

      begin
        # Umwandlung von YAML in ein Ruby-Objekt
        yaml_data = YAML.unsafe_load(raw_value).to_h
        # Erzeugen eines JSON-Strings aus dem Objekt
        json_str = JSON.generate(yaml_data)
      rescue => e
        raise "Fehler bei der Umwandlung von PartyMonitor #{party_monitor.id}: #{e.message}"
      end

      # Aktualisiere den Datenbankeintrag ohne Callbacks, direkt über SQL
      PartyMonitor.where(id: party_monitor.id)
        .update_all("data = '#{json_str.gsub("'", "''")}'")
      # party_monitor.update_column("data", json_str)
    end
  end

  def down
    PartyMonitor.find_each do |party_monitor|
      raw_value = party_monitor.read_attribute_before_type_cast("data")
      next if raw_value.blank?

      begin
        # Von JSON-String zurück zu Ruby-Objekt
        json_data = JSON.parse(raw_value)
        # Zum YAML-String umwandeln
        yaml_str = YAML.dump(json_data)
      rescue => e
        raise "Fehler beim Rückumwandeln von PartyMonitor #{party_monitor.id}: #{e.message}"
      end

      PartyMonitor.where(id: party_monitor.id)
        .update_all("data = '#{yaml_str}'")
      # party_monitor.update_column("data", yaml_str)
    end
  end
end
