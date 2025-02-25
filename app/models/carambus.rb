# frozen_string_literal: true

class Carambus
  attr_accessor :carambus_api_url, :location_id, :application_name, :support_email,
                :business_name, :business_address, :carambus_domain, :queue_adapter

  def initialize
    @config = load_yaml_config
  end

  def method_missing(method_name, *args)
    if method_name.to_s.end_with?('=')
      key = method_name.to_s.chomp('=')
      write_config(key, args.first)
    else
      @config[method_name.to_s]
    end
  end

  def respond_to_missing?(method_name, include_private = false)
    @config.key?(method_name.to_s.chomp('=')) || super
  end

  class << self
    def config
      @config ||= new
    end

    def reload_config!
      @config = new
    end
  end

  private

  def load_yaml_config
    YAML.load_file(Rails.root.join('config', 'carambus.yml'))['default']
  end

  def write_config(key, value)
    @config[key] = value
    yaml = YAML.load_file(Rails.root.join('config', 'carambus.yml'))
    yaml['default'][key] = value
    File.write(Rails.root.join('config', 'carambus.yml'), yaml.to_yaml)
  end
end
