class ConvertGameDataFromYamlToJson < ActiveRecord::Migration[7.2]
  # Definiere eine temporäre Klasse, die direkt auf die `games`-Tabelle zugreift und
  # damit die in app/models/game.rb vorhandene Serializer-Konfiguration umgeht.
  class RawGame < ActiveRecord::Base
    self.table_name = 'games'
  end

  def up
    RawGame.find_each do |game|
      # Lese den rohen, in der DB gespeicherten String (ohne Deserialisierung)
      raw_value = game.read_attribute_before_type_cast("data")
      next if raw_value.blank?

      begin
        # Umwandlung von YAML in ein Ruby-Objekt
        yaml_data = YAML.unsafe_load(raw_value).to_h
        # Erzeugen eines JSON-Strings aus dem Objekt
        json_str = JSON.generate(yaml_data)
      rescue StandardError => e
        raise "Fehler bei der Umwandlung von Game #{game.id}: #{e.message}"
      end

      # Aktualisiere den Datenbankeintrag ohne Callbacks, direkt über SQL
      game.update_column("data", json_str)
    end
  end

  def down
    RawGame.find_each do |game|
      raw_value = game.read_attribute_before_type_cast("data")
      next if raw_value.blank?

      begin
        # Von JSON-String zurück zu Ruby-Objekt
        json_data = JSON.parse(raw_value)
        # Zum YAML-String umwandeln
        yaml_str = YAML.dump(json_data)
      rescue StandardError => e
        raise "Fehler beim Rückumwandeln von Game #{game.id}: #{e.message}"
      end

      game.update_column("data", yaml_str)
    end
  end
end
