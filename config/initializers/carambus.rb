require 'ostruct'

module Carambus
  def self.config
    @config ||= begin
      yaml = YAML.load_file(Rails.root.join('config', 'carambus.yml'))
      settings = yaml['default'].merge(yaml[Rails.env] || {})
      OpenStruct.new(settings)
    end
  end

  def self.config=(new_config)
    @config = new_config
  end

  def self.save_config
    yaml = YAML.load_file(Rails.root.join('config', 'carambus.yml'))
    
    # Konvertiere die Werte zu Symbolen für konsistente Speicherung
    config_hash = @config.to_h.transform_keys(&:to_sym)
    
    # Stelle sicher, dass der Environment-Block existiert
    yaml[Rails.env] ||= {}
    
    # Update nur die geänderten Werte im Environment-Block
    config_hash.each do |key, value|
      if value != yaml['default'][key.to_s]  # Vergleiche mit default-Wert
        yaml[Rails.env][key.to_s] = value    # Speichere nur wenn abweichend
      else
        yaml[Rails.env].delete(key.to_s)     # Entferne wenn gleich default
      end
    end
    
    # Schreibe die aktualisierte YAML-Datei
    File.write(Rails.root.join('config', 'carambus.yml'), yaml.to_yaml)
  end
end 