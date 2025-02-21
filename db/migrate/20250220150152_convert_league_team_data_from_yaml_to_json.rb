class ConvertLeagueTeamDataFromYamlToJson < ActiveRecord::Migration[7.2]
  # Definiere eine temporäre Klasse, die direkt auf die `league_teams`-Tabelle zugreift und
  # damit die in app/models/league_team.rb vorhandene Serializer-Konfiguration umgeht.
  class RawLeagueTeam < ActiveRecord::Base
    self.table_name = 'league_teams'
    self.inheritance_column = :_type_disabled # Disables STI for this model
  end

  def up
    LeagueTeam.find_each do |league_team|
      # Lese den rohen, in der DB gespeicherten String (ohne Deserialisierung)
      raw_value = league_team.read_attribute_before_type_cast("data")
      next if raw_value.blank?

      begin
        # Umwandlung von YAML in ein Ruby-Objekt
        yaml_data = YAML.unsafe_load(raw_value).to_h
        # Erzeugen eines JSON-Strings aus dem Objekt
        json_str = JSON.generate(yaml_data)
      rescue StandardError => e
        raise "Fehler bei der Umwandlung von LeagueTeam #{league_team.id}: #{e.message}"
      end

      # Aktualisiere den Datenbankeintrag ohne Callbacks, direkt über SQL
      LeagueTeam.where(id: league_team.id)
               .update_all("data = '#{json_str.gsub("'", "''")}'")
      #league_team.update_column("data", json_str)
    end
  end

  def down
    LeagueTeam.find_each do |league_team|
      raw_value = league_team.read_attribute_before_type_cast("data")
      next if raw_value.blank?

      begin
        # Von JSON-String zurück zu Ruby-Objekt
        json_data = JSON.parse(raw_value)
        # Zum YAML-String umwandeln
        yaml_str = YAML.dump(json_data)
      rescue StandardError => e
        raise "Fehler beim Rückumwandeln von LeagueTeam #{league_team.id}: #{e.message}"
      end

      LeagueTeam.where(id: league_team.id)
               .update_all("data = '#{yaml_str}'")
      # league_team.update_column("data", yaml_str)
    end
  end
end
