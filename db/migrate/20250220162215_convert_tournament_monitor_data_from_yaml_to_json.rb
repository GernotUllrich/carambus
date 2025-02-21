class ConvertTournamentMonitorDataFromYamlToJson < ActiveRecord::Migration[7.2]
  # Definiere eine temporäre Klasse, die direkt auf die `tournament_monitorss`-Tabelle zugreift und
  # damit die in app/models/tournament_monitors.rb vorhandene Serializer-Konfiguration umgeht.
  class RawTournamentMonitor < ActiveRecord::Base
    self.table_name = "tournament_monitorss"
    self.inheritance_column = :_type_disabled # Disables STI for this model
  end

  def up
    TournamentMonitor.find_each do |tournament_monitors|
      # Lese den rohen, in der DB gespeicherten String (ohne Deserialisierung)
      raw_value = tournament_monitors.read_attribute_before_type_cast("prev_data")
      next if raw_value.blank?

      begin
        # Umwandlung von YAML in ein Ruby-Objekt
        yaml_data = YAML.unsafe_load(raw_value).to_h
        # Erzeugen eines JSON-Strings aus dem Objekt
        json_str = JSON.generate(yaml_data)
      rescue => e
        raise "Fehler bei der Umwandlung von TournamentMonitor #{tournament_monitors.id}: #{e.message}"
      end

      # Aktualisiere den Datenbankeintrag ohne Callbacks, direkt über SQL
      TournamentMonitor.where(id: tournament_monitors.id)
                .update_all("prev_data = '#{json_str.gsub("'", "''")}'")
      # tournament_monitors.update_column("data", json_str)
    end
  end

  def down
    TournamentMonitor.find_each do |tournament_monitors|
      raw_value = tournament_monitors.read_attribute_before_type_cast("prev_data")
      next if raw_value.blank?

      begin
        # Von JSON-String zurück zu Ruby-Objekt
        json_data = JSON.parse(raw_value)
        # Zum YAML-String umwandeln
        yaml_str = YAML.dump(json_data)
      rescue => e
        raise "Fehler beim Rückumwandeln von TournamentMonitor #{tournament_monitors.id}: #{e.message}"
      end

      TournamentMonitor.where(id: tournament_monitors.id)
                .update_all("prev_data = '#{yaml_str}'")
      # tournament_monitors.update_column("prev_data", yaml_str)
    end
  end
end
