# frozen_string_literal: true

require "test_helper"

# Phase 16 / 16-04 — Regression (Defer 18-03-D2): LocationsController#set_location darf bei einem
# ANONYMEN Request (kein current_user) NICHT mit NoMethodError abstuerzen, wenn User.scoreboard nil
# ist. In der Test-Env gibt User.scoreboard IMMER nil zurueck (user.rb: `unless Rails.env == "test"`),
# daher ist der vormalige `@user.errors`-Aufruf auf nil hier trivial reproduzierbar.
#
# set_location laeuft als erste before_action (vor jeder Action-Logik); ohne den nil-Guard wuerde
# der Request mit NoMethodError (nil.errors) 500en bzw. im Test die Exception werfen.
class LocationsSetLocationTest < ActionDispatch::IntegrationTest
  setup do
    @location = locations(:one)
  end

  test "anonymer show-Request wirft keinen set_location-NPE (nil scoreboard user)" do
    # Kein sign_in.
    get location_path(@location)
    assert_not_equal 500, response.status, "set_location darf nicht mit NPE 500en"
  end
end
