class ConvertIonContentDataFromYamlToJson < ActiveRecord::Migration[7.2]
  # Definiere eine temporäre Klasse, die direkt auf die `ion_contents`-Tabelle zugreift und
  # damit die in app/models/ion_content.rb vorhandene Serializer-Konfiguration umgeht.
  class RawIonContent < ActiveRecord::Base
    self.table_name = 'ion_contents'
    self.inheritance_column = :_type_disabled # Disables STI for this model
  end

  def up
    IonContent.find_each do |ion_content|
      # Lese den rohen, in der DB gespeicherten String (ohne Deserialisierung)
      raw_value = ion_content.read_attribute_before_type_cast("data")
      next if raw_value.blank?

      begin
        # Umwandlung von YAML in ein Ruby-Objekt
        yaml_data = YAML.unsafe_load(raw_value).to_h
        # Erzeugen eines JSON-Strings aus dem Objekt
        json_str = JSON.generate(yaml_data)
      rescue StandardError => e
        raise "Fehler bei der Umwandlung von IonContent #{ion_content.id}: #{e.message}"
      end

      # Aktualisiere den Datenbankeintrag ohne Callbacks, direkt über SQL
      IonContent.where(id: ion_content.id)
                .update_all("data = '#{json_str.gsub("'", "''")}'")
      #ion_content.update_column("data", json_str)
    end
  end

  def down
    IonContent.find_each do |ion_content|
      raw_value = ion_content.read_attribute_before_type_cast("data")
      next if raw_value.blank?

      begin
        # Von JSON-String zurück zu Ruby-Objekt
        json_data = JSON.parse(raw_value)
        # Zum YAML-String umwandeln
        yaml_str = YAML.dump(json_data)
      rescue StandardError => e
        raise "Fehler beim Rückumwandeln von IonContent #{ion_content.id}: #{e.message}"
      end

      IonContent.where(id: ion_content.id)
                .update_all("data = '#{yaml_str}'")
      # ion_content.update_column("data", yaml_str)
    end
  end
end
