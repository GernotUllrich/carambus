class ConvertPartyGameDataFromYamlToJson < ActiveRecord::Migration[7.2]
  # Definiere eine temporäre Klasse, die direkt auf die `party_games`-Tabelle zugreift und
  # damit die in app/models/party_game.rb vorhandene Serializer-Konfiguration umgeht.
  class RawPartyGame < ActiveRecord::Base
    self.table_name = 'party_games'
    self.inheritance_column = :_type_disabled # Disables STI for this model
  end

  def up
    PartyGame.find_each do |party_game|
      # Lese den rohen, in der DB gespeicherten String (ohne Deserialisierung)
      raw_value = party_game.read_attribute_before_type_cast("data")
      next if raw_value.blank?

      begin
        # Umwandlung von YAML in ein Ruby-Objekt
        yaml_data = YAML.unsafe_load(raw_value).to_h
        # Erzeugen eines JSON-Strings aus dem Objekt
        json_str = JSON.generate(yaml_data)
      rescue StandardError => e
        raise "Fehler bei der Umwandlung von PartyGame #{party_game.id}: #{e.message}"
      end

      # Aktualisiere den Datenbankeintrag ohne Callbacks, direkt über SQL
      PartyGame.where(id: party_game.id)
             .update_all("data = '#{json_str.gsub("'", "''")}'")
      #party_game.update_column("data", json_str)
    end
  end

  def down
    PartyGame.find_each do |party_game|
      raw_value = party_game.read_attribute_before_type_cast("data")
      next if raw_value.blank?

      begin
        # Von JSON-String zurück zu Ruby-Objekt
        json_data = JSON.parse(raw_value)
        # Zum YAML-String umwandeln
        yaml_str = YAML.dump(json_data)
      rescue StandardError => e
        raise "Fehler beim Rückumwandeln von PartyGame #{party_game.id}: #{e.message}"
      end

      PartyGame.where(id: party_game.id)
             .update_all("data = '#{yaml_str}'")
      # party_game.update_column("data", yaml_str)
    end
  end
end
