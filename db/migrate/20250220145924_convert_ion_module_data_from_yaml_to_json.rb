class ConvertIonModuleDataFromYamlToJson < ActiveRecord::Migration[7.2]
  # Definiere eine temporäre Klasse, die direkt auf die `ion_modules`-Tabelle zugreift und
  # damit die in app/models/ion_module.rb vorhandene Serializer-Konfiguration umgeht.
  class RawIonModule < ActiveRecord::Base
    self.table_name = 'ion_modules'
    self.inheritance_column = :_type_disabled # Disables STI for this model
  end

  def up
    IonModule.find_each do |ion_module|
      # Lese den rohen, in der DB gespeicherten String (ohne Deserialisierung)
      raw_value = ion_module.read_attribute_before_type_cast("data")
      next if raw_value.blank?

      begin
        # Umwandlung von YAML in ein Ruby-Objekt
        yaml_data = YAML.unsafe_load(raw_value).to_h
        # Erzeugen eines JSON-Strings aus dem Objekt
        json_str = JSON.generate(yaml_data)
      rescue StandardError => e
        raise "Fehler bei der Umwandlung von IonModule #{ion_module.id}: #{e.message}"
      end

      # Aktualisiere den Datenbankeintrag ohne Callbacks, direkt über SQL
      IonModule.where(id: ion_module.id)
                .update_all("data = '#{json_str.gsub("'", "''")}'")
      #ion_module.update_column("data", json_str)
    end
  end

  def down
    IonModule.find_each do |ion_module|
      raw_value = ion_module.read_attribute_before_type_cast("data")
      next if raw_value.blank?

      begin
        # Von JSON-String zurück zu Ruby-Objekt
        json_data = JSON.parse(raw_value)
        # Zum YAML-String umwandeln
        yaml_str = YAML.dump(json_data)
      rescue StandardError => e
        raise "Fehler beim Rückumwandeln von IonModule #{ion_module.id}: #{e.message}"
      end

      IonModule.where(id: ion_module.id)
                .update_all("data = '#{yaml_str}'")
      # ion_module.update_column("data", yaml_str)
    end
  end
end
