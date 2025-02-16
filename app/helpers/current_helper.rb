module CurrentHelper

  def local_server?
    Carambus.config.carambus_api_url.present?
  end

end
