# frozen_string_literal: true

require "test_helper"

class CurrentHelperTest < ActionView::TestCase
  test "local_server? returns false when carambus_api_url is blank" do
    original = Carambus.config.carambus_api_url
    Carambus.config.carambus_api_url = nil
    assert_not local_server?, "local_server? should be false when carambus_api_url is blank"
  ensure
    Carambus.config.carambus_api_url = original
  end

  test "local_server? returns true when carambus_api_url is set" do
    original = Carambus.config.carambus_api_url
    Carambus.config.carambus_api_url = "https://api.example.com"
    assert local_server?, "local_server? should be true when carambus_api_url is present"
  ensure
    Carambus.config.carambus_api_url = original
  end
end
