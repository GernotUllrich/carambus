class ConvertTournamentDataFromYamlToJson < ActiveRecord::Migration[7.2]
  # Definiere eine temporäre Klasse, die direkt auf die `tournamentss`-Tabelle zugreift und
  # damit die in app/models/tournaments.rb vorhandene Serializer-Konfiguration umgeht.
  class RawTournament < ActiveRecord::Base
    self.table_name = "tournamentss"
    self.inheritance_column = :_type_disabled # Disables STI for this model
  end

  def up
    Tournament.find_each do |tournaments|
      # Lese den rohen, in der DB gespeicherten String (ohne Deserialisierung)
      raw_value = tournaments.read_attribute_before_type_cast("prev_data")
      next if raw_value.blank?

      begin
        # Umwandlung von YAML in ein Ruby-Objekt
        yaml_data = YAML.unsafe_load(raw_value).to_h
        # Erzeugen eines JSON-Strings aus dem Objekt
        json_str = JSON.generate(yaml_data)
      rescue => e
        raise "Fehler bei der Umwandlung von Tournament #{tournaments.id}: #{e.message}"
      end

      # Aktualisiere den Datenbankeintrag ohne Callbacks, direkt über SQL
      Tournament.where(id: tournaments.id)
                  .update_all("prev_data = '#{json_str.gsub("'", "''")}'")
      # tournaments.update_column("data", json_str)
    end
  end

  def down
    Tournament.find_each do |tournaments|
      raw_value = tournaments.read_attribute_before_type_cast("prev_data")
      next if raw_value.blank?

      begin
        # Von JSON-String zurück zu Ruby-Objekt
        json_data = JSON.parse(raw_value)
        # Zum YAML-String umwandeln
        yaml_str = YAML.dump(json_data)
      rescue => e
        raise "Fehler beim Rückumwandeln von Tournament #{tournaments.id}: #{e.message}"
      end

      Tournament.where(id: tournaments.id)
                  .update_all("prev_data = '#{yaml_str}'")
      # tournaments.update_column("prev_data", yaml_str)
    end
  end
end
