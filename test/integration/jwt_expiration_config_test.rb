# frozen_string_literal: true

require "test_helper"

# Plan 14-G.5 / D-14-G7: Smoke-Tests für Long-Lived-JWT-Token-Konfig.
# Verifiziert dass carambus.yml-Key gelesen wird und devise.rb-Initializer ohne Crash bootet.
class JwtExpirationConfigTest < ActiveSupport::TestCase
  test "Carambus.config respondiert auf jwt_expiration_days" do
    assert Carambus.config.respond_to?(:jwt_expiration_days),
      "Carambus.config muss jwt_expiration_days-Key haben (carambus.yml default-Block)"
  end

  test "Carambus.config.jwt_expiration_days ist Integer >= 30 (UX-Sanity)" do
    days = Carambus.config.jwt_expiration_days
    assert_kind_of Integer, days, "jwt_expiration_days muss Integer sein, ist: #{days.inspect}"
    assert days >= 30, "jwt_expiration_days muss >= 30 Tage sein für UX-Pragma (Token-Expiry-Invisible), ist: #{days}"
  end

  test "Carambus.config.jwt_expiration_days entspricht ROADMAP-Default (90)" do
    # carambus.yml default-Block hat jwt_expiration_days: 90.
    # Per-Environment-Override (carambus.yml development/test/production) kann anders sein —
    # dev/test sollte aber bei Default 90 bleiben.
    assert_equal 90, Carambus.config.jwt_expiration_days,
      "Default-Wert sollte 90 Tage sein (D-14-G7)"
  end

  test "Devise-Initializer evaluiert ohne Crash (Boot-Smoke)" do
    # Devise.setup-Block wird beim Rails-Boot evaluiert. Wenn der Initializer fehlerhaft
    # wäre, würde Rails-Boot crashen und dieser Test würde nie ausgeführt.
    assert defined?(Devise), "Devise muss geladen sein"
    assert User.devise_modules.include?(:jwt_authenticatable),
      "User muss :jwt_authenticatable include haben"
  end
end
