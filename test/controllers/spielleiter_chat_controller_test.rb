# frozen_string_literal: true

require "test_helper"

# Der Carambus-Assistent (Chat) ist NUR auf Local-Servern freigegeben. Auf der zentralen
# Authority (api.carambus.de, carambus_api_url blank) ist er hart geblockt (2026-06-20):
# der Server ist nicht für die Allgemeinheit bestimmt, CC-Schreibaktionen liefen dort
# fehl-attribuiert (Phase 39), persönliche Anfragen funktionieren dort ohnehin nicht.
class SpielleiterChatControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @orig_api_url = Carambus.config.carambus_api_url
  end

  teardown do
    Carambus.config.carambus_api_url = @orig_api_url
  end

  test "Authority (carambus_api_url blank): GET /chat wird geblockt → Redirect zu root" do
    Carambus.config.carambus_api_url = nil
    sign_in @user
    get spielleiter_chat_path
    assert_redirected_to root_path
    assert_equal "Der Carambus-Assistent steht auf diesem Server nicht zur Verfügung.", flash[:alert]
  end
end
