class ConvertGameParticipationDataFromYamlToJson < ActiveRecord::Migration[7.2]
  # Definiere eine temporäre Klasse, die direkt auf die `game_participations`-Tabelle zugreift und
  # damit die in app/models/game_participation.rb vorhandene Serializer-Konfiguration umgeht.
  class RawGameParticipation < ActiveRecord::Base
    self.table_name = 'game_participations'
    self.inheritance_column = :_type_disabled # Disables STI for this model
  end

  def up
    GameParticipation.find_each do |game_participation|
      # Lese den rohen, in der DB gespeicherten String (ohne Deserialisierung)
      raw_value = game_participation.read_attribute_before_type_cast("data")
      next if raw_value.blank?

      begin
        # Umwandlung von YAML in ein Ruby-Objekt
        yaml_data = YAML.unsafe_load(raw_value).to_h
        # Erzeugen eines JSON-Strings aus dem Objekt
        json_str = JSON.generate(yaml_data)
      rescue StandardError => e
        raise "Fehler bei der Umwandlung von GameParticipation #{game_participation.id}: #{e.message}"
      end

      # Aktualisiere den Datenbankeintrag ohne Callbacks, direkt über SQL
      GameParticipation.where(id: game_participation.id)
              .update_all("data = '#{json_str.gsub("'", "''")}'")
      #game_participation.update_column("data", json_str)
    end
  end

  def down
    GameParticipation.find_each do |game_participation|
      raw_value = game_participation.read_attribute_before_type_cast("data")
      next if raw_value.blank?

      begin
        # Von JSON-String zurück zu Ruby-Objekt
        json_data = JSON.parse(raw_value)
        # Zum YAML-String umwandeln
        yaml_str = YAML.dump(json_data)
      rescue StandardError => e
        raise "Fehler beim Rückumwandeln von GameParticipation #{game_participation.id}: #{e.message}"
      end

      GameParticipation.where(id: game_participation.id)
              .update_all("data = '#{yaml_str}'")
      # game_participation.update_column("data", yaml_str)
    end
  end
end
