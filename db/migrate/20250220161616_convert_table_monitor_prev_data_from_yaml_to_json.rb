class ConvertTableMonitorPrevDataFromYamlToJson < ActiveRecord::Migration[7.2]
  # Definiere eine temporäre Klasse, die direkt auf die `table_monitors`-Tabelle zugreift und
  # damit die in app/models/table_monitor.rb vorhandene Serializer-Konfiguration umgeht.
  class RawTableMonitor < ActiveRecord::Base
    self.table_name = "table_monitors"
    self.inheritance_column = :_type_disabled # Disables STI for this model
  end

  def up
    TableMonitor.find_each do |table_monitor|
      # Lese den rohen, in der DB gespeicherten String (ohne Deserialisierung)
      raw_value = table_monitor.read_attribute_before_type_cast("prev_data")
      next if raw_value.blank?

      begin
        # Umwandlung von YAML in ein Ruby-Objekt
        yaml_data = YAML.unsafe_load(raw_value).to_h
        # Erzeugen eines JSON-Strings aus dem Objekt
        json_str = JSON.generate(yaml_data)
      rescue => e
        raise "Fehler bei der Umwandlung von TableMonitor #{table_monitor.id}: #{e.message}"
      end

      # Aktualisiere den Datenbankeintrag ohne Callbacks, direkt über SQL
      TableMonitor.where(id: table_monitor.id)
                  .update_all("prev_data = '#{json_str.gsub("'", "''")}'")
      # table_monitor.update_column("data", json_str)
    end
  end

  def down
    TableMonitor.find_each do |table_monitor|
      raw_value = table_monitor.read_attribute_before_type_cast("prev_data")
      next if raw_value.blank?

      begin
        # Von JSON-String zurück zu Ruby-Objekt
        json_data = JSON.parse(raw_value)
        # Zum YAML-String umwandeln
        yaml_str = YAML.dump(json_data)
      rescue => e
        raise "Fehler beim Rückumwandeln von TableMonitor #{table_monitor.id}: #{e.message}"
      end

      TableMonitor.where(id: table_monitor.id)
                  .update_all("prev_data = '#{yaml_str}'")
      # table_monitor.update_column("prev_data", yaml_str)
    end
  end
end
