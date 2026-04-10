require "test_helper"

class CurrentHelperTest < ActionView::TestCase
  # CurrentHelper provides local_server? based on Carambus config.
  # Controller-level current_user/current_account methods are not part of this helper.

  test "local_server? returns false when carambus_api_url is blank" do
    Carambus.config.stub(:carambus_api_url, "") do
      assert_equal false, local_server?
    end
  end

  test "local_server? returns true when carambus_api_url is present" do
    Carambus.config.stub(:carambus_api_url, "https://api.carambus.de") do
      assert_equal true, local_server?
    end
  end
end
