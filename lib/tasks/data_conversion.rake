class RawGame < ActiveRecord::Base
  self.table_name = 'games'
end

namespace :data do
  desc 'Convert remaining YAML-encoded game data to JSON'
  task convert_yaml_to_json: :environment do

    RawGame.find_each do |game|
      # Lese den rohen, in der DB gespeicherten String (ohne Deserialisierung)
      raw_value = game.read_attribute_before_type_cast("data")
      next if raw_value.blank?
      next unless raw_value =~ /^---/

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
end
