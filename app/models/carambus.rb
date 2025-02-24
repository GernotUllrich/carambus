# frozen_string_literal: true

class Carambus
  attr_accessor :carambus_api_url, :location_id, :application_name, :support_email,
                :business_name, :business_address, :carambus_domain, :queue_adapter

  def initialize
    @carambus_api_url = ENV.fetch('CARAMBUS_API_URL', 'https://api.carambus.de/')
    @location_id = ENV.fetch('CARAMBUS_LOCATION_ID', '1')
    @application_name = ENV.fetch('CARAMBUS_APPLICATION_NAME', 'Carambus')
    @support_email = ENV.fetch('CARAMBUS_SUPPORT_EMAIL', 'gernot.ullrich@gmx.de')
    @business_name = ENV.fetch('CARAMBUS_BUISINESS_NAME', 'Ullrich IT Consulting')
    @business_address = ENV.fetch('CARAMBUS_BUISINESS_ADDRESS', '22869 Schenefeld, Sandstückenweg 15')
    @carambus_domain = ENV.fetch('CARAMBUS_DOMAIN', 'carambus.de')
    @queue_adapter = ENV.fetch('CARAMBUS_QUEUE_ADAPTER', 'async')
  end

  def self.config
    @config ||= Carambus.new
  end
end
