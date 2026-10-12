# frozen_string_literal: true

require "test_helper"

# 2026-10-13: bc-wedel zeigte alle Scoreboards auf Englisch. Die carambus.yml dort hatte keinen
# scoreboard_locale; die Admin-Seite waehlte im Select deshalb die ERSTE Option vor —
# available_locales ist [:en, :de] — und das Speichern der Biathlon-Presets am 06.10. schrieb
# "en" mit. Das Select muss die WIRKSAME Sprache zeigen (Wert, sonst Standardsprache).
class Admin::SettingsLocaleTest < ActionDispatch::IntegrationTest
  setup do
    @original = Carambus.config.scoreboard_locale
    sign_in users(:system_admin)
  end

  teardown do
    Carambus.config.scoreboard_locale = @original
  end

  test "ohne gespeicherten Wert ist die Standardsprache vorausgewaehlt, nicht die erste Option" do
    Carambus.config.scoreboard_locale = nil

    get admin_settings_path

    assert_response :success
    assert_select "select[name='config[scoreboard_locale]'] option[selected][value='#{I18n.default_locale}']"
  end

  test "ein gespeicherter Wert bleibt vorausgewaehlt" do
    Carambus.config.scoreboard_locale = "en"

    get admin_settings_path

    assert_select "select[name='config[scoreboard_locale]'] option[selected][value='en']"
  end
end
